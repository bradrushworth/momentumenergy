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

  test('malformed csv becomes an error status, not a crash', () {
    final s = CsvState();
    s.setCsvForTest('bad.csv', 'Sorry, an error occurred');
    expect(s.status, CsvStatus.error);
    expect(s.errorMessage, isNotNull);
  });
}
