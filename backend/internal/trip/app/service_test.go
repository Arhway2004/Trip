package app_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/trip/adapters/memory"
	"wanderplan/backend/internal/trip/app"
	"wanderplan/backend/internal/trip/domain"
)

func setup() (*app.Service, *memory.Repository) {
	repo := memory.New()
	now := time.Date(2026, 10, 16, 12, 0, 0, 0, time.UTC)
	return app.NewService(repo, repo, func() time.Time { return now }), repo
}

func wantKind(t *testing.T, err error, k kernel.Kind) {
	t.Helper()
	if kernel.KindOf(err) != k {
		t.Fatalf("want kind %v, got %v", k, err)
	}
}

func TestCreateMakesOwnerMembershipAndIsIdempotent(t *testing.T) {
	ctx := context.Background()
	svc, _ := setup()
	alice := uuid.New()
	id := uuid.New()

	v, created, err := svc.Create(ctx, alice, &id, domain.Fields{Title: "Chengdu"})
	if err != nil || !created || v.Role != domain.RoleOwner || v.Trip.ID != id {
		t.Fatalf("create: %+v %v %v", v, created, err)
	}
	again, created, err := svc.Create(ctx, alice, &id, domain.Fields{Title: "Chengdu (retry)"})
	if err != nil || created || again.Trip.Title != "Chengdu" {
		t.Fatalf("retry must return the existing trip unchanged: %+v %v %v", again, created, err)
	}
	_, _, err = svc.Create(ctx, uuid.New(), &id, domain.Fields{Title: "Hijack"})
	wantKind(t, err, kernel.KindConflict)

	list, _ := svc.List(ctx, alice, false)
	if len(list) != 1 {
		t.Fatalf("list: %d", len(list))
	}
}

func TestNonMembersCannotSeeTrips(t *testing.T) {
	ctx := context.Background()
	svc, _ := setup()
	v, _, _ := svc.Create(ctx, uuid.New(), nil, domain.Fields{Title: "Private"})
	_, err := svc.Get(ctx, uuid.New(), v.Trip.ID)
	wantKind(t, err, kernel.KindNotFound)
}

func TestOptimisticLockingAndRoles(t *testing.T) {
	ctx := context.Background()
	svc, repo := setup()
	owner, viewer, editor := uuid.New(), uuid.New(), uuid.New()
	v, _, _ := svc.Create(ctx, owner, nil, domain.Fields{Title: "Plan"})
	_ = repo.AddMember(ctx, domain.Membership{TripID: v.Trip.ID, UserID: viewer, Role: domain.RoleViewer})
	_ = repo.AddMember(ctx, domain.Membership{TripID: v.Trip.ID, UserID: editor, Role: domain.RoleEditor})

	_, err := svc.Replace(ctx, viewer, v.Trip.ID, 1, domain.Fields{Title: "Nope"})
	wantKind(t, err, kernel.KindForbidden)

	updated, err := svc.Replace(ctx, editor, v.Trip.ID, 1, domain.Fields{Title: "Plan v2"})
	if err != nil || updated.Trip.Version != 2 {
		t.Fatalf("editor update: %+v %v", updated, err)
	}
	_, err = svc.Replace(ctx, owner, v.Trip.ID, 1, domain.Fields{Title: "Lost update"})
	wantKind(t, err, kernel.KindPreconditionFailed)

	err = svc.Delete(ctx, editor, v.Trip.ID, nil)
	wantKind(t, err, kernel.KindForbidden)
	stale := int64(1)
	wantKind(t, svc.Delete(ctx, owner, v.Trip.ID, &stale), kernel.KindPreconditionFailed)
	if err := svc.Delete(ctx, owner, v.Trip.ID, nil); err != nil {
		t.Fatal(err)
	}
	_, err = svc.Get(ctx, owner, v.Trip.ID)
	wantKind(t, err, kernel.KindNotFound)
}
