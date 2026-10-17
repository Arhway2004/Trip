# Web planner

The web trip page has editable planning tools based on the Flutter model and the day list in `Reference/Trip`. This is a functional trip workspace, with the existing shared neutral/forest palette and bundled fonts.

## Tools

- **Day plan:** a 00:00–24:00 schedule with activity, travel and arrival/boarding buffer blocks; numbered selectable map stops include untimed visits and overnight hotels. Compare actual-time overlays with the plan, and check overlaps and fixed service departures. All times use the trip's time zone.
- **Timeline / Bookings:** add, edit, duplicate, reorder and delete activities. Edit booking status, operator, service number, reference, URL, dates/times, estimated costs, notes, coordinates, optional and locked flags. Saved places can fill either endpoint.
- **Before you go:** editable tasks, due dates, categories, notes and completion.
- **Budget:** planned/actual expenses, activity links, paid/shared flags, manual exchange rates, totals and actual spending per person. Missing rates are excluded and named, matching mobile accounting.
- **Saved places:** destinations, explicit place search, real OpenStreetMap tiles, map-click coordinates and adding saved places to the itinerary. Coordinates are never invented from a place name.
- **Photos / Cover:** raster uploads, captions, favorites, activity/date links, deletion, cover selection, background colors, title placement/style and non-destructive crop settings. Each photo is limited to 5 MB; the web uploader reserves an 18 MB media budget. Unsupported imported media remains stored without inline rendering.
- **Trip log:** actual arrival/departure dates and times plus notes linked to an activity. Arrival can be recorded before departure is known. Recording actuals does not change planned times. Record costs, notes and photo evidence in the same visit form; they also appear in Budget and Photos. Re-editing the visit updates its own cost/photo entries without duplicates.

## Routing and feasibility

### Google Maps pins

In **Saved places**, or **Day plan → select a stop → Find or update map location**, paste a Google Maps place/share link into Search places. Full coordinate query URLs, place URLs with explicit pin coordinates, `maps.app.goo.gl` and `goo.gl/maps` redirects are supported. Review the result and click Save. The day editor retains the source link with the endpoint. A name-only link runs the existing place search and asks the user to select a result; viewport-center coordinates are never treated as a place pin. Share a single place rather than a directions itinerary.

Short links resolve server-side using a small Google-host allowlist, manual redirects, four-hop and per-request timeout limits. No Google API key is required for this link import. Unresolvable/unsupported links explain how to use a full coordinate link or place-name search. The displayed map remains OpenStreetMap. A real BACC share link published by Bangkok's official public-space directory was tested through the app.

### Compare stop orders

Expand **Compare stop orders** in the day plan. The first stop is the starting point. Choose which other stops may move, a walking/cycling/driving mode, start/finish limits, default untimed-visit duration and arrival buffer. Booked/confirmed activities, booking references and locked stops are protected; their times and relative order remain fixed. Unselected timed visits also retain their times. Existing visit durations are preserved; untimed visits use the displayed default duration.

The tool compares 2–8 local stops with real coordinates using an OSRM road-time matrix. It enumerates allowed orders and offers the current order plus up to three alternatives favoring less road travel, earlier completion or less waiting. Orders worse in all displayed measures are excluded. Disconnected routes, missed fixed appointments and days finishing after the chosen limit cannot be applied. Alternatives are not claimed to account for live traffic, venue opening hours or passenger timetables.

Select an option, review its visit times, then **Preview roads on map**. Only **Use this order and times** changes the document. It saves the displayed visit times and corresponding route estimates/geometry atomically. Unpaid planned estimates for removed/changed-mode connections are removed; paid spending, actual records, photos and unrelated content remain. Local routes with flights, trains, transfers, overnight activities or distinct arrival/departure endpoints require separate planning and are explicitly excluded from this sorter. It never reorders intercity bookings or substitutes a road estimate for their schedule.

Map previews resize with their container and keep the entire route visible on phones. Numbered pins match the selected stop order.

### Travel estimates

Walking, cycling and driving use the corresponding FOSSGIS OSRM profiles over OpenStreetMap roads. Estimates are fetched only on explicit user action; the server uses fixed provider URLs, membership checks, a per-provider one-request-per-second queue and a bounded cache. Stored estimates retain geometry, duration, distance, source and retrieval date. Changing either endpoint invalidates its previous connection.

Compare walking, cycling and driving durations and distances side by side, alongside entered fare estimates. Selected road geometry is fetched again if it was not retained with an alternative mode. Rail, flight and bus schedules can use fixed departure/arrival dates and times in the trip zone, plus departure and arrival buffers. Checks catch an already-departed service even if its overall duration would fit the gap. Entered connection fares create one linked planned expense; re-editing replaces that estimate while preserving actual spending.

The comparison table uses the same fixed-departure and boarding-buffer checks as the saved day plan. A short ride does not appear feasible when its departure has already passed.

**No-account live searches:** train/plane/bus choices expose a route/date/traveler form. Google Flights opens flight results; 12Go opens train/bus comparisons. These searches run on the booking sites in a new tab, where their current prices are displayed. They do not scrape, import or silently invent live fares inside WanderPlan. The user enters the chosen service's schedule and total fare in the connection form. The links were checked in Chrome for Bangkok–Kunming flights (2026-12-03, two adults) and Bangkok–Chiang Mai transport on the same date. Trip.com blocked the automated check and is not used as the primary search. China Railway 12306 is linked separately; its normal sales window is 15 days including the travel day, so the user's December itinerary may not yet have bookable rail tickets.

No road duration is presented as a rail, flight or bus schedule. Road estimates do not include live traffic, weather, queues or service waiting times.

Each connection compares the available gap with travel duration plus an editable arrival buffer. Flights default to 120 minutes, trains to 30, buses/ferries to 20, matching mobile's recommendation. Missing durations remain unchecked. Overlaps and tight connections remain visible; the app never silently moves a booking to make a day appear feasible.

Providers: [Leaflet](https://leafletjs.com/), [FOSSGIS routing](https://routing.openstreetmap.de/about.html), [OpenStreetMap](https://www.openstreetmap.org/copyright), [Nominatim](https://nominatim.org/). Online maps/search/routing need network access; editing and manual durations remain available when providers fail. Leaflet's BSD license is included in `frontend/public/vendor/leaflet-LICENSE.txt`.

## Storage and concurrency

`GET /v1/trips/{tripId}/plan` returns a lossless JSON document/media package plus its own version. It starts from the original import, or an empty plan for a new web trip. Main trip metadata is merged from the canonical trip record.

`PUT /v1/trips/{tripId}/plan` requires `If-Match` (including version `0` for the first save) and owner/editor membership. The entire document is validated before one atomic write. Stale saves return `412`; the modal keeps its draft and offers an explicit discard/reload action. Viewers can view/export but cannot save.

PostgreSQL migration `00005_trip_plans.sql` stores the editable document independently of the immutable import in `imported_trip_packages`. Both cascade on trip deletion. **In-memory API mode loses all trips and plans on process restart.** Use the existing PostgreSQL `DATABASE_URL` configuration for durable storage.

These packages are not materialized into the normalized planning tables or the future device sync feed. There is no automatic mobile/web synchronization.

## Export and compatibility

**Export for mobile** downloads a schema-v3 `.wanderplan` ZIP with the latest canonical trip details, edited planning sections and retained media. Importing it creates a new independent trip on either client. Booking references and notes are included, so export is for the user's own device or a deliberate share.

`connections[]` and `actuals[]`, plus photo `activityRef`/`date`, are additive web extensions. The web preserves them in imports and exports. The current Flutter importer reads the standard planning fields and ignores these extensions; they do not yet appear in the native app. Keep the web/exported package if you need the full actual log.

## Validation

Run frontend `npm test`, `npm run typecheck`, `npm run lint` and `npm run build`; backend `go test -race ./...`. The PostgreSQL integration test also runs when `TEST_DATABASE_URL` points at an isolated database. Browser QA covers complete save/reload cycles, real profile routing, feasibility, actuals, ZIP export, stale edits, keyboard access, desktop/mobile layouts and accessibility checks.

## Optional in-app provider results

Server-side adapters are ready for `HERE_TRANSIT_API_KEY` (HERE Public Transit v8 schedules) and `DUFFEL_ACCESS_TOKEN` (a `duffel_live_*` production token for flight offers). Set them locally in `frontend/.env` or in the server environment, never with a `VITE_` prefix. Restart only the frontend to load environment changes; restarting the in-memory Go API would erase its trips. Public booking searches work with neither credential.

The provider adapters validate responses, enforce trip membership, limit each trip to six searches per minute, use fixed service URLs and bounded timeouts, and expose no credentials to the browser. Flight results retain operating carriers, source/retrieval time, currency, total price for the selected adults, and expiry. Test-mode, expired and malformed-price offers are rejected. HERE rail/bus schedules are not claimed to be guaranteed live vehicle positions; fare data is explicitly unavailable in this adapter. Coverage, operator availability and booking windows vary.

No booking/payment endpoint is implemented. Saving an offer records a planning estimate; it does not reserve or buy a ticket. In-app provider responses were tested with contract-shaped fixtures; production provider access was not exercised because no credentials are configured. Amadeus Self-Service is retired and was not used.

Provider references: [Duffel offer requests](https://duffel.com/docs/api/v2/offer-requests), [Duffel test-mode distinction](https://duffel.com/docs/api/overview/test-mode), [HERE transit routing](https://docs.here.com/transit/reference/public-transit-api-v8-getroutes), [12306 ticket rules](https://kyfw.12306.cn/otn/gonggao/saleTicketMeans.html?linktypeid=means5).
