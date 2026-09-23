import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/csv_state.dart';
import '../utils.dart';
import 'package:momentum_energy/theme.dart';

const _kMuted = MomentumPalette.muted;

/// Momentum's My Usage page, where the "Export table" button lives. A
/// signed-out visitor is sent through the MyAccount login and returned here
/// afterwards (checked 2026-09-23: this path answers 302 to the SSO login
/// with `RelayState=/myaccount/my-usage`, where an unknown path 404s), so it
/// is the right link whether or not the user is logged in.
final Uri momentumMyUsageUri =
    Uri.https('www.momentumenergy.com.au', '/myaccount/my-usage');

/// Opens the guide as its own screen (from the sample-data strip, the Data
/// tab and Settings). It closes itself once an import succeeds, so the user
/// lands back on their charts.
Future<void> openDataGuide(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const GetYourDataScreen()),
  );
}

/// How to get a usage CSV out of Momentum MyAccount and into the app.
///
/// The shell shows it in place of the tabs whenever nothing is loaded: on a
/// first launch, after "Remove my data", and when the only file so far
/// failed to parse (it then leads with that error). It is also the body of
/// [GetYourDataScreen]. The pre-overhaul app said the same thing in one
/// always-visible header line — "Click 'Export table' from MyAccount, then
/// Select File" — and users lost the thread when the overhaul hid it.
class Onboarding extends StatelessWidget {
  /// Offer the bundled sample as a way to look around first. Off where the
  /// sample (or the user's own data) is already on screen.
  final bool offerSample;

  /// Called after an import put a new file on screen.
  final VoidCallback? onImported;

  const Onboarding({super.key, this.offerSample = true, this.onImported});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CsvState>();
    final String? error = state.importError ??
        (state.status == CsvStatus.error ? state.errorMessage : null);

    return SafeArea(
      top: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'See your own electricity use',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This app charts the usage file you download from Momentum '
                  'Energy MyAccount. It isn\'t made by Momentum, and your '
                  'file stays on this device.',
                  style: TextStyle(color: _kMuted, height: 1.4),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorNote(error),
                ],
                const SizedBox(height: 24),
                _Step(
                  number: 1,
                  title: 'Open My Usage in Momentum MyAccount',
                  detail: 'Log in if it asks you to.',
                  action: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Utils.launchURI(momentumMyUsageUri),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open Momentum MyAccount'),
                      ),
                      // Spelled out too, for when the tap cannot open a
                      // browser (or the user is on another device).
                      const SelectableText(
                        'momentumenergy.com.au/myaccount/my-usage',
                        style: TextStyle(color: _kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const _Step(
                  number: 2,
                  title: 'Choose a time period, then tap "Export table"',
                  detail: 'A few weeks works best. Long periods often download '
                      'as an empty file with only an error message in it.',
                ),
                _Step(
                  number: 3,
                  title: 'Import the file here',
                  detail: 'It is named like Your_Usage_List_….csv. On a phone, '
                      'look in Downloads.',
                  action: FilledButton.icon(
                    onPressed: () async {
                      final imported = await context.read<CsvState>().importFile();
                      if (imported) onImported?.call();
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import my CSV'),
                  ),
                ),
                if (offerSample) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => context.read<CsvState>().loadSample(),
                      child: const Text('Just looking? Try it with sample data'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [Onboarding] as a pushed screen, for users who are already looking at
/// the sample or their own data.
class GetYourDataScreen extends StatelessWidget {
  const GetYourDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomentumPalette.indigo,
      appBar: AppBar(
        backgroundColor: MomentumPalette.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Get your data'),
      ),
      body: Onboarding(
        offerSample: false,
        onImported: () {
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String detail;
  final Widget? action;

  const _Step({
    required this.number,
    required this.title,
    required this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: MomentumPalette.mint,
            child: Text(
              '$number',
              style: const TextStyle(
                color: MomentumPalette.indigo,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: _kMuted, height: 1.4)),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  final String message;

  const _ErrorNote(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MomentumPalette.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
