package app_test

import (
	"context"
	"testing"
	"time"

	"wanderplan/backend/internal/identity/adapters/memory"
	"wanderplan/backend/internal/identity/app"
	"wanderplan/backend/internal/identity/domain"
	"wanderplan/backend/internal/kernel"
)

func TestEnsureUserCreatesOnceAndSyncsProfile(t *testing.T) {
	ctx := context.Background()
	svc := app.NewService(memory.New(), func() time.Time { return time.Unix(0, 0) })
	u1, err := svc.EnsureUser(ctx, domain.ExternalIdentity{Subject: "sub-1", Email: "a@x.com"})
	if err != nil {
		t.Fatal(err)
	}
	u2, err := svc.EnsureUser(ctx, domain.ExternalIdentity{Subject: "sub-1", Email: "new@x.com", Name: "Alice"})
	if err != nil || u2.ID != u1.ID || u2.Email != "new@x.com" || u2.DisplayName != "Alice" {
		t.Fatalf("got %+v %v", u2, err)
	}
	if _, err := svc.EnsureUser(ctx, domain.ExternalIdentity{}); kernel.KindOf(err) != kernel.KindUnauthenticated {
		t.Fatalf("empty subject: %v", err)
	}
}
