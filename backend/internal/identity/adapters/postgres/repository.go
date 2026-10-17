// Package postgres implements the Identity repository on PostgreSQL.
package postgres

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"wanderplan/backend/internal/identity/domain"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/database"
)

type Repository struct{ db *database.DB }

func New(db *database.DB) *Repository { return &Repository{db: db} }

const cols = `id, subject, coalesce(email, ''), coalesce(display_name, ''), created_at, updated_at`

func scan(row pgx.Row) (*domain.User, error) {
	var u domain.User
	if err := row.Scan(&u.ID, &u.Subject, &u.Email, &u.DisplayName, &u.CreatedAt, &u.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &u, nil
}

func (r *Repository) FindBySubject(ctx context.Context, subject string) (*domain.User, error) {
	return scan(r.db.Q(ctx).QueryRow(ctx, `SELECT `+cols+` FROM users WHERE subject = $1`, subject))
}

func (r *Repository) FindByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	return scan(r.db.Q(ctx).QueryRow(ctx, `SELECT `+cols+` FROM users WHERE id = $1`, id))
}

func (r *Repository) Insert(ctx context.Context, u *domain.User) error {
	_, err := r.db.Q(ctx).Exec(ctx,
		`INSERT INTO users (id, subject, email, display_name, created_at, updated_at) VALUES ($1, $2, nullif($3, ''), nullif($4, ''), $5, $6)`,
		u.ID, u.Subject, u.Email, u.DisplayName, u.CreatedAt, u.UpdatedAt)
	if database.IsUniqueViolation(err) {
		return kernel.Conflict("user.exists", "user already exists")
	}
	return err
}

func (r *Repository) Update(ctx context.Context, u *domain.User) error {
	_, err := r.db.Q(ctx).Exec(ctx,
		`UPDATE users SET email = nullif($2, ''), display_name = nullif($3, ''), updated_at = $4 WHERE id = $1`,
		u.ID, u.Email, u.DisplayName, u.UpdatedAt)
	return err
}
