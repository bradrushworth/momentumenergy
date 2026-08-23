import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/main.dart' show loadSavedTariffs;
import 'package:momentum_energy/tariffs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression: main.dart's rewrite (dropping HomePageState) accidentally
// stranded tariffs.load() with no caller, so a user's saved rates would
// silently never be re-applied on relaunch. `loadSavedTariffs` is main()'s
// startup hook restoring that behaviour; this proves it actually hydrates
// the mutable `tariffs` singleton from SharedPreferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup hydrates the tariffs singleton from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({'tariffDaily': 9.9});
    final defaults = Tariffs();
    try {
      await loadSavedTariffs();

      expect(tariffs.daily, 9.9);
    } finally {
      // `tariffs` is process-global state; restore the defaults so this
      // doesn't leak into other tests.
      tariffs.daily = defaults.daily;
      tariffs.controlled = defaults.controlled;
      tariffs.offPeak = defaults.offPeak;
      tariffs.shoulder = defaults.shoulder;
      tariffs.peak = defaults.peak;
    }
  });
}
