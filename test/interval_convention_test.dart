import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/bar_chart.dart';

/// Pins the CSV's timestamp convention, because the Amber twin's is the
/// OPPOSITE and fixes get ported between the two by hand.
///
/// Momentum's export stamps the START of each 5-minute interval: a day runs
/// 00:00 to 23:55, so the reading labelled 07:00 covers 07:00-07:05 and belongs
/// in the 07:00 bar. `aggregateData` therefore buckets straight off the parsed
/// timestamp with no subtraction, and that is correct.
///
/// Amber's API instead stamps the END (`nemTime`), so there a record starts at
/// `nemTime - duration` and the aggregator must subtract. Do NOT port that
/// subtraction here: it would drag every reading a bar earlier and hand each
/// half hour the previous one's energy.
void main() {
  /// One day of single-meter rows, all 0 kWh except the half hours named in
  /// [heavy], whose every 5-minute reading is 1 kWh.
  List<List<dynamic>> dayWith(Set<String> heavy) {
    final rows = <List<dynamic>>[];
    for (int i = 0; i < 288; i++) {
      final h = (i * 5) ~/ 60, m = (i * 5) % 60;
      final stamp = '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}';
      final slot = '${h.toString().padLeft(2, '0')}:'
          '${(m ~/ 30 * 30).toString().padLeft(2, '0')}';
      rows.add(['07/07/25 $stamp', heavy.contains(slot) ? 1.0 : 0.0, 'Actual']);
    }
    return rows;
  }

  test('a reading stamped 07:00 belongs to the 07:00 bar, not 06:30', () {
    final agg = DataAggregator(
        const Duration(days: 1), const Duration(days: 0), false,
        numMeters: 1);
    agg.aggregateData(dayWith({'07:00'}));

    double bar(String label) {
      final pos = agg.newTitles.entries
          .firstWhere((e) => e.value == label,
              orElse: () => throw StateError('no bar labelled $label'))
          .key;
      return agg.newData[pos]!.barRods.first.toY;
    }

    // All six 1 kWh readings (07:00, 07:05 ... 07:25) land in 07:00.
    expect(bar('07:00'), closeTo(6.0, 0.001));
    // ...and none of them leak backwards into the quiet half hour before it.
    expect(bar('06:30'), closeTo(0.0, 0.001),
        reason: 'timestamps are interval STARTS here; do not subtract the '
            'interval the way the Amber twin must');
    expect(bar('07:30'), closeTo(0.0, 0.001));
  });

  test('the last reading of the day is 23:55, so a day is start-stamped', () {
    // If the export stamped interval ENDS, a day would run 00:05 to 00:00 of
    // the following day and this bar would be empty.
    final agg = DataAggregator(
        const Duration(days: 1), const Duration(days: 0), false,
        numMeters: 1);
    agg.aggregateData(dayWith({'23:30'}));

    final pos = agg.newTitles.entries
        .firstWhere((e) => e.value == '23:30')
        .key;
    expect(agg.newData[pos]!.barRods.first.toY, closeTo(6.0, 0.001));
  });
}
