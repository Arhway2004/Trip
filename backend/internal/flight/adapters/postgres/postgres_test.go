package postgres_test

import (
	"context"
	"io"
	"log/slog"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/flight/adapters/memory"
	"wanderplan/backend/internal/flight/adapters/postgres"
	"wanderplan/backend/internal/flight/app"
	"wanderplan/backend/internal/flight/domain"
	identitypg "wanderplan/backend/internal/identity/adapters/postgres"
	identitydomain "wanderplan/backend/internal/identity/domain"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/database"
)

type provider struct {
	calls atomic.Int32
	gate  atomic.Value
}

func (p *provider) Name() string     { return "it" }
func (p *provider) FutureData() bool { return true }
func (p *provider) Lookup(_ context.Context, code string, _ bool, d kernel.Date) ([]domain.Status, error) {
	p.calls.Add(1)
	g, _ := p.gate.Load().(string)
	return []domain.Status{{Code: code, Date: d.String(), Phase: domain.PhaseScheduled,
		Departure: domain.End{Scheduled: d.String() + "T10:05", Gate: g}}}, nil
}

// Runs against a real PostgreSQL when TEST_DATABASE_URL is set.
func TestFlightMonitoringOnPostgres(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping PostgreSQL integration test")
	}
	ctx := context.Background()
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	db, err := database.Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := db.Migrate(ctx, log); err != nil {
		t.Fatal(err)
	}

	var mu sync.Mutex
	now := time.Now().UTC().Truncate(time.Second)
	clock := func() time.Time { mu.Lock(); defer mu.Unlock(); return now }
	users := make([]uuid.UUID, 3)
	for i := range users {
		u := &identitydomain.User{ID: uuid.New(), Subject: "flight-it-" + uuid.NewString(), CreatedAt: now, UpdatedAt: now}
		if err := identitypg.New(db).Insert(ctx, u); err != nil {
			t.Fatal(err)
		}
		users[i] = u.ID
	}
	st := postgres.New(db)
	p := &provider{}
	p.gate.Store("")
	svc := app.NewService(p, postgres.Flights{Store: st}, postgres.Bookings{Store: st}, memory.NewCache(clock),
		memory.NewLocker(clock), postgres.Usage{Store: st}, db, app.DefaultConfig, clock, log)

	code := "3U" + now.Format("1504") // unique per run
	date := kernel.DateFromTime(now.AddDate(0, 0, 20))
	seg := []domain.SegmentInput{{Flight: code, Date: date.String()}}

	// Three customers book the same flight at once: one row, one call.
	var wg sync.WaitGroup
	views := make([]app.BookingView, 3)
	for i := range users {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			v, err := svc.CreateBooking(ctx, users[i], app.BookingInput{Traveler: "T", Segments: seg})
			if err != nil {
				t.Error(err)
			}
			views[i] = v
		}(i)
	}
	wg.Wait()
	id := views[0].Flights[0].ID
	if views[1].Flights[0].ID != id || views[2].Flights[0].ID != id {
		t.Fatal("concurrent bookings must share one flight row")
	}
	if got := p.calls.Load(); got != 1 {
		t.Fatalf("one provider call expected, got %d", got)
	}

	// Next day: the scheduler claims it once, a gate change is recorded with an outbox event.
	mu.Lock()
	now = now.Add(25 * time.Hour)
	mu.Unlock()
	p.gate.Store("B12")
	if n, err := svc.RunDue(ctx); err != nil || n != 1 {
		t.Fatalf("RunDue: %d %v", n, err)
	}
	cs, err := svc.ChangesSince(ctx, users[2], time.Time{})
	if err != nil || len(cs) != 1 || cs[0].Kind != domain.ChangeDepartureGate || cs[0].To != "B12" {
		t.Fatalf("changes: %+v %v", cs, err)
	}
	var snaps, outbox int
	_ = db.Pool.QueryRow(ctx, `SELECT count(*) FROM flight_snapshots WHERE flight_id = $1`, id).Scan(&snaps)
	_ = db.Pool.QueryRow(ctx, `SELECT count(*) FROM outbox_events WHERE topic = 'flight.changed' AND aggregate_id = $1`, id).Scan(&outbox)
	if snaps != 2 || outbox != 1 {
		t.Fatalf("snapshots=%d (original + changed), outbox=%d", snaps, outbox)
	}
	used, _ := postgres.Usage{Store: st}.Get(ctx, "it", now.Format("2006-01"))
	if used < 1 {
		t.Fatalf("usage counted: %d", used)
	}

	// Deleting a booking keeps the flight for the others.
	if err := svc.DeleteBooking(ctx, users[0], views[0].ID); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.GetFlight(ctx, users[1], id); err != nil {
		t.Fatalf("other customers keep the flight: %v", err)
	}
	if _, err := svc.GetFlight(ctx, users[0], id); err == nil {
		t.Fatal("after deleting their booking, a customer no longer sees the flight")
	}
}
