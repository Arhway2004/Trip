// Package bootstrap is the composition root: the only place that knows which
// adapter implements which port. main() and the HTTP tests both use it.
package bootstrap

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	identityhttp "wanderplan/backend/internal/identity/adapters/httpapi"
	identitymem "wanderplan/backend/internal/identity/adapters/memory"
	identitypg "wanderplan/backend/internal/identity/adapters/postgres"
	identityapp "wanderplan/backend/internal/identity/app"
	identitydomain "wanderplan/backend/internal/identity/domain"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/config"
	"wanderplan/backend/internal/platform/database"
	"wanderplan/backend/internal/platform/httpx"
	triphttp "wanderplan/backend/internal/trip/adapters/httpapi"
	tripmem "wanderplan/backend/internal/trip/adapters/memory"
	trippg "wanderplan/backend/internal/trip/adapters/postgres"
	tripapp "wanderplan/backend/internal/trip/app"
)

// Deps are the infrastructure pieces the application is built from.
type Deps struct {
	Config   config.Config
	Logger   *slog.Logger
	DB       *database.DB // nil = in-memory storage (dev/test only)
	Verifier auth.Verifier
	Clock    kernel.Clock
}

// Services exposes the application services (handy for tests and workers).
type Services struct {
	Identity *identityapp.Service
	Trips    *tripapp.Service
}

func NewServices(d Deps) Services {
	clock := d.Clock
	if clock == nil {
		clock = kernel.SystemClock
	}
	if d.DB != nil {
		tr := trippg.New(d.DB)
		return Services{
			Identity: identityapp.NewService(identitypg.New(d.DB), clock),
			Trips:    tripapp.NewService(tr, d.DB, clock),
		}
	}
	tr := tripmem.New()
	return Services{
		Identity: identityapp.NewService(identitymem.New(), clock),
		Trips:    tripapp.NewService(tr, tr, clock),
	}
}

// NewRouter builds the Gin engine with middleware and all routes.
func NewRouter(d Deps, s Services) *gin.Engine {
	if d.Config.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}
	r := gin.New()
	r.HandleMethodNotAllowed = true
	r.Use(
		httpx.RequestIDMiddleware(),
		httpx.AccessLog(d.Logger),
		httpx.Recovery(),
		httpx.SecurityHeaders(),
		httpx.CORS(d.Config.CORSOrigins),
		func(c *gin.Context) {
			limit := d.Config.MaxBodyBytes
			if c.Request.Method == http.MethodPost && c.Request.URL.Path == "/v1/trips/import" {
				limit = triphttp.MaxImportBytes
			}
			if c.Request.Method == http.MethodPut && strings.HasPrefix(c.Request.URL.Path, "/v1/trips/") && strings.HasSuffix(c.Request.URL.Path, "/plan") {
				limit = triphttp.MaxPlanBodyBytes
			}
			httpx.BodyLimit(limit)(c)
		},
		httpx.Timeout(d.Config.RequestTimeout),
	)
	r.NoRoute(func(c *gin.Context) {
		httpx.WriteProblem(c, http.StatusNotFound, "route.not_found", "no such endpoint")
	})
	r.NoMethod(func(c *gin.Context) {
		httpx.WriteProblem(c, http.StatusMethodNotAllowed, "route.method_not_allowed", "method not allowed")
	})

	r.GET("/healthz", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "ok"}) })
	r.GET("/readyz", func(c *gin.Context) {
		if d.DB != nil {
			if err := d.DB.Ping(c.Request.Context()); err != nil {
				httpx.WriteProblem(c, http.StatusServiceUnavailable, "not_ready", "database unavailable")
				return
			}
		}
		c.JSON(http.StatusOK, gin.H{"status": "ready"})
	})

	resolve := func(ctx context.Context, cl auth.Claims) (uuid.UUID, error) {
		u, err := s.Identity.EnsureUser(ctx, identitydomain.ExternalIdentity{Subject: cl.Subject, Email: cl.Email, Name: cl.Name})
		return u.ID, err
	}
	v1 := r.Group("/v1", auth.Required(d.Verifier, resolve))
	identityhttp.New(s.Identity).Register(v1)
	triphttp.New(s.Trips).Register(v1)
	return r
}

// NewVerifier picks the token verifier for the configured auth mode.
func NewVerifier(ctx context.Context, c config.Config) (auth.Verifier, error) {
	switch c.Auth {
	case config.AuthOIDC:
		return auth.NewOIDCVerifier(ctx, c.OIDCIssuer, c.OIDCAudience, c.OIDCJWKSURL)
	case config.AuthDev:
		return auth.NewDevVerifier(c.DevJWTSecret), nil
	}
	return nil, errors.New("unknown auth mode")
}
