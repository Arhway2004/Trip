# WanderPlan Web (TanStack Start)

The web version of the planner. It's a full-stack React app built with **TanStack Start** and talks to the Go API in [`../backend`](../backend/README.md).

## Run it

```bash
# 1. Backend (in another terminal)
cd ../backend && make run-mem            # or `make run` with PostgreSQL

# 2. Web app
cp .env.example .env                     # DEV_JWT_SECRET must match the backend's
npm install
npm run dev                              # http://localhost:3000
```

Sign in with any name and email (development sign-in). The web app and the backend must use the same `DEV_JWT_SECRET`.

| Script                                  | What it does                                                                            |
| --------------------------------------- | --------------------------------------------------------------------------------------- |
| `npm run dev` / `build` / `preview`     | Vite dev server, production build (Nitro: `node .output/server/index.mjs`), and preview |
| `npm run gen:api`                       | Regenerates `src/lib/api/schema.d.ts` from [`../api/openapi.yaml`](../api/openapi.yaml) |
| `npm run i18n`                          | Compiles the translations (`messages/{en,zh,th}.json`)                                  |
| `npm test`                              | Vitest: domain rules, form validation, API error mapping, form component                |
| `npm run typecheck` / `lint` / `format` | TypeScript, ESLint, Prettier                                                            |

## Architecture

```
browser ──(server functions)──► TanStack Start server ──(Bearer token)──► Go API ──► PostgreSQL
              no token here          holds the session cookie
```

- **Backend-for-frontend:** the API token lives only in an **httpOnly cookie** (`wp_session`). Server functions (`*.functions.ts`) read it and call the Go API. Browser JavaScript never sees it.
  - Server-only code is named `*.server.ts`: `session.server.ts`, `client.server.ts`, `env.server.ts`.
- **One contract:** API types are generated from `../api/openapi.yaml` with openapi-typescript, then called through `openapi-fetch`.
- **Errors:** the API's RFC 9457 problem responses arrive as plain `Result` data. They become `ApiError` for TanStack Query, and pages map them:
  - 422 → messages next to the matching form fields
  - 412 → "someone else changed this trip" with a reload button
  - 404 → friendly "not found"
  - 503 → "can't reach the server"
- **Concurrency:** edits send `If-Match` with the trip version, so two people editing the same trip can't silently overwrite each other.
- **Same rules as the app:** trip status, countdown (in the trip's time zone), the default banner gradient, and form validation mirror the mobile app and the Go domain.
- **i18n:** Paraglide with English, Simplified Chinese and Thai. The locale comes from a cookie or the browser, and server rendering already uses it (`src/server.ts`).

```
src/
  routes/                 file-based routes (TanStack Router)
    __root.tsx            shell, header, session loading
    sign-in.tsx
    _app.tsx              protected layout (redirects to /sign-in)
    _app/trips/…          list · new · $tripId (detail) · $tripId/edit
  features/
    auth/                 session cookie (server), sign-in/out server functions
    trips/                server functions, queries, domain rules, schema, components
  lib/api/                generated schema, typed client (server), problem/Result model
  components/             header, locale switcher, error boundary, shadcn/ui
```

## Scope today

Implemented:

- sign-in (development) and sign-out
- trip list with status filters
- create, view, edit, archive and delete trips
- members list
- import mobile `.json` / `.wanderplan` ZIP files or paste JSON (schema v1–3), with editable plans and photos
- three languages

The web now includes itinerary/bookings, checklist, budget/rates, destinations, real maps, saved places, photos, covers and actual trip logs. See [the web planner guide](../docs/WEB_PLANNER.md). Live device sync is not enabled.

The day plan combines selectable map stops with activity, travel and buffer blocks. Compare walking/cycling/driving estimates, enter fixed train/bus/flight timetables, and record actual times, cost, notes and photos together. Public live-fare searches open Google Flights or 12Go with the trip criteria; results are viewed on those sites and entered manually. Optional server-only Duffel/HERE adapters are documented in the planner guide and require provider credentials.

Place search also accepts Google Maps place/share links. **Compare stop orders** offers road-based alternatives for 2–8 local stops, preserving bookings and locked visits. Review the proposed times and map before applying a choice; nothing is reordered automatically.

Production single sign-on (OIDC authorization-code flow) is not implemented yet. With `AUTH_MODE=oidc` the sign-in page says so honestly.

## Import a mobile trip

Open **My Trips → Import trip**, then choose a `.json` or `.wanderplan` file,
or select **Paste JSON**. Markdown code fences around pasted JSON are accepted.
The limit is 20 MB per upload and after ZIP expansion, with a maximum 5 MB JSON document.

Every import creates a new independent trip, with a new owner membership; it never
updates an existing trip. Invalid files name the offending field/activity, and no
partial trip is saved. JSON versions 1–3 match the mobile package format.

Trip details use the existing web editor. Destinations, checklist, activities and
bookings, expenses, exchange rates, saved places, cover and gallery images are
editable in the **Trip plan** tools. The original import remains preserved separately. JPEG, PNG, WebP and GIF previews
are supported; other media remains stored. Import does not enable device sync.

The full document and media are stored together in `imported_trip_packages`
(migration `00004`). These are snapshots, not rows in the future planning/sync API.
The snapshot stays as imported when you edit. The working plan is stored in `trip_plans` (migration `00005`) with version checks; export downloads your latest changes. PostgreSQL saves the
package and new trip atomically; in-memory mode keeps it only until API restart.
Restart the Go backend after updating so it loads the new routes and applies the
migration (when `AUTO_MIGRATE=true`).

If import reports **method not allowed (405)**, the API is likely still running
a build from before the import endpoint was added. Stop the running Go API and
start it again from `backend/` using your usual `make run` or `make run-mem`
command. Save any trips you need first: restarting `run-mem` clears its data.
The frontend dev server reloads frontend changes, but `go run` does not reload
backend changes automatically.

## Visual system

The interface shares its atlas typography, colors and journey-folio treatment with Flutter. Fonts and licenses are bundled in `public/fonts/`. See [`../docs/design/DIRECTION.md`](../docs/design/DIRECTION.md). The development overlay is hidden by default; use `VITE_SHOW_DEVTOOLS=true` to enable it. `npm test` includes checks that the core colors, cover palette and bundled font files agree with mobile.
