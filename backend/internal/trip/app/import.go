package app

import (
	"context"
	"github.com/google/uuid"
	"wanderplan/backend/internal/trip/domain"
)

// ImportRepository atomically stores the new aggregate, ownership and complete
// imported document/media. No partial trip may survive a failed import.
type ImportRepository interface {
	Import(context.Context, *domain.Trip, domain.Membership, *domain.ImportedPackage) error
	GetImport(context.Context, uuid.UUID) (*domain.ImportedPackage, error)
}

func (s *Service) Import(ctx context.Context, actor uuid.UUID, p *domain.ImportedPackage) (View, error) {
	f, err := domain.ValidateImport(p)
	if err != nil {
		return View{}, err
	}
	t, err := domain.NewTrip(uuid.New(), actor, f, s.clock())
	if err != nil {
		return View{}, err
	}
	err = s.tx.InTx(ctx, func(ctx context.Context) error {
		return s.repo.Import(ctx, t, domain.Membership{TripID: t.ID, UserID: actor, Role: domain.RoleOwner, CreatedAt: t.CreatedAt}, p)
	})
	return View{Trip: *t, Role: domain.RoleOwner}, err
}
func (s *Service) GetImport(ctx context.Context, actor, id uuid.UUID) (*domain.ImportedPackage, error) {
	if _, _, err := s.load(ctx, actor, id); err != nil {
		return nil, err
	}
	return s.repo.GetImport(ctx, id)
}
