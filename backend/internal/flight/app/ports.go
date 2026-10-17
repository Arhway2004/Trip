// Package app holds the Flight context's use cases: bookings that watch
// operating flights, and the shared, cached, once-per-interval refresh.
package app

import (
	"context"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
)

// ProviderFailure classifies provider errors without carrying their text
// (which may contain the API key).
type ProviderFailure string

const (
	FailureInvalidKey ProviderFailure = "invalid_key"
	FailureQuota      ProviderFailure = "quota_reached"
	FailureNotInPlan  ProviderFailure = "not_in_plan"
	FailureNetwork    ProviderFailure = "network"
	FailureUnknown    ProviderFailure = "unknown"
)

type ProviderError struct{ Failure ProviderFailure }

func (e *ProviderError) Error() string { return "flight provider: " + string(e.Failure) }

// Provider is a flight-data API (aviationstack, AeroDataBox, VariFlight…).
// One Lookup = one billable request.
type Provider interface {
	Name() string
	// FutureData: answers for dates days ahead (schedule changes), not only
	// around the day of the flight.
	FutureData() bool
	Lookup(ctx context.Context, code string, icao bool, date kernel.Date) ([]domain.Status, error)
}

// FlightRepository persists operating flights and their history.
type FlightRepository interface {
	// Ensure returns the flight for (code, date), creating it if needed.
	Ensure(ctx context.Context, code string, date kernel.Date, now time.Time) (domain.Flight, error)
	Get(ctx context.Context, id uuid.UUID) (*domain.Flight, error)
	// ClaimDue returns flights whose next check is due and pushes their next
	// check by lease, so concurrent workers never take the same flight.
	ClaimDue(ctx context.Context, now time.Time, lease time.Duration, limit int) ([]domain.Flight, error)
	// SaveCheck records one refresh: the new status (nil when it failed),
	// a snapshot when the status is new or changed, and detected changes.
	SaveCheck(ctx context.Context, id uuid.UUID, c Check) error
	ChangesFor(ctx context.Context, flightIDs []uuid.UUID, since time.Time, limit int) ([]FlightChange, error)
}

type Check struct {
	At      time.Time
	Status  *domain.Status // nil = failed
	Next    *time.Time
	Changes []domain.Change
	First   bool // first successful answer ("original" snapshot)
}

type FlightChange struct {
	FlightID uuid.UUID
	Code     string
	Date     kernel.Date
	domain.Change
}

// BookingRepository persists bookings and their segments.
type BookingRepository interface {
	Create(ctx context.Context, b domain.Booking) error
	Get(ctx context.Context, id uuid.UUID) (*domain.Booking, error)
	ListByOwner(ctx context.Context, owner uuid.UUID) ([]domain.Booking, error)
	Delete(ctx context.Context, id uuid.UUID) error
	// FlightIDsOf: flights in the owner's bookings (authorisation + changes).
	FlightIDsOf(ctx context.Context, owner uuid.UUID) ([]uuid.UUID, error)
}

// Cache holds the latest flight state for fast reads (Redis in production).
type Cache interface {
	Get(ctx context.Context, key string) (*domain.Flight, bool)
	Set(ctx context.Context, key string, f domain.Flight, ttl time.Duration)
}

// Locker serialises refreshes of one flight across API instances (Redis lock).
type Locker interface {
	// TryLock returns a release func, or ok=false when someone else holds it.
	TryLock(ctx context.Context, key string, ttl time.Duration) (release func(), ok bool, err error)
}

// Usage counts provider requests per calendar month (budget guard).
type Usage interface {
	Add(ctx context.Context, provider string, month string) (int, error)
	Get(ctx context.Context, provider string, month string) (int, error)
}

// TxRunner runs fn in one transaction (no-op for in-memory storage).
type TxRunner interface {
	InTx(ctx context.Context, fn func(ctx context.Context) error) error
}

// CacheKey: one key per operating flight and departure date.
func CacheKey(code string, date kernel.Date) string { return "flight:v1:" + code + ":" + date.String() }
