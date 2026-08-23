# Momentum UI Overhaul (Amber Port) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the approved tabbed-shell UI (already shipped on Amber's `claude/ui-overhaul` branch) to the Momentum Energy app: Data/Days/Weeks tabs, file-summary hero, orientation-adaptive history, chart hygiene, Settings + onboarding.

**Architecture:** A `CsvState` ChangeNotifier parses the CSV ONCE (ending the parse-per-widget pattern) and owns import/status; `BarChartWidget1` switches its input from a raw CSV string to parsed rows and gains every chart-hygiene improvement from the Amber port; screens mirror Amber's, with the hero being a file summary instead of a live price. Old single-screen UI and dead theme system are deleted in the final task.

**Tech Stack:** Flutter stable, provider 6, shared_preferences, csv, file_picker, fl_chart 0.69 (pinned — do NOT upgrade).

**Spec:** `docs/superpowers/specs/2026-08-22-ui-overhaul-design.md` (Momentum sections; the authority).

**Porting reference (read-only source material):** Amber's reviewed implementation at
`C:\Users\Brad\StudioProjects\amber\.claude\worktrees\app-review-overhaul-cca2fc\` — files under `lib/screens/`, `lib/widgets/`, `lib/state/`, and `lib/bar_chart.dart`. When a task says "port X from Amber", read that file and adapt; interfaces in each task below are the binding contract, Amber's code is the how.

## Global Constraints

- No network code anywhere: this app is local-CSV only.
- fl_chart stays pinned at 0.69.x; chart visual style (colors list, bar width 6, rounded caps) unchanged.
- `DataAggregator`'s aggregation semantics are untouched except where a task names the change; the mutable global `tariffs` (lib/tariffs.dart) remains the rates source.
- Dark-only: background `Color(0xFF20202A)`, cards `Color(0xFF1A1A26)`, skeleton `Color(0xFF23232F)`, grey `Color(0xFF9595A4)`.
- Every commit message ends with `[skip ci]`. No version bump in this plan.
- `flutter test` green and `flutter analyze` no NEW warnings after every task (baseline ~40 style infos).
- Windows: locked `build\unit_test_assets` => delete `build/` and retry.
- Amber-learned invariants (do not re-learn them the hard way): chart State must re-sync ALL widget inputs in `didUpdateWidget` and reparse when any changed (never `late final`); feed charts carry a `ValueKey` including the metric; card totals must equal the drawn bars; titles/windows/totals all derive from the DATA's last date, never the clock; in history cards navigation wins over chart tooltips (`IgnorePointer`).

---

### Task 1: CsvState (parse once)

**Files:**
- Create: `lib/state/csv_state.dart`
- Test: `test/csv_state_test.dart`

**Interfaces:**
- Produces (later tasks depend on these exact members):
  ```dart
  enum CsvStatus { loading, ready, cancelled, error }
  class CsvState extends ChangeNotifier {
    CsvStatus status;              // starts loading
    String? errorMessage;          // set when status == error
    String? fileName;              // 'Bundled sample' for the asset
    List<List<dynamic>> rows;      // parsed data rows, header stripped; [] until ready
    int numMeters;                 // >= 1 when ready
    DateTime? firstDate;           // AEST-naive date of first record (00:00)
    DateTime? lastDate;            // AEST-naive date of last record (00:00)
    int get dayCount;              // inclusive days between first/lastDate, 0 when empty
    int tariffsRevision;           // bump() on tariff save; grid keys include it
    void bump();
    Future<void> loadDefaultAsset();   // assets/Your_Usage_List.csv via rootBundle
    Future<void> importFile();         // file_picker + utf8.decode(allowMalformed: true)
  }
  ```
- Parsing: `CsvToListConverter(csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n','\n']))`, `shouldParseNumbers: true`, then `removeAt(0)` for the header — same as today's `BarChartState.parseFile` (`lib/bar_chart.dart:243-258`). Meter detection: count consecutive leading rows sharing `rows[0][0]` (same algorithm as `DataAggregator.aggregateData`'s current loop, `lib/bar_chart.dart:320-332`). Dates: `DateTime.parse(DataAggregator's dateParse(row[0]).substring(0,8) formatted)` — reuse a small public static `DataAggregator.dateParse` (already public).
- Any parse exception => `status = error`, `errorMessage = 'Unrecognized file format — export the usage table from Momentum MyAccount and try again.'` — never throws out.
- Cancelled picker => `status = cancelled` then auto-`loadDefaultAsset()` after 2s (same behavior as today's `_pickFile`, `lib/main.dart:126-136`).

- [ ] **Step 1: Failing tests** — `test/csv_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/state/csv_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const twoMeter = 'Date and Time, kWh, Quality\n'
      '13/12/22 00:05, 0.1, Actual\n13/12/22 00:05, 0.2, Actual\n'
      '13/12/22 00:10, 0.1, Actual\n13/12/22 00:10, 0.2, Actual\n';
  const oneMeter = 'Date and Time, kWh, Quality\n'
      '07/07/25 00:05, 0.1, Actual\n07/07/25 00:10, 0.1, Actual\n'
      '08/07/25 00:05, 0.2, Actual\n';

  test('detects two meters and date range', () {
    final s = CsvState();
    s.setCsvForTest('export.csv', twoMeter);
    expect(s.status, CsvStatus.ready);
    expect(s.numMeters, 2);
    expect(s.firstDate!.day, 13);
    expect(s.dayCount, 1);
  });

  test('detects single meter and multi-day range', () {
    final s = CsvState();
    s.setCsvForTest('export.csv', oneMeter);
    expect(s.numMeters, 1);
    expect(s.dayCount, 2);
    expect(s.lastDate!.day, 8);
  });

  test('malformed csv becomes an error status, not a crash', () {
    final s = CsvState();
    s.setCsvForTest('bad.csv', 'Sorry, an error occurred');
    expect(s.status, CsvStatus.error);
    expect(s.errorMessage, isNotNull);
  });
}
```

Add `@visibleForTesting void setCsvForTest(String name, String csv)` that routes through the same private `_parse` used by loadDefaultAsset/importFile.

- [ ] **Step 2: Run** — `flutter test test/csv_state_test.dart` — FAIL (file missing).
- [ ] **Step 3: Implement** per the interface. `dayCount` = `lastDate.difference(firstDate).inDays + 1`.
- [ ] **Step 4: Run file tests + full suite** — all green (existing 8 stay untouched).
- [ ] **Step 5: Commit** — `git add lib/state/csv_state.dart test/csv_state_test.dart && git commit -m "feat: CsvState parses the CSV once [skip ci]"`

---

### Task 2: bar_chart port (rows input + chart hygiene)

**Files:**
- Modify: `lib/bar_chart.dart`
- Modify: `test/bar_chart_test.dart` (widget-layer expectations only; `DataAggregator` tests untouched)
- Test: `test/widget_smoke_test.dart` (create)

**Interfaces:**
- `BarChartWidget1(List<List<dynamic>> rows, int numMeters, String title, Duration duration, {Key? key, Duration ending = Duration.zero, bool prices = false, bool allowPartial = false})` — input is PARSED rows (empty list = loading/skeleton handled by callers; the widget itself, given empty rows, renders a compact one-line `Text('No data for $title')`).
- `DataAggregator` gains named `allowPartial` (default false): when true, an incomplete range fills all 48 slots instead of throwing `NotEnoughDataException` (port the exact block shape from Amber `lib/bar_chart.dart` — the `if (!beforeRange || !afterRange)` rework; momentum has no forecast mode so the condition is `if (!allowPartial) throw ...` then fill).
- `DataAggregator` gains `numMeters` as a constructor param (from CsvState) instead of self-detecting; keep the detection function available for CsvState reuse.
- BarChartState: NO `late final` input copies — one `_syncFromWidget()` returning changed?, called from initState + didUpdateWidget, reparse when changed (port the pattern from Amber `lib/bar_chart.dart:101-143`).
- TopSectionWidget usage and the sentinel strings `loading`/`cancelled` DELETED from this file (states now live in CsvState; `lib/top_section.dart` itself is deleted in Task 8).
- Axes/tooltips ported from Amber: y-label = `_prices ? '\$$formatted' : '$formatted kWh'` with the maxY<1 ? 2 : 1 decimals rule; x-labels every 3 hours horizontal (`graphPos % 6 == 0`, angle 0 — momentum is fixed half-hour bars so 6 slots = 3h); `barTouchData` tooltip `'{label}\n{value}{_prices ? ' \$' : ' kWh'}'` with `handleBuiltInTouches: true`.

- [ ] **Step 1: Failing smoke test** — `test/widget_smoke_test.dart`: pump `BarChartWidget1(rowsFor2Days, 1, 'Mon 7 Jul', const Duration(days: 1))` in a MaterialApp/Scaffold/SizedBox(300) host (no theme provider) with a `rowsFor2Days` generator in `test/test_data.dart` (48 half-hour rows per day, single meter, kwh 0.5, dates 07/07/25-08/07/25 in `DD/MM/YY HH:MM` strings); assert it renders without the old legend texts ('Off Peak' etc.) and shows no exception. Add the keyless double-pump regression: pump with `prices: false`, then pump same-position widget with `prices: true`, assert the State re-aggregated (expose `@visibleForTesting bool get lastParsePrices` or assert via y-axis '\$' text appearing).
- [ ] **Step 2: Run** — FAIL (constructor mismatch).
- [ ] **Step 3: Implement** the port. Update `test/bar_chart_test.dart`'s aggregator constructions to pass `numMeters:` where the new param is required (values: 2 for the sample fixture, matching what detection returned before).
- [ ] **Step 4: Full suite green.**
- [ ] **Step 5: Commit** — `git commit -m "feat(chart): parsed-rows input, full input re-sync, hygienic axes and tooltips [skip ci]"`

---

### Task 3: Window totals helper

**Files:**
- Create: `lib/state/day_math.dart`
- Test: `test/day_math_test.dart`

**Interfaces:**
- `({double cost, double kwh}) windowTotals(List<List<dynamic>> rows, int numMeters, Duration duration, Duration ending)` — runs `DataAggregator` twice (prices true / false, `allowPartial: true`, `numMeters` passed through) and sums each result's `newData` values (`group.barRods.first.toY`, plus the negative feed... momentum has no feedIn channel — just sum toY). By construction the numbers equal the drawn bars, including supply charge and current `tariffs`.
- Trailing formats used by later tasks: cost `'\$' + cost.toStringAsFixed(2)`, kwh `kwh.toStringAsFixed(1) + ' kWh'`.

- [ ] **Step 1: Failing test** — with `rowsFor2Days` (import from `test/test_data.dart`): totals for `duration: 1 day, ending: 0` — kwh == 24.0 (48 × 0.5) and cost == the same value the aggregator's bars sum to (compute expected by running DataAggregator in the test and summing — the assertion is equality between helper and direct sum, plus kwh exact).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement. Step 4: Suite green.**
- [ ] **Step 5: Commit** — `git commit -m "feat: windowTotals sums exactly what the charts draw [skip ci]"`

---

### Task 4: LegendBar and ChartCard

**Files:**
- Create: `lib/widgets/legend_bar.dart`, `lib/widgets/chart_card.dart`
- Test: append `test/widget_smoke_test.dart`

**Interfaces:**
- `LegendBar({required bool showSupply})` — Wrap of swatch+label pairs, colors from this repo's `colors` list exactly as `_getCostColor` uses them: Off-peak `colors[2]`, Shoulder `colors[3]`, Peak `colors[4]`, Controlled `colors[1]`, plus Supply `colors[0]` when showSupply. Labels: 'Off-peak', 'Shoulder', 'Peak', 'Controlled', 'Supply'.
- `ChartCard({required String title, String? trailing, required Widget chart})` — port from Amber `lib/widgets/chart_card.dart` verbatim (0xFF1A1A26, radius 8, title white70 left, trailing grey right, `SizedBox(height: 180)`).

- [ ] **Step 1: Failing test** — ChartCard renders title+trailing; LegendBar renders 'Peak' and (with showSupply) 'Supply'.
- [ ] **Step 2-4: RED → implement → suite green.**
- [ ] **Step 5: Commit** — `git commit -m "feat: LegendBar and ChartCard widgets [skip ci]"`

---

### Task 5: Data tab (file-summary hero)

**Files:**
- Create: `lib/screens/data_tab.dart`
- Test: `test/data_tab_test.dart`

**Interfaces:**
- `DataTab()` — `context.watch<CsvState>()`. Layout: `LegendBar(showSupply: true)`; hero container (0xFF1A1A26, radius 8): caption 'YOUR DATA'; big line `'{E d MMM of firstDate} – {E d MMM yyyy of lastDate}'`; sub-line `'{fileName} · {numMeters} meter{s} · {dayCount} days'`; stats row of three tiles (0xFF23232F): TOTAL COST `windowTotals(rows, numMeters, Duration(days: dayCount), Duration.zero).cost` as `$X.XX`, TOTAL USE as `X.X kWh`, AVG / DAY `$ (cost/dayCount)`; full-width `FilledButton.icon` 'Import new export' calling `importFile()` (momentum pink `Color(0xFFFF3E8D)` background). Below the hero: the two most recent day `ChartCard`s (Cost metric), titles from data (`lastDate - ending` formatted 'E d MMM'), trailing from windowTotals, charts `BarChartWidget1(rows, numMeters, title, Duration(days: 1), ending: Duration(days: e), prices: true, allowPartial: true)` for e = 0, 1, each wrapped `IgnorePointer` inside the card (no navigation on this tab — tooltips allowed: NO IgnorePointer here after all; leave tooltips live).
- Status handling: `status == loading` → centered `CircularProgressIndicator`; `cancelled` → compact 'Import cancelled — reloading sample…'; `error` → compact error text + Import button. All replace the hero+cards, not the whole tab chrome.

- [ ] **Step 1: Failing test** — with `CsvState()..setCsvForTest('export.csv', <two-day single-meter csv from test_data>)`: hero shows '2 days', '1 meter', an Import button, and a `'$'`-prefixed TOTAL COST; error state shows the error message.
- [ ] **Step 2-4: RED → implement → suite green.**
- [ ] **Step 5: Commit** — `git commit -m "feat: Data tab with file-summary hero [skip ci]"`

---

### Task 6: History tab (Days & Weeks)

**Files:**
- Create: `lib/screens/history_tab.dart`
- Test: `test/history_tab_test.dart`

**Interfaces:**
- `HistoryTab({required bool weeks})` — port Amber's `lib/screens/history_tab.dart` shape with these Momentum differences:
  - Chips: **Cost / Usage** only (enum `_Metric { cost, usage }`, cost default).
  - Data source: `state.rows` / `state.numMeters`; entries exist only for days actually in range: day count shown = `min(28, state.dayCount)`, e = 0..count-1, `ending: Duration(days: e)`, title `'E d MMM'` of `lastDate - e days` (DATA-anchored — CsvState.lastDate, never DateTime.now()).
  - Weeks mode: w = 0..min(3, (dayCount/7).ceil()-1): `duration: 7 days`, `ending: Duration(days: w * 7)`, `allowPartial: true`, title `'Week to {E d MMM of lastDate - w*7 days}'`. No separate current-week card (the CSV is static; w=0 IS the newest week).
  - Metric flags: Cost = `prices: true`; Usage = none. Trailing via `windowTotals` (cost/kwh formats from Task 3).
  - Portrait chip feed / landscape 'USAGE (kWh)' | 'COST (\$)' paired rows — identical structure to Amber's.
  - Every feed chart: `ValueKey('${weeks ? 'w' : 'd'}|$title|${metric.name}|${state.tariffsRevision}')` and wrapped in `IgnorePointer` inside an `InkWell`ed ChartCard → `DayDetail` (Task 7 wires the push; in THIS task the InkWell onTap is a no-op TODO-free `() {}` replaced in Task 7 — acceptable single-task seam).
  - `tariffsRevision` in the key forces reparse after a tariff change.
- Status: when `status != ready`, render the same compact status widgets as DataTab (extract them in this task into `lib/widgets/status_views.dart` with `Widget csvStatusView(CsvState s)` and refactor DataTab to use it).

- [ ] **Step 1: Failing tests** — (a) portrait: two chips; switching to Usage swaps trailing to ' kWh'; titles show the fixture's real dates; (b) landscape (1600×720 viewport, reset in teardown): two column headers, no chips, paired cards per row; (c) weeks: 'Week to' card renders with a two-day fixture (allowPartial proves itself).
- [ ] **Step 2-4: RED → implement → suite green.**
- [ ] **Step 5: Commit** — `git commit -m "feat: history tab with portrait chips and landscape pairs [skip ci]"`

---

### Task 7: Day detail + navigation

**Files:**
- Create: `lib/screens/day_detail.dart`
- Modify: `lib/screens/history_tab.dart` (InkWell onTap → push)
- Test: append `test/history_tab_test.dart`

**Interfaces:**
- `DayDetail({required String title, required List<List<dynamic>> rows, required int numMeters, required Duration duration, required Duration ending})` — Scaffold 0xFF20202A, AppBar 0xFF1A1A26 titled `title`; Expanded cost chart (`prices: true, allowPartial: true`, tooltips LIVE — no IgnorePointer); stat tiles row: TOTAL `$` (windowTotals.cost), USED kWh (windowTotals.kwh), SUPPLY `$` = `tariffs.daily * duration.inDays` formatted `$X.XX` (import the global from lib/tariffs.dart).
- History cards push it with their own entry values; test: tap first portrait card's center → AppBar shows that title.

- [ ] **Steps: RED → implement → suite green → commit** `git commit -m "feat: full-screen day detail [skip ci]"`

---

### Task 8: Settings + Onboarding

**Files:**
- Create: `lib/screens/settings_screen.dart`, `lib/screens/onboarding.dart`
- Test: `test/settings_test.dart`, `test/onboarding_test.dart`

**Interfaces:**
- `SettingsScreen()` — AppBar 'Settings'. Section 'TARIFF RATES' (grey label): five numeric `TextFormField`s (Daily supply $/day, Controlled $/kWh, Off-peak $/kWh, Shoulder $/kWh, Peak $/kWh) prefilled from the global `tariffs`; Save button: parse doubles (invalid → inline red 'Enter a number' under the offending field, nothing saved), assign to `tariffs`, `await tariffs.save()`, `context.read<CsvState>().bump()`, SnackBar 'Rates saved' (mounted-guarded). Section 'ABOUT': ListTiles copied VERBATIM from the current footer (`lib/main.dart:430-509`): Source Code github.com/bradrushworth/momentumenergy; Chart Library pub.dev/packages/fl_chart; Buy Coffee buymeacoffee.com/bitbot when `kIsWeb && kReleaseMode` else Visit BitBot www.bitbot.com.au; Report Issue mailto bitbot@bitbot.com.au subject 'Help with Momentum Energy Dashboard'.
- `Onboarding()` — shown by the shell only when `status == error && rows.isEmpty`-style first-run failure is NOT the trigger; Momentum always has the bundled sample, so onboarding is a banner-style first-run helper: per spec, an intro card at the top of the Data tab is NOT required — instead implement onboarding as the Data tab's error/empty state plus a one-time instruction card: `Onboarding()` widget = centered column with steps '1. Log in to Momentum MyAccount', '2. Export your usage table (CSV)', '3. Tap Import and pick the file', link button opening https://www.momentumenergy.com.au/ via `Utils.launchURI`, and an Import `FilledButton` calling `importFile()`. The shell shows it INSTEAD of tabs only when `status == error` AND no rows are loaded. (Note: the exact portal URL is being fixed in a parallel session; use the host root here, not the dead /myaccount/my-usage path.)
- Tests: invalid rate shows inline error and does not mutate `tariffs`; valid save mutates and bumps revision; onboarding renders steps and its Import button.

- [ ] **Steps: RED → implement → suite green → commit** `git commit -m "feat: Settings with tariff rates and About; onboarding [skip ci]"`

---

### Task 9: HomeShell, root swap, deletions

**Files:**
- Create: `lib/screens/home_shell.dart`
- Modify: `lib/main.dart` (rewrite, ~60 lines mirroring Amber's `lib/main.dart`)
- Delete: `lib/my_theme_model.dart`, `lib/top_section.dart`
- Test: `test/home_shell_test.dart`; update any test hosting `MyThemeModel`

**Interfaces:**
- `HomeShell()` — Scaffold 0xFF20202A; AppBar: 'Momentum' title + context line `'{E d MMM firstDate} – {E d MMM lastDate}'` (grey; empty while loading), actions: an upload `IconButton(Icons.upload_file)` calling `importFile()` and a gear → SettingsScreen; body: `csvStatusView` handles non-ready; error-with-no-rows → `Onboarding()`; else `IndexedStack` of `[DataTab(), HistoryTab(weeks: false), HistoryTab(weeks: true)]`; NavigationBar destinations Data (`Icons.description`), Days (`Icons.calendar_view_day`), Weeks (`Icons.calendar_view_week`), hidden while onboarding shows.
- `main.dart`: keep the DevicePreview wrapper + conditional screenshots import; `ChangeNotifierProvider(create: (_) => CsvState()..loadDefaultAsset())`; `MaterialApp(theme: darkTheme, home: HomeShell())` with the dark `ThemeData` block carried from the current file; DELETE `useInheritedMediaQuery` (deprecated) and light theme/`themeMode`; DELETE `HomePage`, `HomePageState`, `MyCard`, `MyDivider`, `ListItem`, `buildDropDownMenuItems`, the header instruction text, the tariff gear dialog, and the footer.
- Verify: full `flutter test`, `flutter analyze` (count must not rise; expect a drop), `flutter build web --release`.

- [ ] **Step 1: Failing test** — 3 NavigationBar destinations with the sample loaded; tapping Days shows the Cost chip; a `setCsvForTest`-injected error with empty rows shows the onboarding steps.
- [ ] **Steps 2-4: implement, delete, run all three verification commands.**
- [ ] **Step 5: ONE commit** — `git add -A lib test && git commit -m "feat: tabbed shell — swap root to HomeShell, delete legacy screen and theme toggle [skip ci]"`

---

## Follow-ups deliberately OUT of this plan
- AGENTS.md/.clinerules refresh for the new architecture (final fix wave).
- Version bump / release; date-parsing hardening beyond the try/catch in Task 1; share-target import; fl_chart 1.x.

## Self-Review Notes
- Spec coverage: §1 shell→T9, §3 hero→T5, §4 history→T6+T7, §5 hygiene→T2+T4 (+windowTotals matching drawn bars→T3), §6 settings/onboarding/theme→T8+T9. Momentum has no site picker or spike/now concepts — correctly absent.
- Type consistency: `rows` is `List<List<dynamic>>` everywhere; `windowTotals` returns a record `({double cost, double kwh})`; `numMeters` threads CsvState → widgets → DataAggregator.
- No placeholder steps: every task carries either full test code or exact assertions plus binding interfaces; Amber reference paths are source material, not "similar to" hand-waves.
