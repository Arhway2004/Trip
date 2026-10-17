// Command api runs the WanderPlan HTTP API.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "time/tzdata" // IANA zones for trip time-zone validation, even in minimal images

	"wanderplan/backend/internal/bootstrap"
	"wanderplan/backend/internal/platform/config"
	"wanderplan/backend/internal/platform/database"
	"wanderplan/backend/internal/platform/logging"
)

func main() {
	if err := run(); err != nil {
		slog.Error("fatal", "error", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	log := logging.New(cfg.LogLevel, cfg.IsProduction())
	slog.SetDefault(log)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	var db *database.DB
	if cfg.DatabaseURL != "" {
		db, err = database.Open(ctx, cfg.DatabaseURL)
		if err != nil {
			return err
		}
		defer db.Close()
		if cfg.AutoMigrate {
			if err := db.Migrate(ctx, log); err != nil {
				return err
			}
		}
	} else {
		log.Warn("DATABASE_URL not set: using in-memory storage (data is lost on restart)")
	}

	verifier, err := bootstrap.NewVerifier(ctx, cfg)
	if err != nil {
		return err
	}
	deps := bootstrap.Deps{Config: cfg, Logger: log, DB: db, Verifier: verifier}
	services := bootstrap.NewServices(deps)
	router := bootstrap.NewRouter(deps, services)
	go bootstrap.RunFlightWorker(ctx, services, cfg.Flights.WorkerInterval, log)

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           router,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      cfg.RequestTimeout + 5*time.Second,
		IdleTimeout:       120 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() {
		log.Info("listening", "addr", cfg.HTTPAddr, "env", cfg.Env, "auth", cfg.Auth)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
	}
	log.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	return srv.Shutdown(shutdownCtx)
}
