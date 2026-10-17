package bootstrap_test

import (
	"encoding/json"
	"testing"
)

func TestImportCreatesIndependentTripsAndProtectsData(t *testing.T) {
	a := newAPI(t)
	alice, bob := token(t, "alice"), token(t, "bob")
	raw := `{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"Imported","currency":"THB"},"activities":[{"title":"Untimed visit","date":"2026-12-01"}],"todos":[{"title":"Passport"}],"expenses":[{"title":"Lunch","amount":100}],"places":[{"name":"Bangkok","lat":13.75,"lng":100.5}]}`
	res, created := a.do("POST", "/v1/trips/import", alice, raw)
	expect(t, res, 201)
	id := created["id"].(string)
	res, again := a.do("POST", "/v1/trips/import", alice, raw)
	expect(t, res, 201)
	if again["id"] == id {
		t.Fatal("import overwrote trip")
	}
	res, p := a.do("GET", "/v1/trips/"+id+"/import", alice, nil)
	expect(t, res, 200)
	doc := p["document"].(map[string]any)
	if len(doc["activities"].([]any)) != 1 || len(doc["todos"].([]any)) != 1 || len(doc["places"].([]any)) != 1 {
		t.Fatal(p)
	}
	res, _ = a.do("GET", "/v1/trips/"+id+"/import", bob, nil)
	expect(t, res, 404)
	res, _ = a.do("POST", "/v1/trips/import", "", raw)
	expect(t, res, 401)
	var invalid map[string]any
	_ = json.Unmarshal([]byte(raw), &invalid)
	invalid["activities"] = []any{map[string]any{"title": "Bad", "date": "yesterday"}}
	res, _ = a.do("POST", "/v1/trips/import", alice, invalid)
	expect(t, res, 422)
	_, list := a.do("GET", "/v1/trips", alice, nil)
	if len(list["items"].([]any)) != 2 {
		t.Fatal("invalid import left a partial trip")
	}
	res, _ = a.do("DELETE", "/v1/trips/"+id, alice, nil)
	expect(t, res, 204)
	res, _ = a.do("GET", "/v1/trips/"+id+"/import", alice, nil)
	expect(t, res, 404)
}
