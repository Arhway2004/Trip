GO ?= go
export GOTOOLCHAIN ?= local

.PHONY: run run-mem test test-integration lint fmt build docker up down token

run:            ## Run against DATABASE_URL from .env
	set -a; [ -f .env ] && . ./.env; set +a; $(GO) run ./cmd/api

run-mem:        ## Run with in-memory storage (no database needed)
	DATABASE_URL= AUTH_MODE=dev DEV_JWT_SECRET=change-me-local-dev-secret-at-least-32-chars $(GO) run ./cmd/api

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

token:          ## Print a dev token: make token SUB=alice
	DEV_JWT_SECRET=change-me-local-dev-secret-at-least-32-chars $(GO) run ./cmd/devtoken -sub $(or $(SUB),dev-user) -email $(or $(SUB),dev-user)@example.com
