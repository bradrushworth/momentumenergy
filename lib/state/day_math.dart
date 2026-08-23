import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:momentum_energy/bar_chart.dart';

/// The rows list the memo below currently describes, held by IDENTITY.
///
/// `CsvState` replaces `rows` wholesale on every successful parse, so identity
/// is a sound (and free) stand-in for "same file": a new list means a new
/// import, and the whole memo is dropped rather than merged.
List<List<dynamic>>? _memoRows;

/// `'$numMeters|$durationDays|$endingDays|$revision'` -> totals.
Map<String, ({double cost, double kwh})> _memo = {};

/// How many times [windowTotals] has actually run the aggregators (as opposed
/// to answering from the memo). Test hook only.
@visibleForTesting
int windowTotalsComputations = 0;

/// Drops the memo and the [windowTotalsComputations] counter. Test hook only.
@visibleForTesting
void resetWindowTotalsMemo() {
  _memoRows = null;
  _memo = {};
  windowTotalsComputations = 0;
}

/// Computes window totals (cost and kWh) for a given time window.
///
/// Runs DataAggregator twice (prices true/false, allowPartial: true, numMeters
/// passed through) and sums each result's newData values
/// (group.barRods.first.toY) — so the numbers a screen prints are the same
/// numbers its bars draw.
///
/// Memoised: a history feed asks for the same handful of windows on every
/// rebuild (and the landscape layout asks for each one twice, once per
/// column), which is two full passes over every row each time. [revision] is
/// `CsvState.tariffsRevision`, part of the key because the aggregators read
/// the mutable global `tariffs` — bump it (via `CsvState.bump`) whenever
/// rates change or cost totals will answer from a stale entry.
({double cost, double kwh}) windowTotals(
  List<List<dynamic>> rows,
  int numMeters,
  Duration duration,
  Duration ending, {
  int revision = 0,
}) {
  if (!identical(_memoRows, rows)) {
    _memoRows = rows;
    _memo = {};
  }
  final String key = '$numMeters|${duration.inDays}|${ending.inDays}|$revision';
  final cached = _memo[key];
  if (cached != null) return cached;

  windowTotalsComputations++;

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

  final result = (cost: totalCost, kwh: totalKwh);
  _memo[key] = result;
  return result;
}
