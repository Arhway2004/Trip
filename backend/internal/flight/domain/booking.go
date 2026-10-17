package domain

import (
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/kernel"
)

// Booking is a traveller's flight booking (one or more segments). Customer
// details live here, never in the shared flight cache.
type Booking struct {
	ID        uuid.UUID
	OwnerID   uuid.UUID  // the account that manages it (traveller or agency staff)
	TripID    *uuid.UUID // optional link to a trip
	Traveler  string
	Segments  []Segment
	CreatedAt time.Time
}

// Segment links a booking to one operating flight.
type Segment struct {
	ID       uuid.UUID
	Position int
	FlightID uuid.UUID
	Code     string
	Date     kernel.Date
}

// SegmentInput is one requested flight of a new booking.
type SegmentInput struct {
	Flight string
	Date   string
}

const maxSegments = 20

// NewBooking validates the traveller and flights (codes normalised).
func NewBooking(owner uuid.UUID, tripID *uuid.UUID, traveler string, segs []SegmentInput, now time.Time) (Booking, []SegmentInput, error) {
	traveler = strings.TrimSpace(traveler)
	var fields []kernel.FieldError
	if traveler == "" || len([]rune(traveler)) > 200 {
		fields = append(fields, kernel.FieldError{Field: "traveler", Message: "1–200 characters"})
	}
	if len(segs) == 0 || len(segs) > maxSegments {
		fields = append(fields, kernel.FieldError{Field: "segments", Message: "1–20 flights"})
	}
	clean := make([]SegmentInput, 0, len(segs))
	for i, s := range segs {
		code, _, err := ParseCode(s.Flight)
		if err != nil {
			fields = append(fields, kernel.FieldError{Field: "segments[" + strconv.Itoa(i) + "].flight", Message: "not a flight number"})
		}
		if _, err := kernel.ParseDate(s.Date); err != nil {
			fields = append(fields, kernel.FieldError{Field: "segments[" + strconv.Itoa(i) + "].date", Message: "use YYYY-MM-DD"})
		}
		clean = append(clean, SegmentInput{Flight: code, Date: s.Date})
	}
	if len(fields) > 0 {
		return Booking{}, nil, kernel.Validation("booking.invalid", "the booking has invalid fields", fields...)
	}
	return Booking{ID: uuid.New(), OwnerID: owner, TripID: tripID, Traveler: traveler, CreatedAt: now}, clean, nil
}
