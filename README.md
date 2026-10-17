# WanderPlan

Personal travel planner: plan trips anywhere, track budget and bookings, keep memories. Local-first, with an optional backend for sync and collaboration.

## Repository layout

| Folder | What | Stack | Status |
|---|---|---|---|
| [`mobile/`](mobile/README.md) | iOS & Android app | Flutter · Riverpod · Drift (SQLite) · DDD | Phases 1–2 built, parts of 3–6 |
| [`backend/`](backend/README.md) | API for accounts, sync, collaboration, integrations | Go · Gin · PostgreSQL · OIDC | Step 1 (foundation) built |
| [`frontend/`](frontend/README.md) | Web app | TanStack Start · React 19 · TanStack Query/Form · Paraglide · Tailwind v4 + shadcn/ui | Trips (list, create, view, edit, archive, delete), dev sign-in, en/zh/th |
| [`api/`](api/openapi.yaml) | **API contract** (OpenAPI 3) shared by all clients | | |
| [`docs/`](docs/) | [Database schema](docs/DATABASE.md), [import format](docs/IMPORT_FORMAT.md), [request tracker](docs/REQUEST_TRACKER.md) | | |
| [`Example/`](Example/trip_template.json) | Sample trip file to import | | |
| `Reference/` | Earlier web prototype used as design reference | | |

## How the pieces fit

```
 mobile (Flutter) ─┐                         ┌─ PostgreSQL
                   ├── HTTPS /v1 (api/openapi.yaml) ──► backend (Go) ─┤
 frontend (web) ───┘                         └─ OIDC provider, object storage, integrations
```

- **One contract:** `api/openapi.yaml` is the single source of truth. The backend has a test that fails if its routes and the contract drift apart, and clients generate their API code from it.
- **Same domain model everywhere:** trips, itinerary, budget, checklist, gallery and sharing are the same bounded contexts in the app and the backend, with the same JSON field names as the trip file format.
- **The mobile app works fully offline.** The backend adds accounts, multi-device sync, collaboration and server-side keys.

## Quick start

```bash
# Mobile
cd mobile && flutter pub get && flutter run

# Backend (no database needed for a first look)
cd backend && make run-mem

# Web
cd frontend && cp .env.example .env && npm install && npm run dev
```

Each folder's README has full setup, architecture and test instructions.

## Shared interface

Web and mobile use the same personal-travel-atlas design system: bundled Newsreader and DM Sans, paper/forest colors, numbered journey folios and route artwork. See [creative direction and visual review](docs/design/DIRECTION.md) for tokens, preview captures and verification scope.
