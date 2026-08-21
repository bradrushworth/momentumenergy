# AGENTS.md — Momentum Energy Dashboard

Canonical guide for AI agents and new contributors. `.clinerules` carries an
older copy of much of this for Cline compatibility; when they disagree, this
file wins.

## What this is

A Flutter app (Android / iOS / web) that visualises a customer's
[Momentum Energy](https://www.momentumenergy.com.au) (Australian retailer)
electricity usage and estimated costs. **No API**: the user downloads a CSV
from the MyAccount portal ("Export table") and loads it via `file_picker`;
everything is parsed and aggregated on-device. Nothing leaves the device —
keep it that way.

**Sister app:** `../amber` is a near-clone for Amber Electric (live API
instead of CSV). `my_theme_model.dart`, `top_section.dart`,
`screenshots_*.dart`, and most of `utils.dart` are copy-paste twins, and the
`main.dart` / `bar_chart.dart` skeletons match. Fixes to shared-shaped code
are manually ported between repos; a shared package is planned but does not
exist yet. When you fix something in a twin file, say so, so the port isn't
forgotten.

## Commands

```bash
flutter pub get      # deps
flutter test         # 8+ tests, must stay green
flutter analyze      # ~40 pre-existing style warnings are the baseline;
                     # any NEW error/warning is a regression
flutter build web --release
```

## CSV formats (both must keep working)

Header: `Date and Time, Read Value - kWh (kilowatt hours), Reading quality`.
Rows are 5-minute intervals (`METER_INTERVAL = 5`), dates `DD/MM/YY HH:MM`
parsed by fixed substring offsets in `DataAggregator.dateParse` (fragile —
known debt).

- **Multi-meter (older exports)**: N consecutive rows per timestamp, one per
  meter. Meter 0 is the controlled load. Fixture:
  `assets/Your_Usage_List_Sample.csv` (2 meters, meter 0 mostly zeros).
- **Single-meter (current exports)**: one row per timestamp, general usage
  only — no controlled load, no Control legend entry.

Meter detection counts **consecutive rows sharing the first timestamp**
(`aggregateData`). The old "scan for the first repeated timestamp" version
never terminated on single-meter files and rendered nothing ("Not enough data
in file") — regression tests cover both formats; don't regress this.

Picked files are decoded with `utf8.decode(..., allowMalformed: true)`
(`String.fromCharCodes` corrupted non-ASCII). The bundled
`assets/Your_Usage_List.csv` loads at startup as the demo dataset.

## Tariffs (user-configurable since 1.3.3)

`lib/tariffs.dart` holds a mutable global `tariffs` (daily supply $/day plus
controlled / off-peak / shoulder / peak $/kWh), persisted via
`shared_preferences`, edited through the gear-icon Settings dialog in
`main.dart`. The old constants (`DAILY`, `OFFPEAK`, ...) in `bar_chart.dart`
remain only as defaults and test anchors.

- `DataAggregator` reads `tariffs.*` at aggregation time. Charts re-parse
  after a save because `_tariffsRevision` is part of the `GridView` key —
  a plain `setState` is NOT enough (`didUpdateWidget` skips reparse when
  `rawData` is unchanged). Keep the key-bump mechanism.
- Tests that mutate `tariffs` MUST restore the defaults in `finally`
  (see "Changed tariff rates flow through..."), or the global leaks into
  every later test.

## Billing / colouring model

- Bars are fixed **half-hour buckets**: 48/day, `graphPos = hour * 2 +
  minute ~/ 30`, six 5-minute reads summed per bar. Do NOT change to
  per-interval bars (tried, reverted).
- Time-of-use windows (weekdays): off-peak < 07:00, shoulder 07–17, peak
  17–20, shoulder 20–22, off-peak ≥ 22:00. **Weekends are billed off-peak all
  day** (`_getCost`).
- Weekend colouring matches weekend billing only when EVERY in-range record
  is a weekend day (`_allWeekend`) — i.e. single-day weekend charts. Multi-day
  mixed views still colour by time-of-day while billing correctly per record;
  that's a known, documented limitation, not a bug to "fix" casually.
- Controlled-load pricing/colour applies only when the export actually has a
  second meter (`_numMeters > 1`). The stack list is REVERSED before
  rendering; `_getCostColor`'s index math (`_numMeters - 1` / `_numMeters`)
  accounts for that — work the indices through before touching it.
- `roundDouble` rounds (was `ceil`, which biased stacked totals upward).
- The daily supply charge is split per 5-minute interval
  (`tariffs.daily / 24 / (60 / METER_INTERVAL)`).

## Tests

`test/bar_chart_test.dart`: 4 fixture-based tests (2-meter sample CSV) + 4
synthetic single-meter tests (aggregation, TOU billing, weekend billing,
configurable tariffs). `test/widget_test.dart` is fully commented out — no
widget tests exist.

## Git, releases, CI

- Line endings are normalized via `.gitattributes` (`* text=auto`) since
  Aug 2026: repo stores LF, Windows checkouts are CRLF.
- Branch + PR to `master` for non-trivial changes; direct master commits are
  the historical norm for small fixes/bumps.
- Release = bump `version: x.y.z+build` in `pubspec.yaml`, commit
  "Bump version to x.y.z+build: <summary>", push `master`. Codemagic
  (dashboard-configured, no `codemagic.yaml`) builds from master pushes. No
  git tags.
- **iOS/CocoaPods on CI**: `ios/Podfile.lock` is not committed; the
  dashboard's Post-clone script (`scripts/codemagic_post_clone.sh`) nukes and
  regenerates the Pods sandbox each build. "Sandbox is not in sync" failures
  are CI cache issues, not code bugs. Do not remove CocoaPods — native
  plugins (`url_launcher`, `file_picker`) need it.

## Security & privacy (public repo!)

- The in-app "Source Code" link points here — treat the repo as public.
- **Never commit real usage exports.** Interval data reveals household
  occupancy. Personal `Your_Usage_List_*.csv` files may sit untracked in
  `assets/` for local testing — never `git add -A` them; the sanitized
  `Your_Usage_List_Sample.csv` is the only CSV that belongs in git. (Known
  debt: the bundled `Your_Usage_List.csv` is real 2022 data already in
  history.)
- Never commit keystores or `key.properties`. Historical debt:
  `keys/keystore.jks` is already tracked; rotation via Play App Signing is
  the accepted fix — don't make it worse.

## Gotchas

- `flutter test` can fail on a locked `build\unit_test_assets` dir on
  Windows: `Remove-Item -Recurse -Force build` and rerun.
- `git push origin master` can falsely print "Everything up-to-date"; verify
  with `git log origin/master`.
- `fl_chart` is pinned at 0.69.x; the code uses APIs removed in ≥0.70.
  Migrating is a deliberate project, not a drive-by bump.
- Momentum's export is unreliable (occasionally a single error-message row);
  malformed files currently throw unhandled — ingestion hardening is planned,
  so don't be surprised by `RangeError` on odd fixtures.
- `lib/generated_plugin_registrant.dart` is a stale tracked copy of a
  generated file (gitignored yet tracked) — slated for deletion, don't extend
  it.
- Analyzer baseline is dirty (~40 style warnings). Fix opportunistically;
  never add new ones.
