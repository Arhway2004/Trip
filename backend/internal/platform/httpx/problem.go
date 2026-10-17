// Package httpx holds Gin plumbing shared by all contexts: middleware and the
// single place where errors become HTTP responses (RFC 9457 problem details).
package httpx

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"wanderplan/backend/internal/kernel"
)

// Problem is an RFC 9457 "application/problem+json" body.
type Problem struct {
	Type      string              `json:"type"`
	Title     string              `json:"title"`
	Status    int                 `json:"status"`
	Detail    string              `json:"detail,omitempty"`
	Code      string              `json:"code"`
	Errors    []kernel.FieldError `json:"errors,omitempty"`
	RequestID string              `json:"requestId,omitempty"`
}

var statusByKind = map[kernel.Kind]int{
	kernel.KindValidation:         http.StatusUnprocessableEntity,
	kernel.KindNotFound:           http.StatusNotFound,
	kernel.KindForbidden:          http.StatusForbidden,
	kernel.KindConflict:           http.StatusConflict,
	kernel.KindPreconditionFailed: http.StatusPreconditionFailed,
	kernel.KindUnauthenticated:    http.StatusUnauthorized,
}

// WriteError renders err as a problem response. Unknown errors are logged and
// reported as a generic 500 without leaking internals.
func WriteError(c *gin.Context, err error) {
	var ke *kernel.Error
	if errors.As(err, &ke) {
		status, ok := statusByKind[ke.Kind]
		if !ok {
			status = http.StatusInternalServerError
		}
		WriteProblem(c, status, ke.Code, ke.Message, ke.Fields...)
		return
	}
	Logger(c).Error("unhandled error", "error", err)
	WriteProblem(c, http.StatusInternalServerError, "internal", "something went wrong")
}

func WriteProblem(c *gin.Context, status int, code, detail string, fields ...kernel.FieldError) {
	c.Header("Content-Type", "application/problem+json")
	c.AbortWithStatusJSON(status, Problem{
		Type:      "https://wanderplan.app/problems/" + code,
		Title:     http.StatusText(status),
		Status:    status,
		Detail:    detail,
		Code:      code,
		Errors:    fields,
		RequestID: RequestID(c),
	})
}

// Logger returns the request-scoped logger set by the access-log middleware.
func Logger(c *gin.Context) *slog.Logger {
	if l, ok := c.Get(loggerKey); ok {
		return l.(*slog.Logger)
	}
	return slog.Default()
}
