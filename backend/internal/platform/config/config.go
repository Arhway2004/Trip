// Package config loads 12-factor configuration from environment variables.
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type AuthMode string

const (
	AuthOIDC AuthMode = "oidc" // production: verify tokens from an OpenID Connect provider
	AuthDev  AuthMode = "dev"  // local only: HS256 tokens signed with DEV_JWT_SECRET
)

type Config struct {
	Env             string // "development" | "production" | "test"
	HTTPAddr        string
	DatabaseURL     string // empty = in-memory storage (development/test only)
	AutoMigrate     bool
	Auth            AuthMode
	OIDCIssuer      string
	OIDCAudience    string
	OIDCJWKSURL     string
	DevJWTSecret    string
	CORSOrigins     []string
	RequestTimeout  time.Duration
	ShutdownTimeout time.Duration
	MaxBodyBytes    int64
	LogLevel        string
	Flights         Flights
}

// Secret hides its value from logs and fmt output.
type Secret string

func (Secret) String() string               { return "[redacted]" }
func (Secret) GoString() string             { return "[redacted]" }
func (s Secret) Reveal() string             { return string(s) }
func (Secret) MarshalJSON() ([]byte, error) { return []byte(`"[redacted]"`), nil }

// Flights configures live flight monitoring. Keys come from the environment
// (for local runs: ../secrets/*.env, loaded by `make run`), never from code.
type Flights struct {
	Provider         string // "aviationstack" | "aerodatabox" | "" (pick whichever key is set)
	AviationstackKey Secret
	AeroDataBoxKey   Secret
	AeroDataBoxVia   string // "apimarket" | "rapidapi"
	MonthlyBudget    int
	RefreshInterval  time.Duration // once per flight per interval (agency design: 24h)
	DayOfInterval    time.Duration // 0 = same as RefreshInterval
	ManualCooldown   time.Duration
	WorkerInterval   time.Duration
	RedisURL         Secret // empty = in-process cache/lock (single instance)
}

func (c Config) IsProduction() bool { return c.Env == "production" }

// Load reads the environment and validates the combination of settings.
func Load() (Config, error) {
	c := Config{
		Env:             env("APP_ENV", "development"),
		HTTPAddr:        env("HTTP_ADDR", ":8080"),
		DatabaseURL:     os.Getenv("DATABASE_URL"),
		AutoMigrate:     envBool("AUTO_MIGRATE", true),
		Auth:            AuthMode(env("AUTH_MODE", "dev")),
		OIDCIssuer:      os.Getenv("OIDC_ISSUER"),
		OIDCAudience:    os.Getenv("OIDC_AUDIENCE"),
		OIDCJWKSURL:     os.Getenv("OIDC_JWKS_URL"),
		DevJWTSecret:    os.Getenv("DEV_JWT_SECRET"),
		CORSOrigins:     splitList(os.Getenv("CORS_ORIGINS")),
		RequestTimeout:  envDuration("REQUEST_TIMEOUT", 15*time.Second),
		ShutdownTimeout: envDuration("SHUTDOWN_TIMEOUT", 20*time.Second),
		MaxBodyBytes:    int64(envInt("MAX_BODY_BYTES", 1<<20)),
		LogLevel:        env("LOG_LEVEL", "info"),
		Flights: Flights{
			Provider:         env("FLIGHT_PROVIDER", ""),
			AviationstackKey: Secret(strings.TrimSpace(os.Getenv("AVIATIONSTACK_API_KEY"))),
			AeroDataBoxKey:   Secret(strings.TrimSpace(os.Getenv("AERODATABOX_API_KEY"))),
			AeroDataBoxVia:   env("AERODATABOX_VIA", "apimarket"),
			MonthlyBudget:    envInt("FLIGHT_MONTHLY_BUDGET", 100),
			RefreshInterval:  envDuration("FLIGHT_REFRESH_INTERVAL", 24*time.Hour),
			DayOfInterval:    envDuration("FLIGHT_DAY_OF_INTERVAL", 0),
			ManualCooldown:   envDuration("FLIGHT_MANUAL_COOLDOWN", 30*time.Minute),
			WorkerInterval:   envDuration("FLIGHT_WORKER_INTERVAL", 5*time.Minute),
			RedisURL:         Secret(strings.TrimSpace(os.Getenv("REDIS_URL"))),
		},
	}
	return c, c.Validate()
}

func (c Config) Validate() error {
	var errs []error
	switch c.Auth {
	case AuthOIDC:
		if c.OIDCIssuer == "" || c.OIDCAudience == "" {
			errs = append(errs, errors.New("AUTH_MODE=oidc requires OIDC_ISSUER and OIDC_AUDIENCE"))
		}
	case AuthDev:
		if c.IsProduction() {
			errs = append(errs, errors.New("AUTH_MODE=dev is not allowed in production"))
		}
		if len(c.DevJWTSecret) < 32 {
			errs = append(errs, errors.New("AUTH_MODE=dev requires DEV_JWT_SECRET of at least 32 characters"))
		}
	default:
		errs = append(errs, fmt.Errorf("unknown AUTH_MODE %q", c.Auth))
	}
	switch c.Flights.Provider {
	case "", "aviationstack", "aerodatabox":
	default:
		errs = append(errs, fmt.Errorf("unknown FLIGHT_PROVIDER %q", c.Flights.Provider))
	}
	if c.Flights.RefreshInterval != 0 && c.Flights.RefreshInterval < time.Hour {
		errs = append(errs, errors.New("FLIGHT_REFRESH_INTERVAL must be at least 1h"))
	}
	if c.IsProduction() && c.DatabaseURL == "" {
		errs = append(errs, errors.New("DATABASE_URL is required in production"))
	}
	return errors.Join(errs...)
}

func env(k, def string) string {
	if v := strings.TrimSpace(os.Getenv(k)); v != "" {
		return v
	}
	return def
}

func envBool(k string, def bool) bool {
	if v, err := strconv.ParseBool(os.Getenv(k)); err == nil {
		return v
	}
	return def
}

func envInt(k string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(k)); err == nil {
		return v
	}
	return def
}

func envDuration(k string, def time.Duration) time.Duration {
	if v, err := time.ParseDuration(os.Getenv(k)); err == nil {
		return v
	}
	return def
}

func splitList(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}
