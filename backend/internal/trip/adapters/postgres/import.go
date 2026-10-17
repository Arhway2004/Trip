package postgres

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"wanderplan/backend/internal/trip/domain"
)

func (r *Repository) Import(ctx context.Context, t *domain.Trip, m domain.Membership, p *domain.ImportedPackage) error {
	return r.db.InTx(ctx, func(ctx context.Context) error {
		if err := r.Insert(ctx, t); err != nil {
			return err
		}
		if err := r.AddMember(ctx, m); err != nil {
			return err
		}
		data, err := json.Marshal(p)
		if err != nil {
			return err
		}
		_, err = r.db.Q(ctx).Exec(ctx, "INSERT INTO imported_trip_packages (trip_id,package) VALUES ($1,$2)", t.ID, data)
		return err
	})
}
func (r *Repository) GetImport(ctx context.Context, id uuid.UUID) (*domain.ImportedPackage, error) {
	var raw []byte
	err := r.db.Q(ctx).QueryRow(ctx, "SELECT package FROM imported_trip_packages WHERE trip_id=$1", id).Scan(&raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var p domain.ImportedPackage
	err = json.Unmarshal(raw, &p)
	return &p, err
}
