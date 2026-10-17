package memory

import (
	"context"
	"encoding/json"
	"github.com/google/uuid"
	"wanderplan/backend/internal/trip/domain"
)

func (r *Repository) Import(_ context.Context, t *domain.Trip, m domain.Membership, p *domain.ImportedPackage) error {
	data, err := json.Marshal(p)
	if err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.trips[t.ID] = *t
	r.members[memberKey{m.TripID, m.UserID}] = m
	r.imports[t.ID] = data
	return nil
}
func (r *Repository) GetImport(_ context.Context, id uuid.UUID) (*domain.ImportedPackage, error) {
	r.mu.RLock()
	data := append([]byte(nil), r.imports[id]...)
	r.mu.RUnlock()
	if len(data) == 0 {
		return nil, nil
	}
	var p domain.ImportedPackage
	err := json.Unmarshal(data, &p)
	return &p, err
}
