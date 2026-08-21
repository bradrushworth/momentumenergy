import 'package:shared_preferences/shared_preferences.dart';

/// User-adjustable tariff rates. `daily` is $/day; the rest are $/kWh.
/// The defaults are one 2023 Momentum plan; real rates vary per customer and
/// over time, so users maintain them in the Settings dialog.
class Tariffs {
  double daily;
  double controlled;
  double offPeak;
  double shoulder;
  double peak;

  Tariffs({
    this.daily = 2.1109,
    this.controlled = 0.1771,
    this.offPeak = 0.2992,
    this.shoulder = 0.3971,
    this.peak = 0.4620,
  });

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    daily = prefs.getDouble('tariffDaily') ?? daily;
    controlled = prefs.getDouble('tariffControlled') ?? controlled;
    offPeak = prefs.getDouble('tariffOffPeak') ?? offPeak;
    shoulder = prefs.getDouble('tariffShoulder') ?? shoulder;
    peak = prefs.getDouble('tariffPeak') ?? peak;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tariffDaily', daily);
    await prefs.setDouble('tariffControlled', controlled);
    await prefs.setDouble('tariffOffPeak', offPeak);
    await prefs.setDouble('tariffShoulder', shoulder);
    await prefs.setDouble('tariffPeak', peak);
  }
}

/// The rates used by the charts. Mutated by the Settings dialog; charts are
/// re-parsed by bumping the grid key after a change.
final Tariffs tariffs = Tariffs();
