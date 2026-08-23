import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/bar_chart.dart';
import 'package:momentum_energy/state/day_math.dart';
import 'test_data.dart';

void main() {
  group('Day Math', () {
    test('windowTotals for 1-day window computes correct kwh and cost', () {
      // With rowsFor2Days covering 07/07/25 and 08/07/25:
      // A 1-day window ending at day 0 should cover the last day (08/07/25).
      // 48 rows × 0.5 kwh = 24.0 kwh
      final result = windowTotals(
        rowsFor2Days,
        1, // numMeters: 1
        const Duration(days: 1), // duration
        const Duration(days: 0), // ending
      );

      // kwh should be exactly 24.0 (48 half-hour rows × 0.5 kwh)
      expect(result.kwh, 24.0);

      // cost should equal the sum of what DataAggregator produces
      // Run DataAggregator with prices: true to get the expected cost
      final costAggregator = DataAggregator(
        const Duration(days: 1),
        const Duration(days: 0),
        true,
        numMeters: 1,
        allowPartial: true,
      );
      costAggregator.aggregateData(rowsFor2Days);

      double expectedCost = 0.0;
      for (final group in costAggregator.newData.values) {
        expectedCost += group.barRods.first.toY;
      }

      expect(result.cost, expectedCost);
    });
  });
}
