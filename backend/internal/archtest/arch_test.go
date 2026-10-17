// Package archtest enforces the DDD layering so the codebase stays maintainable:
//   - domain: pure Go (stdlib, uuid, kernel only)
//   - app:    domain + kernel; never HTTP, SQL drivers, Gin or adapters
//   - kernel: depends on nothing in this module
//   - contexts never import another context's adapters
package archtest

import (
	"go/parser"
	"go/token"
	"io/fs"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

const module = "wanderplan/backend/"

type file struct{ path, layer, context string }

func goFiles(t *testing.T) map[file][]string {
	t.Helper()
	out := map[file][]string{}
	err := filepath.WalkDir("..", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return err
		}
		f, err := parser.ParseFile(token.NewFileSet(), path, nil, parser.ImportsOnly)
		if err != nil {
			return err
		}
		rel := filepath.ToSlash(strings.TrimPrefix(path, "../"))
		parts := strings.Split(rel, "/")
		fl := file{path: rel}
		if len(parts) >= 2 {
			fl.context = parts[0]
			fl.layer = parts[1]
		}
		for _, imp := range f.Imports {
			p, _ := strconv.Unquote(imp.Path.Value)
			out[fl] = append(out[fl], p)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func TestLayering(t *testing.T) {
	forbiddenInCore := []string{"net/http", "database/sql", "github.com/gin-gonic", "github.com/jackc", "github.com/pressly", module + "internal/platform"}
	for f, imports := range goFiles(t) {
		for _, imp := range imports {
			switch {
			case f.context == "kernel" && strings.HasPrefix(imp, module):
				t.Errorf("%s: kernel must not depend on %s", f.path, imp)
			case f.layer == "domain" || f.layer == "app":
				for _, bad := range forbiddenInCore {
					if strings.HasPrefix(imp, bad) {
						t.Errorf("%s: %s layer must not import %s", f.path, f.layer, imp)
					}
				}
				if strings.Contains(imp, "/adapters/") {
					t.Errorf("%s: %s layer must not import adapters (%s)", f.path, f.layer, imp)
				}
				if f.layer == "domain" && strings.HasPrefix(imp, module) && !strings.HasPrefix(imp, module+"internal/kernel") &&
					!strings.HasPrefix(imp, module+"internal/"+f.context+"/domain") {
					t.Errorf("%s: domain may only use its own domain and the kernel, not %s", f.path, imp)
				}
			}
			if strings.HasPrefix(imp, module+"internal/") && f.context != "bootstrap" {
				target := strings.Split(strings.TrimPrefix(imp, module+"internal/"), "/")
				if len(target) >= 2 && target[1] == "adapters" && target[0] != f.context {
					t.Errorf("%s: must not use another context's adapters (%s)", f.path, imp)
				}
			}
		}
	}
}
