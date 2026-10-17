package app_test

import (
	"context"
	"github.com/google/uuid"
	"testing"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/trip/adapters/memory"
	"wanderplan/backend/internal/trip/app"
	"wanderplan/backend/internal/trip/domain"
)

func TestPlanRolesAndAtomicFirstSave(t *testing.T) {
	ctx := context.Background()
	repo := memory.New()
	svc := app.NewService(repo, repo, kernel.SystemClock)
	owner, viewer := uuid.New(), uuid.New()
	trip, _, err := svc.Create(ctx, owner, nil, domain.Fields{Title: "New trip", TimeZone: "UTC"})
	if err != nil {
		t.Fatal(err)
	}
	if err = repo.AddMember(ctx, domain.Membership{TripID: trip.Trip.ID, UserID: viewer, Role: domain.RoleViewer}); err != nil {
		t.Fatal(err)
	}
	plan, err := svc.GetPlan(ctx, viewer, trip.Trip.ID)
	if err != nil || plan.Version != 0 {
		t.Fatal(err)
	}
	if _, err = svc.SavePlan(ctx, viewer, trip.Trip.ID, 0, &plan.ImportedPackage); kernel.KindOf(err) != kernel.KindForbidden {
		t.Fatal("viewer could edit", err)
	}
	plan.Document["exchangeRates"] = []any{map[string]any{"currency": "CNY", "rate": float64(-1)}}
	if _, err = svc.SavePlan(ctx, owner, trip.Trip.ID, 0, &plan.ImportedPackage); kernel.KindOf(err) != kernel.KindValidation {
		t.Fatal("invalid rate accepted", err)
	}
	plan.Document["exchangeRates"] = []any{}
	if _, err = svc.SavePlan(ctx, owner, trip.Trip.ID, 0, &plan.ImportedPackage); err != nil {
		t.Fatal(err)
	}
	if _, err = svc.SavePlan(ctx, owner, trip.Trip.ID, 0, &plan.ImportedPackage); kernel.KindOf(err) != kernel.KindPreconditionFailed {
		t.Fatal("stale first save accepted", err)
	}
}
