// Shared row fixtures for widget-layer tests (bar_chart, day_math, screens).
//
// Rows mirror the shape CsvState produces: `List<List<dynamic>>` with the
// CSV header already stripped, `[date, kwh, quality]` per row, dates as
// `DD/MM/YY HH:MM` strings (DataAggregator.dateParse's expected format).

/// 48 half-hour rows per day, single meter, kwh 0.5, covering 07/07/25 and
/// 08/07/25 (07/07/25 was a Monday, matching the real export era).
final List<List<dynamic>> rowsFor2Days = _buildRowsFor2Days();

List<List<dynamic>> _buildRowsFor2Days() {
  final rows = <List<dynamic>>[];
  for (final day in ['07', '08']) {
    for (int i = 0; i < 48; i++) {
      final h = i ~/ 2;
      final m = (i % 2) * 30;
      rows.add([
        '$day/07/25 ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
        0.5,
        'Actual',
      ]);
    }
  }
  return rows;
}
