import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../bar_chart.dart';
import '../state/csv_state.dart';
import '../state/day_math.dart';
import '../state/formats.dart';
import '../widgets/chart_card.dart';
import '../widgets/legend_bar.dart';
import '../widgets/status_views.dart';
import 'day_detail.dart';

enum _Metric { cost, usage }

/// One row of the history list: a chart window, described independently of
/// any particular metric.
class _Entry {
  final Duration duration;
  final Duration ending;
  final String title;
  final bool allowPartial;

  const _Entry({
    required this.duration,
    required this.ending,
    required this.title,
    this.allowPartial = false,
  });
}

/// The "History" tab content, shared by the Days and Weeks sub-tabs.
///
/// Portrait shows a Cost/Usage `ChoiceChip` row above a `ListView` of
/// `ChartCard`s for the selected metric. Landscape drops the chips and shows
/// side-by-side Usage/Cost columns for every row instead.
///
/// Unlike Amber's live-fetched `DashboardState`, `CsvState` is a single
/// static parse of the imported export, so every entry here is backed by
/// real data the moment the tab builds — there is no "loading" placeholder
/// row to account for, only the days/weeks actually present in the file.
class HistoryTab extends StatefulWidget {
  final bool weeks;

  const HistoryTab({super.key, required this.weeks});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  _Metric _metric = _Metric.cost;

  List<_Entry> _entries(CsvState state) =>
      widget.weeks ? _weekEntries(state) : _dayEntries(state);

  /// One entry per day actually present in the file, newest first: e = 0 is
  /// the file's own last date (never `DateTime.now()` — the export is
  /// static, so "today" by the clock may not even be in it), up to 28 days.
  /// `allowPartial` because a real export cut mid-day leaves a short last
  /// day; without it the strict range check renders a full-height "Not
  /// enough data" card instead of the partial day's actual chart.
  List<_Entry> _dayEntries(CsvState state) {
    final lastDate = state.lastDate!;
    final count = state.dayCount < 28 ? state.dayCount : 28;
    return [
      for (var e = 0; e < count; e++)
        _Entry(
          duration: const Duration(days: 1),
          ending: Duration(days: e),
          title: dayFormat.format(lastDate.subtract(Duration(days: e))),
          allowPartial: true,
        ),
    ];
  }

  /// Up to 4 weeks, newest first, anchored the same way as [_dayEntries].
  /// `allowPartial` because the file's oldest week is routinely short (the
  /// export doesn't start on a week boundary) and the newest "week" is
  /// whatever days have landed since the last full week — a strict range
  /// check would render "Not enough data" for either.
  List<_Entry> _weekEntries(CsvState state) {
    final lastDate = state.lastDate!;
    final maxAvailable = (state.dayCount / 7).ceil() - 1;
    final lastWeek = maxAvailable < 3 ? maxAvailable : 3;
    return [
      for (var w = 0; w <= lastWeek; w++)
        _Entry(
          duration: const Duration(days: 7),
          ending: Duration(days: w * 7),
          title: 'Week to ${dayFormat.format(lastDate.subtract(Duration(days: w * 7)))}',
          allowPartial: true,
        ),
    ];
  }

  Widget _cardFor(CsvState state, _Entry entry, _Metric metric) {
    // The metric belongs in the key: identical tree positions otherwise let
    // Flutter hand the same BarChartState a differently-configured widget.
    // BarChartState re-syncs everything now, but the key makes the swap a
    // fresh State and keeps the two landscape columns distinct. tariffsRevision
    // forces a reparse after a tariff change.
    final key = ValueKey<String>(
        '${widget.weeks ? 'w' : 'd'}|${entry.title}|${metric.name}|${state.tariffsRevision}');

    final totals = windowTotals(state.rows, state.numMeters, entry.duration, entry.ending,
        revision: state.tariffsRevision);

    final Widget card;
    switch (metric) {
      case _Metric.cost:
        card = ChartCard(
          title: entry.title,
          trailing: '\$${totals.cost.toStringAsFixed(2)}',
          chart: IgnorePointer(
            child: BarChartWidget1(
              state.rows,
              state.numMeters,
              entry.title,
              entry.duration,
              key: key,
              ending: entry.ending,
              prices: true,
              allowPartial: entry.allowPartial,
            ),
          ),
        );
        break;
      case _Metric.usage:
        card = ChartCard(
          title: entry.title,
          trailing: '${totals.kwh.toStringAsFixed(1)} kWh',
          chart: IgnorePointer(
            child: BarChartWidget1(
              state.rows,
              state.numMeters,
              entry.title,
              entry.duration,
              key: key,
              ending: entry.ending,
              allowPartial: entry.allowPartial,
            ),
          ),
        );
        break;
    }

    return InkWell(
      // Pushes the full-screen day detail with this entry's own window (its
      // duration/ending), not the tapped metric -- DayDetail always shows
      // the cost chart with live tooltips regardless of which card (Cost or
      // Usage) was tapped.
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DayDetail(
            title: entry.title,
            rows: state.rows,
            numMeters: state.numMeters,
            duration: entry.duration,
            ending: entry.ending,
            revision: state.tariffsRevision,
          ),
        ),
      ),
      child: card,
    );
  }

  Widget _chipsRow() {
    const labels = {
      _Metric.cost: 'Cost',
      _Metric.usage: 'Usage',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        children: _Metric.values
            .map((m) => ChoiceChip(
                  label: Text(labels[m]!),
                  selected: _metric == m,
                  onSelected: (_) => setState(() => _metric = m),
                ))
            .toList(),
      ),
    );
  }

  Widget _landscapeHeader() {
    const style = TextStyle(
      color: Color(0xFF9595A4),
      fontWeight: FontWeight.bold,
      fontSize: 12,
      letterSpacing: 1.2,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(child: Text('USAGE (kWh)', style: style)),
          Expanded(child: Text('COST (\$)', style: style)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CsvState>();

    // Keyed on the rows, not on `status`: a failed re-import leaves the last
    // good file loaded and this feed keeps rendering it (the shell reports
    // the failure in a banner). windowTotals throws on empty rows, so never
    // call it without this guard.
    if (csvNeedsStatusView(state)) {
      return csvStatusView(state);
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final entries = _entries(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: LegendBar(showSupply: true),
        ),
        if (!isLandscape) _chipsRow(),
        if (isLandscape) _landscapeHeader(),
        Expanded(
          child: isLandscape
              ? ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _cardFor(state, entries[i], _Metric.usage)),
                      const SizedBox(width: 12),
                      Expanded(child: _cardFor(state, entries[i], _Metric.cost)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _cardFor(state, entries[i], _metric),
                ),
        ),
      ],
    );
  }
}
