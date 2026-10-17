package app_test

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/flight/adapters/memory"
	"wanderplan/backend/internal/flight/app"
	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
)

// fakeProvider answers from a script and counts calls (one call = one billable request).
type fakeProvider struct {
	calls  atomic.Int32
	future bool
	mu     sync.Mutex
	answer func(code string, date kernel.Date) ([]domain.Status, error)
	delay  time.Duration
}

func (p *fakeProvider) Name() string     { return "fake" }
func (p *fakeProvider) FutureData() bool { return p.future }
func (p *fakeProvider) Lookup(_ context.Context, code string, _ bool, date kernel.Date) ([]domain.Status, error) {
	p.calls.Add(1)
	time.Sleep(p.delay)
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.answer(code, date)
}

func scheduled(code string, date kernel.Date, depEst, gate string) []domain.Status {
	return []domain.Status{{Code: code, Date: date.String(), Phase: domain.PhaseScheduled,
		Departure: domain.End{Scheduled: date.String() + "T10:05", Estimated: depEst, Gate: gate}}}
}

type rig struct {
	svc     *app.Service
	p       *fakeProvider
	flights *memory.Flights
	now     time.Time
	mu      sync.Mutex
}

func (r *rig) clock() time.Time { r.mu.Lock(); defer r.mu.Unlock(); return r.now }
func (r *rig) advance(d time.Duration) {
	r.mu.Lock()
	r.now = r.now.Add(d)
	r.mu.Unlock()
}

func newRig(t *testing.T, budget int) *rig {
	r := &rig{now: time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC), flights: memory.NewFlights()}
	r.p = &fakeProvider{future: true, answer: func(code string, d kernel.Date) ([]domain.Status, error) {
		return scheduled(code, d, d.String()+"T10:05", ""), nil
	}}
	cfg := app.DefaultConfig
	cfg.MonthlyBudget = budget
	r.svc = app.NewService(r.p, r.flights, memory.NewBookings(), memory.NewCache(r.clock), memory.NewLocker(r.clock),
		memory.NewUsage(), memory.NoTx{}, cfg, r.clock, slog.New(slog.NewTextHandler(io.Discard, nil)))
	return r
}

var seg = []domain.SegmentInput{{Flight: "3U1234", Date: "2026-12-05"}}

func TestFiftyCustomersOnOneFlightCostOneCall(t *testing.T) {
	r := newRig(t, 100)
	ctx := context.Background()
	var flightID uuid.UUID
	for i := 0; i < 50; i++ {
		v, err := r.svc.CreateBooking(ctx, uuid.New(), app.BookingInput{Traveler: "Customer", Segments: seg})
		if err != nil {
			t.Fatal(err)
		}
		flightID = v.Flights[0].ID
		if v.Flights[0].Status == nil {
			t.Fatal("every customer sees the shared answer")
		}
	}
	if got := r.p.calls.Load(); got != 1 {
		t.Fatalf("50 bookings of one flight should cost 1 call, got %d", got)
	}
	// Staff opening it later: cached, no call.
	r.advance(7 * time.Hour)
	owner := uuid.New()
	if _, err := r.svc.CreateBooking(ctx, owner, app.BookingInput{Traveler: "Late", Segments: seg}); err != nil {
		t.Fatal(err)
	}
	if v, err := r.svc.GetFlight(ctx, owner, flightID); err != nil || v.Status == nil || r.p.calls.Load() != 1 {
		t.Fatalf("reads never call the provider: %v %d", err, r.p.calls.Load())
	}
}

func TestDailyRefreshDetectsChangesOnceForEveryone(t *testing.T) {
	r := newRig(t, 100)
	ctx := context.Background()
	a, b := uuid.New(), uuid.New()
	va, _ := r.svc.CreateBooking(ctx, a, app.BookingInput{Traveler: "A", Segments: seg})
	_, _ = r.svc.CreateBooking(ctx, b, app.BookingInput{Traveler: "B", Segments: seg})
	id := va.Flights[0].ID

	// Not due yet: the scheduler does nothing.
	r.advance(23 * time.Hour)
	if n, _ := r.svc.RunDue(ctx); n != 0 || r.p.calls.Load() != 1 {
		t.Fatalf("not due before 24h: %d refreshed, %d calls", n, r.p.calls.Load())
	}
	// Next day: refreshed once, and the airline moved the flight.
	r.advance(2 * time.Hour)
	r.p.answer = func(code string, d kernel.Date) ([]domain.Status, error) {
		return scheduled(code, d, d.String()+"T12:30", "C3"), nil
	}
	if n, err := r.svc.RunDue(ctx); err != nil || n != 1 || r.p.calls.Load() != 2 {
		t.Fatalf("one daily refresh expected: %d %v calls=%d", n, err, r.p.calls.Load())
	}
	for _, who := range []uuid.UUID{a, b} {
		cs, err := r.svc.ChangesSince(ctx, who, time.Time{})
		if err != nil || len(cs) != 2 || cs[0].Kind != domain.ChangeDepartureTime || cs[1].To != "C3" {
			t.Fatalf("both customers see the same changes: %+v %v", cs, err)
		}
	}
	snaps := r.flights.Snapshots(id)
	if len(snaps) != 2 {
		t.Fatalf("original + changed snapshot expected, got %d", len(snaps))
	}
}

func TestUrgentRefreshIsSharedAndRateLimited(t *testing.T) {
	r := newRig(t, 100)
	ctx := context.Background()
	owner := uuid.New()
	v, _ := r.svc.CreateBooking(ctx, owner, app.BookingInput{Traveler: "A", Segments: seg})
	id := v.Flights[0].ID
	r.advance(10 * time.Minute)
	if _, err := r.svc.RefreshNow(ctx, owner, id); err != nil || r.p.calls.Load() != 1 {
		t.Fatalf("within the cooldown the last answer is reused: %v calls=%d", err, r.p.calls.Load())
	}
	r.advance(25 * time.Minute)
	if _, err := r.svc.RefreshNow(ctx, owner, id); err != nil || r.p.calls.Load() != 2 {
		t.Fatalf("after the cooldown: %v calls=%d", err, r.p.calls.Load())
	}
	if _, err := r.svc.RefreshNow(ctx, uuid.New(), id); !isKind(err, kernel.KindNotFound) {
		t.Fatalf("strangers can't see or refresh it: %v", err)
	}
}

func TestFailuresKeepLastKnownDataMarkedStale(t *testing.T) {
	r := newRig(t, 100)
	ctx := context.Background()
	owner := uuid.New()
	v, _ := r.svc.CreateBooking(ctx, owner, app.BookingInput{Traveler: "A", Segments: seg})
	r.advance(25 * time.Hour)
	r.p.answer = func(string, kernel.Date) ([]domain.Status, error) {
		return nil, &app.ProviderError{Failure: app.FailureNetwork}
	}
	_, _ = r.svc.RunDue(ctx)
	f, err := r.svc.GetFlight(ctx, owner, v.Flights[0].ID)
	if err != nil || !f.Stale || f.Status == nil || f.Failures != 1 {
		t.Fatalf("stale last-known data expected: %+v %v", f, err)
	}
	if f.NextCheckAt == nil || !f.NextCheckAt.Equal(r.clock().Add(time.Hour)) {
		t.Fatalf("retry in an hour, got %v", f.NextCheckAt)
	}
}

func TestBudgetStopsProviderCalls(t *testing.T) {
	r := newRig(t, 2)
	ctx := context.Background()
	for i, code := range []string{"3U1234", "MU5103", "CA1001"} {
		if _, err := r.svc.CreateBooking(ctx, uuid.New(), app.BookingInput{Traveler: "T", Segments: []domain.SegmentInput{{Flight: code, Date: "2026-12-05"}}}); err != nil {
			t.Fatal(i, err)
		}
	}
	if got := r.p.calls.Load(); got != 2 {
		t.Fatalf("the monthly budget (2) must not be exceeded, got %d", got)
	}
}

func TestConcurrentWorkersRefreshAFlightOnce(t *testing.T) {
	r := newRig(t, 100)
	ctx := context.Background()
	_, _ = r.svc.CreateBooking(ctx, uuid.New(), app.BookingInput{Traveler: "A", Segments: seg})
	r.advance(25 * time.Hour)
	r.p.delay = 20 * time.Millisecond
	var wg sync.WaitGroup
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); _, _ = r.svc.RunDue(ctx) }()
	}
	wg.Wait()
	if got := r.p.calls.Load(); got != 2 {
		t.Fatalf("5 workers, one due flight: 1 more call expected, got %d total", got)
	}
}

func TestWithoutProviderNothingIsCalled(t *testing.T) {
	r := newRig(t, 100)
	cfg := app.DefaultConfig
	svc := app.NewService(nil, memory.NewFlights(), memory.NewBookings(), memory.NewCache(r.clock), memory.NewLocker(r.clock),
		memory.NewUsage(), memory.NoTx{}, cfg, r.clock, slog.New(slog.NewTextHandler(io.Discard, nil)))
	owner := uuid.New()
	v, err := svc.CreateBooking(context.Background(), owner, app.BookingInput{Traveler: "A", Segments: seg})
	if err != nil || v.Flights[0].Status != nil {
		t.Fatalf("booking works without data: %v", err)
	}
	if _, err := svc.RefreshNow(context.Background(), owner, v.Flights[0].ID); !isKind(err, kernel.KindUnavailable) {
		t.Fatalf("503 expected: %v", err)
	}
}

func isKind(err error, k kernel.Kind) bool {
	var ke *kernel.Error
	return errors.As(err, &ke) && ke.Kind == k
}
