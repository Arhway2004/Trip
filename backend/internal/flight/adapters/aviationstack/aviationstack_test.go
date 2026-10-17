package aviationstack_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"wanderplan/backend/internal/flight/adapters/aviationstack"
	"wanderplan/backend/internal/flight/app"
	"wanderplan/backend/internal/kernel"
)

func TestLookupAndErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("access_key") != "GOODKEY" {
			_, _ = w.Write([]byte(`{"error":{"code":"invalid_access_key","message":"access_key=` + r.URL.Query().Get("access_key") + `"}}`))
			return
		}
		_, _ = w.Write([]byte(`{"data":[{"flight_date":"2026-12-12","flight_status":"active",
			"departure":{"iata":"KMG","terminal":"1","gate":"20","delay":35,"scheduled":"2026-12-12T15:55:00+00:00","estimated":"2026-12-12T16:30:00+00:00"},
			"arrival":{"iata":"XMN","baggage":"7","scheduled":"2026-12-12T18:25:00+00:00"},
			"airline":{"name":"China Eastern Airlines"},"flight":{"iata":"MU5103"}}]}`))
	}))
	defer srv.Close()
	got, err := aviationstack.New("GOODKEY", nil).WithBaseURL(srv.URL).Lookup(context.Background(), "MU5103", false, kernel.NewDate(2026, 12, 12))
	if err != nil || len(got) != 1 {
		t.Fatal(err)
	}
	s := got[0]
	if s.Phase != "active" || s.Departure.Estimated != "2026-12-12T16:30" || *s.Departure.Delay != 35 || s.Arrival.Baggage != "7" {
		t.Fatalf("%+v", s)
	}
	_, err = aviationstack.New("BADKEY", nil).WithBaseURL(srv.URL).Lookup(context.Background(), "MU5103", false, kernel.NewDate(2026, 12, 12))
	var pe *app.ProviderError
	if !errors.As(err, &pe) || pe.Failure != app.FailureInvalidKey || strings.Contains(err.Error(), "BADKEY") {
		t.Fatalf("%v", err)
	}
}
