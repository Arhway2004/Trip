# WanderPlan API (Go + Gin)

Backend for the WanderPlan app: accounts, and (in later steps) sync, collaboration, cloud backup and server-side integrations. The app stays **local-first**; this service syncs and extends it.

**Step 1 (this commit): foundation.** Auth, users, and trips with memberships, optimistic concurrency, and an OpenAPI contract.

## Run it

```bash
make run-mem          # no database needed (in-memory, dev auth) → http://localhost:8080
make token SUB=alice  # prints a dev bearer token
curl -H "Authorization: Bearer $(make -s token SUB=alice)" localhost:8080/v1/me
```

With PostgreSQL. You already have PostgreSQL 17 installed at `/Library/PostgreSQL/17`; create a database and set `DATABASE_URL` in `.env`, then run `make run`. Or use Docker:

```bash
make up               # Postgres + API via docker compose (migrations run on start)
make test-integration # includes the PostgreSQL repository tests
```

Requires Go 1.23+. Configuration is environment variables only (see `.env.example`).

## Architecture

Modular monolith, domain-driven, ports & adapters. It mirrors the Flutter app's bounded contexts.

```
cmd/api            HTTP server (graceful shutdown, timeouts)
cmd/devtoken       dev JWT minting for AUTH_MODE=dev
internal/
  kernel/          shared kernel: error kinds, Date, Clock (no dependencies)
  platform/        config, logging (slog), database (pgx pool, goose migrations, tx-in-context),
                   httpx (Gin middleware, RFC 9457 errors), auth (OIDC/JWKS, dev HS256)
  identity/        domain · app · adapters/{postgres,memory,httpapi}
  trip/            domain · app · adapters/{postgres,memory,httpapi}
  bootstrap/       composition root: wires adapters → ports → services → Gin routes
migrations/        SQL (goose), embedded in the binary
../api/openapi.yaml  the API contract shared with the app
```

| Layer | May depend on | Enforced by |
|---|---|---|
| `domain` | stdlib, `uuid`, `kernel`, its own domain | `internal/archtest` |
| `app` (use cases + ports) | its domain, `kernel` (never Gin, pgx, `net/http`, adapters) | `internal/archtest` |
| `adapters` | anything; implement the ports | — |
| `bootstrap` | everything (the only place that wires) | — |

Contexts never import another context's adapters.

### API conventions
- `/v1` prefix; JSON field names match the app's trip file format.
- **Errors:** `application/problem+json` (RFC 9457) with a stable `code`, field `errors`, and `requestId`.
- **Concurrency:** `GET` returns `ETag: "<version>"`. `PUT` **requires** `If-Match` (428 if missing, 412 if stale). `GET` supports `If-None-Match` → 304.
- **Idempotent create:** the app sends its own UUID `id`. A retry returns 200 with the existing trip.
- **Privacy:** non-members get 404, never 403, so trip IDs can't be probed.
- **Roles:** `owner` (everything), `editor` (edit), `viewer` (read).
- `X-Request-ID` is propagated and logged. Every request gets one structured access-log line.

### Auth
- **Production:** any OpenID Connect provider (Zitadel, Auth0, Cognito, Keycloak). Set `AUTH_MODE=oidc`, `OIDC_ISSUER` and `OIDC_AUDIENCE`. Signing keys are discovered and rotated automatically.
- Users are created on first sign-in from the token's `sub`. There are no passwords in this service.
- `AUTH_MODE=dev` (HS256 shared secret) exists for local work and is refused when `APP_ENV=production`.

## Tests

`make test` (with `-race`) runs:

- **Domain rules:** validation, roles.
- **Use cases:** idempotent create, permissions, optimistic locking (in-memory adapters).
- **End-to-end HTTP:** through the real Gin router.
- **Contract test:** every Gin route must be in `openapi.yaml` and vice versa.
- **Architecture test:** the layering rules above.

PostgreSQL repository tests run when `TEST_DATABASE_URL` is set (`make test-integration`).

## Roadmap

1. ✅ Foundation (this)
2. Sync: push/pull change feed for trips, activities, expenses, checklist (cursor + idempotency keys)
3. Collaboration: invite links, member management, real-time updates (SSE)
4. Media and cloud backup: S3/R2 presigned uploads
5. Integrations: Amap/routing proxy (server-held keys), rates cache, OCR, push notifications (River jobs + outbox)

## Mobile trip import

`POST /v1/trips/import` accepts raw JSON (including fenced text) or `.wanderplan`
ZIP bytes as `application/octet-stream`. Upload limit: 20 MB; total expanded ZIP
limit: 20 MB, 1000 entries, with a maximum 5 MB JSON document. No archive paths are
extracted to disk. Validated mobile schema versions 1–3 create a fresh trip and
owner membership, and atomically retain the complete package in migration
`00004_imported_packages.sql`.

`GET /v1/trips/{tripId}/import` returns that read-only snapshot, or `null` for a
non-imported trip. Membership is checked first. Planning data is retained in the
snapshot pending the planning API, not inserted into the future sync tables.
