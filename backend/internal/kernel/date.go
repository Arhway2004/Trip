package kernel

import (
	"database/sql/driver"
	"fmt"
	"time"
)

// Date is a calendar date without time or zone ("2026-12-03"), local to a trip.
type Date struct{ t time.Time }

func NewDate(y int, m time.Month, d int) Date { return Date{time.Date(y, m, d, 0, 0, 0, 0, time.UTC)} }

// ParseDate parses YYYY-MM-DD and rejects impossible dates such as 2026-02-30.
func ParseDate(s string) (Date, error) {
	t, err := time.Parse(time.DateOnly, s)
	if err != nil {
		return Date{}, fmt.Errorf("invalid date %q, want YYYY-MM-DD", s)
	}
	return Date{t}, nil
}

func (d Date) String() string               { return d.t.Format(time.DateOnly) }
func (d Date) Before(o Date) bool           { return d.t.Before(o.t) }
func (d Date) DaysUntil(o Date) int         { return int(o.t.Sub(d.t).Hours() / 24) }
func (d Date) Time() time.Time              { return d.t }
func (d Date) IsZero() bool                 { return d.t.IsZero() }
func DateFromTime(t time.Time) Date         { return NewDate(t.Year(), t.Month(), t.Day()) }
func (d Date) Value() (driver.Value, error) { return d.t, nil }

// Clock abstracts "now" so rules and tests never depend on the wall clock.
type Clock func() time.Time

func SystemClock() time.Time { return time.Now().UTC() }
