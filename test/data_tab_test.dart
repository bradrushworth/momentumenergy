import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/screens/data_tab.dart';
import 'package:momentum_energy/state/csv_state.dart';
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
    expect(find.textContaining('2 days'), findsOneWidget);
    expect(find.textContaining('1 meter'), findsOneWidget);
    expect(find.text('Import new export'), findsOneWidget);
    expect(find.text('TOTAL COST'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('\$')),
      findsWidgets,
    );
  });

  testWidgets('error state shows the error message', (tester) async {
    final state = CsvState()..setCsvForTest('bad.csv', 'Sorry, an error occurred');

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(state.errorMessage!), findsOneWidget);
  });
}
