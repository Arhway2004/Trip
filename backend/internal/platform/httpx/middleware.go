package httpx

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net/http"
	"slices"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	requestIDKey    = "request_id"
	loggerKey       = "logger"
	HeaderRequestID = "X-Request-ID"
)

func RequestID(c *gin.Context) string { return c.GetString(requestIDKey) }

// RequestIDMiddleware propagates a caller's X-Request-ID or creates one.
func RequestIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(HeaderRequestID)
		if id == "" || len(id) > 64 {
			b := make([]byte, 8)
			_, _ = rand.Read(b)
			id = hex.EncodeToString(b)
		}
		c.Set(requestIDKey, id)
		c.Header(HeaderRequestID, id)
		c.Next()
	}
}

// AccessLog logs one structured line per request and exposes a
// request-scoped logger to handlers.
func AccessLog(base *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		l := base.With("request_id", RequestID(c))
		c.Set(loggerKey, l)
		c.Next()
		status := c.Writer.Status()
		level := slog.LevelInfo
		if status >= 500 {
			level = slog.LevelError
		} else if status >= 400 {
			level = slog.LevelWarn
		}
		l.Log(c.Request.Context(), level, "http request",
			"method", c.Request.Method,
			"route", c.FullPath(),
			"status", status,
			"duration_ms", time.Since(start).Milliseconds(),
			"user_id", c.GetString(userIDLogKey),
		)
	}
}

// userIDLogKey is set by the auth middleware so access logs include the user.
const userIDLogKey = "log_user_id"

func SetLogUser(c *gin.Context, id string) { c.Set(userIDLogKey, id) }

// Recovery turns panics into a 500 problem response and logs the panic.
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if p := recover(); p != nil {
				Logger(c).Error("panic", "panic", fmt.Sprint(p))
				WriteProblem(c, http.StatusInternalServerError, "internal", "something went wrong")
			}
		}()
		c.Next()
	}
}

// Timeout bounds request handling via the request context.
func Timeout(d time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), d)
		defer cancel()
		c.Request = c.Request.WithContext(ctx)
		c.Next()
	}
}

// BodyLimit rejects request bodies larger than n bytes.
func BodyLimit(n int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, n)
		c.Next()
	}
}

func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.Writer.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("X-Frame-Options", "DENY")
		h.Set("Referrer-Policy", "no-referrer")
		h.Set("Cache-Control", "no-store")
		c.Next()
	}
}

// CORS allows the listed origins (browser clients only; the mobile app does not need it).
func CORS(origins []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin != "" && (slices.Contains(origins, "*") || slices.Contains(origins, origin)) {
			h := c.Writer.Header()
			h.Set("Access-Control-Allow-Origin", origin)
			h.Set("Vary", "Origin")
			h.Set("Access-Control-Allow-Headers", strings.Join([]string{"Authorization", "Content-Type", "If-Match", HeaderRequestID}, ", "))
			h.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			h.Set("Access-Control-Expose-Headers", "ETag, Location, "+HeaderRequestID)
		}
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// BindJSON decodes the body or writes a 400 problem; returns false on failure.
func BindJSON(c *gin.Context, dst any) bool {
	if err := c.ShouldBindJSON(dst); err != nil {
		WriteProblem(c, http.StatusBadRequest, "request.malformed", "the request body is not valid JSON for this endpoint")
		return false
	}
	return true
}
