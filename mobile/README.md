# WanderPlan Mobile (Flutter)

Part of the WanderPlan monorepo, see the [root README](../README.md). Run all commands below from `mobile/`.

## About the app

A local-first Flutter app (Android + iOS) for planning trips anywhere in the world. No account, no cloud backend: all data lives in an on-device SQLite database (Drift), and photos live in the app sandbox.

The app is being built in the six phases defined in the product spec. **Only Phase 1 is implemented so far.** Screens for later phases are shown as clearly labelled "Not implemented yet" states, not as fake data.

## Status

| Phase | Scope | Status |
|---|---|---|
| 1 — Foundation & personalization | Project setup, navigation, database, trip creation, multiple trips, cover banners, countdown, trip dashboard, photo storage | ✅ Implemented and tested |
| 2 — Planning | Daily timeline, flights, trains, hotels, budget ✅ · attraction library ⏳ | 🟡 Mostly done |
| 3 — Real maps & routes | Map provider abstraction (OpenStreetMap / Amap with GCJ-02), place search, explore nearby, saved places, marker filters, real road routes per day, current location, external navigation ✅ · transport comparison & timeline sync (§10–11) ⏳ | 🟡 Map system (§9) done |
| 4 — Intelligent features | Feasibility checks ✅ · optimization, fatigue, scenarios ⏳ | 🟡 Started |
| 5 — Travel & memories | Travel Mode, expenses, receipt import/OCR, albums, journal, planned vs actual | ⏳ Not started |
| 6 — Export & production | JSON/XLSX/PDF/ZIP export + restore, ChatGPT export, notifications, home-screen widgets | ⏳ Not started |

### What works in Phase 1

- **My Trips (Home):** unlimited trips as large banner cards with destination(s), dates, duration, travelers, live countdown, status, and budget. Filters: All / Upcoming / Traveling / Completed / Archived (All hides archived trips). Create, open, edit, duplicate (as a template), reorder (drag), archive/unarchive, delete with confirmation. Friendly empty state; no trip is ever created automatically.
- **Create / edit trip:** only the title is required. Optional cover photo (gallery or camera), description, any number of city/country destinations, a date range or no dates yet, a "dates confirmed" toggle for flexible dates, an optional departure time, an IANA time zone (searchable; defaults to the device zone), traveler count, any ISO 4217 currency, total budget, travel style, and planning stage.
- **Trip status:** *Dreaming* / *Planning* are set by the user. *Upcoming* (confirmed future dates), *Traveling*, and *Completed* come from the dates in the trip's time zone. *Archived* overrides everything else.
- **Countdown:** "45 days to go", "12 days, 6 hours remaining" (when a departure time is set), "Day 3 of 10", "Trip Completed". It is computed in the trip's time zone, never goes negative, and refreshes every 30 s while the app is open.
- **Banner editor:** upload from the device, take a photo, or pick an existing trip photo; drag to reposition and pinch or use the slider to zoom; reset the crop; gradient and solid-color backgrounds; title overlay on/off, title placement, text color; four styles (Classic, Minimal, Bold, Framed). The crop is **non-destructive**: the original image is kept, and scale and alignment are stored so you can re-edit later.
- **Dashboard:** collapsing banner header, countdown card, overview (destinations, dates, duration, travelers, time zone, style, description), budget summary (total and per person), and a photo strip. Planning modules from later phases are shown disabled.
- **Gallery:** add multiple photos from the device or take one with the camera, a full-screen viewer with pinch zoom, captions, favorites (with a filter), set as cover banner, and delete (if the photo is the banner, the banner falls back to colors).
- **Before you go (to-do list):** a per-trip pre-departure checklist with categories (documents, bookings, packing, health and insurance, money, phone and internet, home, other), optional due dates, and notes. It shows "Due in N days" / overdue in the trip's time zone, and warns about tasks due after departure. You can hide completed tasks, swipe to delete (with undo), and add optional generic starter suggestions. These are reminders only, with no destination facts. The dashboard shows progress and the next 3 open tasks, and trip cards show `To-dos 3/10`. Duplicating a trip copies the list, unchecked.
- **Import:** from a file, or by **pasting JSON text** (e.g. from ChatGPT). Errors name the exact field and activity. Activities may have no time yet ("Time TBD"); the app never invents one.
- **Share with a friend:** the dashboard's 👤+ button packages the trip as a `.wanderplan` file (trip details, destinations, banner, to-dos, and optionally gallery photos) and opens the system share sheet (Messages, LINE, WeChat, email, AirDrop, …). Your friend imports it with **My Trips → ⋮ → Import trip from file** and gets their **own independent copy**. Later edits are *not* synced between the two copies. Importing never overwrites anything, and files from newer app versions are rejected with a clear message.
- **Timeline (itinerary):** day-by-day plan with a status per day (Feasible / Tight / Unrealistic / Needs info / Free day) and the specific reasons. It flags overlaps, no time to travel between places, too little buffer before flights (2 h) and trains (30 min), very long days, no lunch break, late finishes, nights without accommodation, double-booked hotels, unbooked flights/trains, and items outside the trip dates. Distance checks use straight-line distance at about 25 km/h and say they are estimates. Views: list with free-time gaps, or a 00:00–24:00 time grid (starts at 06:00) where you long-press to drag and drag the bottom edge to resize, snapping to 15 min. Locked bookings never move. Hotels span nights; overnight transport spans days.
- **Bookings:** all flights, trains, buses, ferries and hotel stays in one list, with status, cost and private reference.
- **Map (spec §9):**
  - **Providers:** a provider abstraction with *Automatic* (Amap in mainland China, OpenStreetMap elsewhere), *OpenStreetMap* or *Amap*, chosen in Settings or the map's layer menu. Everything is stored in WGS84. Points are converted to GCJ-02 only to draw on Amap, and taps and Amap results are converted back. Mainland China is detected with a region table, not a bounding box, so Bangkok, Hanoi, Seoul and Taipei are never shifted.
  - **Pins:** all days, or one day with numbered stops in time order.
  - **Day route:** starts at last night's hotel and ends at tonight's hotel. Road routes for walking, cycling or driving come from OSRM (FOSSGIS) or, with a key, Amap. Distance and typical time are shown, labelled as estimates. Booked flights, trains and ferries are drawn as dotted direct lines, never as roads. A leg with no route is a dashed straight line labelled **unverified**. Activities without a time are pinned but kept out of the route.
  - **Search and explore:** search on submit (Nominatim; Amap with a key). *Explore nearby* finds attractions, restaurants, hotels, airports, railway stations and bus stations around the visible area.
  - **Saved places:** save, recategorize, remove (with undo) or **Add to day**, which creates an untimed activity. Long-press the map to pin your own place. Saved places are in trip files (schema v3), are copied when a trip is duplicated, and are listed under Saved places.
  - **Find locations:** for plans imported with only place names (e.g. from ChatGPT), the map offers *Find locations*. Each distinct name is searched once, and matches near the trip's destination cities rank first; far ones are flagged (a 中山路步行街 in another city). Generic names such as "Kunming hotel" are never pre-selected. Nothing changes until you accept, and one accepted place updates every activity that uses that name.
  - **Paste a link:** anywhere a location is chosen (map search box, location picker, Find locations), paste a Google Maps link, `maps.app.goo.gl` short link, embed `<iframe>`, Amap/Apple Maps link, "lat, lng" or a Plus Code ("RP63+XW2, Shangri-La"). Google, Amap and Apple Maps coordinates in mainland China are GCJ-02 and are converted to GPS. An embed link only carries the map centre, which is flagged.
  - **Other:** marker filters by activity kind and place category, *My location* (asked on tap, foreground only, never stored), and handoff to Google Maps, Apple Maps or Amap.
  - **Online:** tiles, search and routing need the internet. Viewed tiles are cached as the tile servers allow.
- **Budget:** planned (itinerary costs + planned expenses) vs spent (actual expenses), remaining, per person, by category (paired bars, colors checked for color-blind safety) and by day. Multiple currencies with per-trip exchange rates, entered by hand or fetched live from frankfurter.app (ECB rates); amounts without a rate are flagged, not guessed. Expenses can be linked to activities, marked paid/unpaid, and shared or personal.
- **Languages:** English (default), Simplified Chinese, and Thai, switchable in Settings. Dates and currency use locale-aware formatting.
- **Privacy:** Settings → Delete all data wipes the database and all stored media.

### Deviations and known limits

- **Cropping:** instead of a native cropping package, Phase 1 uses an in-app, non-destructive pan/zoom editor. This meets the "re-edit the crop later" requirement better than a destructive crop, and it needs no extra native setup. `image_cropper` can be added later if a free-form crop rectangle is needed.
- **Images:** picked images are downscaled to at most 2048 px at quality 85 for performance. Banners decode at display width, so very wide panoramas (wider than about 2:1) may look slightly soft.
- **Live collaboration (join via link, real-time sync) is not built.** It needs a sync backend and accounts, which the local-first design deliberately avoids for core features. Sharing is currently file-based copies. Tapping a `.wanderplan` file in another app doesn't open WanderPlan yet (no file-type registration). Use Import trip.
- **Not yet built:** full backup restore (the menu entry explains this), reminders and notifications, home-screen widgets, the per-traveler `Traveler` and `TripDay` entities, albums, and attaching photos to days or attractions. These come in later phases.
- **Map limits (honest list):**
  - Public-transport routing isn't offered: no free provider returns timetabled routes, so the app hands off to a map app instead.
  - Route times are the provider's typical estimates (no live traffic, no departure-time routing, §11).
  - Choosing and comparing a transport mode per leg (§10) is not built yet.
  - Offline maps aren't offered; the OSM tile policy forbids bulk downloads.
  - Amap draws with its public web tiles through `flutter_map`, not the native Amap SDK. The official `amap_flutter_map` plugin was last released in 2021 and doesn't support Dart 3; the community `amap_map` needs a key, a privacy-consent flow and a native build. Before a commercial release, confirm the Amap licence or switch to the native SDK.
  - Nearby search uses Nominatim's category search inside the visible area. The public Overpass API was tested but reported itself at capacity and asks apps not to depend on it.
- **Freezed / json_serializable:** not used yet. Phase 1 models are Drift data classes plus small hand-written classes. They will be introduced with the JSON export schema in Phase 6.

## Backend

A separate Go (Gin) API lives in [`backend/`](../backend/README.md), with the shared contract in [`api/openapi.yaml`](../api/openapi.yaml). Step 1 (accounts, trips, memberships, optimistic concurrency) is built; the app does not call it yet. Sync is step 2.

## Requirements

- Flutter 3.38+ (stable), Dart 3.10+
- Xcode 16+ for iOS (minimum iOS 14), Android SDK 36 for Android

## Getting started

```bash
flutter pub get
flutter run                      # pick an Android or iOS device / simulator
```

Optional: Amap search and routing in mainland China need an Amap **Web 服务** key from [lbs.amap.com](https://lbs.amap.com/). Without one, Amap tiles still draw and OpenStreetMap search and routing are used, and the map says so.

```bash
flutter run --dart-define=AMAP_WEB_KEY=your_key
```

Generated code (`*.g.dart`, `lib/l10n/gen/`) is included in the project. You only need to regenerate it after changing tables or strings:

```bash
# Drift schema → lib/core/db/app_database.g.dart
dart run build_runner build --delete-conflicting-outputs --force-jit
```

`--force-jit` is needed on this toolchain because some transitive dependencies use native build hooks, and AOT build-script compilation doesn't support them.

```bash
# Strings: edit the table in tool/gen_arb.py, then
python3 tool/gen_arb.py && flutter gen-l10n
```

`tool/gen_arb.py` is the single source for all three languages, so keys can't drift apart.

## Building

```bash
flutter build apk --release             # Android APK (configure signing in android/app/build.gradle.kts)
flutter build appbundle --release       # Play Store bundle
flutter build ios --release             # iOS (set your Team in Xcode → Runner → Signing)
```

## Tests

```bash
flutter test
```

| File | Covers |
|---|---|
| `test/domain/countdown_test.dart` | Countdown in the trip's time zone, days/hours/minutes, Day N of M, completed, never negative, invalid zones and dates |
| `test/domain/trip_status_test.dart` | Status derivation and filters |
| `test/domain/domain_model_test.dart` | Trip invariants (title, travelers, budget, dates), banner value object, checklist ordering, package colors |
| `test/application/trip_service_test.dart` | Independent trips, edits, reorder, duplicate (banner file and checklist copy), banner round-trip, photos, cascade delete with media cleanup, archive, delete-all |
| `test/application/checklist_service_test.dart` | Per-trip lists, ordering, done/undo, **v1 → v2 migration on a real DB file** |
| `test/application/trip_package_test.dart` | Share/import between two simulated devices, banner-only export, double import, invalid / too-new / blank-title files, bare JSON, **`Example/trip_template.json`** |
| `test/application/persistence_test.dart` | Data survives an app restart (DB reopened) |
| `test/architecture/layering_test.dart` | Enforces the DDD dependency rules |
| `test/widgets/app_flow_test.dart` | Empty state → create trip with only a title → dashboard → home card; countdown text and filters on the home screen; switching to Thai and Chinese; adding suggested to-dos and checking one off |

## Architecture (domain-driven)

The code is organized by **bounded context**. Each context has four layers, and the dependency rules are enforced by `test/architecture/layering_test.dart`:

| Layer | Contains | May depend on |
|---|---|---|
| `domain/` | Entities, value objects, business rules, repository **interfaces** (ports) | Pure Dart only + `shared/domain` |
| `application/` | Use-case services (commands), query services and read models, DTOs | Domain + `shared/application` ports. Never Flutter, Drift or presentation |
| `infrastructure/` | Adapters: Drift repositories + row↔entity mappers, ZIP codec | Domain, database |
| `presentation/` | Screens, widgets, Riverpod providers | Application + domain. Never the database |

```
lib/
  main.dart                       bootstrap (time zones, DB, media, device zone)
  app/
    service_registry.dart         composition root: wires adapters → ports → services
    providers.dart                Riverpod exposure of the registry + UI-wide state
    router.dart, app.dart
  contexts/
    trip/        Trip aggregate (destinations, banner VO), status/countdown rules,
                 TripService (create/update/duplicate/archive/delete/banner),
                 TripQueryService → TripSummary read model, home/dashboard/form/banner UI
    gallery/     Photo entity, GalleryService, gallery UI
    itinerary/   Activity entity (incl. transport & stays), feasibility analyzer, day-route planner,
                 ItineraryService, timeline (list + drag/resize grid), activity editor, bookings
    budget/      Expense & ExchangeRate entities, BudgetReport, BudgetService, RateSource port
                 (Frankfurter adapter), budget screen
    places/      Map provider policy (OSM/Amap, WGS84↔GCJ-02), SavedPlace entity + service, ports for
                 PlaceSearch / RouteService / LocationService with Nominatim, OSRM, Amap and geolocator
                 adapters, trip map, place sheet, location picker
    checklist/   ChecklistItem entity ("Before you go"), ChecklistService, UI
    sharing/     .wanderplan package schema, ZIP codec, TripPackageService, share sheet
    settings/    DataManagementService (delete all data), settings UI
  shared/
    domain/          LocalDate, countdown, Clock, IdGenerator, DomainException, currency list
    application/     UnitOfWork, MediaStore, SettingsStore ports
    infrastructure/  Drift database + migrations, file media store, UUIDs, UoW
    presentation/    theme tokens, reusable widgets, l10n helpers, pickers
```

**Conventions**

- One aggregate per repository. Use cases that touch several aggregates run inside `UnitOfWork.run`, which is a Drift transaction.
- Contexts talk to each other only through domain types and application services, never through another context's infrastructure.
- The query side (`TripQueryService`) combines streams from several contexts into read models, so the UI never joins tables itself.
- Tests build a whole simulated device with `TestDevice.create()` (in-memory DB, temp media, real services).
- **Adding a feature (e.g. Phase 2 Flights):** create `contexts/flight/{domain,application,infrastructure,presentation}`, add a table and a migration step, implement the repository port, register the service in `ServiceRegistry`, then expose it in `providers.dart`.

See also: [`docs/IMPORT_FORMAT.md`](../docs/IMPORT_FORMAT.md) (trip file format) and [`docs/REQUEST_TRACKER.md`](../docs/REQUEST_TRACKER.md) (every request mapped to the plan).

## Database (schema v5)

All IDs are client-generated UUIDv4. Foreign keys are enforced (`PRAGMA foreign_keys = ON`), and child rows cascade on trip deletion. Multi-table writes run in transactions.

| Table | Purpose / key columns |
|---|---|
| `trips` | `id`, `title`, `description`, `start_date`/`end_date` (`yyyy-MM-dd`, local to the trip zone, nullable), `departure_time` (`HH:mm`), `dates_confirmed`, `time_zone` (IANA), `traveler_count`, `currency` (ISO 4217), `total_budget`, `travel_style`, `stage`, `archived`, `sort_order`, timestamps |
| `trip_destinations` | `trip_id` → trips, `country`, `city`, `sort_order` (first = main destination) |
| `trip_banners` | 1:1 with trips: `kind` (photo/gradient/solid), `image_path` (relative), `scale`, `align_x`, `align_y`, `color_a`, `color_b`, `show_title`, `title_placement`, `text_color`, `style` |
| `trip_photos` | `trip_id` → trips, `rel_path`, `caption`, `is_favorite`, `created_at` |
| `activities` *(v3)* | `trip_id` → trips, kind, date/start/end (+ end date), `has_time` *(v4: false = time not decided)*, location/destination name + optional WGS84 lat/lng + source, cost, currency, booking status/provider/number/reference/url, locked, optional, notes |
| `expenses` *(v3)* | `trip_id` → trips, title, category, amount, currency, kind (planned/actual), paid, date, `activity_id` → activities (set null on delete), shared, notes |
| `exchange_rates` *(v3)* | (`trip_id`, currency) → rate into the trip currency, source, updated at |
| `saved_places` *(v5)* | `trip_id` → trips, name, category, **required** WGS84 lat/lng, address, coordinate source, notes, timestamps |
| `trip_todos` *(v2)* | `trip_id` → trips, `title`, `notes`, `category`, `due_date`, `is_done`, `done_at`, `sort_order` |
| `app_settings` | key/value (language, map provider, selected trip) |

### Trip share file (`.wanderplan`)

A ZIP with `trip.json` and `media/<n>.<ext>`. `trip.json` has `format: "wanderplan.trip"`, `schemaVersion: 1`, `exportedAt`, plus `trip`, `destinations`, `banner` (with `image` → media path), `photos`, and `todos`. Local IDs and absolute paths are never exported. A bare `trip.json` without media is also accepted.

Media paths are stored **relative** to the media root because iOS changes the absolute container path between installs and restores.

**Migrations:** bump `schemaVersion` in `lib/core/db/app_database.dart` and add `if (from < N)` steps in `onUpgrade`. Later phases add the remaining spec entities (Traveler, TripDay, Place, Attraction, Scenario, Activity, TransportSegment, Flight, Train, HotelBooking, Expense, Receipt, ExchangeRate, RouteCache, VerificationSource, Reminder, PhotoAlbum, JournalEntry) this way.

## Visual system

The interface shares its personal-travel-atlas design with the web app: paper and forest colors, bundled Newsreader/DM Sans fonts, numbered covers, route artwork and underlined filters. Existing photos and custom banner settings are retained. See [`../docs/design/DIRECTION.md`](../docs/design/DIRECTION.md) for the shared tokens and visual review. Widget layout tests include small screens, tablets, dark mode, large text and translated labels.
