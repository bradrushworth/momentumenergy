import 'dart:convert' show utf8;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:momentum_energy/bar_chart.dart' show DataAggregator;
import 'package:shared_preferences/shared_preferences.dart';

/// `empty` means nothing is loaded and nothing failed: a first launch, or
/// the user removed their data. The shell answers it with the welcome guide.
enum CsvStatus { loading, empty, ready, error }

/// Where the rows on screen came from. The bundled sample is real data from
/// someone else's 2022 meter, so every screen that shows it must say so.
enum CsvSource { none, sample, user }

/// The decoder for a Momentum usage export: comma-separated with numbers
/// parsed, so the kWh column arrives as `num` (fields carry a leading space,
/// which `int`/`double.tryParse` ignore). The delimiter is pinned rather than
/// auto-detected so a stray error-message line cannot change it, and csv 8
/// accepts both CRLF and LF line endings on its own.
final Csv usageCsv = Csv(autoDetect: false, dynamicTyping: true);

/// Parses the imported/bundled CSV export exactly once and holds the result
/// for every screen to share, replacing the old parse-per-widget pattern.
///
/// Launch calls [restore]: the user's last import comes back from
/// SharedPreferences if there is one, otherwise the state is `empty` and the
/// shell shows the welcome guide. The sample loads only when asked for
/// ([loadSample]) and is flagged by [isSample] so the UI can label it.
///
/// Two distinct failure surfaces, and the difference matters:
///
/// * [status] `error` (+ [errorMessage]) means there is NOTHING to draw —
///   [rows] is empty, so a load failed before any good file existed. The
///   shell answers this with the welcome guide, which shows the message.
/// * [importError] means a *later* import failed while a good file is still
///   loaded. [rows], [numMeters], [firstDate], [lastDate], [fileName] and
///   [source] are deliberately left untouched — they describe the file still
///   on screen — and [status] stays `ready` so every tab keeps rendering it.
///   The shell answers this with a dismissible banner.
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
  CsvSource source = CsvSource.none;
  List<List<dynamic>> rows = [];
  int numMeters = 1;
  DateTime? firstDate;
  DateTime? lastDate;

  /// False when the user's file parsed but could not be saved on the device
  /// (browser storage full, say): it is on screen now, but will not be there
  /// after a relaunch, and the Data tab says so.
  bool savedOnDevice = true;

  // Bumped when tariffs are saved so grid keys derived from it invalidate.
  int tariffsRevision = 0;

  /// The bundled sample export. A test can point this at a missing key to
  /// exercise [loadSample]'s failure path.
  @visibleForTesting
  static String sampleAssetKey = 'assets/Your_Usage_List.csv';

  /// SharedPreferences keys for the user's last successful import. The raw
  /// CSV text is kept (not the parsed rows) so a restore goes through the
  /// same parse path as the original import.
  @visibleForTesting
  static const String savedCsvKey = 'userCsv';
  @visibleForTesting
  static const String savedNameKey = 'userCsvName';

  static const String _formatMessage =
      'Unrecognized file format — export the usage table from Momentum MyAccount and try again.';

  bool get isSample => source == CsvSource.sample;

  bool get hasUserData => source == CsvSource.user;

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

  /// Launch: reload the user's last import, or settle on `empty` so the shell
  /// shows the welcome guide. A saved file that no longer parses is dropped
  /// rather than leaving the user stuck on an error they cannot fix.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(savedCsvKey);
      if (saved != null && saved.isNotEmpty) {
        final name = prefs.getString(savedNameKey) ?? 'Your usage file';
        if (_parse(name, saved, CsvSource.user)) {
          notifyListeners();
          return;
        }
        await _forget(prefs);
      }
    } catch (e) {
      // Storage unavailable: fall through to the welcome guide.
    }
    _clear(CsvStatus.empty);
    notifyListeners();
  }

  /// Loads the bundled sample. A missing/unreadable asset must not strand the
  /// app in `loading` forever, so the whole body is guarded.
  Future<void> loadSample() async {
    if (rows.isEmpty) {
      status = CsvStatus.loading;
      notifyListeners();
    }
    try {
      final data = await rootBundle.loadString(sampleAssetKey);
      _parse('Sample export', data, CsvSource.sample);
    } catch (e) {
      _fail();
    }
    notifyListeners();
  }

  /// Picks, parses and saves a file; true when a new file is now on screen.
  ///
  /// Cancelling the picker changes nothing: whatever was on screen (the
  /// user's own data, the sample, or the welcome guide) stays. `pickFile`
  /// itself can throw (no platform channel, a permission refusal, an
  /// unreadable file), so it is guarded the same way as [loadSample].
  Future<bool> importFile() async {
    final PlatformFile? file;
    final Uint8List bytes;
    try {
      file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return false;
      bytes = await file.readAsBytes();
    } catch (e) {
      _fail();
      notifyListeners();
      return false;
    }
    // Momentum exports are UTF-8; fromCharCodes treated the bytes as UTF-16.
    return importCsv(file.name, utf8.decode(bytes, allowMalformed: true));
  }

  /// Parses [csv] as the user's own export and, when it parses, saves it on
  /// the device so the next launch opens straight onto it.
  Future<bool> importCsv(String name, String csv) async {
    if (!_parse(name, csv, CsvSource.user)) {
      notifyListeners();
      return false;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      savedOnDevice = await prefs.setString(savedCsvKey, csv) &&
          await prefs.setString(savedNameKey, name);
    } catch (e) {
      savedOnDevice = false;
    }
    if (!savedOnDevice) notifyListeners();
    return true;
  }

  /// Deletes the saved import from the device and returns to the welcome
  /// guide (a shared tablet, or a user who no longer wants it kept).
  Future<void> removeUserData() async {
    try {
      await _forget(await SharedPreferences.getInstance());
    } catch (e) {
      // Nothing saved, or storage unavailable: the on-screen state still goes.
    }
    _clear(CsvStatus.empty);
    notifyListeners();
  }

  @visibleForTesting
  void setCsvForTest(String name, String csv, {CsvSource source = CsvSource.user}) {
    _parse(name, csv, source);
    notifyListeners();
  }

  Future<void> _forget(SharedPreferences prefs) async {
    await prefs.remove(savedCsvKey);
    await prefs.remove(savedNameKey);
  }

  void _clear(CsvStatus to) {
    rows = [];
    numMeters = 1;
    firstDate = null;
    lastDate = null;
    fileName = null;
    source = CsvSource.none;
    savedOnDevice = true;
    status = to;
    errorMessage = null;
    importError = null;
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

  /// True when [csv] parsed and is now on screen. Does not notify; callers
  /// do, once their own follow-up (saving, say) has settled the state.
  bool _parse(String name, String csv, CsvSource from) {
    try {
      final List<List<dynamic>> data = usageCsv.decode(csv);
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
      source = from;
      savedOnDevice = true;
      status = CsvStatus.ready;
      errorMessage = null;
      importError = null;
      return true;
    } catch (e) {
      _fail();
      return false;
    }
  }

  /// Routes a parse/load failure to the right surface: a banner over the file
  /// still on screen, or the fatal empty state. Callers must call
  /// `notifyListeners` themselves.
  void _fail() {
    if (rows.isNotEmpty) {
      // A good file is still loaded: keep every field describing it and just
      // report that THIS import failed.
      importError = _formatMessage;
      status = CsvStatus.ready;
      errorMessage = null;
    } else {
      _clear(CsvStatus.error);
      errorMessage = _formatMessage;
    }
  }
}
