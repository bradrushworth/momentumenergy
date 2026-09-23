import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/csv_state.dart';
import '../state/formats.dart';
import '../tariffs.dart';
import '../utils.dart';
import '../version.dart';
import 'onboarding.dart' show openDataGuide;
import 'package:momentum_energy/theme.dart';

const _kBg = MomentumPalette.indigo;
const _kAppBarBg = MomentumPalette.surface;
const _kFieldBg = MomentumPalette.surface;
const _kMuted = MomentumPalette.muted;

const _kSectionLabelStyle = TextStyle(
  color: _kMuted,
  fontWeight: FontWeight.bold,
  fontSize: 12,
  letterSpacing: 1.2,
);

/// Settings: the loaded file (import, how-to guide, remove), tariff rate
/// entry, and About links.
///
/// The five rate fields mirror `Tariffs` (lib/tariffs.dart): `daily` is
/// $/day, the rest are $/kWh. Save parses all five as doubles first — any
/// single invalid field shows an inline error under itself and NOTHING is
/// saved (all-or-nothing), matching the old tariff dialog's behaviour before
/// it was deleted with legacy main.dart.
///
/// The About section's four links are copied verbatim (scheme/host/path/
/// query and the kIsWeb && kReleaseMode switch) from the deleted footer at
/// lib/main.dart:430-509 (commit b1c6a38), followed by a non-tappable
/// Version tile reading `lib/version.dart` (kept in sync with pubspec).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _dailyController;
  late final TextEditingController _controlledController;
  late final TextEditingController _offPeakController;
  late final TextEditingController _shoulderController;
  late final TextEditingController _peakController;

  String? _dailyError;
  String? _controlledError;
  String? _offPeakError;
  String? _shoulderError;
  String? _peakError;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dailyController = TextEditingController(text: tariffs.daily.toString());
    _controlledController = TextEditingController(text: tariffs.controlled.toString());
    _offPeakController = TextEditingController(text: tariffs.offPeak.toString());
    _shoulderController = TextEditingController(text: tariffs.shoulder.toString());
    _peakController = TextEditingController(text: tariffs.peak.toString());
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _controlledController.dispose();
    _offPeakController.dispose();
    _shoulderController.dispose();
    _peakController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Guard re-entry: a double-tap would otherwise fire two overlapping
    // saves.
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final daily = double.tryParse(_dailyController.text.trim());
      final controlled = double.tryParse(_controlledController.text.trim());
      final offPeak = double.tryParse(_offPeakController.text.trim());
      final shoulder = double.tryParse(_shoulderController.text.trim());
      final peak = double.tryParse(_peakController.text.trim());

      setState(() {
        _dailyError = daily == null ? 'Enter a number' : null;
        _controlledError = controlled == null ? 'Enter a number' : null;
        _offPeakError = offPeak == null ? 'Enter a number' : null;
        _shoulderError = shoulder == null ? 'Enter a number' : null;
        _peakError = peak == null ? 'Enter a number' : null;
      });

      // All-or-nothing: one bad field and nothing is saved.
      if (daily == null ||
          controlled == null ||
          offPeak == null ||
          shoulder == null ||
          peak == null) {
        return;
      }

      tariffs.daily = daily;
      tariffs.controlled = controlled;
      tariffs.offPeak = offPeak;
      tariffs.shoulder = shoulder;
      tariffs.peak = peak;
      await tariffs.save();
      if (!mounted) return;
      context.read<CsvState>().bump();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Rates saved')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Deleting the saved import sends the user back to the welcome guide, so
  /// it asks first; Settings then closes to show that guide.
  Future<void> _confirmRemove() async {
    final bool? remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove your usage data?'),
        content: const Text(
            'This deletes the imported file from this device. You can import '
            'it again at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    await context.read<CsvState>().removeUserData();
    if (mounted) Navigator.of(context).maybePop();
  }

  List<Widget> _dataSection(CsvState state) {
    final first = state.firstDate;
    final last = state.lastDate;
    final String title = state.hasUserData
        ? (state.fileName ?? 'Your usage file')
        : state.isSample
            ? 'Sample data (not yours)'
            : 'No usage file loaded';
    final String? range = first != null && last != null && state.rows.isNotEmpty
        ? '${dayYearFormat.format(first)} – ${dayYearFormat.format(last)}'
        : null;
    final String? saved = !state.hasUserData
        ? null
        : state.savedOnDevice
            ? 'Saved on this device'
            : 'Not saved on this device — import it again next time';

    return [
      const Text('YOUR DATA', style: _kSectionLabelStyle),
      ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: range == null && saved == null
            ? null
            : Text([?range, ?saved].join('\n'),
                style: const TextStyle(color: _kMuted)),
      ),
      ListTile(
        leading: const Icon(Icons.upload_file, color: _kMuted),
        title: Text(state.hasUserData ? 'Import a newer CSV' : 'Import my CSV',
            style: const TextStyle(color: Colors.white)),
        onTap: state.importFile,
      ),
      ListTile(
        leading: const Icon(Icons.help_outline, color: _kMuted),
        title: const Text('How to get your CSV', style: TextStyle(color: Colors.white)),
        onTap: () => openDataGuide(context),
      ),
      if (state.hasUserData)
        ListTile(
          leading: const Icon(Icons.delete_outline, color: _kMuted),
          title: const Text('Remove my data from this device',
              style: TextStyle(color: Colors.white)),
          onTap: _confirmRemove,
        ),
      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CsvState>();
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kAppBarBg,
        title: const Text('Settings'),
      ),
      // SafeArea keeps the last About tile above the Android gesture bar —
      // the same regression the old footer's fix (40e6724) addressed.
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._dataSection(state),
            const Text('TARIFF RATES', style: _kSectionLabelStyle),
            const SizedBox(height: 8),
            _rateField(
              key: const Key('tariff_daily'),
              label: 'Daily supply \$/day',
              controller: _dailyController,
              errorText: _dailyError,
            ),
            _rateField(
              key: const Key('tariff_controlled'),
              label: 'Controlled \$/kWh',
              controller: _controlledController,
              errorText: _controlledError,
            ),
            _rateField(
              key: const Key('tariff_offpeak'),
              label: 'Off-peak \$/kWh',
              controller: _offPeakController,
              errorText: _offPeakError,
            ),
            _rateField(
              key: const Key('tariff_shoulder'),
              label: 'Shoulder \$/kWh',
              controller: _shoulderController,
              errorText: _shoulderError,
            ),
            _rateField(
              key: const Key('tariff_peak'),
              label: 'Peak \$/kWh',
              controller: _peakController,
              errorText: _peakError,
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
            const SizedBox(height: 24),
            const Text('ABOUT', style: _kSectionLabelStyle),
            ListTile(
              title: const Text('Source Code', style: TextStyle(color: Colors.white)),
              onTap: () {
                Utils.launchURI(Uri(
                  scheme: 'https',
                  host: 'github.com',
                  path: '/bradrushworth/momentumenergy',
                ));
              },
            ),
            ListTile(
              title: const Text('Chart Library', style: TextStyle(color: Colors.white)),
              onTap: () {
                Utils.launchURI(Uri(
                  scheme: 'https',
                  host: 'pub.dev',
                  path: '/packages/fl_chart',
                ));
              },
            ),
            ListTile(
              title: Text(kIsWeb && kReleaseMode ? 'Buy Coffee' : 'Visit BitBot',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                if (kIsWeb && kReleaseMode) {
                  Utils.launchURI(Uri(
                    scheme: 'https',
                    host: 'www.buymeacoffee.com',
                    path: '/bitbot',
                  ));
                } else {
                  Utils.launchURI(Uri(
                    scheme: 'https',
                    host: 'www.bitbot.com.au',
                    path: '/',
                  ));
                }
              },
            ),
            ListTile(
              title: const Text('Report Issue', style: TextStyle(color: Colors.white)),
              onTap: () {
                Utils.launchURI(Uri(
                  scheme: 'mailto',
                  path: 'bitbot@bitbot.com.au',
                  query: 'subject=Help with Momentum Energy Dashboard',
                ));
              },
            ),
            // Not tappable: the last line of About is a fact, not a link.
            const ListTile(
              title: Text('Version', style: TextStyle(color: Colors.white)),
              subtitle: Text(appVersion, style: TextStyle(color: _kMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateField({
    required Key key,
    required String label,
    required TextEditingController controller,
    required String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _kMuted),
          errorText: errorText,
          filled: true,
          fillColor: _kFieldBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
