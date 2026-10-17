// Package domain holds the Trip context's aggregate and rules. Pure Go.
// Field rules mirror the Flutter app's Trip aggregate so both sides agree.
package domain

import (
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/kernel"
)

type Stage string

const (
	StageDreaming Stage = "dreaming"
	StagePlanning Stage = "planning"
)

type TravelStyle string

var travelStyles = map[TravelStyle]bool{
	"relaxed": true, "balanced": true, "packed": true, "budget": true,
	"comfort": true, "luxury": true, "adventure": true, "family": true,
}

const (
	MaxTitleLength = 200
	MaxTravelers   = 999
)

var (
	currencyRe = regexp.MustCompile(`^[A-Z]{3}$`)
	timeRe     = regexp.MustCompile(`^([01][0-9]|2[0-3]):[0-5][0-9]$`)
)

// Fields are the user-editable attributes of a trip (a full replacement on update).
type Fields struct {
	Title          string
	Description    *string
	StartDate      *kernel.Date
	EndDate        *kernel.Date
	DepartureTime  *string // "HH:mm", local to TimeZone
	DatesConfirmed bool
	TimeZone       string // IANA, e.g. "Asia/Shanghai"
	TravelerCount  int
	Currency       *string // ISO 4217
	TotalBudget    *float64
	TravelStyle    *TravelStyle
	Stage          Stage
	Archived       bool
}

// Trip is the aggregate root of the Trip context.
type Trip struct {
	ID      uuid.UUID
	OwnerID uuid.UUID
	Fields
	Version   int64 // incremented on every change; exposed as the HTTP ETag
	CreatedAt time.Time
	UpdatedAt time.Time
}

// NewTrip validates fields and creates a trip at version 1.
func NewTrip(id, owner uuid.UUID, f Fields, now time.Time) (*Trip, error) {
	nf, err := Normalize(f)
	if err != nil {
		return nil, err
	}
	return &Trip{ID: id, OwnerID: owner, Fields: nf, Version: 1, CreatedAt: now, UpdatedAt: now}, nil
}

// Replace applies a full update and bumps the version.
func (t *Trip) Replace(f Fields, now time.Time) error {
	nf, err := Normalize(f)
	if err != nil {
		return err
	}
	t.Fields = nf
	t.Version++
	t.UpdatedAt = now
	return nil
}

// Normalize trims/defaults fields and checks every rule, reporting all problems at once.
func Normalize(f Fields) (Fields, error) {
	var errs []kernel.FieldError
	add := func(field, msg string) { errs = append(errs, kernel.FieldError{Field: field, Message: msg}) }

	f.Title = strings.TrimSpace(f.Title)
	switch {
	case f.Title == "":
		add("title", "is required")
	case len([]rune(f.Title)) > MaxTitleLength:
		add("title", "must be at most 200 characters")
	}
	if f.Description != nil {
		if d := strings.TrimSpace(*f.Description); d == "" {
			f.Description = nil
		} else {
			f.Description = &d
		}
	}
	if f.TimeZone == "" {
		f.TimeZone = "UTC"
	}
	if _, err := time.LoadLocation(f.TimeZone); err != nil {
		add("timeZone", "must be an IANA time zone such as Asia/Shanghai")
	}
	if f.EndDate != nil && f.StartDate == nil {
		add("endDate", "requires startDate")
	}
	if f.StartDate != nil && f.EndDate != nil && f.EndDate.Before(*f.StartDate) {
		add("endDate", "must not be before startDate")
	}
	if f.StartDate == nil {
		f.DepartureTime, f.DatesConfirmed = nil, false
	}
	if f.DepartureTime != nil && !timeRe.MatchString(*f.DepartureTime) {
		add("departureTime", "must be HH:mm (24-hour)")
	}
	if f.TravelerCount == 0 {
		f.TravelerCount = 1
	}
	if f.TravelerCount < 1 || f.TravelerCount > MaxTravelers {
		add("travelerCount", "must be between 1 and 999")
	}
	if f.Currency != nil {
		c := strings.ToUpper(strings.TrimSpace(*f.Currency))
		if c == "" {
			f.Currency = nil
		} else if !currencyRe.MatchString(c) {
			add("currency", "must be a 3-letter ISO 4217 code")
		} else {
			f.Currency = &c
		}
	}
	if f.TotalBudget != nil {
		if *f.TotalBudget < 0 {
			add("totalBudget", "must not be negative")
		}
		if f.Currency == nil {
			add("currency", "is required when totalBudget is set")
		}
	}
	if f.TravelStyle != nil && !travelStyles[*f.TravelStyle] {
		add("travelStyle", "is not a known travel style")
	}
	switch f.Stage {
	case "":
		f.Stage = StagePlanning
	case StageDreaming, StagePlanning:
	default:
		add("stage", "must be dreaming or planning")
	}
	if len(errs) > 0 {
		return Fields{}, kernel.Validation("trip.invalid", "the trip has invalid fields", errs...)
	}
	return f, nil
}
