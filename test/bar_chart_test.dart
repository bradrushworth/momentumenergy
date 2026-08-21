import 'dart:io';

import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/bar_chart.dart';
import 'package:momentum_energy/tariffs.dart';

void main() {
  group('Bar Chart', () {
    double dailySupplyChargePer30mins = DAILY / 24 / 2;

    test('1 Day', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[1]!.x, 1);
      expect(dataAggregator.newData[46]!.x, 46);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(dataAggregator.newData[0]!.barRods.first.toY,
          closeTo(0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.toY,
          closeTo(0.023 + 0.02 + 0.019 + 0.019 + 0.021 + 0.022, 0.001));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY,
          closeTo(0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019, 0.001));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019, 0.001));
    });

    test('1 Day Costs', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true);
      dataAggregator.aggregateData(data);

      expect(dailySupplyChargePer30mins, closeTo(0.0440, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.toY,
          closeTo(
              OFFPEAK * (0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019) +
                  dailySupplyChargePer30mins,
              0.01));
      expect(
          dataAggregator.newData[47]!.barRods.first.toY,
          closeTo(
              OFFPEAK * (0.023 + 0.02 + 0.019 + 0.019 + 0.021 + 0.022) + dailySupplyChargePer30mins,
              0.01));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.04, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY,
          closeTo(0.04 + 0.03, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY,
          closeTo(0.04 + 0.03, 0.01));
    });

    test('2 Days', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 2), const Duration(days: 0), false);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(
          dataAggregator.newData[0]!.barRods.first.toY,
          closeTo(
              (0.018 + 0.015 + 0.016 + 0.016 + 0.018 + 0.019) +
                  (0.023 + 0.023 + 0.023 + 0.018 + 0.017 + 0.017) +
                  (0.0 + 0.3 + 0.23 + 0.0 + 0.2 + 0.0) +
                  (0.0),
              0.001));
      expect(
          dataAggregator.newData[47]!.barRods.first.toY,
          closeTo(
              (0.023 + 0.02 + 0.019 + 0.019 + 0.021 + 0.022) +
                  (0.016 + 0.017 + 0.019 + 0.019 + 0.02 + 0.019),
              0.001));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.0, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.223, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY, closeTo(0.223, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY, closeTo(0.953, 0.001));
    });

    test('1 Day Costs 1 Day Prior', () async {
      final myData = await File('assets/Your_Usage_List_Sample.csv').readAsString();
      List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(myData, shouldParseNumbers: true);
      List<dynamic> fieldNames = data.removeAt(0);
      expect(fieldNames.length, 3);
      expect(fieldNames[0].trim(), 'Date and Time');
      expect(fieldNames[1].trim(), 'Read Value - kWh (kilowatt hours)');
      expect(fieldNames[2].trim(), 'Reading quality');

      DataAggregator dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 1), true);
      dataAggregator.aggregateData(data);

      expect(dataAggregator.newTitles.length, 48);
      expect(dataAggregator.newTitles[0], '00:00');
      expect(dataAggregator.newTitles[1], '00:30');
      expect(dataAggregator.newTitles[46], '23:00');
      expect(dataAggregator.newTitles[47], '23:30');

      expect(dataAggregator.newData.length, 48);
      expect(dataAggregator.newData[0]!.x, 0);
      expect(dataAggregator.newData[1]!.x, 1);
      expect(dataAggregator.newData[46]!.x, 46);
      expect(dataAggregator.newData[47]!.x, 47);

      expect(dailySupplyChargePer30mins, closeTo(0.0440, 0.001));
      expect(
          dataAggregator.newData[0]!.barRods.first.toY,
          closeTo(
              (OFFPEAK * (0.023 + 0.023 + 0.023 + 0.018 + 0.017 + 0.017)) +
                  (CONTROLLED * (0.0 + 0.0 + 0.3 + 0.23 + 0.0 + 0.2)) +
                  dailySupplyChargePer30mins,
              0.01));
      expect(
          dataAggregator.newData[47]!.barRods.first.toY,
          closeTo(
              (OFFPEAK * (0.016 + 0.017 + 0.019 + 0.019 + 0.02 + 0.019)) +
                  (CONTROLLED * (0.0 + 0.0 + 0.0 + 0.0 + 0.0 + 0.0)) +
                  dailySupplyChargePer30mins,
              0.01));

      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.first.fromY, closeTo(0.00, 0.01));
      expect(dataAggregator.newData[0]!.barRods.first.rodStackItems.first.toY, closeTo(0.04, 0.01));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.fromY, closeTo(0.08, 0.01));
      expect(
          dataAggregator.newData[0]!.barRods.first.rodStackItems.last.toY, closeTo(0.21, 0.01));
    });

    // Current Momentum exports contain a single meter (one row per timestamp).
    // The old meter detection scanned for the first repeated timestamp and
    // never found one, so every chart threw NotEnoughDataException.
    List<List<dynamic>> buildSingleMeter({int days = 2, int startDay = 6}) {
      // 06/07/25 was a Sunday; 07/07/25 a Monday (matches the real export era).
      final data = <List<dynamic>>[];
      for (int d = 0; d < days; d++) {
        for (int i = 0; i < 288; i++) {
          final h = (i * 5) ~/ 60, m = (i * 5) % 60;
          final dd = (startDay + d).toString().padLeft(2, '0');
          data.add([
            '$dd/07/25 ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
            0.1,
            'Actual'
          ]);
        }
      }
      return data;
    }

    test('Single-meter export aggregates (regression)', () {
      final dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), false);
      dataAggregator.aggregateData(buildSingleMeter());

      expect(dataAggregator.newData.length, 48);
      // 6 five-minute reads of 0.1 kWh per half-hour bar.
      expect(dataAggregator.newData[0]!.barRods.first.toY, closeTo(0.6, 0.001));
      expect(dataAggregator.newData[47]!.barRods.first.toY, closeTo(0.6, 0.001));
    });

    test('Single-meter export bills at time-of-use, not controlled load', () {
      // Last day of the fixture is Monday 07/07/25 (a weekday): peak window
      // bars must use PEAK, and never the controlled-load rate.
      final dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 0), true);
      dataAggregator.aggregateData(buildSingleMeter());

      final supplyPer30mins = DAILY / 24 / 2;
      // 18:00 sits in the 17:00-20:00 peak window (graphPos 36).
      expect(dataAggregator.newData[36]!.barRods.first.toY,
          closeTo(PEAK * 0.6 + supplyPer30mins, 0.01));
      // 03:00 is off peak (graphPos 6).
      expect(dataAggregator.newData[6]!.barRods.first.toY,
          closeTo(OFFPEAK * 0.6 + supplyPer30mins, 0.01));
    });

    test('Weekend day bills off-peak all day (single meter)', () {
      // One-day chart ending one day back lands on Sunday 06/07/25.
      final dataAggregator =
          DataAggregator(const Duration(days: 1), const Duration(days: 1), true);
      dataAggregator.aggregateData(buildSingleMeter());

      final supplyPer30mins = DAILY / 24 / 2;
      // Peak-window slot still billed off peak on a weekend.
      expect(dataAggregator.newData[36]!.barRods.first.toY,
          closeTo(OFFPEAK * 0.6 + supplyPer30mins, 0.01));
    });

    test('Changed tariff rates flow through to aggregated values', () {
      // The aggregator must read the mutable `tariffs` singleton, not the
      // compile-time default constants. `tariffs` is process-global state, so
      // restore the defaults afterwards or the change leaks into other tests.
      tariffs.daily = 4.8;
      tariffs.offPeak = 0.10;
      tariffs.peak = 1.00;
      try {
        final dataAggregator =
            DataAggregator(const Duration(days: 1), const Duration(days: 0), true);
        dataAggregator.aggregateData(buildSingleMeter());

        final supplyPer30mins = 4.8 / 24 / 2;
        // Weekday peak slot (18:00) uses the new peak rate...
        expect(dataAggregator.newData[36]!.barRods.first.toY,
            closeTo(1.00 * 0.6 + supplyPer30mins, 0.01));
        // ...and the off-peak slot (03:00) the new off-peak rate. Both must
        // differ from what the default constants would have produced.
        expect(dataAggregator.newData[6]!.barRods.first.toY,
            closeTo(0.10 * 0.6 + supplyPer30mins, 0.01));
        expect((dataAggregator.newData[6]!.barRods.first.toY -
                    (OFFPEAK * 0.6 + DAILY / 24 / 2))
                .abs(),
            greaterThan(0.05));
      } finally {
        final defaults = Tariffs();
        tariffs.daily = defaults.daily;
        tariffs.controlled = defaults.controlled;
        tariffs.offPeak = defaults.offPeak;
        tariffs.shoulder = defaults.shoulder;
        tariffs.peak = defaults.peak;
      }
    });
  });
}
