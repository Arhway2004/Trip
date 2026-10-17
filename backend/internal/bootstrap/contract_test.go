package bootstrap_test

import (
	"io"
	"log/slog"
	"os"
	"regexp"
	"sort"
	"strings"
	"testing"
	"time"

	"gopkg.in/yaml.v3"

	"wanderplan/backend/internal/bootstrap"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/config"
)

// The OpenAPI document is the contract with the app. Every Gin route must be
// documented and every documented operation must exist.
func TestRoutesMatchOpenAPIContract(t *testing.T) {
	raw, err := os.ReadFile("../../../api/openapi.yaml")
	if err != nil {
		t.Fatal(err)
	}
	var doc struct {
		Paths map[string]map[string]any `yaml:"paths"`
	}
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		t.Fatal(err)
	}
	documented := map[string]bool{}
	for path, ops := range doc.Paths {
		for method := range ops {
			if method == "parameters" {
				continue
			}
			documented[strings.ToUpper(method)+" "+path] = true
		}
	}

	cfg := config.Config{Env: "test", Auth: config.AuthDev, DevJWTSecret: secret, RequestTimeout: time.Second, MaxBodyBytes: 1024}
	deps := bootstrap.Deps{Config: cfg, Logger: slog.New(slog.NewTextHandler(io.Discard, nil)), Verifier: auth.NewDevVerifier(secret)}
	param := regexp.MustCompile(`:(\w+)`)
	implemented := map[string]bool{}
	for _, r := range bootstrap.NewRouter(deps, bootstrap.NewServices(deps)).Routes() {
		implemented[r.Method+" "+param.ReplaceAllString(r.Path, "{$1}")] = true
	}

	var missingDocs, missingImpl []string
	for k := range implemented {
		if !documented[k] {
			missingDocs = append(missingDocs, k)
		}
	}
	for k := range documented {
		if !implemented[k] {
			missingImpl = append(missingImpl, k)
		}
	}
	sort.Strings(missingDocs)
	sort.Strings(missingImpl)
	if len(missingDocs) > 0 || len(missingImpl) > 0 {
		t.Fatalf("contract drift\n undocumented routes: %v\n unimplemented operations: %v", missingDocs, missingImpl)
	}
}
