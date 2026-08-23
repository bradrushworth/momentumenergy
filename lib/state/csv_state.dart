import 'dart:convert' show utf8;

import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:momentum_energy/bar_chart.dart' show DataAggregator;

enum CsvStatus { loading, ready, cancelled, error }

/// Parses the imported/bundled CSV export exactly once and holds the result
/// for every screen to share, replacing the old parse-per-widget pattern.
class CsvState extends ChangeNotifier {
  CsvStatus status = CsvStatus.loading;
  String? errorMessage;
  String? fileName;
  List<List<dynamic>> rows = [];
  int numMeters = 1;
  DateTime? firstDate;
  DateTime? lastDate;

  // Bumped when tariffs are saved so grid keys derived from it invalidate.
  int tariffsRevision = 0;

  int get dayCount {
    final first = firstDate;
    final last = lastDate;
    if (first == null || last == null) return 0;
    return last.difference(first).inDays + 1;
  }

  void bump() {
    tariffsRevision++;
    notifyListeners();
  }

  Future<void> loadDefaultAsset() async {
    final data = await rootBundle.loadString('assets/Your_Usage_List.csv');
    _parse('Bundled sample', data);
  }

  Future<void> importFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.first.bytes != null) {
      // Momentum exports are UTF-8; fromCharCodes treated the bytes as UTF-16.
      final data = utf8.decode(result.files.first.bytes!, allowMalformed: true);
      _parse(result.files.first.name, data);
    } else {
      // User cancelled the picker.
      status = CsvStatus.cancelled;
      notifyListeners();

      // Wait then load the template again, same as the old _pickFile.
      Future.delayed(const Duration(seconds: 2), loadDefaultAsset);
    }
  }

  @visibleForTesting
  void setCsvForTest(String name, String csv) {
    _parse(name, csv);
  }

  void _parse(String name, String csv) {
    try {
      final List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(csv, shouldParseNumbers: true);
      data.removeAt(0); // Strip the header row.

      // Meters show up as consecutive rows sharing one timestamp, mirroring
      // DataAggregator.aggregateData's detection loop.
      int meters = 1;
      final firstRowDate = data.first[0];
      while (meters < data.length && data[meters][0] == firstRowDate) {
        meters++;
      }

      final DateTime first =
          DateTime.parse(DataAggregator.dateParse(data.first[0]).substring(0, 8));
      final DateTime last =
          DateTime.parse(DataAggregator.dateParse(data.last[0]).substring(0, 8));

      rows = data;
      numMeters = meters;
      firstDate = first;
      lastDate = last;
      fileName = name;
      status = CsvStatus.ready;
      errorMessage = null;
    } catch (e) {
      rows = [];
      status = CsvStatus.error;
      errorMessage =
          'Unrecognized file format — export the usage table from Momentum MyAccount and try again.';
    }
    notifyListeners();
  }
}
