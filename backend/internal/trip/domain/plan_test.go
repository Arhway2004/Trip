package domain

import (
	"encoding/json"
	"testing"
)

func planFixture(t *testing.T, extension string) *ImportedPackage {
	t.Helper()
	var doc map[string]any
	if err := json.Unmarshal([]byte(`{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"Test","timeZone":"UTC"},"activities":[{"title":"Visit","date":"2026-12-03","ref":"visit"}],`+extension+`}`), &doc); err != nil {
		t.Fatal(err)
	}
	return &ImportedPackage{Document: doc, Media: map[string][]byte{}}
}
func TestPlanActualsAndConnections(t *testing.T) {
	good := planFixture(t, `"actuals":[{"activityRef":"visit","date":"2026-12-03","start":"23:00","endDate":"2026-12-04","end":"01:00","notes":"A late arrival"}],"connections":[{"key":"a::b","fromRef":"a","toRef":"b","signature":"checked","mode":"train","durationMinutes":90,"bufferMinutes":30}]`)
	if err := ValidatePlan(good); err != nil {
		t.Fatal(err)
	}
	for _, extension := range []string{
		`"actuals":[{"activityRef":"visit","date":"2026-12-03","start":"12:00","end":"11:00"}]`,
		`"actuals":[{"date":"2026-12-03"}]`,
		`"actuals":[{"activityRef":"visit","date":"2026-12-03","start":"25:00"}]`,
		`"connections":[{"key":"a::b","fromRef":"a","toRef":"b","signature":"checked","mode":"train","durationMinutes":-1,"bufferMinutes":30}]`,
		`"connections":[{"key":"a::b","fromRef":"a","toRef":"b","signature":"checked","mode":"walking","durationMinutes":1,"bufferMinutes":0,"geometry":[[100,12]]}]`,
	} {
		if err := ValidatePlan(planFixture(t, extension)); err == nil {
			t.Errorf("accepted invalid extension: %s", extension)
		}
	}
}
