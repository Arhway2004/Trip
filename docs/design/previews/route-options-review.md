# Google Maps pins and route choices — 2026-10-17

Reviewed rendered desktop and 390px phone layouts, including dark mode. The existing neutral/forest system remains; route options use simple radio choices and a single road preview. The panel is collapsed by default. Removed choices worse on all travel/finish/wait measures.

Verified in Chrome against the running app and API: exact Google coordinate pin save with source URL, a real Google short-link redirect, name-only link fallback to Nominatim without viewport guessing, a real OSRM walking matrix, selectable orders, real road geometry previews, all route pins visible after phone resize, explicit application and persistence after reload. A confirmed lunch stayed at 13:00–14:00. Temporary QA trips were deleted by their exact created IDs.

The real Bangkok example offered 44 minutes walking with a 15:22 finish versus 32 minutes walking with a 15:23 finish. These are routing estimates from the test, not fixed promises or live traffic predictions.

64 frontend tests across 17 files, TypeScript, ESLint and production build pass. Five new Axe views have zero violations. Screenshots were inspected after refining marker-number alignment, map zoom, map resizing and dark form controls.

Scope: web planner, 2–8 local stops, walking/cycling/driving. Booked or locked stops cannot be selected to move. Intercity/overnight optimization is excluded explicitly. Traffic, opening hours and transit timetables are not modeled by this sorter. Native Flutter and automatic device synchronization were not changed.

Sources: [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started), [OSRM route/table APIs](https://project-osrm.org/docs/v5.24.0/api/), and the [Bangkok public-space directory](https://publicspace.bangkok.go.th/Spaces/Info/C2D5D7EB-8309-4CD8-A709-144D8C1C3A70) for the public BACC Google share link.
