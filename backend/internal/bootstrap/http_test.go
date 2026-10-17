package bootstrap_test

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/bootstrap"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/config"
)

const secret = "test-secret-test-secret-test-secret!!"

type api struct {
	t   *testing.T
	srv *httptest.Server
}

func newAPI(t *testing.T) *api {
	cfg := config.Config{Env: "test", Auth: config.AuthDev, DevJWTSecret: secret, RequestTimeout: 5 * time.Second, MaxBodyBytes: 1 << 20}
	deps := bootstrap.Deps{Config: cfg, Logger: slog.New(slog.NewTextHandler(io.Discard, nil)), Verifier: auth.NewDevVerifier(secret)}
	srv := httptest.NewServer(bootstrap.NewRouter(deps, bootstrap.NewServices(deps)))
	t.Cleanup(srv.Close)
	return &api{t: t, srv: srv}
}

func token(t *testing.T, sub string) string {
	tok, err := auth.IssueDevToken(secret, sub, sub+"@example.com", sub, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	return tok
}

func (a *api) do(method, path, tok string, body any, headers ...string) (*http.Response, map[string]any) {
	a.t.Helper()
	var rd io.Reader
	if s, ok := body.(string); ok {
		rd = strings.NewReader(s)
	} else if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	}
	req, _ := http.NewRequest(method, a.srv.URL+path, rd)
	if tok != "" {
		req.Header.Set("Authorization", "Bearer "+tok)
	}
	req.Header.Set("Content-Type", "application/json")
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		a.t.Fatal(err)
	}
	defer res.Body.Close()
	var out map[string]any
	_ = json.NewDecoder(res.Body).Decode(&out)
	return res, out
}

func expect(t *testing.T, res *http.Response, status int) {
	t.Helper()
	if res.StatusCode != status {
		t.Fatalf("%s %s: want %d, got %d", res.Request.Method, res.Request.URL.Path, status, res.StatusCode)
	}
}

func TestAuthIsRequiredAndProblemsAreRFC9457(t *testing.T) {
	a := newAPI(t)
	res, body := a.do("GET", "/v1/trips", "", nil)
	expect(t, res, 401)
	if res.Header.Get("Content-Type") != "application/problem+json" || body["code"] != "auth.missing_token" {
		t.Fatalf("problem body: %v %v", res.Header, body)
	}
	if res.Header.Get("X-Request-ID") == "" || body["requestId"] == "" {
		t.Fatal("request id must be returned")
	}
	res, body = a.do("GET", "/v1/trips", "not-a-jwt", nil)
	expect(t, res, 401)
	if body["code"] != "auth.invalid_token" {
		t.Fatal(body)
	}
}

func TestMeCreatesUserOnFirstSignIn(t *testing.T) {
	a := newAPI(t)
	res, me := a.do("GET", "/v1/me", token(t, "alice"), nil)
	expect(t, res, 200)
	if me["email"] != "alice@example.com" || me["id"] == "" {
		t.Fatal(me)
	}
	_, again := a.do("GET", "/v1/me", token(t, "alice"), nil)
	if again["id"] != me["id"] {
		t.Fatal("same subject must map to the same user")
	}
}

func TestTripLifecycleWithETags(t *testing.T) {
	a := newAPI(t)
	alice := token(t, "alice")
	id := uuid.NewString()
	trip := map[string]any{
		"id": id, "title": "China Winter Adventure 2026", "startDate": "2026-12-03", "endDate": "2026-12-13",
		"timeZone": "Asia/Shanghai", "travelerCount": 2, "currency": "thb", "totalBudget": 50000, "travelStyle": "balanced",
	}

	res, created := a.do("POST", "/v1/trips", alice, trip)
	expect(t, res, 201)
	if res.Header.Get("ETag") != `"1"` || res.Header.Get("Location") != "/v1/trips/"+id {
		t.Fatalf("headers: %v", res.Header)
	}
	if created["currency"] != "THB" || created["role"] != "owner" {
		t.Fatal(created)
	}
	res, _ = a.do("POST", "/v1/trips", alice, trip) // network retry
	expect(t, res, 200)

	res, _ = a.do("GET", "/v1/trips/"+id, alice, nil)
	expect(t, res, 200)
	res, _ = a.do("GET", "/v1/trips/"+id, alice, nil, "If-None-Match", `"1"`)
	expect(t, res, 304)

	trip["title"] = "China Winter 2026"
	res, body := a.do("PUT", "/v1/trips/"+id, alice, trip)
	expect(t, res, 428)
	if body["code"] != "trip.if_match_required" {
		t.Fatal(body)
	}
	res, body = a.do("PUT", "/v1/trips/"+id, alice, trip, "If-Match", `"1"`)
	expect(t, res, 200)
	if body["version"] != float64(2) || res.Header.Get("ETag") != `"2"` {
		t.Fatal(body)
	}
	res, body = a.do("PUT", "/v1/trips/"+id, alice, trip, "If-Match", `"1"`)
	expect(t, res, 412)
	if body["code"] != "trip.version_mismatch" {
		t.Fatal(body)
	}

	res, list := a.do("GET", "/v1/trips", alice, nil)
	expect(t, res, 200)
	if items := list["items"].([]any); len(items) != 1 {
		t.Fatal(list)
	}
	res, members := a.do("GET", "/v1/trips/"+id+"/members", alice, nil)
	expect(t, res, 200)
	if m := members["items"].([]any)[0].(map[string]any); m["role"] != "owner" {
		t.Fatal(members)
	}

	res, _ = a.do("DELETE", "/v1/trips/"+id, alice, nil, "If-Match", `"2"`)
	expect(t, res, 204)
	res, _ = a.do("GET", "/v1/trips/"+id, alice, nil)
	expect(t, res, 404)
}

func TestOtherUsersCannotSeeOrTouchATrip(t *testing.T) {
	a := newAPI(t)
	res, created := a.do("POST", "/v1/trips", token(t, "alice"), map[string]any{"title": "Mine"})
	expect(t, res, 201)
	id := created["id"].(string)
	bob := token(t, "bob")
	res, _ = a.do("GET", "/v1/trips/"+id, bob, nil)
	expect(t, res, 404)
	res, _ = a.do("PUT", "/v1/trips/"+id, bob, map[string]any{"title": "Hacked"}, "If-Match", `"1"`)
	expect(t, res, 404)
	res, _ = a.do("DELETE", "/v1/trips/"+id, bob, nil)
	expect(t, res, 404)
	res, _ = a.do("GET", "/v1/trips/not-a-uuid", bob, nil)
	expect(t, res, 404)
}

func TestValidationAndMalformedBodies(t *testing.T) {
	a := newAPI(t)
	alice := token(t, "alice")
	res, body := a.do("POST", "/v1/trips", alice, map[string]any{"title": "", "startDate": "2026-02-30", "timeZone": "Nowhere"})
	expect(t, res, 422)
	fields := map[string]bool{}
	for _, e := range body["errors"].([]any) {
		fields[e.(map[string]any)["field"].(string)] = true
	}
	if !fields["startDate"] {
		t.Fatalf("date format errors are reported first: %v", body)
	}
	res, body = a.do("POST", "/v1/trips", alice, map[string]any{"title": "", "timeZone": "Nowhere"})
	expect(t, res, 422)
	if len(body["errors"].([]any)) != 2 {
		t.Fatal(body)
	}
	res, body = a.do("POST", "/v1/trips", alice, "{not json")
	expect(t, res, 400)
	if body["code"] != "request.malformed" {
		t.Fatal(body)
	}
	res, _ = a.do("GET", "/v1/nope", alice, nil)
	expect(t, res, 404)
}

func TestHealth(t *testing.T) {
	a := newAPI(t)
	res, _ := a.do("GET", "/healthz", "", nil)
	expect(t, res, 200)
	res, _ = a.do("GET", "/readyz", "", nil)
	expect(t, res, 200)
}
