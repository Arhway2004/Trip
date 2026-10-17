GO ?= go
export GOTOOLCHAIN ?= local

.PHONY: run run-mem test test-integration lint fmt build docker up down token

# Secrets (API keys) live in ../secrets/*.env, outside git; they are loaded
# into the environment here and never printed.
LOAD_SECRETS = for f in ../secrets/*.env; do [ -f "$$f" ] && . "$$f"; done

run:            ## Run against DATABASE_URL from .env (+ API keys from ../secrets)
	set -a; [ -f .env ] && . ./.env; $(LOAD_SECRETS); set +a; $(GO) run ./cmd/api

run-mem:        ## Run with in-memory storage (no database needed; API keys from ../secrets)
	set -a; $(LOAD_SECRETS); set +a; DATABASE_URL= AUTH_MODE=dev DEV_JWT_SECRET=change-me-local-dev-secret-at-least-32-chars $(GO) run ./cmd/api

test:           ## Unit, HTTP, contract and architecture tests
	$(GO) test -race -count=1 ./...

test-integration: ## Also run PostgreSQL tests (needs `make up`)
	TEST_DATABASE_URL=postgres://wanderplan:wanderplan@localhost:5432/wanderplan?sslmode=disable $(GO) test -race -count=1 ./...

lint:
	$(GO) vet ./... && golangci-lint run

fmt:
	gofmt -w .

build:
	CGO_ENABLED=0 $(GO) build -trimpath -o bin/api ./cmd/api

docker:
	docker build -t wanderplan-api .

up:
	docker compose up -d --build

down:
	docker compose down

token:          ## Print a dev sign-in token for the phone: make token SUB=alice TTL=720h
	@DEV_JWT_SECRET=change-me-local-dev-secret-at-least-32-chars $(GO) run ./cmd/devtoken -sub $(or $(SUB),dev-user) -email $(or $(SUB),dev-user)@example.com -ttl $(or $(TTL),24h)
