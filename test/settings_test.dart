import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/screens/settings_screen.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:momentum_energy/tariffs.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('invalid rate shows inline error and does not mutate tariffs', (tester) async {
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

  testWidgets('valid save mutates tariffs and bumps revision', (tester) async {
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
