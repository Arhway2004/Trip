package app

import (
	"context"
	"github.com/google/uuid"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/trip/domain"
)

type PlanRepository interface {
	GetPlan(context.Context, uuid.UUID) (*domain.Plan, error)
	SavePlan(context.Context, uuid.UUID, int64, *domain.ImportedPackage) (int64, error)
}

func mergeTripDocument(p *domain.ImportedPackage, t *domain.Trip) {
	if p.Document == nil {
		p.Document = map[string]any{}
	}
	if p.Media == nil {
		p.Media = map[string][]byte{}
	}
	p.Document["format"], p.Document["schemaVersion"] = "wanderplan.trip", float64(3)
	trip, _ := p.Document["trip"].(map[string]any)
	if trip == nil {
		trip = map[string]any{}
	}
	trip["title"], trip["description"], trip["timeZone"] = t.Title, t.Description, t.TimeZone
	trip["travelerCount"], trip["currency"], trip["totalBudget"] = t.TravelerCount, t.Currency, t.TotalBudget
	trip["travelStyle"], trip["stage"], trip["datesConfirmed"], trip["departureTime"] = t.TravelStyle, t.Stage, t.DatesConfirmed, t.DepartureTime
	trip["startDate"], trip["endDate"] = nil, nil
	if t.StartDate != nil {
		trip["startDate"] = t.StartDate.String()
	}
	if t.EndDate != nil {
		trip["endDate"] = t.EndDate.String()
	}
	p.Document["trip"] = trip
	for _, key := range []string{"activities", "todos", "expenses", "exchangeRates", "places", "destinations", "photos"} {
		if p.Document[key] == nil {
			p.Document[key] = []any{}
		}
	}
}

func (s *Service) GetPlan(ctx context.Context, actor, id uuid.UUID) (*domain.Plan, error) {
	t, _, err := s.load(ctx, actor, id)
	if err != nil {
		return nil, err
	}
	p, err := s.repo.GetPlan(ctx, id)
	if err != nil {
		return nil, err
	}
	if p == nil {
		original, err := s.repo.GetImport(ctx, id)
		if err != nil {
			return nil, err
		}
		if original == nil {
			original = &domain.ImportedPackage{}
		}
		p = &domain.Plan{ImportedPackage: *original}
	}
	mergeTripDocument(&p.ImportedPackage, t)
	return p, nil
}

func (s *Service) SavePlan(ctx context.Context, actor, id uuid.UUID, expected int64, p *domain.ImportedPackage) (*domain.Plan, error) {
	var out *domain.Plan
	err := s.tx.InTx(ctx, func(ctx context.Context) error {
		t, role, err := s.load(ctx, actor, id)
		if err != nil {
			return err
		}
		if !role.CanEdit() {
			return kernel.Forbidden("trip.read_only", "you can view this trip but not edit it")
		}
		mergeTripDocument(p, t) // Trip details have their own editor and version.
		if err := domain.ValidatePlan(p); err != nil {
			return err
		}
		version, err := s.repo.SavePlan(ctx, id, expected, p)
		if err != nil {
			return err
		}
		out = &domain.Plan{Version: version, ImportedPackage: *p}
		return nil
	})
	return out, err
}
