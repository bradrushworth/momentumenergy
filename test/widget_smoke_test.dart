import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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

/// The rod width the chart actually drew in a card [width] wide.
Future<double> _drawnRodWidth(WidgetTester tester, double width) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: 300,
          child: BarChartWidget1(rowsFor2Days, 1, 'Mon 7 Jul', const Duration(days: 1)),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  final chart = tester.widget<BarChart>(find.byType(BarChart));
  return chart.data.barGroups.first.barRods.first.width;
}

void main() {
  group('bar widths track the card', () {
    test('about 70% of each slot, clamped', () {
      // 48 half-hour bars; 40px of the width is the y-axis labels.
      expect(barWidthFor(40 + 48 * 10, 48), closeTo(7, 1e-9)); // Amber's look
      expect(barWidthFor(40 + 48 * 20, 48), closeTo(14, 1e-9));
      expect(barWidthFor(40 + 48 * 4, 48), closeTo(2.8, 1e-9));
      expect(barWidthFor(100, 48), 1.5);
      expect(barWidthFor(10000, 48), 24);
      expect(barWidthFor(double.infinity, 48), 6);
      expect(barWidthFor(500, 0), 6);
    });

    testWidgets('a wide card draws wider bars than a phone card, never touching',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final phone = await _drawnRodWidth(tester, 340);
      final landscape = await _drawnRodWidth(tester, 1100);

      expect(landscape, greaterThan(phone * 3));
      // Each rod stays inside its slot (the chart is 8px narrower than the
      // card, and the axis takes 40px), so neighbours never run together.
      expect(phone, lessThan((340 - 8 - 40) / 48));
      expect(landscape, lessThan((1100 - 8 - 40) / 48));
    });
  });

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
      expect(find.text('Supply charge'), findsOneWidget);
    });

    testWidgets('does not render Supply label when showSupply is false', (tester) async {
      await tester.pumpWidget(_host(
        LegendBar(showSupply: false),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Supply charge'), findsNothing);
    });
  });
}
