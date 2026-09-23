import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/screens/onboarding.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(CsvState state, {bool offerSample = true}) {
  return ChangeNotifierProvider<CsvState>.value(
    value: state,
    child: MaterialApp(
      home: Scaffold(body: Onboarding(offerSample: offerSample)),
    ),
  );
}

/// The guide is taller than the default 800x600 surface.
void _tall(WidgetTester tester) {
  final originalSize = tester.view.physicalSize;
  final originalRatio = tester.view.devicePixelRatio;
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.physicalSize = originalSize;
    tester.view.devicePixelRatio = originalRatio;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('the MyAccount link goes straight to My Usage, not the home page', () {
    // The overhaul pointed this at the site root on the belief that
    // /myaccount/my-usage was dead; it is live (signed-out visitors are sent
    // through the login and returned there), and the root makes users hunt.
    expect(momentumMyUsageUri.toString(),
        'https://www.momentumenergy.com.au/myaccount/my-usage');
  });

  testWidgets('walks through the three steps with the link and Import', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(CsvState()..status = CsvStatus.empty));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('See your own electricity use'), findsOneWidget);
    expect(find.textContaining('stays on this device'), findsOneWidget);
    expect(find.text('Open My Usage in Momentum MyAccount'), findsOneWidget);
    expect(find.textContaining('Export table'), findsOneWidget);
    expect(find.text('Import the file here'), findsOneWidget);

    expect(find.widgetWithText(OutlinedButton, 'Open Momentum MyAccount'), findsOneWidget);
    expect(find.text('momentumenergy.com.au/myaccount/my-usage'), findsOneWidget);

    final importButton = find.widgetWithText(FilledButton, 'Import my CSV');
    expect(importButton, findsOneWidget);
    expect(tester.widget<FilledButton>(importButton).onPressed, isNotNull);
  });

  testWidgets('offers the sample, which then loads labelled as the sample', (tester) async {
    _tall(tester);
    final state = CsvState()..status = CsvStatus.empty;
    await tester.pumpWidget(_host(state));

    await tester.tap(find.text('Just looking? Try it with sample data'));
    // runAsync: decoding a large asset hops to another isolate, which the
    // fake-async test zone would otherwise never let finish.
    await tester.runAsync(() async {
      for (var i = 0; i < 250 && state.status == CsvStatus.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    expect(state.status, CsvStatus.ready);
    expect(state.isSample, isTrue);
  });

  testWidgets('no sample offer where data is already on screen', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_host(CsvState(), offerSample: false));
    await tester.pumpAndSettle();

    expect(find.text('Just looking? Try it with sample data'), findsNothing);
    expect(find.text('Import my CSV'), findsOneWidget);
  });

  testWidgets('a first file that failed to parse leads with why', (tester) async {
    _tall(tester);
    final state = CsvState()..setCsvForTest('junk.csv', 'Sorry, an error occurred');
    expect(state.status, CsvStatus.error);

    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(find.text(state.errorMessage!), findsOneWidget);
    expect(find.text('Open My Usage in Momentum MyAccount'), findsOneWidget);
  });
}
