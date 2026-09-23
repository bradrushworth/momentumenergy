import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/screens/data_tab.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:momentum_energy/widgets/chart_card.dart';
import 'package:provider/provider.dart';

import 'test_data.dart';

Widget _host(CsvState state) {
  return ChangeNotifierProvider<CsvState>.value(
    value: state,
    child: const MaterialApp(
      home: Scaffold(body: DataTab()),
    ),
  );
}

void main() {
  testWidgets('ready state shows the file-summary hero', (tester) async {
    final state = CsvState()..setCsvForTest('export.csv', csvFor2Days);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('YOUR DATA'), findsOneWidget);
    expect(find.textContaining('2 days'), findsOneWidget);
    expect(find.textContaining('1 meter'), findsOneWidget);
    expect(find.text('Import a newer CSV'), findsOneWidget);
    expect(find.text('How do I get my CSV?'), findsOneWidget);
    expect(find.text('TOTAL COST'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('\$')),
      findsWidgets,
    );
    expect(find.textContaining("couldn't be saved"), findsNothing);
  });

  testWidgets('the sample is labelled SAMPLE DATA and asks for the user\'s own', (tester) async {
    final state = CsvState()
      ..setCsvForTest('Sample export', csvFor2Days, source: CsvSource.sample);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(find.text('SAMPLE DATA'), findsOneWidget);
    expect(find.text('YOUR DATA'), findsNothing);
    expect(find.text('Import my CSV'), findsOneWidget);
  });

  testWidgets('a file that could not be saved says it will not be there next time',
      (tester) async {
    final state = CsvState()..setCsvForTest('export.csv', csvFor2Days);
    state.savedOnDevice = false;

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't be saved on this device"), findsOneWidget);
  });

  testWidgets('How do I get my CSV? opens the guide', (tester) async {
    final state = CsvState()..setCsvForTest('export.csv', csvFor2Days);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('How do I get my CSV?'));
    await tester.tap(find.text('How do I get my CSV?'));
    await tester.pumpAndSettle();

    expect(find.text('Get your data'), findsOneWidget);
    expect(find.text('Open My Usage in Momentum MyAccount'), findsOneWidget);
  });

  testWidgets('error state with no rows shows the error message', (tester) async {
    final state = CsvState()..setCsvForTest('bad.csv', 'Sorry, an error occurred');

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(state.errorMessage!), findsOneWidget);
  });

  testWidgets('a failed import keeps the previous file drawn, with no error body',
      (tester) async {
    final state = CsvState()..setCsvForTest('export.csv', csvFor2Days);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    state.setCsvForTest('junk.csv', 'Sorry, an error occurred');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Still the good file's hero, and no error body anywhere in the tab (the
    // shell's banner is the only report).
    expect(find.textContaining('2 days'), findsOneWidget);
    expect(find.text('export.csv · 1 meter · 2 days'), findsOneWidget);
    expect(find.text(state.importError!), findsNothing);
  });

  testWidgets('a csv with a junk row mid-file still renders', (tester) async {
    final withJunk = csvFor2Days.replaceFirst(
        '07/07/25 12:00, 0.5, Actual', 'Sorry, an error occurred');
    final state = CsvState()..setCsvForTest('export.csv', withJunk);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    // Before the shape check this threw a RangeError out of dateParse while
    // the chart was building.
    expect(tester.takeException(), isNull);
    expect(state.status, CsvStatus.ready);
    expect(find.textContaining('2 days'), findsOneWidget);
    expect(find.text('TOTAL COST'), findsOneWidget);
  });

  testWidgets('a one-day export renders a single day card', (tester) async {
    const oneDay = 'Date and Time, kWh, Quality\n'
        '07/07/25 00:05, 0.1, Actual\n'
        '07/07/25 00:10, 0.1, Actual\n';
    final state = CsvState()..setCsvForTest('export.csv', oneDay);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.dayCount, 1);
    // Only day e=0: there is no day before the file starts to chart.
    expect(find.byType(ChartCard), findsOneWidget);
    expect(find.text('Mon 7 Jul'), findsOneWidget);
    expect(find.text('Sun 6 Jul'), findsNothing);
  });
}
