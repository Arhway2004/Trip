// Package app contains the Identity context's use cases and ports.
package app

import (
	"context"

	"github.com/google/uuid"

	"wanderplan/backend/internal/identity/domain"
	"wanderplan/backend/internal/kernel"
)

// Repository is the persistence port for users.
type Repository interface {
	FindBySubject(ctx context.Context, subject string) (*domain.User, error) // nil, nil when absent
	FindByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
	Insert(ctx context.Context, u *domain.User) error // kernel.Conflict on duplicate subject
	Update(ctx context.Context, u *domain.User) error
}

type Service struct {
	repo  Repository
	clock kernel.Clock
}

func NewService(repo Repository, clock kernel.Clock) *Service {
	return &Service{repo: repo, clock: clock}
}

// EnsureUser returns the user for a verified identity, creating it on first
// sign-in and refreshing profile fields that changed at the provider.
func (s *Service) EnsureUser(ctx context.Context, ext domain.ExternalIdentity) (domain.User, error) {
	if ext.Subject == "" {
		return domain.User{}, kernel.Unauthenticated("auth.missing_subject", "token has no subject")
	}
	u, err := s.repo.FindBySubject(ctx, ext.Subject)
	if err != nil {
		return domain.User{}, err
	}
	now := s.clock()
	if u == nil {
		nu := &domain.User{ID: uuid.New(), Subject: ext.Subject, Email: ext.Email, DisplayName: ext.Name, CreatedAt: now, UpdatedAt: now}
		if err := s.repo.Insert(ctx, nu); err != nil {
			// Two first requests raced: the other one created the user.
			if kernel.KindOf(err) == kernel.KindConflict {
				return s.EnsureUser(ctx, ext)
			}
			return domain.User{}, err
		}
		return *nu, nil
	}
	if u.SyncProfile(ext, now) {
		if err := s.repo.Update(ctx, u); err != nil {
			return domain.User{}, err
		}
	}
	return *u, nil
}

func (s *Service) Get(ctx context.Context, id uuid.UUID) (domain.User, error) {
	u, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return domain.User{}, err
	}
	if u == nil {
		return domain.User{}, kernel.NotFound("user.not_found", "user not found")
	}
	return *u, nil
}
