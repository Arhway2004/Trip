package httpapi

import (
	"archive/zip"
	"bytes"
	"os"
	"strings"
	"testing"
	"wanderplan/backend/internal/trip/domain"
)

func zipFile(t *testing.T, files map[string][]byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	for name, data := range files {
		f, err := w.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err = f.Write(data); err != nil {
			t.Fatal(err)
		}
	}
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}
func TestImportMobileExamples(t *testing.T) {
	for _, name := range []string{"../../../../../Example/trip_template.json", "../../../../../Example/china_winter_trip_2026.json", "../../../../../mobile/test/fixtures/china_winter_trip_2026.json"} {
		t.Run(name, func(t *testing.T) {
			data, err := os.ReadFile(name)
			if err != nil {
				t.Fatal(err)
			}
			p, err := decodeImport(data)
			if err != nil {
				t.Fatal(err)
			}
			f, err := domain.ValidateImport(p)
			if err != nil {
				t.Fatal(err)
			}
			if f.Title == "" {
				t.Fatal("lost title")
			}
		})
	}
}
func TestImportZipAndPastedText(t *testing.T) {
	raw := []byte(`{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"Mobile"},"photos":[{"file":"media/0.png"}]}`)
	data := zipFile(t, map[string][]byte{"trip.json": raw, "media/0.png": {1, 2, 3}})
	p, err := decodeImport(data)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(p.Media["media/0.png"], []byte{1, 2, 3}) {
		t.Fatal("lost media")
	}
	p, err = decodeImport([]byte("```json\n" + string(raw) + "\n```"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err = domain.ValidateImport(p); err != nil {
		t.Fatal(err)
	}
}
func TestInvalidImports(t *testing.T) {
	cases := []struct{ name, raw, contains string }{
		{"malformed", "{bad", "invalid JSON"},
		{"array", "[]", "invalid JSON"},
		{"wrong format", `{"format":"other","schemaVersion":3,"trip":{"title":"x"}}`, "not a WanderPlan"},
		{"too new", `{"format":"wanderplan.trip","schemaVersion":4,"trip":{"title":"x"}}`, "newer version"},
		{"partial time", `{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"x"},"activities":[{"title":"Flight","date":"2026-12-01","start":"10:00"}]}`, "Flight"},
		{"bad coordinate", `{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"x"},"places":[{"name":"Museum","lat":91,"lng":0}]}`, "WGS84"},
		{"negative expense", `{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"x"},"expenses":[{"title":"Lunch","amount":-1,"currency":"THB"}]}`, "Lunch"},
		{"bad date", `{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"x"},"activities":[{"title":"Flight","date":"2026-02-30"}]}`, "YYYY-MM-DD"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p, err := decodeImport([]byte(c.raw))
			if err == nil {
				_, err = domain.ValidateImport(p)
			}
			if err == nil || !strings.Contains(err.Error(), c.contains) {
				t.Fatalf("want %q, got %v", c.contains, err)
			}
		})
	}
	for _, files := range []map[string][]byte{{"media/image.png": {1}}, {"trip.json": []byte(`{}`), "../escape": {1}}} {
		if _, err := decodeImport(zipFile(t, files)); err == nil {
			t.Fatal("unsafe or missing trip.json accepted")
		}
	}
}
func TestUntimedAndOvernightActivities(t *testing.T) {
	for _, times := range []string{"", `,"start":"23:00","end":"06:00","endDate":"2026-12-02"`} {
		p, err := decodeImport([]byte(`{"format":"wanderplan.trip","schemaVersion":3,"trip":{"title":"x"},"activities":[{"title":"Train","date":"2026-12-01"` + times + `}]}`))
		if err != nil {
			t.Fatal(err)
		}
		if _, err = domain.ValidateImport(p); err != nil {
			t.Fatal(err)
		}
	}
}

func TestImportArchiveAndDocumentLimits(t *testing.T) {
	// Highly compressed media must not bypass the expansion limit.
	large := bytes.Repeat([]byte{0}, maxExpandedBytes+1)
	archive := zipFile(t, map[string][]byte{"trip.json": []byte(`{}`), "media/large.bin": large})
	if _, err := decodeImport(archive); err == nil || !strings.Contains(err.Error(), "20 MB") {
		t.Fatalf("expanded archive accepted: %v", err)
	}
	if _, err := decodeImport(bytes.Repeat([]byte{' '}, maxDocumentBytes+1)); err == nil || !strings.Contains(err.Error(), "5 MB") {
		t.Fatalf("oversized document accepted: %v", err)
	}
}
