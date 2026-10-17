package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"

	"wanderplan/backend/internal/kernel"
)

func ptr[T any](v T) *T { return &v }

func date(s string) *kernel.Date {
	d, err := kernel.ParseDate(s)
	if err != nil {
		panic(err)
	}
	return &d
}

func fieldsOf(err error) map[string]bool {
	out := map[string]bool{}
	if e, ok := err.(*kernel.Error); ok {
		for _, f := range e.Fields {
			out[f.Field] = true
		}
	}
	return out
}

func TestNewTripDefaultsAndNormalizes(t *testing.T) {
	tr, err := NewTrip(uuid.New(), uuid.New(), Fields{Title: "  Kyoto  ", Currency: ptr("thb"), Description: ptr("  ")}, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if tr.Title != "Kyoto" || *tr.Currency != "THB" || tr.Description != nil {
		t.Fatalf("not normalized: %+v", tr.Fields)
	}
	if tr.TimeZone != "UTC" || tr.TravelerCount != 1 || tr.Stage != StagePlanning || tr.Version != 1 {
		t.Fatalf("defaults not applied: %+v", tr)
	}
}

func TestValidationReportsEveryProblem(t *testing.T) {
	_, err := NewTrip(uuid.New(), uuid.New(), Fields{
		Title:         " ",
		TimeZone:      "Mars/Olympus",
		StartDate:     date("2026-12-10"),
		EndDate:       date("2026-12-03"),
		DepartureTime: ptr("25:00"),
		TravelerCount: 1000,
		Currency:      ptr("baht"),
		TotalBudget:   ptr(-1.0),
		TravelStyle:   ptr(TravelStyle("yolo")),
		Stage:         "maybe",
	}, time.Now())
	if kernel.KindOf(err) != kernel.KindValidation {
		t.Fatalf("want validation error, got %v", err)
	}
	got := fieldsOf(err)
	for _, f := range []string{"title", "timeZone", "endDate", "departureTime", "travelerCount", "currency", "totalBudget", "travelStyle", "stage"} {
		if !got[f] {
			t.Errorf("missing field error for %s (got %v)", f, got)
		}
	}
}

func TestDatesRules(t *testing.T) {
	_, err := NewTrip(uuid.New(), uuid.New(), Fields{Title: "x", EndDate: date("2026-01-02")}, time.Now())
	if !fieldsOf(err)["endDate"] {
		t.Fatal("endDate without startDate must be rejected")
	}
	tr, err := NewTrip(uuid.New(), uuid.New(), Fields{Title: "x", DepartureTime: ptr("08:00"), DatesConfirmed: true}, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if tr.DepartureTime != nil || tr.DatesConfirmed {
		t.Fatal("departure time and confirmation are cleared when there are no dates")
	}
}

func TestBudgetNeedsCurrency(t *testing.T) {
	_, err := NewTrip(uuid.New(), uuid.New(), Fields{Title: "x", TotalBudget: ptr(100.0)}, time.Now())
	if !fieldsOf(err)["currency"] {
		t.Fatal("budget without currency must be rejected")
	}
}

func TestReplaceBumpsVersion(t *testing.T) {
	tr, _ := NewTrip(uuid.New(), uuid.New(), Fields{Title: "a"}, time.Now())
	if err := tr.Replace(Fields{Title: "b"}, time.Now()); err != nil {
		t.Fatal(err)
	}
	if tr.Version != 2 || tr.Title != "b" {
		t.Fatalf("got %+v", tr)
	}
	if err := tr.Replace(Fields{Title: ""}, time.Now()); err == nil || tr.Version != 2 {
		t.Fatal("an invalid replace must not change the trip")
	}
}

func TestRolePermissions(t *testing.T) {
	cases := []struct {
		r                         Role
		view, edit, del, managers bool
	}{
		{RoleOwner, true, true, true, true},
		{RoleEditor, true, true, false, false},
		{RoleViewer, true, false, false, false},
		{Role("guest"), false, false, false, false},
	}
	for _, c := range cases {
		if c.r.CanView() != c.view || c.r.CanEdit() != c.edit || c.r.CanDelete() != c.del || c.r.CanManageMembers() != c.managers {
			t.Errorf("unexpected permissions for %s", c.r)
		}
	}
}
