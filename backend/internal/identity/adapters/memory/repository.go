// Package memory is an in-memory Identity repository for tests and local
// development without PostgreSQL.
package memory

import (
	"context"
	"sync"

	"github.com/google/uuid"

	"wanderplan/backend/internal/identity/domain"
	"wanderplan/backend/internal/kernel"
)

type Repository struct {
	mu   sync.RWMutex
	byID map[uuid.UUID]domain.User
}

func New() *Repository { return &Repository{byID: map[uuid.UUID]domain.User{}} }

func (r *Repository) FindBySubject(_ context.Context, subject string) (*domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for _, u := range r.byID {
		if u.Subject == subject {
			c := u
			return &c, nil
		}
	}
	return nil, nil
}

func (r *Repository) FindByID(_ context.Context, id uuid.UUID) (*domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	if u, ok := r.byID[id]; ok {
		return &u, nil
	}
	return nil, nil
}

func (r *Repository) Insert(_ context.Context, u *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, x := range r.byID {
		if x.Subject == u.Subject {
			return kernel.Conflict("user.exists", "user already exists")
		}
	}
	r.byID[u.ID] = *u
	return nil
}

func (r *Repository) Update(_ context.Context, u *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.byID[u.ID] = *u
	return nil
}
