# WanderPlan — the personal travel atlas

WanderPlan is a planning product for independent travelers, including people
organizing detailed trips with friends and family. Its core job is to turn dates,
places, bookings and expenses into a readable plan. The collection should invite
a traveler to return; the working screens should make the next action clear.

This is a product interface. It does not use a marketing hero, invented travel
statistics, destination recommendations or stock scenery to fill empty space.

## Creative direction

The visual reference is a well-kept travel folio: white surfaces, a neutral canvas, forest
actions, editorial typography and precise, practical annotations. A vermilion point adds a small
human accent. The signature is the **journey folio**: a numbered cover, schematic
route drawing and perforated divider leading into its travel facts.

The route drawing is decorative, not a geographical map. Real trip maps and
coordinates retain their existing accuracy rules. User photos and custom cover
settings remain personal; no travel imagery is fabricated or substituted.

## Shared system

| Decision | Web and Flutter |
|---|---|
| Canvas / surface | `#F7F9F8` / `#FFFFFF` |
| Primary ink / secondary ink | `#1F2923` / `#4D5C53` |
| Muted ink (including tinted panels) | `#5C6B62` |
| Forest action / pale forest | `#245C46` / `#EAF2ED` |
| Hairline / vermilion accent | `#DCE3DE` / `#B64B32` |
| Dark canvas / surface | `#151C18` / `#1E2721` |
| Dark primary text / action | `#F0F5F1` / `#A8C8A0` |
| Display type | Bundled Newsreader, regular weight, optical sizing |
| Controls and body | Bundled DM Sans; platform fallback for Chinese and Thai |
| Geometry | 8px folio corners, 6px controls, fine borders, minimal shadow |
| Spacing | 4px base; 20px phone edges; 40px desktop edges; 22–28px folio gaps |
| Collection | One column on phones, two columns on larger screens |
| Navigation | Underlined text filters; explicit create/import actions |
| Interaction | Short color/focus transitions; no entrance choreography; reduced-motion support |

Fonts are bundled in both applications and include their SIL Open Font Licenses.
The web uses local font URLs, not a third-party font request. The palette for new
covers is the same deterministic, eight-pair set in React and Dart; existing
mobile cover colors and photos are retained.

The collection, cover, departure summary, metrics, forms and empty state share a
visual hierarchy. Native mobile controls remain native where that improves use.
The mobile app still has more planning tools than the current web app; this
redesign does not imply new sync or planning APIs.

## Implementation

- Web tokens: `frontend/src/styles.css`.
- Flutter tokens: `mobile/lib/shared/presentation/theme/app_theme.dart`.
- Route and identity artwork: `frontend/src/components/atlas-art.tsx` and
  `mobile/lib/shared/presentation/atlas.dart`.
- Shared text: web `messages/{en,zh,th}.json`; Flutter `tool/gen_arb.py`.
- Development overlay is opt-in with `VITE_SHOW_DEVTOOLS=true`.

## Visual review

Preview captures live in `previews/`. Web captures come from the running React
application in Chrome at 1440, 820, 390 and 320 CSS pixels, including light/dark
appearance, sign-in, forms and import. Chinese and Thai are checked in Chrome.

On macOS the preview host registers installed Chinese/Thai fallback fonts for translated captures; system font files are not copied into the project.

Mobile captures render the actual Flutter widgets with the bundled fonts and
Material icon font, an isolated database and a fixed clock. They are widget-host
renders, not physical iOS/Android device screenshots. Layout tests cover 320,
390 and 820 pixels, dark appearance, 160% text scaling, and Chinese/Thai labels.

To regenerate the Flutter previews from `mobile/`:

```sh
flutter test --dart-define=DESIGN_PREVIEWS=true test/widgets/design_review_test.dart
```

Review findings addressed during iteration: cramped small-screen headers,
empty-state actions falling below the fold, long titles in cover overlays,
fixed-height tool tiles overflowing, and decorative artwork painting past its
cover. Tool rows adapt to content and larger text; metrics use a single column
when needed for readability.

### Final verification

- 32 web tests, including a cross-client design contract for colors, cover palette and font files.
- 125 Flutter tests, plus analyzer checks.
- TypeScript, ESLint and the web production build pass.
- Chrome screenshots at 320, 390, 820 and 1440px; no horizontal overflow or page-script errors during the final render pass.
- Axe WCAG A/AA checks report zero violations across ten page/appearance checks, including sign-in, the collection, creation and an imported plan.
- Browser interactions verified creation, file import and switching to Chinese and Thai.
- Flutter previews reviewed at phone/tablet sizes, in dark mode, with 160% text, and with translated labels.

### Clean palette and usability pass

The collection grid, typography and personal covers remain in place. Both clients
now use white surfaces on a light neutral canvas, charcoal text and the existing
forest action color. Dark mode uses neutral green-grey surfaces with the same
hierarchy. Status and chart colors retain their semantic meaning.

- Search trips by title in either client, with a clear action and a recoverable empty result.
- Mobile dashboards expose labeled Timeline, Map and Budget buttons below the cover. These adapt to narrow screens and larger text.
- Web imported plans group activities by day, open the first day, and reveal full activity fields on expansion. The original snapshot and media are preserved.
- Import modes announce which option is selected. Shorter scope text explains editing and sync limits.
- Web sign-in updates the cached session immediately, so the trip list opens without a manual refresh.

The latest Chrome captures use the `clean-` prefix in `previews/`, and the latest
accessibility results are in `previews/clean-accessibility.json`. Flutter captures
use the existing `mobile-` names. Verified with 32 web tests, 125 Flutter tests,
TypeScript, the web production build, Flutter analysis, and the responsive and
translated preview checks described above. Mobile previews are widget-host
renders rather than physical-device captures.
