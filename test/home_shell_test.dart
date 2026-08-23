import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/main.dart' show darkTheme;
import 'package:momentum_energy/screens/home_shell.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:provider/provider.dart';

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

    expect(find.text('1. Log in to Momentum MyAccount'), findsOneWidget);
    expect(find.text('3. Tap Import and pick the file'), findsOneWidget);
    // No tabs to switch between yet, so no (inert) NavigationBar.
    expect(find.byType(NavigationBar), findsNothing);
    // The context line has no dates to show while the parse failed.
    expect(find.textContaining(' – '), findsNothing);
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
    expect(find.text('1. Log in to Momentum MyAccount'), findsNothing);

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
