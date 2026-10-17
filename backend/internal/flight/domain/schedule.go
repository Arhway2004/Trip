package domain

import (
	"time"

	"wanderplan/backend/internal/kernel"
)

// Cadence decides when a flight is refreshed next. Each operating flight
// (code + date) is refreshed at most once per Interval for everyone watching
// it; urgent manual refreshes are the exception (see ManualCooldown).
type Cadence struct {
	Interval time.Duration // normal refresh, e.g. 24h
	// DayOf: shorter interval on the day of departure (0 = use Interval).
	DayOf time.Duration
	Retry time.Duration // after a failed refresh
	// ManualCooldown: the shortest gap between urgent refreshes of one flight.
	ManualCooldown time.Duration
	// FutureData: the provider knows flights days ahead (AeroDataBox does;
	// aviationstack's live feed only covers flights around their day).
	FutureData bool
}

// DefaultCadence: once a day, as the agency design recommends.
var DefaultCadence = Cadence{Interval: 24 * time.Hour, Retry: time.Hour, ManualCooldown: 30 * time.Minute, FutureData: true}

// Next returns when to refresh again after a refresh at now, or nil for never.
// Day offsets use UTC dates; the ±1-day margin absorbs airport time zones.
func (c Cadence) Next(now time.Time, date kernel.Date, last *Status, failed bool) *time.Time {
	if last != nil && last.Phase.Final() {
		return nil
	}
	days := kernel.DateFromTime(now.UTC()).DaysUntil(date)
	var at time.Time
	switch {
	case days < -1:
		return nil // long gone
	case failed:
		at = now.Add(c.Retry)
	case days > 1 && !c.FutureData:
		// No data yet: wake up when the provider's window opens.
		at = date.Time().AddDate(0, 0, -1)
	case days == 0 && c.DayOf > 0:
		at = now.Add(c.DayOf)
	default:
		at = now.Add(c.Interval)
	}
	return &at
}
