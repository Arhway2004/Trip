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
