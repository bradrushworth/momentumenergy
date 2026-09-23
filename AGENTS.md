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
instead of CSV). The remaining copy-paste twins are `screenshots_*.dart`,
most of `utils.dart`, and the `bar_chart.dart` skeleton. `my_theme_model.dart`
and `top_section.dart` were twins but are **deleted in both repos** by the UI
overhaul (here, and on Amber's overhaul branch) — do not resurrect them or
"port" them back. `main.dart` no longer matches either: it is now just a
provider + `HomeShell` host. Fixes to shared-shaped code are still ported by
hand; a shared package is planned but does not exist yet. When you fix
something in a twin file, say so, so the port isn't forgotten.

## Architecture

`CsvState` (`lib/state/csv_state.dart`, a `ChangeNotifier` behind
`provider`) parses the bundled or imported CSV **once** and holds `rows`,
`numMeters`, `firstDate`/`lastDate`, `fileName` and `source` (none / sample
/ user) for everyone. `HomeShell` (app bar + `NavigationBar`) hosts three
tabs — Data, Days, Weeks — plus the `SettingsScreen`, `DayDetail` and
`GetYourDataScreen` routes. Screens never parse: they hand `state.rows` to
`DataAggregator` (`lib/bar_chart.dart`) for the bars and to `windowTotals`
(`lib/state/day_math.dart`) for the headline numbers.

### Getting the user's data in (the part users get lost in)

Users repeatedly got confused by demo data they had not asked for, could not
find where the CSV comes from, and lost their import on every relaunch. The
flow that answers that, and must not quietly regress:

- **Launch** calls `CsvState.restore()`: the user's last import comes back
  from SharedPreferences (`userCsv` raw text + `userCsvName`, re-parsed
  through the same path as an import); otherwise `status` is `empty`.
- **Nothing loaded** (`rows.isEmpty` and not `loading` — first launch,
  "Remove my data", or a first import that failed) → `HomeShell` shows
  `Onboarding` (`lib/screens/onboarding.dart`) instead of the tabs: three
  steps, a deep link to `momentumMyUsageUri`
  (`https://www.momentumenergy.com.au/myaccount/my-usage` — live; a
  signed-out visitor goes through the login and lands back there, so do not
  "fix" it to the site root), **Import my CSV**, and "Try it with sample
  data". The same widget is the body of `GetYourDataScreen`
  (`openDataGuide`), reached from the sample strip, the Data tab's "How do I
  get my CSV?" and Settings; it pops itself after a successful import.
- **The sample** (`assets/Your_Usage_List.csv`) loads only from that button
  (`loadSample`) and is always labelled: a mint strip above every tab, a
  `Sample ·` prefix on the app-bar dates, and SAMPLE DATA on the Data hero.
- **Imports** (`importFile` → `importCsv`) are saved on the device on
  success; `savedOnDevice == false` (browser storage full) is shown on the
  Data hero and in Settings. A failed import never overwrites the saved file.
  Cancelling the picker changes nothing — it used to reload the sample over
  the user's own data.
- Settings → YOUR DATA shows the file, re-import, the guide, and "Remove my
  data from this device" (confirmed, then back to the guide).

The pre-overhaul app said all of this in one always-visible header line
("Click 'Export table' from MyAccount, Then Select File", see
`b1c6a38^:lib/main.dart`); the overhaul hid it inside an error-only
onboarding and pointed the link at the home page.

`windowTotals` deliberately sums the *aggregated bar values* rather than
re-deriving totals from the rows, so the number a card prints is by
construction the sum of the bars it draws. It is memoised per rows-list
identity and keyed on `numMeters | duration | ending | tariffsRevision`;
pass `revision: state.tariffsRevision` from every screen call site or cost
totals will answer from a pre-rate-change entry.

Two failure surfaces, and the difference is load-bearing:

- `status == CsvStatus.error` (+ `errorMessage`) means **nothing can be
  drawn** — `rows` is empty, so the very first load failed. `HomeShell`
  answers this with `Onboarding`, which leads with the message.
- `importError` means a **later** import failed while a good file is still
  loaded. `rows`/`numMeters`/dates/`fileName` are left describing the file
  still on screen and `status` stays `ready`, so the tabs keep drawing it;
  `HomeShell` reports it once in a dismissible `MaterialBanner`. Tab guards
  therefore key off `rows.isEmpty` (`csvNeedsStatusView`), never off
  `status != ready`. Any successful parse clears both.

## Commands

```bash
flutter pub get      # deps
flutter test         # 76 tests, must stay green
flutter analyze      # 29 pre-existing style infos are the baseline;
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

Meter detection counts **consecutive rows sharing the first timestamp**.
`DataAggregator.detectNumMeters` is the single implementation: `CsvState`
calls it once per file and every `DataAggregator` is handed the answer. The
old "scan for the first repeated timestamp" version never terminated on
single-meter files and rendered nothing ("Not enough data in file") —
regression tests cover both formats; don't regress this.

Momentum's export is unreliable and occasionally carries a stray
error-message line mid-file. `CsvState._parse` filters every row failing a
cheap shape check (at least 2 fields, a numeric kWh, a timestamp of at least
14 chars — the width `dateParse` indexes into) **before** anything parses a
date; fewer than two survivors is treated as a parse failure. Junk rows are
dropped, not fatal.

Every parse goes through the one `usageCsv` decoder (csv 8: comma pinned,
`dynamicTyping` so the kWh column arrives as `num`; CRLF and LF both work).
If the kWh column ever came back as strings, the shape check would silently
drop every row — "the bundled export parses whole" in `csv_state_test`
guards that. Picked files come from `FilePicker.pickFile` (file_picker 13's
static API) and are decoded with `utf8.decode(..., allowMalformed: true)`
(`String.fromCharCodes` corrupted non-ASCII). The bundled
`assets/Your_Usage_List.csv` is the sample, loaded only on request (see
"Getting the user's data in").

## Tariffs (user-configurable since 1.3.3)

`lib/tariffs.dart` holds a mutable global `tariffs` (daily supply $/day plus
controlled / off-peak / shoulder / peak $/kWh), persisted via
`shared_preferences`, edited on the **Settings screen**
(`lib/screens/settings_screen.dart`, reached from the app bar's gear). The
old constants (`DAILY`, `OFFPEAK`, ...) in `bar_chart.dart` remain only as
defaults and test anchors.

- `DataAggregator` reads `tariffs.*` at aggregation time. Saving calls
  `CsvState.bump()`, which increments `tariffsRevision`; that revision is
  part of each chart's own `ValueKey` (history feed) and of the
  `windowTotals` memo key, so both the bars and the totals re-derive.
- `BarChartState` re-syncs **every** rendering input in
  `_syncFromWidget()` — rows, numMeters, title, duration, ending, prices,
  allowPartial — and re-aggregates whenever any of them changed, from both
  `initState` and `didUpdateWidget`. That is the contract to preserve: the
  older "reparse only when `rawData` changed" check silently kept rendering
  the first metric when the Cost/Usage chips swapped `prices` on a reused
  State.
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

76 tests across 12 files, all real. `test/widget_test.dart` (the
commented-out counter tombstone) is **deleted** — don't recreate it.

- `test/bar_chart_test.dart` — 4 fixture-based tests (2-meter sample CSV) +
  4 synthetic single-meter tests (aggregation, TOU billing, weekend billing,
  configurable tariffs).
- `test/csv_state_test.dart` — meter/date detection, junk-row filtering, the
  whole bundled export, the `error` vs `importError` split (including the
  `loadSample` failure path via the `sampleAssetKey` test hook), and the
  launch / sample / save / restore / remove / cancel flow.
- `test/fake_picker.dart` — `usePicker(PickedFile(name, text))` (or
  `usePicker(null)` for a cancel) swaps in a fake `FilePickerPlatform`, so
  `importFile` and the screens that call it run without a platform channel.
  Tests touching saved imports call `SharedPreferences.setMockInitialValues`.
- `test/day_math_test.dart` — `windowTotals` values and its memo
  (`windowTotalsComputations` / `resetWindowTotalsMemo` are the test hooks).
- Widget suites: `home_shell_test`, `data_tab_test`, `history_tab_test`,
  `settings_test`, `onboarding_test`, `widget_smoke_test`.
- `test/test_data.dart` holds the shared 2-day fixture in both shapes
  (parsed rows and raw CSV text) — screen tests go through the real
  `CsvState.setCsvForTest` parse path rather than poking public fields.

Widget tests default to an 800x600 landscape surface; set
`t.view.physicalSize` (and restore it in `addTearDown`) for anything that
depends on portrait, or on a list being tall enough to build.

## Git, releases, CI

- Line endings are normalized via `.gitattributes` (`* text=auto`) since
  Aug 2026: repo stores LF, Windows checkouts are CRLF.
- Branch + PR to `master` for non-trivial changes; direct master commits are
  the historical norm for small fixes/bumps.
- Release = bump `version: x.y.z+build` in `pubspec.yaml` **and
  `appVersion` in `lib/version.dart` together** (the About screen shows the
  latter; they drift silently otherwise), commit
  "Bump version to x.y.z+build: <summary>", push `master`. Codemagic builds
  from master pushes. It is still configured in the **dashboard's Workflow
  Editor**; the committed `codemagic.yaml` is inert documentation of that
  workflow until the app is switched to YAML builds (its header lists the
  credentials that must be wired up first). No git tags.
- CI keys off the commit message: feature commits carry `[skip ci]`, so a
  **merge commit without `[skip ci]` triggers a release build**. Either
  fast-forward the branch (no merge commit, no build) or make that merge a
  deliberate release — don't discover it after the fact.
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
- The user's own import is kept only on their device (SharedPreferences;
  browser localStorage on web) so it survives a relaunch. Never send it
  anywhere, and keep "Remove my data from this device" working.
- Never commit keystores or `key.properties`. Historical debt:
  `keys/keystore.jks` is already tracked; rotation via Play App Signing is
  the accepted fix — don't make it worse.

## Look and feel (Momentum's palette, deliberately)

`lib/theme.dart` holds the whole palette, sampled from momentumenergy.com.au:
deep indigo `#000045` with the mint `#2CF2AE` accent and a cyan `#4FD8F0` for
the icon gradient. The app is NOT affiliated with Momentum Energy, but it reads
an export their customers download from MyAccount, so it speaks the visual
language those customers already associate with their account. The line not to
cross is passing for an official app: their logo, wordmark (Poppins) and
artwork stay theirs.

Amber's palette (`../amber/lib/theme.dart`) is a close cousin — both retailers
brand navy-plus-mint. The two apps are told apart by Momentum's deeper indigo
ground and its cyan-into-mint gradient against Amber's slate navy and flat
mint, and by the icon silhouettes (an M here, a price peak there).

Screens must not hardcode hex colours; add a named `MomentumPalette` entry
instead. Accent roles (chips, `FilledButton`, the `NavigationBar` indicator)
and dialog colours come from `darkTheme` in `main.dart` — its `textTheme`
replaces `ThemeData.dark()`'s wholesale, so anything that reads an unset text
style (dialog titles did) draws near-black on indigo unless the theme sets it.

**Encoding:** these files contain em-dashes and middle dots. Do NOT rewrite
them with PowerShell's `Get-Content`/`Set-Content` or `[IO.File]` helpers — the
default-encoding round-trip turns `—` into mojibake, and .NET resolves relative
paths against the process directory, not `$PWD` (that is how an unrelated
repo's pubspec.yaml once landed here). Use an editor or Python with an explicit
`encoding='utf-8'`.

## Store assets and the app icon

`store/` holds everything the Play Store / App Store listings are built from,
so the repo is the record of what is published:

- `store/listing.md` — app name, short/full description, "What's new". Edit here
  first, then paste into the console.
- `store/screenshots/` — `play-*` 1080x1920, `ios-*` 1290x2796 (iPhone 6.7"),
  `land-*` 1600x800. Regenerated from a real `flutter build web --release`
  driven by headless Chrome, never mocked up.
- `store/feature-graphic.png` (1024x500, Play only), `store/icon-512.png`.

The launcher icon is generated, not hand-drawn: `assets/icon.png` (full-bleed
1024x1024) and `assets/icon_foreground.png` (same art, transparent) feed
`flutter_launcher_icons`. After changing either, run:

```bash
dart run flutter_launcher_icons
```

The five bars trace a subtle **M** — tall at the edges, dipping between — so
the icon reads as Momentum. Two silhouettes are ruled out: bars climbing
short-to-tall read as the mobile signal-strength glyph (the 1.5.0 icon), and
a single centre spike is Amber's price peak.

`adaptive_icon_foreground` is wrapped in a 16% inset by the generator, so the
foreground must use the SAME geometry as the full icon — pre-shrinking it a
second time makes the launcher icon look tiny.

## Gotchas

- `flutter test` can fail on a locked `build\unit_test_assets` dir on
  Windows: `Remove-Item -Recurse -Force build` and rerun.
- `git push origin master` can falsely print "Everything up-to-date"; verify
  with `git log origin/master`.
- `fl_chart` is pinned at 0.69.x; the code uses APIs removed in ≥0.70.
  Migrating is a deliberate project, not a drive-by bump — held back by the
  owner on 2026-09-23 when everything else was upgraded (bead `me-txc`).
- Momentum's export is unreliable (occasionally a single error-message row).
  That is handled now: `CsvState._parse` drops rows failing the shape check,
  and a file with fewer than two usable rows fails cleanly to `error` /
  `importError` rather than throwing a `RangeError` out of `dateParse` at
  build time. `restore` / `loadSample` / `importFile` are guarded too — no
  path leaves the app stuck in `loading`.
- Flutter's tooling deletes the `/lib/generated_plugin_registrant.dart` line
  from `.gitignore` on any web build; that change is committed, so a build
  leaving `.gitignore` modified means something else touched it. The file
  itself was never tracked.
- `Utils.launchURI` returns false instead of throwing when nothing can open
  the link (the old version escaped every tap handler as an unhandled async
  error). `utils.dart` is an Amber twin — port it.
- Analyzer baseline is dirty (29 style infos, mostly deprecated `Color`
  getters in `utils.dart` and unreferenced screenshot-only packages). Fix
  opportunistically; never add new ones.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:970c3bf2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
