// Package bootstrap is the composition root: the only place that knows which
// adapter implements which port. main() and the HTTP tests both use it.
package bootstrap

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	goredis "github.com/redis/go-redis/v9"

	"wanderplan/backend/internal/flight/adapters/aerodatabox"
	"wanderplan/backend/internal/flight/adapters/aviationstack"
	flighthttp "wanderplan/backend/internal/flight/adapters/httpapi"
	flightmem "wanderplan/backend/internal/flight/adapters/memory"
	flightpg "wanderplan/backend/internal/flight/adapters/postgres"
	flightredis "wanderplan/backend/internal/flight/adapters/redis"
	flightapp "wanderplan/backend/internal/flight/app"

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
	// FlightProvider overrides the provider chosen from Config (tests).
	FlightProvider flightapp.Provider
}

// Services exposes the application services (handy for tests and workers).
type Services struct {
	Identity *identityapp.Service
	Trips    *tripapp.Service
	Flights  *flightapp.Service
}

func NewServices(d Deps) Services {
	clock := d.Clock
	if clock == nil {
		clock = kernel.SystemClock
	}
	log := d.Logger
	if log == nil {
		log = slog.Default()
	}
	if d.DB != nil {
		tr := trippg.New(d.DB)
		st := flightpg.New(d.DB)
		return Services{
			Identity: identityapp.NewService(identitypg.New(d.DB), clock),
			Trips:    tripapp.NewService(tr, d.DB, clock),
			Flights: newFlights(d, clock, log, flightpg.Flights{Store: st}, flightpg.Bookings{Store: st},
				flightpg.Usage{Store: st}, d.DB),
		}
	}
	tr := tripmem.New()
	return Services{
		Identity: identityapp.NewService(identitymem.New(), clock),
		Trips:    tripapp.NewService(tr, tr, clock),
		Flights: newFlights(d, clock, log, flightmem.NewFlights(), flightmem.NewBookings(),
			flightmem.NewUsage(), flightmem.NoTx{}),
	}
}

func newFlights(d Deps, clock kernel.Clock, log *slog.Logger, f flightapp.FlightRepository, b flightapp.BookingRepository, u flightapp.Usage, tx flightapp.TxRunner) *flightapp.Service {
	fc := d.Config.Flights
	cfg := flightapp.DefaultConfig
	if fc.RefreshInterval > 0 {
		cfg.Cadence.Interval = fc.RefreshInterval
	}
	cfg.Cadence.DayOf = fc.DayOfInterval
	if fc.ManualCooldown > 0 {
		cfg.Cadence.ManualCooldown = fc.ManualCooldown
	}
	cfg.MonthlyBudget = fc.MonthlyBudget
	cfg.CacheTTL = cfg.Cadence.Interval

	var cache flightapp.Cache = flightmem.NewCache(clock)
	var locks flightapp.Locker = flightmem.NewLocker(clock)
	if url := fc.RedisURL.Reveal(); url != "" {
		if opts, err := goredis.ParseURL(url); err == nil {
			rdb := goredis.NewClient(opts)
			cache, locks = flightredis.NewCache(rdb, log), flightredis.NewLocker(rdb)
		} else {
			log.Error("REDIS_URL is not valid; using the in-process cache")
		}
	}
	return flightapp.NewService(flightProvider(d), f, b, cache, locks, u, tx, cfg, clock, log)
}

// flightProvider picks the configured provider; nil when no key is set.
func flightProvider(d Deps) flightapp.Provider {
	if d.FlightProvider != nil {
		return d.FlightProvider
	}
	fc := d.Config.Flights
	adb, avs := fc.AeroDataBoxKey.Reveal(), fc.AviationstackKey.Reveal()
	switch {
	case (fc.Provider == "aerodatabox" || fc.Provider == "") && adb != "":
		return aerodatabox.New(adb, aerodatabox.Marketplace(fc.AeroDataBoxVia), nil)
	case (fc.Provider == "aviationstack" || fc.Provider == "") && avs != "":
		return aviationstack.New(avs, nil)
	}
	return nil
}

// RunFlightWorker refreshes due flights every interval until ctx ends (the
// daily scheduler; due-ness is decided per flight by its cadence).
func RunFlightWorker(ctx context.Context, s Services, interval time.Duration, log *slog.Logger) {
	if !s.Flights.Configured() {
		log.Info("flight monitoring off: no AVIATIONSTACK_API_KEY or AERODATABOX_API_KEY")
		return
	}
	if interval <= 0 {
		interval = 5 * time.Minute
	}
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		if n, err := s.Flights.RunDue(ctx); err != nil {
			log.Warn("flight worker", "error", err)
		} else if n > 0 {
			log.Info("flights refreshed", "count", n)
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
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
	if d.Config.Auth == config.AuthDev && !d.Config.IsProduction() {
		// Development only: the app signs in to the demo account by itself.
		r.POST("/v1/auth/demo", identityhttp.DemoSignIn(d.Config.DevJWTSecret))
	}
	v1 := r.Group("/v1", auth.Required(d.Verifier, resolve))
	identityhttp.New(s.Identity).Register(v1)
	triphttp.New(s.Trips).Register(v1)
	flighthttp.New(s.Flights).Register(v1)
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
