package httpapi

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"path"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/httpx"
	"wanderplan/backend/internal/trip/domain"
)

const MaxImportBytes = 20 << 20
const maxExpandedBytes = 20 << 20
const maxDocumentBytes = 5 << 20

// No archive paths are ever extracted to the filesystem.
func decodeImport(data []byte) (*domain.ImportedPackage, error) {
	p := &domain.ImportedPackage{Media: map[string][]byte{}}
	if len(data) >= 2 && string(data[:2]) == "PK" {
		z, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
		if err != nil {
			return nil, domain.ImportError("file", "invalid ZIP archive")
		}
		if len(z.File) > 1000 {
			return nil, domain.ImportError("file", "too many archive entries (maximum 1000)")
		}
		seen := map[string]bool{}
		remaining := int64(maxExpandedBytes)
		var document []byte
		for _, file := range z.File {
			if file.FileInfo().IsDir() {
				continue
			}
			name := file.Name
			if path.Clean(name) != name || strings.HasPrefix(name, "/") || strings.Contains(name, "\\") || name == ".." || strings.HasPrefix(name, "../") || seen[name] {
				return nil, domain.ImportError("file", "unsafe or duplicate archive path")
			}
			seen[name] = true
			if file.UncompressedSize64 > uint64(remaining) {
				return nil, domain.ImportError("file", "expanded archive exceeds 20 MB")
			}
			r, err := file.Open()
			if err != nil {
				return nil, domain.ImportError("file", "cannot read ZIP entry")
			}
			b, err := io.ReadAll(io.LimitReader(r, remaining+1))
			_ = r.Close()
			if err != nil || int64(len(b)) > remaining {
				return nil, domain.ImportError("file", "invalid or oversized ZIP entry")
			}
			remaining -= int64(len(b))
			if name == "trip.json" {
				document = b
			} else if strings.HasPrefix(name, "media/") {
				p.Media[name] = b
			}
		}
		if document == nil {
			return nil, domain.ImportError("file", "trip.json is missing from the archive")
		}
		data = document
	}
	if len(data) > maxDocumentBytes {
		return nil, domain.ImportError("trip.json", "JSON document exceeds 5 MB")
	}
	text := strings.TrimSpace(strings.TrimPrefix(string(data), "\ufeff"))
	if strings.HasPrefix(text, "```") && strings.HasSuffix(text, "```") {
		if i := strings.IndexByte(text, '\n'); i >= 0 {
			text = strings.TrimSpace(text[i+1 : len(text)-3])
		}
	}
	if !utf8.ValidString(text) || json.Unmarshal([]byte(text), &p.Document) != nil || p.Document == nil {
		return nil, domain.ImportError("file", "invalid JSON; expected a WanderPlan trip object")
	}
	return p, nil
}
func (h *Handler) importTrip(c *gin.Context) {
	data, err := io.ReadAll(io.LimitReader(c.Request.Body, MaxImportBytes+1))
	var tooLarge *http.MaxBytesError
	if len(data) > MaxImportBytes || errors.As(err, &tooLarge) {
		httpx.WriteProblem(c, 413, "import.too_large", "The file must be 20 MB or smaller")
		return
	}
	if err != nil {
		httpx.WriteProblem(c, 400, "import.unreadable", "Cannot read the file")
		return
	}
	p, err := decodeImport(data)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	v, err := h.svc.Import(c.Request.Context(), auth.UserID(c), p)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Header("Location", "/v1/trips/"+v.Trip.ID.String())
	c.Header("ETag", etag(v.Trip.Version))
	c.JSON(201, toResponse(v))
}
func (h *Handler) importedPackage(c *gin.Context) {
	id, ok := tripID(c)
	if !ok {
		return
	}
	p, err := h.svc.GetImport(c.Request.Context(), auth.UserID(c), id)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Header("Cache-Control", "private, no-store")
	c.JSON(200, p)
}
