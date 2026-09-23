import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/main.dart' show darkTheme;
import 'package:momentum_energy/screens/home_shell.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_picker.dart';
import 'test_data.dart';

Widget _host(CsvState state, {ThemeData? theme}) =>
    ChangeNotifierProvider<CsvState>.value(
      value: state,
      child: MaterialApp(theme: theme, home: const HomeShell()),
    );

/// The default 800x600 test surface is landscape-shaped; [HistoryTab] only
/// renders its metric chips in portrait, so force a portrait surface.
void _portrait(WidgetTester t) {
  final originalSize = t.view.physicalSize;
  final originalRatio = t.view.devicePixelRatio;
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(() {
    t.view.physicalSize = originalSize;
    t.view.devicePixelRatio = originalRatio;
  });
}

/// A state holding the two-day sample, parsed through the real CSV path.
CsvState _ready() => CsvState()..setCsvForTest('export.csv', csvFor2Days);

/// Not a usage export at all: no row survives the shape check, so the parse
/// fails wherever it is fed in.
const String _malformedCsv = 'not,a,usage,export\nsorry,an error occurred\n';

/// The one message `CsvState` reports for an unreadable file.
const String _formatMessage =
    'Unrecognized file format — export the usage table from Momentum MyAccount and try again.';

const String _sampleStripText = "You're looking at sample data, not yours";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a NavigationBar with Data / Days / Weeks destinations',
      (t) async {
    _portrait(t);
    await t.pumpWidget(_host(_ready()));
    await t.pump();

    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 3);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('Weeks'), findsOneWidget);
    expect(find.byIcon(Icons.description), findsOneWidget);
    expect(find.byIcon(Icons.calendar_view_day), findsOneWidget);
    expect(find.byIcon(Icons.calendar_view_week), findsOneWidget);

    // App bar: title, data-anchored context line, an import action and a gear.
    expect(find.text('Momentum'), findsOneWidget);
    expect(find.text('Mon 7 Jul – Tue 8 Jul'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.upload_file),
      ),
      findsOneWidget,
    );

    await t.tap(find.byIcon(Icons.settings));
    await t.pumpAndSettle();
    expect(find.text('TARIFF RATES'), findsOneWidget);
  });

  testWidgets('tapping Days swaps the visible tab to the history feed',
      (t) async {
    _portrait(t);
    await t.pumpWidget(_host(_ready()));
    await t.pump();

    // The IndexedStack builds every tab, so the Cost chip exists in the tree
    // from the start — but only the selected tab is hit-testable.
    expect(find.text('Cost').hitTestable(), findsNothing);

    await t.tap(find.text('Days'));
    await t.pumpAndSettle();

    expect(find.text('Cost').hitTestable(), findsOneWidget);
    expect(t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
  });

  testWidgets('a parse error with no rows shows onboarding instead of the tabs',
      (t) async {
    _portrait(t);
    // A fresh state whose FIRST (and only) file is malformed: nothing ever
    // parsed, so `error` with empty rows — the one state in which the shell
    // has nothing at all to show.
    final state = CsvState()..setCsvForTest('junk.csv', _malformedCsv);
    expect(state.status, CsvStatus.error);
    expect(state.rows, isEmpty);
    expect(state.importError, isNull);

    await t.pumpWidget(_host(state));
    await t.pump();

    expect(find.text('Open My Usage in Momentum MyAccount'), findsOneWidget);
    expect(find.text('Import the file here'), findsOneWidget);
    // The guide leads with why the file failed.
    expect(find.text(_formatMessage), findsOneWidget);
    // No tabs to switch between yet, so no (inert) NavigationBar.
    expect(find.byType(NavigationBar), findsNothing);
    // The context line has no dates to show while the parse failed.
    expect(find.textContaining(' – '), findsNothing);
  });

  testWidgets('a first launch opens on the guide, not on the sample', (t) async {
    _portrait(t);
    SharedPreferences.setMockInitialValues({});
    final state = CsvState();
    await state.restore();

    await t.pumpWidget(_host(state));
    await t.pump();

    expect(find.text('See your own electricity use'), findsOneWidget);
    expect(find.text('Just looking? Try it with sample data'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text(_sampleStripText), findsNothing);
  });

  testWidgets('while the first file loads: a spinner, no guide, no tabs', (t) async {
    _portrait(t);
    await t.pumpWidget(_host(CsvState()));
    await t.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('See your own electricity use'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('the sample is labelled on every tab and leads to the guide', (t) async {
    _portrait(t);
    final state = CsvState()
      ..setCsvForTest('Sample export', csvFor2Days, source: CsvSource.sample);
    await t.pumpWidget(_host(state));
    await t.pump();

    expect(find.text(_sampleStripText), findsOneWidget);
    expect(find.text('Sample · Mon 7 Jul – Tue 8 Jul'), findsOneWidget);

    // The strip sits above the tabs, so it stays on Days and Weeks too.
    await t.tap(find.text('Weeks'));
    await t.pumpAndSettle();
    expect(find.text(_sampleStripText), findsOneWidget);

    await t.tap(find.text('Use my data'));
    await t.pumpAndSettle();
    expect(find.text('Get your data'), findsOneWidget);
    expect(find.text('Open My Usage in Momentum MyAccount'), findsOneWidget);
    // The sample is already on screen, so the guide doesn't offer it again.
    expect(find.text('Just looking? Try it with sample data'), findsNothing);
  });

  testWidgets('importing from the guide returns to the charts, now the user\'s own',
      (t) async {
    _portrait(t);
    SharedPreferences.setMockInitialValues({});
    usePicker(PickedFile('Your_Usage_List_2025.csv', csvFor2Days));
    final state = CsvState()
      ..setCsvForTest('Sample export', csvFor2Days, source: CsvSource.sample);
    await t.pumpWidget(_host(state));
    await t.pump();

    await t.tap(find.text('Use my data'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Import my CSV'));
    await t.tap(find.text('Import my CSV'));
    await t.pumpAndSettle();

    expect(state.hasUserData, isTrue);
    expect(find.text('Get your data'), findsNothing);
    expect(find.text(_sampleStripText), findsNothing);
    expect(find.text('YOUR DATA'), findsOneWidget);
    expect(find.text('Mon 7 Jul – Tue 8 Jul'), findsOneWidget);
  });

  testWidgets('the user\'s own data carries no sample strip', (t) async {
    _portrait(t);
    await t.pumpWidget(_host(_ready()));
    await t.pump();

    expect(find.text(_sampleStripText), findsNothing);
    expect(find.text('Use my data'), findsNothing);
  });

  testWidgets(
      'a failed import over good data keeps the tabs and adds a dismissible banner',
      (t) async {
    _portrait(t);
    // The real path: a good file is loaded, then a malformed one is imported
    // over it. No public field is poked — the whole point is that _parse's
    // own failure handling keeps the good file on screen.
    final state = _ready();
    await t.pumpWidget(_host(state));
    await t.pump();

    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.text('Tue 8 Jul'), findsWidgets);

    state.setCsvForTest('junk.csv', _malformedCsv);
    await t.pump();

    // The good file survived, in the state AND on screen.
    expect(state.rows, isNotEmpty);
    expect(state.status, CsvStatus.ready);
    expect(state.fileName, 'export.csv');
    expect(state.importError, _formatMessage);
    expect(find.text('Mon 7 Jul – Tue 8 Jul'), findsOneWidget);
    expect(find.text('Tue 8 Jul'), findsWidgets);

    // One report of the failure, in the banner — the tabs show no error body.
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MaterialBanner),
        matching: find.text(_formatMessage),
      ),
      findsOneWidget,
    );
    expect(find.text(_formatMessage), findsOneWidget);
    // Still the tabbed shell, not onboarding.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Open My Usage in Momentum MyAccount'), findsNothing);

    await t.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await t.pump();

    // Dismissed locally even though importError is still set on the state.
    expect(find.byType(MaterialBanner), findsNothing);
    expect(state.importError, _formatMessage);
    // ...and the data is untouched by the dismissal.
    expect(find.text('Tue 8 Jul'), findsWidgets);

    // A successful import clears the flag, so nothing is left to report.
    state.setCsvForTest('export2.csv', csvFor2Days);
    await t.pump();

    expect(state.importError, isNull);
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('renders under the app dark theme', (t) async {
    _portrait(t);
    await t.pumpWidget(_host(_ready(), theme: darkTheme));
    await t.pump();

    expect(find.text('Momentum'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
