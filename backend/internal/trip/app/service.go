// Package app contains the Trip context's use cases (application services)
// and the ports they need. It knows nothing about HTTP or SQL.
package app

import (
	"context"

	"github.com/google/uuid"

	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/trip/domain"
)

// Repository is the persistence port for the Trip aggregate and its memberships.
type Repository interface {
	ImportRepository
	PlanRepository
	Get(ctx context.Context, id uuid.UUID) (*domain.Trip, error) // nil, nil when absent
	Insert(ctx context.Context, t *domain.Trip) error
	// Update stores t if the stored version equals expectedVersion,
	// otherwise returns a kernel PreconditionFailed error.
	Update(ctx context.Context, t *domain.Trip, expectedVersion int64) error
	Delete(ctx context.Context, id uuid.UUID) error
	ListForUser(ctx context.Context, userID uuid.UUID, includeArchived bool) ([]View, error)
	AddMember(ctx context.Context, m domain.Membership) error
	GetMember(ctx context.Context, tripID, userID uuid.UUID) (*domain.Membership, error)
	ListMembers(ctx context.Context, tripID uuid.UUID) ([]domain.Membership, error)
}

// TxRunner runs a use case atomically (unit of work).
type TxRunner interface {
	InTx(ctx context.Context, fn func(ctx context.Context) error) error
}

// View is a trip as seen by one user, with that user's role.
type View struct {
	Trip domain.Trip
	Role domain.Role
}

type Service struct {
	repo  Repository
	tx    TxRunner
	clock kernel.Clock
}

func NewService(repo Repository, tx TxRunner, clock kernel.Clock) *Service {
	return &Service{repo: repo, tx: tx, clock: clock}
}

var errNotFound = kernel.NotFound("trip.not_found", "trip not found")

// Create creates a trip owned by actor. If the client supplies an ID (the app
// generates UUIDs offline) and that trip already exists for the same owner,
// the existing trip is returned: retries are safe (idempotent create).
func (s *Service) Create(ctx context.Context, actor uuid.UUID, id *uuid.UUID, f domain.Fields) (View, bool, error) {
	tripID := uuid.New()
	if id != nil {
		tripID = *id
	}
	var out View
	created := false
	err := s.tx.InTx(ctx, func(ctx context.Context) error {
		existing, err := s.repo.Get(ctx, tripID)
		if err != nil {
			return err
		}
		if existing != nil {
			if existing.OwnerID != actor {
				return kernel.Conflict("trip.id_taken", "a trip with this id already exists")
			}
			out = View{Trip: *existing, Role: domain.RoleOwner}
			return nil
		}
		now := s.clock()
		t, err := domain.NewTrip(tripID, actor, f, now)
		if err != nil {
			return err
		}
		if err := s.repo.Insert(ctx, t); err != nil {
			return err
		}
		if err := s.repo.AddMember(ctx, domain.Membership{TripID: t.ID, UserID: actor, Role: domain.RoleOwner, CreatedAt: now}); err != nil {
			return err
		}
		out, created = View{Trip: *t, Role: domain.RoleOwner}, true
		return nil
	})
	return out, created, err
}

// Get returns a trip the actor is a member of. Non-members get "not found"
// so trip IDs can't be probed.
func (s *Service) Get(ctx context.Context, actor, id uuid.UUID) (View, error) {
	t, role, err := s.load(ctx, actor, id)
	if err != nil {
		return View{}, err
	}
	return View{Trip: *t, Role: role}, nil
}

func (s *Service) List(ctx context.Context, actor uuid.UUID, includeArchived bool) ([]View, error) {
	return s.repo.ListForUser(ctx, actor, includeArchived)
}

// Replace updates all editable fields if expectedVersion matches (optimistic locking).
func (s *Service) Replace(ctx context.Context, actor, id uuid.UUID, expectedVersion int64, f domain.Fields) (View, error) {
	var out View
	err := s.tx.InTx(ctx, func(ctx context.Context) error {
		t, role, err := s.load(ctx, actor, id)
		if err != nil {
			return err
		}
		if !role.CanEdit() {
			return kernel.Forbidden("trip.read_only", "you can view this trip but not edit it")
		}
		if t.Version != expectedVersion {
			return staleVersion()
		}
		if err := t.Replace(f, s.clock()); err != nil {
			return err
		}
		if err := s.repo.Update(ctx, t, expectedVersion); err != nil {
			return err
		}
		out = View{Trip: *t, Role: role}
		return nil
	})
	return out, err
}

// Delete removes a trip (owner only). A non-nil expectedVersion must match.
func (s *Service) Delete(ctx context.Context, actor, id uuid.UUID, expectedVersion *int64) error {
	return s.tx.InTx(ctx, func(ctx context.Context) error {
		t, role, err := s.load(ctx, actor, id)
		if err != nil {
			return err
		}
		if !role.CanDelete() {
			return kernel.Forbidden("trip.owner_only", "only the owner can delete this trip")
		}
		if expectedVersion != nil && t.Version != *expectedVersion {
			return staleVersion()
		}
		return s.repo.Delete(ctx, id)
	})
}

func (s *Service) Members(ctx context.Context, actor, id uuid.UUID) ([]domain.Membership, error) {
	if _, _, err := s.load(ctx, actor, id); err != nil {
		return nil, err
	}
	return s.repo.ListMembers(ctx, id)
}

func (s *Service) load(ctx context.Context, actor, id uuid.UUID) (*domain.Trip, domain.Role, error) {
	m, err := s.repo.GetMember(ctx, id, actor)
	if err != nil {
		return nil, "", err
	}
	if m == nil || !m.Role.CanView() {
		return nil, "", errNotFound
	}
	t, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, "", err
	}
	if t == nil {
		return nil, "", errNotFound
	}
	return t, m.Role, nil
}

func staleVersion() error {
	return kernel.PreconditionFailed("trip.version_mismatch", "the trip was changed by someone else; reload and try again")
}
