# Trip import format (`wanderplan.trip`, schema v3)

You can import a trip into WanderPlan from:

- a **`.json` file** you write by hand (start from [`Example/trip_template.json`](../Example/trip_template.json)), or
- a **`.wanderplan` file** exported by the app (**Share with a friend**). This is a ZIP containing `trip.json` plus `media/…` images.

**In the app:** My Trips → **⋮** → **Import trip from file**, then choose:

- **Choose a file:** a `.json` or `.wanderplan` file, or
- **Paste text:** paste the JSON straight from ChatGPT, Notes or an email (**Paste from clipboard** button). Code fences like ```` ```json ```` are ignored.

Each import creates a **new, independent trip** and never overwrites an existing one. If something is wrong, the message names the exact problem, for example `activity "Flight: Bangkok → Kunming": …`.

## Minimal file

Only the three header fields and `trip.title` are required:

```json
{ "format": "wanderplan.trip", "schemaVersion": 3, "trip": { "title": "Weekend in Hua Hin" } }
```

## Full reference

| Path | Type | Required | Notes |
|---|---|---|---|
| `format` | string | ✅ | Must be `"wanderplan.trip"` |
| `schemaVersion` | int | ✅ | `3` (`2` has no saved places, `1` has no itinerary or budget; both still import). Files with a higher version are rejected ("made by a newer version") |
| `trip.title` | string | ✅ | Must not be blank |
| `trip.description` | string | | |
| `trip.startDate` / `trip.endDate` | `"YYYY-MM-DD"` | | Local dates in the trip's time zone. `endDate` is ignored without `startDate` |
| `trip.departureTime` | `"HH:mm"` | | 24-hour time, local to the trip's time zone |
| `trip.datesConfirmed` | bool | | `true` marks the trip *Upcoming*, `false` means flexible dates |
| `trip.timeZone` | string | | IANA name, e.g. `Asia/Shanghai`, `Asia/Bangkok`, `Europe/Paris`. Default `UTC` |
| `trip.travelerCount` | int | | 1–999, default 1 |
| `trip.currency` | string | | ISO 4217 code: `CNY`, `THB`, `USD`, … |
| `trip.totalBudget` | number | | ≥ 0, in `currency` |
| `trip.travelStyle` | enum | | `relaxed` `balanced` `packed` `budget` `comfort` `luxury` `adventure` `family` |
| `trip.stage` | enum | | `dreaming` or `planning` (default). *Upcoming*, *Traveling* and *Completed* are derived from the dates |
| `destinations[]` | array | | `{ "city": "…", "country": "…" }`. The first entry is the main destination |
| `banner.kind` | enum | | `gradient` (default), `solid`, `photo`. A `photo` banner without an image falls back to `gradient` |
| `banner.colorA`, `banner.colorB` | color | | `"#RRGGBB"`, `"#AARRGGBB"` or an ARGB integer. `colorB` applies to gradients only |
| `banner.textColor` | color | | Default white |
| `banner.showTitle` | bool | | Default `true` |
| `banner.titlePlacement` | enum | | `topLeft` `center` `bottomLeft` `bottomCenter` |
| `banner.style` | enum | | `classic` `minimal` `bold` `framed` |
| `banner.image`, `banner.scale`, `banner.alignX`, `banner.alignY` | | | Used in `.wanderplan` ZIPs (`image` = `media/0.jpg`). Ignored in plain JSON |
| `photos[]` | array | | ZIP only: `{ "file": "media/1.jpg", "caption": "…", "isFavorite": false }` |
| `todos[]` | array | | "Before you go" items: `{ "title", "notes", "category", "dueDate": "YYYY-MM-DD", "isDone" }` |
| `todos[].category` | enum | | `documents` `bookings` `packing` `health` `money` `connectivity` `home` `other`. `transport`, `accommodation` and `tickets` count as `bookings` |

### Itinerary: `activities[]` (v2)

Each entry is one item on the timeline: a visit, a meal, a transport segment or a hotel stay. Times are local to the trip's time zone.

| Field | Type | Required | Notes |
|---|---|---|---|
| `title` | string | ✅ | |
| `date` | `"YYYY-MM-DD"` | ✅ | Start date. For hotels, the check-in date |
| `start`, `end` | `"HH:mm"` | | `end` may be `"24:00"`. It must be after `start`, or put the later day in `endDate`. **Leave both out when the time isn't decided yet** (e.g. unconfirmed flights): the app never guesses a time, shows "Time TBD", and marks the day "Needs info". Giving only one of them is an error |
| `endDate` | `"YYYY-MM-DD"` | | Overnight trains and flights, or a hotel's **check-out** date. Nights = check-out − check-in |
| `kind` | enum | | `sightseeing` `food` `activity` `shopping` `rest` `flight` `train` `bus` `transfer` (taxi/metro) `ferry` `transport` (mode not decided yet) `hotel` `other`. Common synonyms are accepted too, e.g. `taxi`, `metro`, `plane`, `rail`, `accommodation`, `meal`, `attraction` |
| `location` | `{ "name", "lat", "lng" }` or a string | | The departure point for transport. **Only add `lat`/`lng` if they are real** (WGS84, e.g. copied from OpenStreetMap). Otherwise give just the name: after importing, **Map → Find locations** searches every name for you, and you can paste a Google Maps link or Plus Code for any place (offset-corrected for mainland China) |
| `destination` | same as `location` | | Arrival point for `flight` / `train` / `bus` / `transfer` / `ferry` / `transport` |
| `cost`, `currency` | number, ISO code | | Counted as **planned** cost |
| `bookingStatus` | enum | | `notBooked` (default) `booked` `confirmed` `cancelled`. An unbooked flight or train marks the day "Needs info" |
| `provider`, `serviceNumber` | string | | Airline / operator / hotel; flight or train number |
| `bookingReference` | string | | Private. Exported only when you choose to include private details |
| `bookingUrl`, `notes` | string | | |
| `isLocked`, `isOptional` | bool | | Locked items can't be moved by dragging or by **Optimize order** |
| `travelMode` | enum | | How you get **to** this stop from the previous one: `walking` `cycling` `driving` `transit` (train/metro/bus). Synonyms like `walk`, `bike`, `taxi`, `metro`, `bus` are accepted |
| `travelMinutes` | int | | Your own travel time for that leg. Needed for `transit`, which is never calculated |
| `openingHours` | `{ "opens": "HH:mm", "closes": "HH:mm", "closedDays": ["mon"] }` | | Same hours every open day; a closing time before the opening time means after midnight. `closedDays`: `mon`…`sun` or 1–7 |
| `reservation` | `{ "via": "…", "bookAheadDays": 7, "remind": true }` | | Needs booking in advance. `via` = where/how to book (app, website, WeChat account…). `remind` sends a notification at 09:00 (trip time) on the book-by date |
| `ref` | string | | Your own label, so expenses can point to this activity |

### Day start/end: `days[]`

Each day starts at last night's hotel and ends at tonight's, unless you set it:

```json
"days": [
  { "date": "2026-12-08", "start": { "name": "Guesthouse", "lat": 27.82, "lng": 99.70 }, "endTravelMode": "driving", "endTravelMinutes": 20 }
]
```

`start` / `end` take the same form as `location`. `endTravelMode` / `endTravelMinutes` say how you reach the end point.

These fields (and `travelMode`, `openingHours`, `reservation` above) are optional additions to schema 3: older app versions and the web app ignore what they don't know.

### Budget: `expenses[]` and `exchangeRates[]` (v2)

| Field | Type | Required | Notes |
|---|---|---|---|
| `expenses[].title` | string | ✅ | |
| `expenses[].amount` | number | ✅ | ≥ 0 |
| `expenses[].currency` | ISO code | | Defaults to the trip currency |
| `expenses[].kind` | enum | | `actual` (default, money spent) or `planned` (a cost that's not in the itinerary, e.g. insurance) |
| `expenses[].category` | enum | | `flights` `trains` `buses` `taxis` `transport` `hotels` `food` `attractions` `activities` `internet` `insurance` `shopping` `emergency` `misc`. Synonyms such as `accommodation`, `tickets`, `esim` are accepted |
| `expenses[].isPaid`, `isShared` | bool | | `isShared: false` means the cost is for one person, not split |
| `expenses[].date` | `"YYYY-MM-DD"` | | |
| `expenses[].activityRef` | string | | The `ref` of an activity this expense paid for |
| `exchangeRates[]` | `{ "currency", "rate" }` | | `1 currency = rate × trip currency`. Imported as **"entered manually, not verified"**. Use **Budget → Rates → Fetch live rates** to update them |

### Saved places: `places[]` (v3)

Places you want to go to, shown on the trip map and in **Map → Saved places**. They are not in the plan until you use **Add to day**.

| Field | Type | Required | Notes |
|---|---|---|---|
| `places[].name` | string | ✅ | |
| `places[].lat`, `places[].lng` | number | ✅ | **Real** WGS84 coordinates (e.g. copied from OpenStreetMap or Google Maps). A place without them stops the import: the app never guesses a location. Don't paste coordinates copied from Amap or Baidu; those are offset in mainland China |
| `places[].category` | enum | | `attraction` (default) `restaurant` `hotel` `airport` `railwayStation` `busStation` `other`. Synonyms such as `museum`, `food`, `train station`, `bus terminal` are accepted |
| `places[].address`, `places[].notes` | string | | |

```json
"places": [
  { "name": "Louvre Museum", "category": "attraction", "lat": 48.8611, "lng": 2.3380 }
]
```

**How the budget counts:** *Planned* = activity costs + planned expenses. *Spent* = actual expenses. Amounts in a currency without a rate are left out of the totals (and flagged) rather than guessed.

Unknown fields are ignored. Invalid enum values fall back to their defaults. An activity with a missing or invalid time stops the import, and the error names that activity, so a hand-written file never half-imports.

## Validate a file before importing

```bash
python3 -m json.tool my_trip.json > /dev/null && echo "valid JSON"
```

## Web editing and actual records

The web can edit all standard planning sections after import and export them back as a schema-v3 ZIP. It retains the original imported snapshot separately. Optional `connections[]` (routing/transfer estimates), `actuals[]` (actual times and notes) and photo activity/date links are web extensions; the current native importer ignores them. See [WEB_PLANNER.md](WEB_PLANNER.md) for storage, routing, post-trip logs and compatibility details.
