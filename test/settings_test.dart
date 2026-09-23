import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/screens/settings_screen.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:momentum_energy/tariffs.dart';
import 'package:momentum_energy/version.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(CsvState state) {
  return ChangeNotifierProvider<CsvState>.value(
    value: state,
    child: const MaterialApp(
      home: SettingsScreen(),
    ),
  );
}

/// Settings pushed over a stand-in home, so closing it has somewhere to go.
Widget _pushedHost(CsvState state) {
  return ChangeNotifierProvider<CsvState>.value(
    value: state,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            child: const Text('open settings'),
          ),
        ),
      ),
    ),
  );
}

/// YOUR DATA, the rate fields and About run past the default 800x600
/// surface, and a ListView only builds what it lays out — give it room.
void _tall(WidgetTester tester) {
  final originalSize = tester.view.physicalSize;
  final originalRatio = tester.view.devicePixelRatio;
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.physicalSize = originalSize;
    tester.view.devicePixelRatio = originalRatio;
  });
}

const _oneMeter = 'Date and Time, kWh, Quality\n'
    '07/07/25 00:05, 0.1, Actual\n07/07/25 00:10, 0.1, Actual\n'
    '08/07/25 00:05, 0.2, Actual\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('YOUR DATA names the user\'s file and offers to remove it', (tester) async {
    _tall(tester);
    final state = CsvState();
    await state.importCsv('Your_Usage_List_2025.csv', _oneMeter);

    await tester.pumpWidget(_pushedHost(state));
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR DATA'), findsOneWidget);
    expect(find.text('Your_Usage_List_2025.csv'), findsOneWidget);
    expect(find.textContaining('Saved on this device'), findsOneWidget);
    expect(find.text('Import a newer CSV'), findsOneWidget);
    expect(find.text('How to get your CSV'), findsOneWidget);

    await tester.tap(find.text('Remove my data from this device'));
    await tester.pumpAndSettle();
    // Asks first; Cancel changes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(state.hasUserData, isTrue);

    await tester.tap(find.text('Remove my data from this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(state.status, CsvStatus.empty);
    expect(state.rows, isEmpty);
    // Settings closed, back to what the shell would now show as the guide.
    expect(find.text('YOUR DATA'), findsNothing);
    expect(find.text('open settings'), findsOneWidget);
  });

  testWidgets('YOUR DATA labels the sample and has nothing to remove', (tester) async {
    _tall(tester);
    final state = CsvState()
      ..setCsvForTest('Sample export', _oneMeter, source: CsvSource.sample);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(find.text('Sample data (not yours)'), findsOneWidget);
    expect(find.text('Import my CSV'), findsOneWidget);
    expect(find.text('Remove my data from this device'), findsNothing);
  });

  testWidgets('How to get your CSV opens the guide', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(CsvState()));
    await tester.tap(find.text('How to get your CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Get your data'), findsOneWidget);
    expect(find.text('Open Momentum MyAccount'), findsOneWidget);
  });

  testWidgets('invalid rate shows inline error and does not mutate tariffs', (tester) async {
    _tall(tester);
    // `tariffs` is process-global state; restore the defaults in finally so
    // this doesn't leak into other tests.
    final defaults = Tariffs();
    final state = CsvState();
    try {
      await tester.pumpWidget(_host(state));

      await tester.enterText(find.byKey(const Key('tariff_daily')), 'not a number');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a number'), findsOneWidget);
      expect(tariffs.daily, defaults.daily);
      expect(tariffs.controlled, defaults.controlled);
      expect(tariffs.offPeak, defaults.offPeak);
      expect(tariffs.shoulder, defaults.shoulder);
      expect(tariffs.peak, defaults.peak);
      expect(state.tariffsRevision, 0);
    } finally {
      tariffs.daily = defaults.daily;
      tariffs.controlled = defaults.controlled;
      tariffs.offPeak = defaults.offPeak;
      tariffs.shoulder = defaults.shoulder;
      tariffs.peak = defaults.peak;
    }
  });

  testWidgets('About ends with a non-tappable version tile', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(CsvState()));
    await tester.pumpAndSettle();

    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text(appVersion), findsOneWidget);
    // Version is a fact, not a link: unlike every other About tile it has no
    // onTap.
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Version')).onTap,
      isNull,
    );
  });

  testWidgets('valid save mutates tariffs and bumps revision', (tester) async {
    _tall(tester);
    final defaults = Tariffs();
    final state = CsvState();
    try {
      await tester.pumpWidget(_host(state));

      await tester.enterText(find.byKey(const Key('tariff_daily')), '3.5');
      await tester.enterText(find.byKey(const Key('tariff_controlled')), '0.2');
      await tester.enterText(find.byKey(const Key('tariff_offpeak')), '0.3');
      await tester.enterText(find.byKey(const Key('tariff_shoulder')), '0.4');
      await tester.enterText(find.byKey(const Key('tariff_peak')), '0.5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a number'), findsNothing);
      expect(tariffs.daily, 3.5);
      expect(tariffs.controlled, 0.2);
      expect(tariffs.offPeak, 0.3);
      expect(tariffs.shoulder, 0.4);
      expect(tariffs.peak, 0.5);
      expect(state.tariffsRevision, 1);
      expect(find.text('Rates saved'), findsOneWidget);
    } finally {
      tariffs.daily = defaults.daily;
      tariffs.controlled = defaults.controlled;
      tariffs.offPeak = defaults.offPeak;
      tariffs.shoulder = defaults.shoulder;
      tariffs.peak = defaults.peak;
    }
  });
}
