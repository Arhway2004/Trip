// Package memory provides in-process adapters for the Flight context, for
// development without PostgreSQL/Redis and for tests.
package memory

import (
	"context"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/flight/app"
	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
)

// Flights implements app.FlightRepository.
type Flights struct {
	mu      sync.Mutex
	flights map[uuid.UUID]*domain.Flight
	byKey   map[string]uuid.UUID
	changes []app.FlightChange
	snaps   map[uuid.UUID][]domain.Status
}

func NewFlights() *Flights {
	return &Flights{flights: map[uuid.UUID]*domain.Flight{}, byKey: map[string]uuid.UUID{}, snaps: map[uuid.UUID][]domain.Status{}}
}

func cp(f *domain.Flight) *domain.Flight {
	c := *f
	return &c
}

func (s *Flights) Ensure(_ context.Context, code string, date kernel.Date, now time.Time) (domain.Flight, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	k := app.CacheKey(code, date)
	if id, ok := s.byKey[k]; ok {
		return *cp(s.flights[id]), nil
	}
	f := &domain.Flight{ID: uuid.New(), Code: code, Date: date, NextCheckAt: &now}
	s.flights[f.ID], s.byKey[k] = f, f.ID
	return *cp(f), nil
}

func (s *Flights) Get(_ context.Context, id uuid.UUID) (*domain.Flight, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if f, ok := s.flights[id]; ok {
		return cp(f), nil
	}
	return nil, nil
}

func (s *Flights) ClaimDue(_ context.Context, now time.Time, lease time.Duration, limit int) ([]domain.Flight, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []domain.Flight
	for _, f := range s.flights {
		if f.NextCheckAt != nil && !f.NextCheckAt.After(now) && len(out) < limit {
			next := now.Add(lease)
			f.NextCheckAt = &next
			out = append(out, *cp(f))
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Code < out[j].Code })
	return out, nil
}

func (s *Flights) SaveCheck(_ context.Context, id uuid.UUID, c app.Check) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	f, ok := s.flights[id]
	if !ok {
		return kernel.NotFound("flight.not_found", "flight not found")
	}
	at := c.At
	f.LastCheckedAt, f.NextCheckAt = &at, c.Next
	if c.Status == nil {
		f.Failures++
		return nil
	}
	st := *c.Status
	f.Status, f.LastSuccessAt, f.Failures = &st, &at, 0
	if c.First || len(c.Changes) > 0 {
		s.snaps[id] = append(s.snaps[id], st)
	}
	for _, ch := range c.Changes {
		s.changes = append(s.changes, app.FlightChange{FlightID: id, Code: f.Code, Date: f.Date, Change: ch})
	}
	return nil
}

func (s *Flights) ChangesFor(_ context.Context, ids []uuid.UUID, since time.Time, limit int) ([]app.FlightChange, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	want := map[uuid.UUID]bool{}
	for _, id := range ids {
		want[id] = true
	}
	var out []app.FlightChange
	for _, c := range s.changes {
		if want[c.FlightID] && c.DetectedAt.After(since) {
			out = append(out, c)
		}
	}
	if len(out) > limit {
		out = out[len(out)-limit:]
	}
	return out, nil
}

// Snapshots returns the stored history of a flight (tests).
func (s *Flights) Snapshots(id uuid.UUID) []domain.Status {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]domain.Status(nil), s.snaps[id]...)
}

// Bookings implements app.BookingRepository.
type Bookings struct {
	mu sync.Mutex
	m  map[uuid.UUID]domain.Booking
}

func NewBookings() *Bookings { return &Bookings{m: map[uuid.UUID]domain.Booking{}} }

func (s *Bookings) Create(_ context.Context, b domain.Booking) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.m[b.ID] = b
	return nil
}

func (s *Bookings) Get(_ context.Context, id uuid.UUID) (*domain.Booking, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if b, ok := s.m[id]; ok {
		return &b, nil
	}
	return nil, nil
}

func (s *Bookings) ListByOwner(_ context.Context, owner uuid.UUID) ([]domain.Booking, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []domain.Booking
	for _, b := range s.m {
		if b.OwnerID == owner {
			out = append(out, b)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

func (s *Bookings) Delete(_ context.Context, id uuid.UUID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.m, id)
	return nil
}

func (s *Bookings) FlightIDsOf(_ context.Context, owner uuid.UUID) ([]uuid.UUID, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	seen := map[uuid.UUID]bool{}
	var out []uuid.UUID
	for _, b := range s.m {
		if b.OwnerID != owner {
			continue
		}
		for _, sg := range b.Segments {
			if !seen[sg.FlightID] {
				seen[sg.FlightID] = true
				out = append(out, sg.FlightID)
			}
		}
	}
	return out, nil
}

// Usage implements app.Usage.
type Usage struct {
	mu sync.Mutex
	m  map[string]int
}

func NewUsage() *Usage { return &Usage{m: map[string]int{}} }

func (u *Usage) Add(_ context.Context, provider, month string) (int, error) {
	u.mu.Lock()
	defer u.mu.Unlock()
	u.m[provider+"|"+month]++
	return u.m[provider+"|"+month], nil
}

func (u *Usage) Get(_ context.Context, provider, month string) (int, error) {
	u.mu.Lock()
	defer u.mu.Unlock()
	return u.m[provider+"|"+month], nil
}

// NoTx runs fn directly (in-memory storage has no transactions).
type NoTx struct{}

func (NoTx) InTx(ctx context.Context, fn func(ctx context.Context) error) error { return fn(ctx) }

// Cache is an in-process TTL cache (single API instance only).
type Cache struct {
	mu sync.Mutex
	m  map[string]cacheEntry
	// Now is the clock (tests).
	Now func() time.Time
}

type cacheEntry struct {
	f   domain.Flight
	exp time.Time
}

func NewCache(now func() time.Time) *Cache { return &Cache{m: map[string]cacheEntry{}, Now: now} }

func (c *Cache) Get(_ context.Context, key string) (*domain.Flight, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.m[key]
	if !ok || c.Now().After(e.exp) {
		return nil, false
	}
	f := e.f
	return &f, true
}

func (c *Cache) Set(_ context.Context, key string, f domain.Flight, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.m[key] = cacheEntry{f: f, exp: c.Now().Add(ttl)}
}

// Locker is an in-process lock (single API instance only).
type Locker struct {
	mu   sync.Mutex
	held map[string]time.Time
	Now  func() time.Time
}

func NewLocker(now func() time.Time) *Locker { return &Locker{held: map[string]time.Time{}, Now: now} }

func (l *Locker) TryLock(_ context.Context, key string, ttl time.Duration) (func(), bool, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if exp, ok := l.held[key]; ok && l.Now().Before(exp) {
		return nil, false, nil
	}
	l.held[key] = l.Now().Add(ttl)
	return func() {
		l.mu.Lock()
		delete(l.held, key)
		l.mu.Unlock()
	}, true, nil
}
