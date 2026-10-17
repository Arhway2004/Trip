package domain_test

import (
	"testing"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
)

func TestParseCode(t *testing.T) {
	for raw, want := range map[string]string{"mu 5103": "MU5103", "3U-1234": "3U1234", "CES5103": "CES5103"} {
		if got, _, err := domain.ParseCode(raw); err != nil || got != want {
			t.Errorf("%q → %q, %v", raw, got, err)
		}
	}
	if _, icao, _ := domain.ParseCode("CES5103"); !icao {
		t.Error("CES5103 is ICAO")
	}
	for _, bad := range []string{"", "G1", "train", "12345"} {
		if _, _, err := domain.ParseCode(bad); err == nil {
			t.Errorf("%q should be rejected", bad)
		}
	}
}

func status(phase domain.Phase, depEst, gate string) domain.Status {
	return domain.Status{Code: "3U1234", Date: "2026-12-05", Phase: phase,
		Departure: domain.End{Scheduled: "2026-12-05T10:05", Estimated: depEst, Gate: gate}}
}

func TestDiff(t *testing.T) {
	at := time.Date(2026, 12, 5, 0, 0, 0, 0, time.UTC)
	base := status(domain.PhaseScheduled, "2026-12-05T10:05", "")
	if got := domain.Diff(nil, base, at); len(got) != 0 {
		t.Fatalf("a normal first answer is not a change: %v", got)
	}
	if got := domain.Diff(&base, status(domain.PhaseScheduled, "2026-12-05T10:12", ""), at); len(got) != 0 {
		t.Fatalf("7 minutes is noise: %v", got)
	}
	got := domain.Diff(&base, status(domain.PhaseScheduled, "2026-12-05T11:00", "B12"), at)
	if len(got) != 2 || got[0].Kind != domain.ChangeDepartureTime || got[1].Kind != domain.ChangeDepartureGate || got[0].To != "2026-12-05T11:00" {
		t.Fatalf("delay + gate expected: %+v", got)
	}
	if got := domain.Diff(nil, status(domain.PhaseCancelled, "", ""), at); len(got) != 1 || got[0].To != "cancelled" {
		t.Fatalf("a first answer that is cancelled is news: %+v", got)
	}
}

func TestCadence(t *testing.T) {
	c := domain.DefaultCadence // 24h, future data
	date := kernel.NewDate(2026, 12, 5)
	now := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
	if n := c.Next(now, date, nil, false); n == nil || !n.Equal(now.Add(24*time.Hour)) {
		t.Fatalf("daily refresh expected, got %v", n)
	}
	if n := c.Next(now, date, nil, true); !n.Equal(now.Add(time.Hour)) {
		t.Fatalf("retry after failure, got %v", n)
	}
	landed := status(domain.PhaseLanded, "", "")
	if c.Next(now, date, &landed, false) != nil {
		t.Fatal("landed flights are not checked again")
	}
	if c.Next(time.Date(2026, 12, 9, 0, 0, 0, 0, time.UTC), date, nil, false) != nil {
		t.Fatal("past flights are not checked again")
	}
	live := domain.Cadence{Interval: 24 * time.Hour, Retry: time.Hour} // provider without future data
	if n := live.Next(now, date, nil, false); !n.Equal(time.Date(2026, 12, 4, 0, 0, 0, 0, time.UTC)) {
		t.Fatalf("wait for the live window, got %v", n)
	}
	dayOf := domain.Cadence{Interval: 24 * time.Hour, DayOf: time.Hour, FutureData: true}
	d0 := time.Date(2026, 12, 5, 2, 0, 0, 0, time.UTC)
	if n := dayOf.Next(d0, date, nil, false); !n.Equal(d0.Add(time.Hour)) {
		t.Fatalf("optional day-of interval, got %v", n)
	}
}

func TestNewBooking(t *testing.T) {
	_, segs, err := domain.NewBooking(uuid.New(), nil, " Yaohui ", []domain.SegmentInput{{Flight: "3u 1234", Date: "2026-12-05"}}, time.Now())
	if err != nil || segs[0].Flight != "3U1234" {
		t.Fatalf("%v %v", segs, err)
	}
	_, _, err = domain.NewBooking(uuid.New(), nil, "", []domain.SegmentInput{{Flight: "x", Date: "2026-02-30"}}, time.Now())
	ke, ok := err.(*kernel.Error)
	if !ok || len(ke.Fields) != 3 {
		t.Fatalf("traveler, flight and date should be reported: %v", err)
	}
}
