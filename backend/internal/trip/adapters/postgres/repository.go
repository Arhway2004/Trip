// Package postgres implements the Trip repository on PostgreSQL.
package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/database"
	"wanderplan/backend/internal/trip/app"
	"wanderplan/backend/internal/trip/domain"
)

type Repository struct{ db *database.DB }

func New(db *database.DB) *Repository { return &Repository{db: db} }

const tripCols = `t.id, t.owner_id, t.title, t.description, t.start_date, t.end_date, t.departure_time,
	t.dates_confirmed, t.time_zone, t.traveler_count, t.currency, t.total_budget::float8, t.travel_style,
	t.stage, t.archived, t.version, t.created_at, t.updated_at`

type scanner interface{ Scan(dest ...any) error }

func scanTrip(row scanner, extra ...any) (*domain.Trip, error) {
	var (
		t               domain.Trip
		start, end      *time.Time
		currency, style *string
		stage           string
	)
	dest := []any{&t.ID, &t.OwnerID, &t.Title, &t.Description, &start, &end, &t.DepartureTime,
		&t.DatesConfirmed, &t.TimeZone, &t.TravelerCount, &currency, &t.TotalBudget, &style,
		&stage, &t.Archived, &t.Version, &t.CreatedAt, &t.UpdatedAt}
	if err := row.Scan(append(dest, extra...)...); err != nil {
		return nil, err
	}
	if start != nil {
		d := kernel.DateFromTime(*start)
		t.StartDate = &d
	}
	if end != nil {
		d := kernel.DateFromTime(*end)
		t.EndDate = &d
	}
	t.Currency = currency
	if style != nil {
		s := domain.TravelStyle(*style)
		t.TravelStyle = &s
	}
	t.Stage = domain.Stage(stage)
	return &t, nil
}

func dateArg(d *kernel.Date) any {
	if d == nil {
		return nil
	}
	return d.Time()
}

func styleArg(s *domain.TravelStyle) any {
	if s == nil {
		return nil
	}
	return string(*s)
}

func (r *Repository) Get(ctx context.Context, id uuid.UUID) (*domain.Trip, error) {
	t, err := scanTrip(r.db.Q(ctx).QueryRow(ctx, `SELECT `+tripCols+` FROM trips t WHERE t.id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return t, err
}

func (r *Repository) Insert(ctx context.Context, t *domain.Trip) error {
	_, err := r.db.Q(ctx).Exec(ctx, `
		INSERT INTO trips (id, owner_id, title, description, start_date, end_date, departure_time, dates_confirmed,
			time_zone, traveler_count, currency, total_budget, travel_style, stage, archived, version, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`,
		t.ID, t.OwnerID, t.Title, t.Description, dateArg(t.StartDate), dateArg(t.EndDate), t.DepartureTime,
		t.DatesConfirmed, t.TimeZone, t.TravelerCount, t.Currency, t.TotalBudget, styleArg(t.TravelStyle),
		string(t.Stage), t.Archived, t.Version, t.CreatedAt, t.UpdatedAt)
	if database.IsUniqueViolation(err) {
		return kernel.Conflict("trip.id_taken", "a trip with this id already exists")
	}
	return err
}

func (r *Repository) Update(ctx context.Context, t *domain.Trip, expectedVersion int64) error {
	tag, err := r.db.Q(ctx).Exec(ctx, `
		UPDATE trips SET title=$2, description=$3, start_date=$4, end_date=$5, departure_time=$6, dates_confirmed=$7,
			time_zone=$8, traveler_count=$9, currency=$10, total_budget=$11, travel_style=$12, stage=$13, archived=$14,
			version=$15, updated_at=$16
		WHERE id=$1 AND version=$17`,
		t.ID, t.Title, t.Description, dateArg(t.StartDate), dateArg(t.EndDate), t.DepartureTime, t.DatesConfirmed,
		t.TimeZone, t.TravelerCount, t.Currency, t.TotalBudget, styleArg(t.TravelStyle), string(t.Stage), t.Archived,
		t.Version, t.UpdatedAt, expectedVersion)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return kernel.PreconditionFailed("trip.version_mismatch", "the trip was changed by someone else; reload and try again")
	}
	return nil
}

func (r *Repository) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Q(ctx).Exec(ctx, `DELETE FROM trips WHERE id = $1`, id)
	return err
}

func (r *Repository) ListForUser(ctx context.Context, userID uuid.UUID, includeArchived bool) ([]app.View, error) {
	rows, err := r.db.Q(ctx).Query(ctx, `
		SELECT `+tripCols+`, m.role FROM trips t
		JOIN trip_members m ON m.trip_id = t.id AND m.user_id = $1
		WHERE ($2 OR NOT t.archived)
		ORDER BY t.start_date NULLS LAST, t.created_at DESC`, userID, includeArchived)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []app.View
	for rows.Next() {
		var role string
		t, err := scanTrip(rows, &role)
		if err != nil {
			return nil, err
		}
		out = append(out, app.View{Trip: *t, Role: domain.Role(role)})
	}
	return out, rows.Err()
}

func (r *Repository) AddMember(ctx context.Context, m domain.Membership) error {
	_, err := r.db.Q(ctx).Exec(ctx,
		`INSERT INTO trip_members (trip_id, user_id, role, created_at) VALUES ($1,$2,$3,$4)
		 ON CONFLICT (trip_id, user_id) DO UPDATE SET role = EXCLUDED.role`,
		m.TripID, m.UserID, string(m.Role), m.CreatedAt)
	return err
}

func (r *Repository) GetMember(ctx context.Context, tripID, userID uuid.UUID) (*domain.Membership, error) {
	var m domain.Membership
	var role string
	err := r.db.Q(ctx).QueryRow(ctx,
		`SELECT trip_id, user_id, role, created_at FROM trip_members WHERE trip_id = $1 AND user_id = $2`,
		tripID, userID).Scan(&m.TripID, &m.UserID, &role, &m.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	m.Role = domain.Role(role)
	return &m, err
}

func (r *Repository) ListMembers(ctx context.Context, tripID uuid.UUID) ([]domain.Membership, error) {
	rows, err := r.db.Q(ctx).Query(ctx,
		`SELECT trip_id, user_id, role, created_at FROM trip_members WHERE trip_id = $1 ORDER BY created_at`, tripID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Membership
	for rows.Next() {
		var m domain.Membership
		var role string
		if err := rows.Scan(&m.TripID, &m.UserID, &role, &m.CreatedAt); err != nil {
			return nil, err
		}
		m.Role = domain.Role(role)
		out = append(out, m)
	}
	return out, rows.Err()
}
