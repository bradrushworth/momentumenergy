import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/state/csv_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const twoMeter = 'Date and Time, kWh, Quality\n'
      '13/12/22 00:05, 0.1, Actual\n13/12/22 00:05, 0.2, Actual\n'
      '13/12/22 00:10, 0.1, Actual\n13/12/22 00:10, 0.2, Actual\n';
  const oneMeter = 'Date and Time, kWh, Quality\n'
      '07/07/25 00:05, 0.1, Actual\n07/07/25 00:10, 0.1, Actual\n'
      '08/07/25 00:05, 0.2, Actual\n';

  test('detects two meters and date range', () {
    final s = CsvState();
    s.setCsvForTest('export.csv', twoMeter);
    expect(s.status, CsvStatus.ready);
    expect(s.numMeters, 2);
    expect(s.firstDate!.day, 13);
    expect(s.dayCount, 1);
  });

  test('detects single meter and multi-day range', () {
    final s = CsvState();
    s.setCsvForTest('export.csv', oneMeter);
    expect(s.numMeters, 1);
    expect(s.dayCount, 2);
    expect(s.lastDate!.day, 8);
  });

  test('the bundled export parses whole: every row, both meters, its dates', () async {
    // Guards the csv decoder config (csv 8 replaced CsvToListConverter): the
    // real export has a space after each comma and CRLF line endings, and
    // every kWh field must still arrive as a num or the shape check drops it.
    final text = await File('assets/Your_Usage_List.csv').readAsString();
    final dataLines =
        text.split(RegExp(r'\r?\n')).skip(1).where((l) => l.trim().isNotEmpty).length;

    final s = CsvState();
    s.setCsvForTest('Your_Usage_List.csv', text);

    expect(s.status, CsvStatus.ready);
    expect(s.rows.length, dataLines);
    expect(s.rows.every((r) => r[1] is num), isTrue);
    expect(s.numMeters, 2);
    expect(s.firstDate, DateTime(2022, 12, 13));
    expect(s.lastDate, DateTime(2023, 1, 2));
  });

  test('malformed csv becomes an error status, not a crash', () {
    final s = CsvState();
    s.setCsvForTest('bad.csv', 'Sorry, an error occurred');
    expect(s.status, CsvStatus.error);
    expect(s.errorMessage, isNotNull);
    // Nothing was ever loaded, so this is the fatal surface, not the banner.
    expect(s.importError, isNull);
    expect(s.rows, isEmpty);
  });

  test('a junk row mid-file is dropped and the rest still parses', () {
    // Momentum's export occasionally carries a stray error-message line.
    // Before the shape check it reached DataAggregator.dateParse and blew up
    // with a RangeError at build time.
    const withJunk = 'Date and Time, kWh, Quality\n'
        '07/07/25 00:05, 0.1, Actual\n'
        'Sorry, an error occurred\n'
        '07/07/25 00:10, 0.1, Actual\n'
        '08/07/25 00:05, 0.2, Actual\n';

    final s = CsvState();
    s.setCsvForTest('export.csv', withJunk);

    expect(s.status, CsvStatus.ready);
    expect(s.rows.length, 3); // the junk row is gone
    expect(s.rows.every((r) => r[1] is num), isTrue);
    expect(s.numMeters, 1);
    expect(s.dayCount, 2);
  });

  test('a file whose rows are all junk fails rather than half-parsing', () {
    final s = CsvState();
    s.setCsvForTest('bad.csv', 'Date and Time, kWh, Quality\n'
        'Sorry, an error occurred\nPlease try again later\n');
    expect(s.status, CsvStatus.error);
    expect(s.rows, isEmpty);
  });

  test('a failed import over a good file keeps the file and sets importError', () {
    final s = CsvState();
    s.setCsvForTest('good.csv', oneMeter);
    final goodRows = s.rows;

    s.setCsvForTest('junk.csv', 'Sorry, an error occurred');

    // Everything describing the file on screen is untouched...
    expect(s.rows, same(goodRows));
    expect(s.fileName, 'good.csv');
    expect(s.numMeters, 1);
    expect(s.dayCount, 2);
    // ...and the failure is reported on the non-fatal surface only.
    expect(s.status, CsvStatus.ready);
    expect(s.errorMessage, isNull);
    expect(s.importError, isNotNull);

    // A later good import clears it.
    s.setCsvForTest('good2.csv', oneMeter);
    expect(s.importError, isNull);
    expect(s.status, CsvStatus.ready);
  });

  test('loadDefaultAsset failure ends in error, not eternal loading', () async {
    final original = CsvState.defaultAssetKey;
    addTearDown(() => CsvState.defaultAssetKey = original);
    CsvState.defaultAssetKey = 'assets/does_not_exist.csv';

    final s = CsvState();
    expect(s.status, CsvStatus.loading);

    await s.loadDefaultAsset();

    expect(s.status, CsvStatus.error);
    expect(s.errorMessage, isNotNull);
    expect(s.rows, isEmpty);
  });

  test('loadDefaultAsset failure over a good file only sets importError', () async {
    final s = CsvState();
    s.setCsvForTest('good.csv', oneMeter);

    final original = CsvState.defaultAssetKey;
    addTearDown(() => CsvState.defaultAssetKey = original);
    CsvState.defaultAssetKey = 'assets/does_not_exist.csv';

    await s.loadDefaultAsset();

    expect(s.status, CsvStatus.ready);
    expect(s.rows, isNotEmpty);
    expect(s.importError, isNotNull);
  });
}
