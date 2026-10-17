// Package postgres persists bookings, shared flights, their history and
// provider usage in PostgreSQL.
package postgres

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"wanderplan/backend/internal/flight/app"
	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/database"
)

type Store struct{ db *database.DB }

func New(db *database.DB) *Store { return &Store{db: db} }

// --- Flights ----------------------------------------------------------------

type Flights struct{ *Store }

const flightCols = `id, code, flight_date, status, last_checked_at, last_success_at, next_check_at, consecutive_failures`

func scanFlight(row interface{ Scan(...any) error }) (*domain.Flight, error) {
	var (
		f    domain.Flight
		date time.Time
		raw  []byte
	)
	if err := row.Scan(&f.ID, &f.Code, &date, &raw, &f.LastCheckedAt, &f.LastSuccessAt, &f.NextCheckAt, &f.Failures); err != nil {
		return nil, err
	}
	f.Date = kernel.DateFromTime(date)
	if len(raw) > 0 {
		var st domain.Status
		if err := json.Unmarshal(raw, &st); err == nil {
			f.Status = &st
		}
	}
	return &f, nil
}

func (s Flights) Ensure(ctx context.Context, code string, date kernel.Date, now time.Time) (domain.Flight, error) {
	// Insert-or-get in one statement; concurrent bookings of the same flight
	// end up on the same row.
	row := s.db.Q(ctx).QueryRow(ctx, `
		WITH ins AS (
			INSERT INTO flights (id, code, flight_date, next_check_at, created_at)
			VALUES ($1, $2, $3, $4, $4)
			ON CONFLICT (code, flight_date) DO NOTHING
			RETURNING `+flightCols+`)
		SELECT `+flightCols+` FROM ins
		UNION ALL
		SELECT `+flightCols+` FROM flights WHERE code = $2 AND flight_date = $3
		LIMIT 1`, uuid.New(), code, date, now)
	f, err := scanFlight(row)
	if err != nil {
		return domain.Flight{}, err
	}
	return *f, nil
}

func (s Flights) Get(ctx context.Context, id uuid.UUID) (*domain.Flight, error) {
	f, err := scanFlight(s.db.Q(ctx).QueryRow(ctx, `SELECT `+flightCols+` FROM flights WHERE id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return f, err
}

// ClaimDue takes due flights with SKIP LOCKED and pushes their next check by
// the lease, so several API instances never refresh the same flight.
func (s Flights) ClaimDue(ctx context.Context, now time.Time, lease time.Duration, limit int) ([]domain.Flight, error) {
	rows, err := s.db.Q(ctx).Query(ctx, `
		UPDATE flights SET next_check_at = $2
		WHERE id IN (
			SELECT id FROM flights WHERE next_check_at <= $1
			ORDER BY next_check_at LIMIT $3 FOR UPDATE SKIP LOCKED)
		RETURNING `+flightCols, now, now.Add(lease), limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Flight
	for rows.Next() {
		f, err := scanFlight(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *f)
	}
	return out, rows.Err()
}

// SaveCheck records a refresh, its snapshot and changes in one transaction,
// plus an outbox event so notifications are sent exactly when data commits.
func (s Flights) SaveCheck(ctx context.Context, id uuid.UUID, c app.Check) error {
	return s.db.InTx(ctx, func(ctx context.Context) error {
		q := s.db.Q(ctx)
		if c.Status == nil {
			_, err := q.Exec(ctx, `UPDATE flights SET last_checked_at = $2, next_check_at = $3,
				consecutive_failures = consecutive_failures + 1 WHERE id = $1`, id, c.At, c.Next)
			return err
		}
		raw, err := json.Marshal(c.Status)
		if err != nil {
			return err
		}
		if _, err := q.Exec(ctx, `UPDATE flights SET status = $2, last_checked_at = $3, last_success_at = $3,
			next_check_at = $4, consecutive_failures = 0 WHERE id = $1`, id, raw, c.At, c.Next); err != nil {
			return err
		}
		if c.First || len(c.Changes) > 0 {
			if _, err := q.Exec(ctx, `INSERT INTO flight_snapshots (flight_id, fetched_at, is_original, status)
				VALUES ($1, $2, $3, $4)`, id, c.At, c.First, raw); err != nil {
				return err
			}
		}
		for _, ch := range c.Changes {
			if _, err := q.Exec(ctx, `INSERT INTO flight_changes (flight_id, detected_at, kind, old_value, new_value)
				VALUES ($1, $2, $3, NULLIF($4, ''), $5)`, id, ch.DetectedAt, string(ch.Kind), ch.From, ch.To); err != nil {
				return err
			}
		}
		if len(c.Changes) > 0 {
			payload, _ := json.Marshal(map[string]any{"flightId": id, "changes": c.Changes})
			if _, err := q.Exec(ctx, `INSERT INTO outbox_events (topic, aggregate_type, aggregate_id, payload)
				VALUES ('flight.changed', 'flight', $1, $2)`, id, payload); err != nil {
				return err
			}
		}
		return nil
	})
}

func (s Flights) ChangesFor(ctx context.Context, ids []uuid.UUID, since time.Time, limit int) ([]app.FlightChange, error) {
	rows, err := s.db.Q(ctx).Query(ctx, `
		SELECT * FROM (
			SELECT c.flight_id, f.code, f.flight_date, c.kind, COALESCE(c.old_value, ''), c.new_value, c.detected_at
			FROM flight_changes c JOIN flights f ON f.id = c.flight_id
			WHERE c.flight_id = ANY($1) AND c.detected_at > $2
			ORDER BY c.detected_at DESC, c.id DESC LIMIT $3) x
		ORDER BY detected_at`, ids, since, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []app.FlightChange
	for rows.Next() {
		var (
			c    app.FlightChange
			date time.Time
			kind string
		)
		if err := rows.Scan(&c.FlightID, &c.Code, &date, &kind, &c.From, &c.To, &c.DetectedAt); err != nil {
			return nil, err
		}
		c.Date, c.Kind = kernel.DateFromTime(date), domain.ChangeKind(kind)
		out = append(out, c)
	}
	return out, rows.Err()
}

// --- Bookings ---------------------------------------------------------------

type Bookings struct{ *Store }

func (s Bookings) Create(ctx context.Context, b domain.Booking) error {
	return s.db.InTx(ctx, func(ctx context.Context) error {
		q := s.db.Q(ctx)
		if _, err := q.Exec(ctx, `INSERT INTO bookings (id, owner_id, trip_id, traveler, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, $5)`, b.ID, b.OwnerID, b.TripID, b.Traveler, b.CreatedAt); err != nil {
			return err
		}
		for _, sg := range b.Segments {
			if _, err := q.Exec(ctx, `INSERT INTO booking_segments (id, booking_id, position, flight_id)
				VALUES ($1, $2, $3, $4)`, sg.ID, b.ID, sg.Position, sg.FlightID); err != nil {
				return err
			}
		}
		return nil
	})
}

const bookingSelect = `
	SELECT b.id, b.owner_id, b.trip_id, b.traveler, b.created_at,
	       s.id, s.position, f.id, f.code, f.flight_date
	FROM bookings b
	JOIN booking_segments s ON s.booking_id = b.id
	JOIN flights f ON f.id = s.flight_id`

func (s Bookings) scan(ctx context.Context, where string, args ...any) ([]domain.Booking, error) {
	rows, err := s.db.Q(ctx).Query(ctx, bookingSelect+" WHERE "+where+" ORDER BY b.created_at DESC, b.id, s.position", args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Booking
	for rows.Next() {
		var (
			b    domain.Booking
			sg   domain.Segment
			date time.Time
		)
		if err := rows.Scan(&b.ID, &b.OwnerID, &b.TripID, &b.Traveler, &b.CreatedAt, &sg.ID, &sg.Position, &sg.FlightID, &sg.Code, &date); err != nil {
			return nil, err
		}
		sg.Date = kernel.DateFromTime(date)
		if n := len(out); n > 0 && out[n-1].ID == b.ID {
			out[n-1].Segments = append(out[n-1].Segments, sg)
			continue
		}
		b.Segments = []domain.Segment{sg}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (s Bookings) Get(ctx context.Context, id uuid.UUID) (*domain.Booking, error) {
	bs, err := s.scan(ctx, "b.id = $1", id)
	if err != nil || len(bs) == 0 {
		return nil, err
	}
	return &bs[0], nil
}

func (s Bookings) ListByOwner(ctx context.Context, owner uuid.UUID) ([]domain.Booking, error) {
	return s.scan(ctx, "b.owner_id = $1", owner)
}

func (s Bookings) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := s.db.Q(ctx).Exec(ctx, `DELETE FROM bookings WHERE id = $1`, id)
	return err
}

func (s Bookings) FlightIDsOf(ctx context.Context, owner uuid.UUID) ([]uuid.UUID, error) {
	rows, err := s.db.Q(ctx).Query(ctx, `SELECT DISTINCT s.flight_id FROM booking_segments s
		JOIN bookings b ON b.id = s.booking_id WHERE b.owner_id = $1`, owner)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// --- Usage ------------------------------------------------------------------

type Usage struct{ *Store }

func (s Usage) Add(ctx context.Context, provider, month string) (int, error) {
	var n int
	err := s.db.Q(ctx).QueryRow(ctx, `INSERT INTO flight_provider_usage (provider, month, requests) VALUES ($1, $2, 1)
		ON CONFLICT (provider, month) DO UPDATE SET requests = flight_provider_usage.requests + 1
		RETURNING requests`, provider, month).Scan(&n)
	return n, err
}

func (s Usage) Get(ctx context.Context, provider, month string) (int, error) {
	var n int
	err := s.db.Q(ctx).QueryRow(ctx, `SELECT requests FROM flight_provider_usage WHERE provider = $1 AND month = $2`,
		provider, month).Scan(&n)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	return n, err
}
