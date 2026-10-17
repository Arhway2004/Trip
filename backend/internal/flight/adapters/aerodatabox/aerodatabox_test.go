package aerodatabox_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"wanderplan/backend/internal/flight/adapters/aerodatabox"
	"wanderplan/backend/internal/flight/app"
	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
)

// One FlightContract item as documented in AeroDataBox's OpenAPI spec.
const answer = `[{
  "number": "3U 1234", "status": "Delayed", "codeshareStatus": "IsOperator", "isCargo": false,
  "lastUpdatedUtc": "2026-12-05 01:10Z",
  "airline": {"name": "Sichuan Airlines", "iata": "3U", "icao": "CSC"},
  "departure": {"airport": {"iata": "TFU", "name": "Chengdu Tianfu"},
    "scheduledTime": {"utc": "2026-12-05 02:05Z", "local": "2026-12-05 10:05+08:00"},
    "revisedTime": {"utc": "2026-12-05 02:45Z", "local": "2026-12-05 10:45+08:00"},
    "terminal": "T2", "gate": "B12", "quality": ["Basic", "Live"]},
  "arrival": {"airport": {"iata": "DIG", "name": "Diqing Shangri-La"},
    "scheduledTime": {"utc": "2026-12-05 03:40Z", "local": "2026-12-05 11:40+08:00"},
    "baggageBelt": "2", "quality": ["Basic"]}
}]`

func TestLookupSendsKeyInHeaderAndParsesLocalTimes(t *testing.T) {
	var gotPath, gotKey string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath, gotKey = r.URL.Path, r.Header.Get("x-api-market-key")
		_, _ = w.Write([]byte(answer))
	}))
	defer srv.Close()
	p := aerodatabox.New("KEY123", aerodatabox.APIMarket, nil).WithBaseURL(srv.URL)
	got, err := p.Lookup(context.Background(), "3U1234", false, kernel.NewDate(2026, 12, 5))
	if err != nil {
		t.Fatal(err)
	}
	if gotPath != "/flights/number/3U1234/2026-12-05" || gotKey != "KEY123" {
		t.Fatalf("path %q key %q", gotPath, gotKey)
	}
	s := got[0]
	if s.Code != "3U1234" || s.Phase != domain.PhaseScheduled || s.Detail != "Delayed" || s.Date != "2026-12-05" {
		t.Fatalf("%+v", s)
	}
	if s.Departure.Scheduled != "2026-12-05T10:05" || s.Departure.Estimated != "2026-12-05T10:45" || *s.Departure.Delay != 40 {
		t.Fatalf("local wall-clock times expected: %+v", s.Departure)
	}
	if s.Departure.Gate != "B12" || s.Arrival.Baggage != "2" || s.Arrival.IATA != "DIG" {
		t.Fatalf("%+v", s)
	}
}

func TestErrorsAreCodesWithoutTheKey(t *testing.T) {
	for status, want := range map[int]app.ProviderFailure{401: app.FailureInvalidKey, 429: app.FailureQuota, 500: app.FailureUnknown} {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(status) }))
		_, err := aerodatabox.New("SECRETKEY", aerodatabox.RapidAPI, nil).WithBaseURL(srv.URL).
			Lookup(context.Background(), "3U1234", false, kernel.NewDate(2026, 12, 5))
		srv.Close()
		var pe *app.ProviderError
		if !errors.As(err, &pe) || pe.Failure != want || strings.Contains(err.Error(), "SECRETKEY") {
			t.Fatalf("%d: %v", status, err)
		}
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(204) }))
	defer srv.Close()
	got, err := aerodatabox.New("k", aerodatabox.APIMarket, nil).WithBaseURL(srv.URL).Lookup(context.Background(), "3U1234", false, kernel.NewDate(2026, 12, 5))
	if err != nil || len(got) != 0 {
		t.Fatalf("no flight that day is not an error: %v", err)
	}
}
