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
///
/// Two distinct failure surfaces, and the difference matters:
///
/// * [status] `error` (+ [errorMessage]) means there is NOTHING to draw —
///   [rows] is empty, so the very first load failed (an unreadable bundled
///   asset, or a bad import before any good file existed). The shell answers
///   this with onboarding.
/// * [importError] means a *later* import failed while a good file is still
///   loaded. [rows], [numMeters], [firstDate], [lastDate] and [fileName] are
///   deliberately left untouched — they describe the file still on screen —
///   and [status] stays `ready` so every tab keeps rendering it. The shell
///   answers this with a dismissible banner.
///
/// Any successful parse clears both.
class CsvState extends ChangeNotifier {
  CsvStatus status = CsvStatus.loading;

  /// Fatal message: set only when nothing can be rendered (see class docs).
  String? errorMessage;

  /// Non-fatal message: a failed import that left the previous file on
  /// screen. Never set while [rows] is empty.
  String? importError;

  String? fileName;
  List<List<dynamic>> rows = [];
  int numMeters = 1;
  DateTime? firstDate;
  DateTime? lastDate;

  // Bumped when tariffs are saved so grid keys derived from it invalidate.
  int tariffsRevision = 0;

  /// The bundled demo export. A test can point this at a missing key to
  /// exercise [loadDefaultAsset]'s failure path.
  @visibleForTesting
  static String defaultAssetKey = 'assets/Your_Usage_List.csv';

  static const String _formatMessage =
      'Unrecognized file format — export the usage table from Momentum MyAccount and try again.';

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

  /// Loads the bundled sample. A missing/unreadable asset must not strand the
  /// app in `loading` forever, so the whole body is guarded.
  Future<void> loadDefaultAsset() async {
    try {
      final data = await rootBundle.loadString(defaultAssetKey);
      _parse('Bundled sample', data);
    } catch (e) {
      _fail();
      notifyListeners();
    }
  }

  /// Picks and parses a file. `pickFiles` itself can throw (no platform
  /// channel, a permission refusal, an unreadable file), so it is guarded the
  /// same way as [loadDefaultAsset].
  Future<void> importFile() async {
    try {
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
    } catch (e) {
      _fail();
      notifyListeners();
    }
  }

  @visibleForTesting
  void setCsvForTest(String name, String csv) {
    _parse(name, csv);
  }

  /// Cheap shape check for one data row. Momentum's export occasionally
  /// carries a stray error-message line mid-file; such a row has no numeric
  /// kWh value and/or no `DD/MM/YY HH:MM` timestamp, and reaching
  /// `DataAggregator.dateParse` with it used to blow up at build time with a
  /// `RangeError`. 14 is the exact length `dateParse` indexes into.
  static bool _isUsableRow(List<dynamic> row) =>
      row.length >= 2 &&
      row[1] is num &&
      row[0] is String &&
      (row[0] as String).trim().length >= 14;

  void _parse(String name, String csv) {
    try {
      final List<List<dynamic>> data = const CsvToListConverter(
              csvSettingsDetector: FirstOccurrenceSettingsDetector(eols: ['\r\n', '\n']))
          .convert(csv, shouldParseNumbers: true);
      if (data.isEmpty) {
        throw const FormatException('Empty export.');
      }
      data.removeAt(0); // Strip the header row.
      data.retainWhere(_isUsableRow);
      if (data.length < 2) {
        // Nothing survived the shape check, so this was never a usage export
        // (or it is damaged beyond a chart's usefulness).
        throw const FormatException('No usable interval rows.');
      }

      final DateTime first =
          DateTime.parse(DataAggregator.dateParse(data.first[0]).substring(0, 8));
      final DateTime last =
          DateTime.parse(DataAggregator.dateParse(data.last[0]).substring(0, 8));

      rows = data;
      numMeters = DataAggregator.detectNumMeters(data);
      firstDate = first;
      lastDate = last;
      fileName = name;
      status = CsvStatus.ready;
      errorMessage = null;
      importError = null;
    } catch (e) {
      _fail();
    }
    notifyListeners();
  }

  /// Routes a parse/load failure to the right surface: a banner over the file
  /// still on screen, or the fatal empty state. Callers outside [_parse] must
  /// call `notifyListeners` themselves.
  void _fail() {
    if (rows.isNotEmpty) {
      // A good file is still loaded: keep every field describing it and just
      // report that THIS import failed.
      importError = _formatMessage;
      status = CsvStatus.ready;
      errorMessage = null;
    } else {
      rows = [];
      status = CsvStatus.error;
      errorMessage = _formatMessage;
      importError = null;
    }
  }
}
