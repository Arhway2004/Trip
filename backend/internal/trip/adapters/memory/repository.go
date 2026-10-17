// Package memory is an in-memory Trip repository for tests and local
// development without PostgreSQL. Not for production use.
package memory

import (
	"context"
	"sort"
	"sync"

	"github.com/google/uuid"

	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/trip/app"
	"wanderplan/backend/internal/trip/domain"
)

type memberKey struct{ trip, user uuid.UUID }

type Repository struct {
	mu      sync.RWMutex
	trips   map[uuid.UUID]domain.Trip
	members map[memberKey]domain.Membership
	imports map[uuid.UUID][]byte
	plans   map[uuid.UUID][]byte
}

func New() *Repository {
	return &Repository{plans: map[uuid.UUID][]byte{}, imports: map[uuid.UUID][]byte{}, trips: map[uuid.UUID]domain.Trip{}, members: map[memberKey]domain.Membership{}}
}

// InTx is a no-op unit of work (memory storage has no rollback).
func (r *Repository) InTx(ctx context.Context, fn func(ctx context.Context) error) error {
	return fn(ctx)
}

func (r *Repository) Get(_ context.Context, id uuid.UUID) (*domain.Trip, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	if t, ok := r.trips[id]; ok {
		return &t, nil
	}
	return nil, nil
}

func (r *Repository) Insert(_ context.Context, t *domain.Trip) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.trips[t.ID]; ok {
		return kernel.Conflict("trip.id_taken", "a trip with this id already exists")
	}
	r.trips[t.ID] = *t
	return nil
}

func (r *Repository) Update(_ context.Context, t *domain.Trip, expectedVersion int64) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	cur, ok := r.trips[t.ID]
	if !ok || cur.Version != expectedVersion {
		return kernel.PreconditionFailed("trip.version_mismatch", "the trip was changed by someone else; reload and try again")
	}
	r.trips[t.ID] = *t
	return nil
}

func (r *Repository) Delete(_ context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.trips, id)
	delete(r.imports, id)
	delete(r.plans, id)
	for k := range r.members {
		if k.trip == id {
			delete(r.members, k)
		}
	}
	return nil
}

func (r *Repository) ListForUser(_ context.Context, userID uuid.UUID, includeArchived bool) ([]app.View, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var out []app.View
	for k, m := range r.members {
		if k.user != userID {
			continue
		}
		t := r.trips[k.trip]
		if t.Archived && !includeArchived {
			continue
		}
		out = append(out, app.View{Trip: t, Role: m.Role})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Trip.CreatedAt.After(out[j].Trip.CreatedAt) })
	return out, nil
}

func (r *Repository) AddMember(_ context.Context, m domain.Membership) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.members[memberKey{m.TripID, m.UserID}] = m
	return nil
}

func (r *Repository) GetMember(_ context.Context, tripID, userID uuid.UUID) (*domain.Membership, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	if m, ok := r.members[memberKey{tripID, userID}]; ok {
		return &m, nil
	}
	return nil, nil
}

func (r *Repository) ListMembers(_ context.Context, tripID uuid.UUID) ([]domain.Membership, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var out []domain.Membership
	for k, m := range r.members {
		if k.trip == tripID {
			out = append(out, m)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.Before(out[j].CreatedAt) })
	return out, nil
}
