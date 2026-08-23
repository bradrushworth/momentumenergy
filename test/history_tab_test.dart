import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/bar_chart.dart';
import 'package:momentum_energy/screens/history_tab.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:momentum_energy/widgets/chart_card.dart';
import 'package:provider/provider.dart';

import 'test_data.dart';

Widget _host(Widget child, CsvState state) {
  return ChangeNotifierProvider<CsvState>.value(
    value: state,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// All the [BarChartWidget1]s currently in the tree, as widgets (so their
/// configuration — not just a card's trailing text — can be asserted).
Finder _charts({bool? prices, bool? allowPartial}) => find.byWidgetPredicate((w) =>
    w is BarChartWidget1 &&
    (prices == null || w.prices == prices) &&
    (allowPartial == null || w.allowPartial == allowPartial));

void main() {
  testWidgets(
      'portrait: two chips render, switching to Usage swaps trailing, titles are data-anchored',
      (t) async {
    // The default test surface (800x600) is landscape-shaped; force a
    // portrait size so MediaQuery.orientation reports portrait.
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final state = CsvState()..setCsvForTest('export.csv', csvFor2Days);
    await t.pumpWidget(_host(const HistoryTab(weeks: false), state));
    await t.pump();

    expect(t.takeException(), isNull);
    expect(find.text('Cost'), findsOneWidget);
    expect(find.text('Usage'), findsOneWidget);
    // Default metric is Cost: no ' kWh' trailing text yet, and every chart in
    // the feed is actually configured as a cost chart.
    expect(find.textContaining(' kWh'), findsNothing);
    expect(_charts(prices: true), findsWidgets);
    expect(_charts(prices: false), findsNothing);

    // Titles come from the fixture's own last date (08/07/25, a Tuesday),
    // never from the clock.
    expect(find.text('Tue 8 Jul'), findsOneWidget);
    expect(find.text('Mon 7 Jul'), findsOneWidget);

    await t.tap(find.text('Usage'));
    await t.pump();

    // Usage metric swaps in ' kWh' trailing text, and the CHART follows the
    // chip too (not just the card's trailing text).
    expect(find.textContaining(' kWh'), findsWidgets);
    expect(_charts(prices: false), findsWidgets);
    expect(_charts(prices: true), findsNothing);
  });

  testWidgets('landscape: shows column headers, no chips, paired cards per row',
      (t) async {
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(1600, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final state = CsvState()..setCsvForTest('export.csv', csvFor2Days);
    await t.pumpWidget(_host(const HistoryTab(weeks: false), state));
    await t.pump();

    expect(t.takeException(), isNull);
    expect(find.text('USAGE (kWh)'), findsOneWidget);
    expect(find.text('COST (\$)'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    // Two days in the fixture -> two rows, each a Usage/Cost pair of cards.
    expect(find.byType(ChartCard), findsNWidgets(4));
    expect(find.text('Tue 8 Jul'), findsNWidgets(2));
    expect(find.text('Mon 7 Jul'), findsNWidgets(2));
  });

  testWidgets('weeks: "Week to" card renders under allowPartial with a two-day fixture',
      (t) async {
    final originalSize = t.view.physicalSize;
    final originalRatio = t.view.devicePixelRatio;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.physicalSize = originalSize;
      t.view.devicePixelRatio = originalRatio;
    });

    final state = CsvState()..setCsvForTest('export.csv', csvFor2Days);
    await t.pumpWidget(_host(const HistoryTab(weeks: true), state));
    await t.pump();

    expect(t.takeException(), isNull);
    // Only 2 days of data can't fill a real 7-day window; without
    // allowPartial the chart would render "Not enough data" instead.
    expect(find.text('Week to Tue 8 Jul'), findsOneWidget);
    expect(find.textContaining('Not enough data'), findsNothing);
    expect(_charts(allowPartial: true), findsWidgets);
  });
}
