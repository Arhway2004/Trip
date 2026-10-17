package postgres_test

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	identitypg "wanderplan/backend/internal/identity/adapters/postgres"
	identitydomain "wanderplan/backend/internal/identity/domain"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/database"
	"wanderplan/backend/internal/trip/adapters/postgres"
	"wanderplan/backend/internal/trip/app"
	"wanderplan/backend/internal/trip/domain"
)

// Runs against a real PostgreSQL when TEST_DATABASE_URL is set, e.g.
// TEST_DATABASE_URL=postgres://wanderplan:wanderplan@localhost:5432/wanderplan_test?sslmode=disable
func TestPostgresRepository(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping PostgreSQL integration test")
	}
	ctx := context.Background()
	db, err := database.Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := db.Migrate(ctx, slog.New(slog.NewTextHandler(io.Discard, nil))); err != nil {
		t.Fatal(err)
	}

	now := time.Now().UTC().Truncate(time.Microsecond)
	owner := &identitydomain.User{ID: uuid.New(), Subject: "it-" + uuid.NewString(), CreatedAt: now, UpdatedAt: now}
	if err := identitypg.New(db).Insert(ctx, owner); err != nil {
		t.Fatal(err)
	}
	svc := app.NewService(postgres.New(db), db, func() time.Time { return now })

	start, _ := kernel.ParseDate("2026-12-03")
	end, _ := kernel.ParseDate("2026-12-13")
	cur, budget, style := "THB", 50000.0, domain.TravelStyle("balanced")
	v, created, err := svc.Create(ctx, owner.ID, nil, domain.Fields{
		Title: "China Winter Adventure 2026", StartDate: &start, EndDate: &end, TimeZone: "Asia/Shanghai",
		TravelerCount: 2, Currency: &cur, TotalBudget: &budget, TravelStyle: &style,
	})
	if err != nil || !created {
		t.Fatal(err)
	}
	got, err := svc.Get(ctx, owner.ID, v.Trip.ID)
	if err != nil {
		t.Fatal(err)
	}
	if got.Trip.StartDate.String() != "2026-12-03" || *got.Trip.TotalBudget != 50000 || got.Role != domain.RoleOwner {
		t.Fatalf("round trip: %+v", got.Trip)
	}
	if _, err := svc.Replace(ctx, owner.ID, v.Trip.ID, 1, domain.Fields{Title: "Renamed", TimeZone: "UTC"}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Replace(ctx, owner.ID, v.Trip.ID, 1, domain.Fields{Title: "Stale"}); kernel.KindOf(err) != kernel.KindPreconditionFailed {
		t.Fatalf("stale update: %v", err)
	}
	list, err := svc.List(ctx, owner.ID, false)
	if err != nil || len(list) != 1 {
		t.Fatalf("list: %v %d", err, len(list))
	}

	var document map[string]any
	if err := json.Unmarshal([]byte(`{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"Imported"},"activities":[{"title":"Untimed","date":"2026-12-03"}]}`), &document); err != nil {
		t.Fatal(err)
	}
	imported, err := svc.Import(ctx, owner.ID, &domain.ImportedPackage{Document: document, Media: map[string][]byte{"media/0.png": {1, 2, 3}}})
	if err != nil {
		t.Fatal(err)
	}
	// A fresh repository/service simulates a restart; no in-process cache may be needed.
	reopened := app.NewService(postgres.New(db), db, func() time.Time { return now })
	saved, err := reopened.GetImport(ctx, owner.ID, imported.Trip.ID)
	if err != nil || saved == nil || len(saved.Media["media/0.png"]) != 3 || len(saved.Document["activities"].([]any)) != 1 {
		t.Fatalf("lost imported package: %+v %v", saved, err)
	}
	plan, err := reopened.GetPlan(ctx, owner.ID, imported.Trip.ID)
	if err != nil || plan.Version != 0 {
		t.Fatalf("initial plan: %+v %v", plan, err)
	}
	plan.Document["activities"].([]any)[0].(map[string]any)["title"] = "Edited after import"
	written, err := reopened.SavePlan(ctx, owner.ID, imported.Trip.ID, 0, &plan.ImportedPackage)
	if err != nil || written.Version != 1 {
		t.Fatalf("save plan: %+v %v", written, err)
	}
	if _, err := svc.SavePlan(ctx, owner.ID, imported.Trip.ID, 0, &plan.ImportedPackage); kernel.KindOf(err) != kernel.KindPreconditionFailed {
		t.Fatalf("stale first plan save: %v", err)
	}
	fresh := app.NewService(postgres.New(db), db, func() time.Time { return now })
	persisted, err := fresh.GetPlan(ctx, owner.ID, imported.Trip.ID)
	if err != nil || persisted.Version != 1 || persisted.Document["activities"].([]any)[0].(map[string]any)["title"] != "Edited after import" {
		t.Fatalf("lost editable plan: %+v %v", persisted, err)
	}
	original, err := fresh.GetImport(ctx, owner.ID, imported.Trip.ID)
	if err != nil || original.Document["activities"].([]any)[0].(map[string]any)["title"] != "Untimed" {
		t.Fatalf("original import changed: %+v %v", original, err)
	}
	if err := reopened.Delete(ctx, owner.ID, imported.Trip.ID, nil); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := db.Pool.QueryRow(ctx, "SELECT count(*) FROM imported_trip_packages WHERE trip_id=$1", imported.Trip.ID).Scan(&count); err != nil || count != 0 {
		t.Fatalf("package did not cascade: %d %v", count, err)
	}
	if err := db.Pool.QueryRow(ctx, "SELECT count(*) FROM trip_plans WHERE trip_id=$1", imported.Trip.ID).Scan(&count); err != nil || count != 0 {
		t.Fatalf("plan did not cascade: %d %v", count, err)
	}
	if err := svc.Delete(ctx, owner.ID, v.Trip.ID, nil); err != nil {
		t.Fatal(err)
	}
}
