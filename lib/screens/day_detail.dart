import 'package:flutter/material.dart';

import '../bar_chart.dart';
import '../state/day_math.dart';
import '../tariffs.dart';
import 'package:momentum_energy/theme.dart';

/// Full-screen detail for a single history entry (day or week): a full-height
/// cost chart with LIVE tooltips above a row of TOTAL / USED / SUPPLY stat
/// tiles, reached by tapping a history `ChartCard`.
///
/// Unlike the feed's chart (wrapped in `IgnorePointer` so scrolling the list
/// isn't fought by tooltip gestures), this chart is the only thing on
/// screen, so its tooltips are left live.
class DayDetail extends StatelessWidget {
  final String title;
  final List<List<dynamic>> rows;
  final int numMeters;
  final Duration duration;
  final Duration ending;

  /// `CsvState.tariffsRevision` at push time — only the `windowTotals` memo
  /// key needs it, so a caller without a CsvState can leave it at 0.
  final int revision;

  const DayDetail({
    super.key,
    required this.title,
    required this.rows,
    required this.numMeters,
    required this.duration,
    required this.ending,
    this.revision = 0,
  });

  Widget _statTile(String label, String value) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: MomentumPalette.skeleton,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: MomentumPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = windowTotals(rows, numMeters, duration, ending, revision: revision);
    final supply = tariffs.daily * duration.inDays;

    return Scaffold(
      backgroundColor: MomentumPalette.indigo,
      appBar: AppBar(
        backgroundColor: MomentumPalette.surface,
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(
            child: BarChartWidget1(rows, numMeters, title, duration,
                ending: ending, prices: true, allowPartial: true),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _statTile('TOTAL', '\$${totals.cost.toStringAsFixed(2)}'),
                const SizedBox(width: 8),
                _statTile('USED', '${totals.kwh.toStringAsFixed(1)} kWh'),
                const SizedBox(width: 8),
                _statTile('SUPPLY', '\$${supply.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
