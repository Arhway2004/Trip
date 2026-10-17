package httpapi

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"errors"
	"github.com/gin-gonic/gin"
	"net/http"
	"sort"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/httpx"
	"wanderplan/backend/internal/trip/domain"
)

const MaxPlanBodyBytes = 32 << 20 // Includes base64 overhead for bounded media.

func (h *Handler) plan(c *gin.Context) {
	id, ok := tripID(c)
	if !ok {
		return
	}
	p, err := h.svc.GetPlan(c.Request.Context(), auth.UserID(c), id)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Header("ETag", etag(p.Version))
	c.Header("Cache-Control", "private, no-store")
	c.JSON(200, p)
}

func (h *Handler) savePlan(c *gin.Context) {
	id, ok := tripID(c)
	if !ok {
		return
	}
	version, ok := parseIfMatch(c)
	if !ok || version < 0 {
		httpx.WriteProblem(c, 428, "plan.if_match_required", "send the plan version in If-Match")
		return
	}
	var p domain.ImportedPackage
	if err := c.ShouldBindJSON(&p); err != nil {
		var large *http.MaxBytesError
		if errors.As(err, &large) {
			httpx.WriteProblem(c, 413, "plan.too_large", "plan upload exceeds 32 MB")
		} else {
			httpx.WriteProblem(c, 400, "plan.invalid_json", "expected a document object and media map")
		}
		return
	}
	if p.Document == nil {
		httpx.WriteProblem(c, 422, "plan.document_required", "document is required")
		return
	}
	saved, err := h.svc.SavePlan(c.Request.Context(), auth.UserID(c), id, version, &p)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Header("ETag", etag(saved.Version))
	c.Header("Cache-Control", "private, no-store")
	c.JSON(200, saved)
}

func (h *Handler) exportPlan(c *gin.Context) {
	id, ok := tripID(c)
	if !ok {
		return
	}
	p, err := h.svc.GetPlan(c.Request.Context(), auth.UserID(c), id)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	var output bytes.Buffer
	w := zip.NewWriter(&output)
	document, err := w.Create("trip.json")
	if err == nil {
		err = json.NewEncoder(document).Encode(p.Document)
	}
	names := make([]string, 0, len(p.Media))
	for name := range p.Media {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		if err != nil {
			break
		}
		var file interface{ Write([]byte) (int, error) }
		file, err = w.Create(name)
		if err == nil {
			_, err = file.Write(p.Media[name])
		}
	}
	if closeErr := w.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Header("Cache-Control", "private, no-store")
	c.Header("Content-Disposition", `attachment; filename="trip.wanderplan"`)
	c.Data(200, "application/zip", output.Bytes())
}
