package postgres

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/trip/domain"
)

func (r *Repository) GetPlan(ctx context.Context, id uuid.UUID) (*domain.Plan, error) {
	p := &domain.Plan{}
	var raw []byte
	err := r.db.Q(ctx).QueryRow(ctx, "SELECT version, package FROM trip_plans WHERE trip_id=$1", id).Scan(&p.Version, &raw)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(raw, &p.ImportedPackage)
	return p, err
}

func (r *Repository) SavePlan(ctx context.Context, id uuid.UUID, expected int64, p *domain.ImportedPackage) (int64, error) {
	raw, err := json.Marshal(p)
	if err != nil {
		return 0, err
	}
	var version int64
	if expected == 0 {
		err = r.db.Q(ctx).QueryRow(ctx, "INSERT INTO trip_plans(trip_id,version,package) VALUES($1,1,$2) ON CONFLICT DO NOTHING RETURNING version", id, raw).Scan(&version)
	} else {
		err = r.db.Q(ctx).QueryRow(ctx, "UPDATE trip_plans SET package=$2, version=version+1, updated_at=now() WHERE trip_id=$1 AND version=$3 RETURNING version", id, raw, expected).Scan(&version)
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, kernel.PreconditionFailed("plan.version_mismatch", "the plan changed in another tab; reload before saving")
	}
	return version, err
}
