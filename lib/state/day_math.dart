import 'package:momentum_energy/bar_chart.dart';

/// Computes window totals (cost and kWh) for a given time window.
///
/// Runs DataAggregator twice (prices true/false, allowPartial: true, numMeters passed through)
/// and sums each result's newData values (group.barRods.first.toY).
///
/// Returns a record with cost and kwh values computed from the aggregated bar data.
({double cost, double kwh}) windowTotals(
  List<List<dynamic>> rows,
  int numMeters,
  Duration duration,
  Duration ending,
) {
  // Aggregate kwh values (prices: false)
  final kwhAggregator = DataAggregator(
    duration,
    ending,
    false,
    numMeters: numMeters,
    allowPartial: true,
  );
  kwhAggregator.aggregateData(rows);

  double totalKwh = 0.0;
  for (final group in kwhAggregator.newData.values) {
    totalKwh += group.barRods.first.toY;
  }

  // Aggregate cost values (prices: true)
  final costAggregator = DataAggregator(
    duration,
    ending,
    true,
    numMeters: numMeters,
    allowPartial: true,
  );
  costAggregator.aggregateData(rows);

  double totalCost = 0.0;
  for (final group in costAggregator.newData.values) {
    totalCost += group.barRods.first.toY;
  }

  return (cost: totalCost, kwh: totalKwh);
}
