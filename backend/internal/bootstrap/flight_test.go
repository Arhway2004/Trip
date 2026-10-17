package bootstrap_test

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"wanderplan/backend/internal/bootstrap"
	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/config"
)

type countingProvider struct{ calls atomic.Int32 }

func (p *countingProvider) Name() string     { return "test" }
func (p *countingProvider) FutureData() bool { return true }
func (p *countingProvider) Lookup(_ context.Context, code string, _ bool, d kernel.Date) ([]domain.Status, error) {
	p.calls.Add(1)
	return []domain.Status{{Code: code, Date: d.String(), Phase: domain.PhaseScheduled,
		Departure: domain.End{IATA: "TFU", Scheduled: d.String() + "T10:05", Gate: "B12"}}}, nil
}

func newFlightAPI(t *testing.T, p *countingProvider) *api {
	cfg := config.Config{Env: "test", Auth: config.AuthDev, DevJWTSecret: secret, RequestTimeout: 5 * time.Second, MaxBodyBytes: 1 << 20,
		Flights: config.Flights{RefreshInterval: 24 * time.Hour, MonthlyBudget: 100, ManualCooldown: 30 * time.Minute}}
	deps := bootstrap.Deps{Config: cfg, Logger: slog.New(slog.NewTextHandler(io.Discard, nil)), Verifier: auth.NewDevVerifier(secret)}
	if p != nil {
		deps.FlightProvider = p
	}
	srv := httptest.NewServer(bootstrap.NewRouter(deps, bootstrap.NewServices(deps)))
	t.Cleanup(srv.Close)
	return &api{t: t, srv: srv}
}

func TestBookingsShareFlightsAndExposeCachedStatus(t *testing.T) {
	p := &countingProvider{}
	a := newFlightAPI(t, p)
	alice, bob := token(t, "alice"), token(t, "bob")
	body := map[string]any{"traveler": "Alice", "segments": []map[string]string{{"flight": "3u 1234", "date": "2026-12-05"}}}

	res, b := a.do(http.MethodPost, "/v1/bookings", alice, body)
	if res.StatusCode != http.StatusCreated {
		t.Fatalf("create: %d %v", res.StatusCode, b)
	}
	flights := b["flights"].([]any)
	f := flights[0].(map[string]any)
	if f["flight"] != "3U1234" || f["status"] == nil || f["stale"] != false {
		t.Fatalf("%v", f)
	}
	flightID := f["id"].(string)
	body["traveler"] = "Bob"
	if res, _ := a.do(http.MethodPost, "/v1/bookings", bob, body); res.StatusCode != http.StatusCreated || p.calls.Load() != 1 {
		t.Fatalf("second customer on the same flight: %d calls=%d", res.StatusCode, p.calls.Load())
	}

	res, b = a.do(http.MethodGet, "/v1/flights/"+flightID, bob, nil)
	if res.StatusCode != 200 || b["status"].(map[string]any)["departure"].(map[string]any)["gate"] != "B12" {
		t.Fatalf("%d %v", res.StatusCode, b)
	}
	// Urgent refresh within the cooldown reuses the answer.
	if res, _ := a.do(http.MethodPost, "/v1/flights/"+flightID+"/refresh", alice, nil); res.StatusCode != 200 || p.calls.Load() != 1 {
		t.Fatalf("refresh: %d calls=%d", res.StatusCode, p.calls.Load())
	}
	res, b = a.do(http.MethodGet, "/v1/bookings", alice, nil)
	if res.StatusCode != 200 || len(b["items"].([]any)) != 1 {
		t.Fatalf("alice sees only her booking: %v", b)
	}
	if res, b := a.do(http.MethodGet, "/v1/flight-changes?since=2026-01-01T00:00:00Z", alice, nil); res.StatusCode != 200 || len(b["items"].([]any)) != 0 {
		t.Fatalf("changes: %d %v", res.StatusCode, b)
	}
	// A stranger can't read or refresh it.
	carol := token(t, "carol")
	if res, _ := a.do(http.MethodGet, "/v1/flights/"+flightID, carol, nil); res.StatusCode != 404 {
		t.Fatalf("stranger: %d", res.StatusCode)
	}
	if res, b := a.do(http.MethodPost, "/v1/bookings", alice, map[string]any{"traveler": "", "segments": []map[string]string{{"flight": "train", "date": "2026-02-30"}}}); res.StatusCode != 422 || b["code"] != "booking.invalid" {
		t.Fatalf("validation: %d %v", res.StatusCode, b)
	}
}

func TestRefreshWithoutProviderIs503(t *testing.T) {
	a := newFlightAPI(t, nil)
	alice := token(t, "alice")
	_, b := a.do(http.MethodPost, "/v1/bookings", alice, map[string]any{"traveler": "A", "segments": []map[string]string{{"flight": "MU5103", "date": "2026-12-12"}}})
	id := b["flights"].([]any)[0].(map[string]any)["id"].(string)
	res, p := a.do(http.MethodPost, "/v1/flights/"+id+"/refresh", alice, nil)
	if res.StatusCode != http.StatusServiceUnavailable || p["code"] != "flight.not_configured" {
		t.Fatalf("%d %v", res.StatusCode, p)
	}
}

func TestSecretsAreRedacted(t *testing.T) {
	s := config.Secret("abc123")
	if s.String() != "[redacted]" || s.Reveal() != "abc123" {
		t.Fatal("secrets must not print")
	}
}
