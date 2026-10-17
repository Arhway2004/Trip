// Package domain holds the Flight context's rules: what identifies an
// operating flight, what its live status looks like, what counts as a change,
// and how often it should be checked.
package domain

import (
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/kernel"
)

// Phase is the provider's live state of a flight.
type Phase string

const (
	PhaseScheduled Phase = "scheduled"
	PhaseActive    Phase = "active"
	PhaseLanded    Phase = "landed"
	PhaseCancelled Phase = "cancelled"
	PhaseIncident  Phase = "incident"
	PhaseDiverted  Phase = "diverted"
	PhaseUnknown   Phase = "unknown"
)

// Final phases never change again, so the flight is no longer checked.
func (p Phase) Final() bool { return p == PhaseLanded || p == PhaseCancelled || p == PhaseDiverted }

// End is one end of a flight. Times are airport local wall-clock times
// ("2026-12-12T15:55"): providers report local time and it is shown as such.
type End struct {
	Airport   string `json:"airport,omitempty"`
	IATA      string `json:"iata,omitempty"`
	Terminal  string `json:"terminal,omitempty"`
	Gate      string `json:"gate,omitempty"`
	Baggage   string `json:"baggage,omitempty"`
	Delay     *int   `json:"delay,omitempty"`
	Scheduled string `json:"scheduled,omitempty"`
	Estimated string `json:"estimated,omitempty"`
	Actual    string `json:"actual,omitempty"`
}

// Best is the most current time: actual, else estimated, else scheduled.
func (e End) Best() string {
	switch {
	case e.Actual != "":
		return e.Actual
	case e.Estimated != "":
		return e.Estimated
	}
	return e.Scheduled
}

// Status is one provider answer for a flight on a date.
type Status struct {
	Code      string    `json:"flight"`
	Date      string    `json:"date"`
	Phase     Phase     `json:"phase"`
	Detail    string    `json:"detail,omitempty"` // provider's own wording, e.g. "Boarding"
	Airline   string    `json:"airline,omitempty"`
	Departure End       `json:"departure"`
	Arrival   End       `json:"arrival"`
	FetchedAt time.Time `json:"fetchedAt"`
	Provider  string    `json:"provider"`
}

// Flight is one operating flight on one departure date, shared by every
// traveller who watches it: it is checked once for all of them.
type Flight struct {
	ID            uuid.UUID
	Code          string // "MU5103" (IATA) or "CES5103" (ICAO)
	Date          kernel.Date
	Status        *Status // latest successful answer
	LastCheckedAt *time.Time
	LastSuccessAt *time.Time
	NextCheckAt   *time.Time // nil = no more checks
	Failures      int        // consecutive failed checks
}

// Stale: the last check failed, so the data shown is the last known answer.
func (f Flight) Stale() bool {
	return f.Status != nil && f.LastCheckedAt != nil && f.LastSuccessAt != nil && f.LastCheckedAt.After(*f.LastSuccessAt)
}

// Fresh: answered successfully within maxAge; no provider call is needed.
func (f Flight) Fresh(now time.Time, maxAge time.Duration) bool {
	return f.LastSuccessAt != nil && now.Sub(*f.LastSuccessAt) < maxAge
}

var (
	iataRe = regexp.MustCompile(`^[A-Z0-9]{2}\d{1,4}[A-Z]?$`)
	icaoRe = regexp.MustCompile(`^[A-Z]{3}\d{1,4}[A-Z]?$`)
)

// ParseCode normalises "mu 5103" → "MU5103" and tells whether it is ICAO.
func ParseCode(raw string) (code string, icao bool, err error) {
	s := strings.ToUpper(strings.NewReplacer(" ", "", "-", "").Replace(strings.TrimSpace(raw)))
	switch {
	case iataRe.MatchString(s) && strings.ContainsAny(s[:2], "ABCDEFGHIJKLMNOPQRSTUVWXYZ"):
		return s, false, nil
	case icaoRe.MatchString(s):
		return s, true, nil
	}
	return "", false, kernel.Validation("flight.code_invalid", "use a flight number such as MU5103 or CES5103",
		kernel.FieldError{Field: "flight", Message: "not a flight number"})
}
