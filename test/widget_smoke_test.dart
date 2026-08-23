import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/bar_chart.dart';
import 'package:momentum_energy/widgets/chart_card.dart';
import 'package:momentum_energy/widgets/legend_bar.dart';

import 'test_data.dart';

// No theme provider on purpose: the UI overhaul deletes the
// Consumer<MyThemeModel> wrapper from BarChartWidget1, so the widget must
// render standalone under a plain MaterialApp.
Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(height: 300, child: child),
    ),
  );
}

void main() {
  group('BarChartWidget1 smoke', () {
    testWidgets('renders parsed rows without the old legend texts', (tester) async {
      await tester.pumpWidget(_host(
        BarChartWidget1(rowsFor2Days, 1, 'Mon 7 Jul', const Duration(days: 1)),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // TopSectionWidget (and its per-card legend) is gone from this widget.
      expect(find.text('Off Peak'), findsNothing);
      expect(find.text('Shoulder'), findsNothing);
      expect(find.text('Peak'), findsNothing);
      expect(find.text('Control'), findsNothing);
      expect(find.text('Supply'), findsNothing);
    });

    // Regression: the history feed hands this State a brand-new
    // BarChartWidget1 (same key/position, different `prices`) when a chip is
    // toggled. `late final` input copies used to keep rendering the first
    // metric forever; `_syncFromWidget` + reparse-on-any-change fixes that.
    testWidgets('keyless metric change re-syncs and re-aggregates the reused State',
        (tester) async {
      await tester.pumpWidget(_host(
        BarChartWidget1(rowsFor2Days, 1, 'Mon 7 Jul', const Duration(days: 1),
            prices: false),
      ));
      await tester.pumpAndSettle();

      final state = tester.state<BarChartState>(find.byType(BarChartWidget1));
      expect(state.lastParsePrices, isFalse);
      expect(find.textContaining('\$'), findsNothing);

      await tester.pumpWidget(_host(
        BarChartWidget1(rowsFor2Days, 1, 'Mon 7 Jul', const Duration(days: 1),
            prices: true),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Same State object (no key change moved it in the tree).
      expect(
        tester.state<BarChartState>(find.byType(BarChartWidget1)),
        same(state),
      );
      expect(state.lastParsePrices, isTrue);
      // The y-axis label switches from 'X kWh' to '$X' once prices is true.
      expect(find.textContaining('\$'), findsWidgets);
    });

    testWidgets('empty rows render a compact "no data" message', (tester) async {
      await tester.pumpWidget(_host(
        BarChartWidget1(const [], 1, 'Mon 7 Jul', const Duration(days: 1)),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No data for Mon 7 Jul'), findsOneWidget);
    });
  });

  group('ChartCard smoke', () {
    testWidgets('renders title and trailing text', (tester) async {
      await tester.pumpWidget(_host(
        ChartCard(
          title: 'Usage (kWh)',
          trailing: '12.34 kWh',
          chart: Container(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Usage (kWh)'), findsOneWidget);
      expect(find.text('12.34 kWh'), findsOneWidget);
    });
  });

  group('LegendBar smoke', () {
    testWidgets('renders Peak label', (tester) async {
      await tester.pumpWidget(_host(
        LegendBar(showSupply: false),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Peak'), findsOneWidget);
    });

    testWidgets('renders Supply label when showSupply is true', (tester) async {
      await tester.pumpWidget(_host(
        LegendBar(showSupply: true),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Supply'), findsOneWidget);
    });

    testWidgets('does not render Supply label when showSupply is false', (tester) async {
      await tester.pumpWidget(_host(
        LegendBar(showSupply: false),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Supply'), findsNothing);
    });
  });
}
