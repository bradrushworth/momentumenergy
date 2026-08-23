import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../bar_chart.dart';
import '../state/csv_state.dart';
import '../state/day_math.dart';
import '../widgets/chart_card.dart';
import '../widgets/legend_bar.dart';
import '../widgets/status_views.dart';

const _kMomentumPink = Color(0xFFFF3E8D);
const _kHeroBg = Color(0xFF1A1A26);
const _kTileBg = Color(0xFF23232F);
const _kMuted = Color(0xFF9595A4);

/// The "Data" tab: a file-summary hero (date range, file name, meter/day
/// counts, cost/usage totals, and an import button) above the two most
/// recent per-day cost charts.
///
/// Unlike the Now tab's history feed, there is no tap-navigation on this
/// tab's charts, so their tooltips stay live (no `IgnorePointer`).
class DataTab extends StatelessWidget {
  const DataTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CsvState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LegendBar(showSupply: true),
          const SizedBox(height: 12),
          _body(state),
        ],
      ),
    );
  }

  Widget _body(CsvState state) {
    // Belt-and-braces: CsvState._parse never leaves `ready` with empty rows
    // (an empty CSV throws to `error` first), but windowTotals throws on
    // empty rows, so never call it without this guard.
    if (state.status != CsvStatus.ready || state.rows.isEmpty) {
      return csvStatusView(state);
    }
    return _ReadyBody(state: state);
  }
}

class _ReadyBody extends StatelessWidget {
  final CsvState state;

  const _ReadyBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final rows = state.rows;
    final numMeters = state.numMeters;
    final dayCount = state.dayCount;
    final firstDate = state.firstDate!;
    final lastDate = state.lastDate!;

    final totals = windowTotals(rows, numMeters, Duration(days: dayCount), Duration.zero);
    final avgPerDay = dayCount > 0 ? totals.cost / dayCount : 0.0;

    final bigLine = '${DateFormat('E d MMM').format(firstDate)} – '
        '${DateFormat('E d MMM yyyy').format(lastDate)}';
    final meterWord = numMeters == 1 ? 'meter' : 'meters';
    final subLine = '${state.fileName} · $numMeters $meterWord · $dayCount days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _kHeroBg,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR DATA',
                style: TextStyle(
                  color: _kMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bigLine,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(subLine, style: const TextStyle(color: _kMuted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatTile('TOTAL COST', '\$${totals.cost.toStringAsFixed(2)}'),
                  const SizedBox(width: 8),
                  _StatTile('TOTAL USE', '${totals.kwh.toStringAsFixed(1)} kWh'),
                  const SizedBox(width: 8),
                  _StatTile('AVG / DAY', '\$${avgPerDay.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.importFile,
                  style: FilledButton.styleFrom(backgroundColor: _kMomentumPink),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import new export'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _dayCard(rows, numMeters, lastDate, 0),
        const SizedBox(height: 12),
        _dayCard(rows, numMeters, lastDate, 1),
      ],
    );
  }

  Widget _dayCard(List<List<dynamic>> rows, int numMeters, DateTime lastDate, int e) {
    final title = DateFormat('E d MMM').format(lastDate.subtract(Duration(days: e)));
    final dayTotals = windowTotals(rows, numMeters, const Duration(days: 1), Duration(days: e));

    return ChartCard(
      title: title,
      trailing: '\$${dayTotals.cost.toStringAsFixed(2)}',
      // No IgnorePointer here: unlike the history feed, this tab has no
      // tap-navigation on its charts, so tooltips stay live.
      chart: BarChartWidget1(
        rows,
        numMeters,
        title,
        const Duration(days: 1),
        ending: Duration(days: e),
        prices: true,
        allowPartial: true,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: _kTileBg,
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
                color: _kMuted,
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
}
