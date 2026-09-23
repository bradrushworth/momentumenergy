import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../bar_chart.dart';
import '../state/csv_state.dart';
import '../state/day_math.dart';
import '../state/formats.dart';
import '../widgets/chart_card.dart';
import '../widgets/legend_bar.dart';
import '../widgets/status_views.dart';
import 'onboarding.dart' show openDataGuide;
import 'package:momentum_energy/theme.dart';

const _kHeroBg = MomentumPalette.surface;
const _kTileBg = MomentumPalette.skeleton;
const _kMuted = MomentumPalette.muted;

/// The "Data" tab: a file-summary hero (whose file it is — SAMPLE DATA or
/// YOUR DATA — date range, file name, meter/day counts, cost/usage totals, an
/// import button and a way to the how-to guide) above the two most recent
/// per-day cost charts.
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
    // Keyed on the rows, not on `status`: a failed re-import leaves the last
    // good file loaded, and this tab must keep drawing it (the shell reports
    // the failure in a banner). windowTotals throws on empty rows, so never
    // call it without this guard.
    if (csvNeedsStatusView(state)) {
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

    final totals = windowTotals(rows, numMeters, Duration(days: dayCount), Duration.zero,
        revision: state.tariffsRevision);
    final avgPerDay = dayCount > 0 ? totals.cost / dayCount : 0.0;

    final bigLine = '${dayFormat.format(firstDate)} – '
        '${dayYearFormat.format(lastDate)}';
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
              Text(
                state.isSample ? 'SAMPLE DATA' : 'YOUR DATA',
                style: const TextStyle(
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
              if (!state.savedOnDevice) ...[
                const SizedBox(height: 4),
                const Text(
                  "This file couldn't be saved on this device, so you'll need "
                  'to import it again next time.',
                  style: TextStyle(color: MomentumPalette.mutedBright),
                ),
              ],
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
                  // Mint, from filledButtonTheme — Momentum's own CTA colour.
                  // The hardcoded pink here predates the brand palette.
                  icon: const Icon(Icons.upload_file),
                  label: Text(state.isSample ? 'Import my CSV' : 'Import a newer CSV'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => openDataGuide(context),
                  child: const Text('How do I get my CSV?'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _dayCard(rows, numMeters, lastDate, 0),
        // A one-day export has no second day to chart: without this guard the
        // e=1 card renders an empty "day before the file starts".
        if (dayCount > 1) ...[
          const SizedBox(height: 12),
          _dayCard(rows, numMeters, lastDate, 1),
        ],
      ],
    );
  }

  Widget _dayCard(List<List<dynamic>> rows, int numMeters, DateTime lastDate, int e) {
    final title = dayFormat.format(lastDate.subtract(Duration(days: e)));
    final dayTotals = windowTotals(rows, numMeters, const Duration(days: 1), Duration(days: e),
        revision: state.tariffsRevision);

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
