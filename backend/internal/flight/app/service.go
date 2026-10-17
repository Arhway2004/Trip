package app

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
)

// Config tunes refreshes and spending.
type Config struct {
	Cadence       domain.Cadence
	MonthlyBudget int           // provider requests per calendar month (0 = unlimited)
	LockTTL       time.Duration // how long one refresh may hold the flight lock
	CacheTTL      time.Duration // Redis entry lifetime
}

var DefaultConfig = Config{Cadence: domain.DefaultCadence, MonthlyBudget: 100, LockTTL: 30 * time.Second, CacheTTL: 24 * time.Hour}

// FlightView is a flight as shown to travellers and staff: always the cached
// or stored state; reading never calls the provider.
type FlightView struct {
	domain.Flight
	Stale   bool
	Changes []domain.Change
}

type BookingView struct {
	domain.Booking
	Flights []FlightView // same order as Segments
}

// Service implements the agency flight-monitoring design: bookings point to
// shared operating flights; each flight is refreshed at most once per
// Cadence.Interval for everyone (cache + lock), urgent refreshes are
// rate-limited, failures keep the last known data (marked stale), and every
// change is recorded for notifications.
type Service struct {
	provider Provider // nil: no provider configured
	flights  FlightRepository
	bookings BookingRepository
	cache    Cache
	locks    Locker
	usage    Usage
	tx       TxRunner
	cfg      Config
	clock    kernel.Clock
	log      *slog.Logger
}

func NewService(p Provider, f FlightRepository, b BookingRepository, c Cache, l Locker, u Usage, tx TxRunner, cfg Config, clock kernel.Clock, log *slog.Logger) *Service {
	if p != nil {
		cfg.Cadence.FutureData = p.FutureData()
	}
	return &Service{provider: p, flights: f, bookings: b, cache: c, locks: l, usage: u, tx: tx, cfg: cfg, clock: clock, log: log}
}

func (s *Service) Configured() bool { return s.provider != nil }

// --- Bookings ---------------------------------------------------------------

type BookingInput struct {
	TripID   *uuid.UUID
	Traveler string
	Segments []domain.SegmentInput
}

// CreateBooking stores the booking and links each segment to its shared
// flight. Flights nobody has checked yet are refreshed once now; flights
// already known (another customer booked them) cost no API call.
func (s *Service) CreateBooking(ctx context.Context, owner uuid.UUID, in BookingInput) (BookingView, error) {
	now := s.clock()
	b, segs, err := domain.NewBooking(owner, in.TripID, in.Traveler, in.Segments, now)
	if err != nil {
		return BookingView{}, err
	}
	err = s.tx.InTx(ctx, func(ctx context.Context) error {
		for i, sg := range segs {
			date, _ := kernel.ParseDate(sg.Date)
			f, err := s.flights.Ensure(ctx, sg.Flight, date, now)
			if err != nil {
				return err
			}
			b.Segments = append(b.Segments, domain.Segment{ID: uuid.New(), Position: i, FlightID: f.ID, Code: f.Code, Date: f.Date})
		}
		return s.bookings.Create(ctx, b)
	})
	if err != nil {
		return BookingView{}, err
	}
	for _, sg := range b.Segments {
		f, err := s.flights.Get(ctx, sg.FlightID)
		if err == nil && f != nil && s.provider != nil && f.LastCheckedAt == nil && s.inDataWindow(*f, now) {
			_, _ = s.refresh(ctx, *f, false) // best effort; the worker retries
		}
	}
	return s.bookingView(ctx, b)
}

func (s *Service) ListBookings(ctx context.Context, owner uuid.UUID) ([]BookingView, error) {
	bs, err := s.bookings.ListByOwner(ctx, owner)
	if err != nil {
		return nil, err
	}
	out := make([]BookingView, 0, len(bs))
	for _, b := range bs {
		v, err := s.bookingView(ctx, b)
		if err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, nil
}

func (s *Service) GetBooking(ctx context.Context, owner, id uuid.UUID) (BookingView, error) {
	b, err := s.ownBooking(ctx, owner, id)
	if err != nil {
		return BookingView{}, err
	}
	return s.bookingView(ctx, *b)
}

func (s *Service) DeleteBooking(ctx context.Context, owner, id uuid.UUID) error {
	if _, err := s.ownBooking(ctx, owner, id); err != nil {
		return err
	}
	return s.bookings.Delete(ctx, id)
}

func (s *Service) ownBooking(ctx context.Context, owner, id uuid.UUID) (*domain.Booking, error) {
	b, err := s.bookings.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if b == nil || b.OwnerID != owner {
		return nil, kernel.NotFound("booking.not_found", "booking not found")
	}
	return b, nil
}

func (s *Service) bookingView(ctx context.Context, b domain.Booking) (BookingView, error) {
	v := BookingView{Booking: b}
	for _, sg := range b.Segments {
		f, err := s.flightView(ctx, sg.FlightID)
		if err != nil {
			return BookingView{}, err
		}
		v.Flights = append(v.Flights, f)
	}
	return v, nil
}

// --- Flights ----------------------------------------------------------------

// GetFlight returns the cached/stored state. It never calls the provider.
func (s *Service) GetFlight(ctx context.Context, owner, id uuid.UUID) (FlightView, error) {
	if err := s.authorize(ctx, owner, id); err != nil {
		return FlightView{}, err
	}
	return s.flightView(ctx, id)
}

// RefreshNow is the urgent exception to the schedule ("Check now"). It is
// shared by everyone watching the flight and limited by Cadence.ManualCooldown.
func (s *Service) RefreshNow(ctx context.Context, owner, id uuid.UUID) (FlightView, error) {
	if err := s.authorize(ctx, owner, id); err != nil {
		return FlightView{}, err
	}
	if s.provider == nil {
		return FlightView{}, kernel.Unavailable("flight.not_configured", "no flight-data provider is configured on the server")
	}
	f, err := s.flights.Get(ctx, id)
	if err != nil || f == nil {
		return FlightView{}, kernel.NotFound("flight.not_found", "flight not found")
	}
	if f.LastCheckedAt != nil && s.clock().Sub(*f.LastCheckedAt) < s.cfg.Cadence.ManualCooldown {
		// Someone checked it moments ago: everyone gets that answer.
		return s.flightView(ctx, id)
	}
	if _, err := s.refresh(ctx, *f, true); err != nil {
		var pe *ProviderError
		if errors.As(err, &pe) {
			return FlightView{}, providerProblem(pe)
		}
		if !errors.Is(err, errBusy) && !errors.Is(err, errBudget) {
			return FlightView{}, err
		}
	}
	return s.flightView(ctx, id)
}

// ChangesSince lists changes to the owner's flights after since (newest last).
func (s *Service) ChangesSince(ctx context.Context, owner uuid.UUID, since time.Time) ([]FlightChange, error) {
	ids, err := s.bookings.FlightIDsOf(ctx, owner)
	if err != nil || len(ids) == 0 {
		return nil, err
	}
	return s.flights.ChangesFor(ctx, ids, since, 200)
}

func (s *Service) authorize(ctx context.Context, owner, id uuid.UUID) error {
	ids, err := s.bookings.FlightIDsOf(ctx, owner)
	if err != nil {
		return err
	}
	for _, x := range ids {
		if x == id {
			return nil
		}
	}
	return kernel.NotFound("flight.not_found", "flight not found")
}

func (s *Service) flightView(ctx context.Context, id uuid.UUID) (FlightView, error) {
	f, err := s.flights.Get(ctx, id)
	if err != nil {
		return FlightView{}, err
	}
	if f == nil {
		return FlightView{}, kernel.NotFound("flight.not_found", "flight not found")
	}
	if cached, ok := s.cache.Get(ctx, CacheKey(f.Code, f.Date)); ok && cached.LastCheckedAt != nil &&
		(f.LastCheckedAt == nil || !cached.LastCheckedAt.Before(*f.LastCheckedAt)) {
		f = cached
	}
	changes, err := s.flights.ChangesFor(ctx, []uuid.UUID{f.ID}, time.Time{}, 20)
	if err != nil {
		return FlightView{}, err
	}
	v := FlightView{Flight: *f, Stale: f.Stale()}
	for _, c := range changes {
		v.Changes = append(v.Changes, c.Change)
	}
	return v, nil
}

// --- Scheduled refresh ------------------------------------------------------

// RunDue refreshes every flight whose next check is due (the daily scheduler).
// Safe to run on several instances at once: flights are claimed with a lease
// and each refresh holds a per-flight lock.
func (s *Service) RunDue(ctx context.Context) (int, error) {
	if s.provider == nil {
		return 0, nil
	}
	due, err := s.flights.ClaimDue(ctx, s.clock(), 10*time.Minute, 50)
	if err != nil {
		return 0, err
	}
	n := 0
	for _, f := range due {
		if ctx.Err() != nil {
			break
		}
		if _, err := s.refresh(ctx, f, false); err == nil {
			n++
		} else if errors.Is(err, errBudget) {
			break
		}
	}
	return n, nil
}

var (
	errBusy   = errors.New("refresh in progress elsewhere")
	errBudget = errors.New("monthly provider budget used up")
)

func (s *Service) inDataWindow(f domain.Flight, now time.Time) bool {
	return s.cfg.Cadence.FutureData || kernel.DateFromTime(now.UTC()).DaysUntil(f.Date) <= 1
}

// refresh calls the provider once for f (under its lock), saves the answer,
// records changes and updates the cache. On failure the last known data is
// kept and the flight shows as stale.
func (s *Service) refresh(ctx context.Context, f domain.Flight, manual bool) (*domain.Flight, error) {
	if s.provider == nil {
		return nil, kernel.Unavailable("flight.not_configured", "no flight-data provider is configured on the server")
	}
	key := CacheKey(f.Code, f.Date)
	release, ok, err := s.locks.TryLock(ctx, "lock:"+key, s.cfg.LockTTL)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, errBusy
	}
	defer release()

	now := s.clock()
	// Another instance may have refreshed it after we decided to: reuse that.
	seen := f.LastCheckedAt
	if cur, err := s.flights.Get(ctx, f.ID); err == nil && cur != nil {
		f = *cur
	}
	if !manual && f.LastCheckedAt != nil && (seen == nil || f.LastCheckedAt.After(*seen)) {
		return &f, nil
	}
	month := now.UTC().Format("2006-01")
	if s.cfg.MonthlyBudget > 0 {
		used, err := s.usage.Get(ctx, s.provider.Name(), month)
		if err != nil {
			return nil, err
		}
		if used >= s.cfg.MonthlyBudget {
			next := time.Date(now.Year(), now.Month()+1, 1, 0, 5, 0, 0, time.UTC)
			_ = s.flights.SaveCheck(ctx, f.ID, Check{At: now, Next: &next})
			s.log.Warn("flight provider monthly budget used up", "provider", s.provider.Name(), "used", used)
			return nil, errBudget
		}
	}

	_, icao, _ := domain.ParseCode(f.Code)
	results, lookupErr := s.provider.Lookup(ctx, f.Code, icao, f.Date)
	var pe *ProviderError
	if lookupErr == nil || !errors.As(lookupErr, &pe) || pe.Failure != FailureNetwork {
		// The provider answered (even with an error code): count it.
		if _, err := s.usage.Add(ctx, s.provider.Name(), month); err != nil {
			s.log.Warn("could not count provider request", "error", err)
		}
	}
	if lookupErr != nil {
		next := s.cfg.Cadence.Next(now, f.Date, f.Status, true)
		_ = s.flights.SaveCheck(ctx, f.ID, Check{At: now, Next: next})
		s.log.Warn("flight refresh failed", "flight", f.Code, "date", f.Date.String(), "failure", failureOf(lookupErr))
		return nil, lookupErr
	}

	status := pickForDate(results, f.Date)
	check := Check{At: now}
	if status != nil {
		status.FetchedAt = now
		check.Status = status
		check.First = f.Status == nil
		check.Changes = domain.Diff(f.Status, *status, now)
	}
	check.Next = s.cfg.Cadence.Next(now, f.Date, check.Status, false)
	if err := s.flights.SaveCheck(ctx, f.ID, check); err != nil {
		return nil, err
	}
	updated, err := s.flights.Get(ctx, f.ID)
	if err != nil || updated == nil {
		return nil, err
	}
	s.cache.Set(ctx, key, *updated, s.cfg.CacheTTL)
	return updated, nil
}

func failureOf(err error) string {
	var pe *ProviderError
	if errors.As(err, &pe) {
		return string(pe.Failure)
	}
	return "error"
}

func providerProblem(pe *ProviderError) error {
	switch pe.Failure {
	case FailureQuota:
		return kernel.Unavailable("flight.provider_quota", "the flight-data plan's request limit is reached")
	case FailureInvalidKey, FailureNotInPlan:
		return kernel.Unavailable("flight.provider_config", "the server's flight-data provider is not set up correctly")
	}
	return kernel.Unavailable("flight.provider_unavailable", "the flight-data provider did not answer; showing the last known data")
}

// pickForDate chooses the provider entry for the planned date (±1 day for
// time zones), preferring an exact match.
func pickForDate(rs []domain.Status, date kernel.Date) *domain.Status {
	var best *domain.Status
	bestGap := 99
	for i := range rs {
		d, err := kernel.ParseDate(rs[i].Date)
		if err != nil {
			continue
		}
		gap := date.DaysUntil(d)
		if gap < 0 {
			gap = -gap
		}
		if gap <= 1 && gap < bestGap {
			best, bestGap = &rs[i], gap
		}
	}
	return best
}
