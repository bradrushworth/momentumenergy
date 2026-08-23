import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/screens/onboarding.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:provider/provider.dart';

Widget _host(CsvState state) {
  return ChangeNotifierProvider<CsvState>.value(
    value: state,
    child: const MaterialApp(
      home: Scaffold(body: Onboarding()),
    ),
  );
}

void main() {
  testWidgets('renders the three steps and an enabled Import button', (tester) async {
    final state = CsvState();

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Log in to Momentum MyAccount'), findsOneWidget);
    expect(find.textContaining('Export your usage table'), findsOneWidget);
    expect(find.textContaining('Tap Import and pick the file'), findsOneWidget);

    final importButton = find.widgetWithText(FilledButton, 'Import');
    expect(importButton, findsOneWidget);
    expect(tester.widget<FilledButton>(importButton).onPressed, isNotNull);
  });
}
