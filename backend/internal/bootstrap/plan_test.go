package bootstrap_test

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"testing"
)

func TestEditablePlanLifecycleAndMobileExport(t *testing.T) {
	a := newAPI(t)
	alice, bob := token(t, "plan-owner"), token(t, "other-plan-user")
	raw := `{"format":"wanderplan.trip","schemaVersion":2,"trip":{"title":"Original","currency":"THB"},"activities":[{"title":"Train","date":"2026-12-03","ref":"train"}],"todos":[{"title":"Passport"}]}`
	res, trip := a.do("POST", "/v1/trips/import", alice, raw)
	expect(t, res, 201)
	id := trip["id"].(string)
	endpoint := "/v1/trips/" + id + "/plan"
	res, plan := a.do("GET", endpoint, alice, nil)
	expect(t, res, 200)
	if plan["version"] != float64(0) {
		t.Fatal(plan)
	}
	document := plan["document"].(map[string]any)
	document["activities"].([]any)[0].(map[string]any)["title"] = "Edited train"
	document["trip"].(map[string]any)["title"] = "Must not overwrite trip details"
	body := map[string]any{"document": document, "media": map[string]string{"media/photo.png": "AQID"}}
	document["photos"] = []any{map[string]any{"file": "media/photo.png", "caption": "My photo"}}
	res, _ = a.do("PUT", endpoint, alice, body)
	expect(t, res, 428)
	res, saved := a.do("PUT", endpoint, alice, body, "If-Match", `"0"`)
	expect(t, res, 200)
	if saved["version"] != float64(1) || saved["document"].(map[string]any)["trip"].(map[string]any)["title"] != "Original" {
		t.Fatal(saved)
	}
	res, _ = a.do("PUT", endpoint, alice, body, "If-Match", `"0"`)
	expect(t, res, 412)
	res, _ = a.do("GET", endpoint, bob, nil)
	expect(t, res, 404)
	res, _ = a.do("PUT", endpoint, bob, body, "If-Match", `"1"`)
	expect(t, res, 404)
	res, original := a.do("GET", "/v1/trips/"+id+"/import", alice, nil)
	expect(t, res, 200)
	if original["document"].(map[string]any)["activities"].([]any)[0].(map[string]any)["title"] != "Train" {
		t.Fatal("original import was modified")
	}
	document["activities"].([]any)[0].(map[string]any)["cost"] = -1
	res, _ = a.do("PUT", endpoint, alice, body, "If-Match", `"1"`)
	expect(t, res, 422)
	res, persisted := a.do("GET", endpoint, alice, nil)
	expect(t, res, 200)
	if persisted["version"] != float64(1) {
		t.Fatal("invalid edit changed plan")
	}
	req, _ := http.NewRequest("GET", a.srv.URL+"/v1/trips/"+id+"/export", nil)
	req.Header.Set("Authorization", "Bearer "+alice)
	response, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		t.Fatal(response.Status)
	}
	data, _ := io.ReadAll(response.Body)
	archive, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		t.Fatal(err)
	}
	found := map[string]bool{}
	for _, file := range archive.File {
		found[file.Name] = true
		if file.Name == "trip.json" {
			r, _ := file.Open()
			var exported map[string]any
			err = json.NewDecoder(r).Decode(&exported)
			r.Close()
			if err != nil || exported["activities"].([]any)[0].(map[string]any)["title"] != "Edited train" {
				t.Fatal("export lost edits", err)
			}
		}
	}
	if !found["trip.json"] || !found["media/photo.png"] {
		t.Fatal("export lost media")
	}
	res, _ = a.do("DELETE", "/v1/trips/"+id, alice, nil)
	expect(t, res, 204)
	res, _ = a.do("GET", endpoint, alice, nil)
	expect(t, res, 404)
}
