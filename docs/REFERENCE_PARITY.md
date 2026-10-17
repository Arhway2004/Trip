# Reference feature integration

Source: `Reference/Trip/README.md` and all 23 application/view modules. Existing WanderPlan data, photos, actual records, trip IDs and version checks remain the source of truth. Reference labels and calculation behavior are reused where applicable; reference sample timings and fares are not treated as live data.

Implementation checklist:

- [ ] Attraction library: full metadata, search/filter, selection, add to day, shared-ticket/transport costs.
- [ ] Itinerary: list/month/week views, drag/move/resize, day metadata, insert/duplicate/clear/delete, date-shift preview.
- [ ] Flight journeys: grouped legs, local airport time zones, layovers, airport changes, ticket types and fees.
- [ ] Ground transport: type, station/service/luggage, per-person/group pricing and linked attractions.
- [ ] Hotels: room/night pricing, heating/cancellation, night coverage, placeholder generation.
- [ ] Budget: forecast, paid/unpaid, category/day/city charts, target lines, food and contingency allowances.
- [ ] Insights: conflicts, travel feasibility, fatigue estimates, free time, upcoming bookings.
- [ ] Scenarios: create/clone/rename/delete/switch and metric comparison.
- [ ] History: undo/redo and recoverable local drafts.
- [ ] Reports: private/public JSON, CSV/ZIP, XLSX, printable/PDF, AI-ready Markdown/JSON and map image.
- [ ] Compatibility: reference JSON/backup imports, current mobile ZIP exports and lossless extension preservation.
- [ ] Settings/map: display currency, sourced exchange rates, cities/places, tile styles, navigation, layer/filter controls and adjustable split view.
- [ ] QA: unit/contract checks, production build, browser save/reload/export, desktop/phone screenshots and accessibility.

The web is the integration surface for this request. Existing native Flutter features are checked for schema compatibility; native-only screens are not represented by web screenshots.
