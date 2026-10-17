package memory

import (
	"context"
	"encoding/json"
	"github.com/google/uuid"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/trip/domain"
)

func (r *Repository) GetPlan(_ context.Context, id uuid.UUID) (*domain.Plan, error) {
	r.mu.RLock()
	data := append([]byte(nil), r.plans[id]...)
	r.mu.RUnlock()
	if len(data) == 0 {
		return nil, nil
	}
	var p domain.Plan
	err := json.Unmarshal(data, &p)
	return &p, err
}

func (r *Repository) SavePlan(_ context.Context, id uuid.UUID, expected int64, p *domain.ImportedPackage) (int64, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.trips[id]; !ok {
		return 0, kernel.NotFound("trip.not_found", "trip not found")
	}
	var current domain.Plan
	if data := r.plans[id]; len(data) > 0 {
		if err := json.Unmarshal(data, &current); err != nil {
			return 0, err
		}
	}
	if current.Version != expected {
		return 0, kernel.PreconditionFailed("plan.version_mismatch", "the plan changed in another tab; reload before saving")
	}
	next := domain.Plan{Version: expected + 1, ImportedPackage: *p}
	data, err := json.Marshal(next)
	if err == nil {
		r.plans[id] = data
	}
	return next.Version, err
}
