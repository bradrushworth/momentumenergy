import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/csv_state.dart';
import '../utils.dart';
import 'package:momentum_energy/theme.dart';

const _kMuted = MomentumPalette.muted;

/// First-run helper shown by the shell only when the CSV failed to parse
/// AND no rows are loaded (Momentum always ships the bundled sample, so an
/// empty-state "no data yet" trigger never happens on its own).
///
/// Walks the user through exporting their usage table from Momentum
/// MyAccount and importing it, then hands off to [CsvState.importFile]
/// directly rather than routing through Settings.
class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  static const _stepStyle = TextStyle(color: _kMuted, height: 1.5);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Momentum Energy',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '1. Log in to Momentum MyAccount',
                textAlign: TextAlign.center,
                style: _stepStyle,
              ),
              const SizedBox(height: 8),
              const Text(
                '2. Export your usage table (CSV)',
                textAlign: TextAlign.center,
                style: _stepStyle,
              ),
              const SizedBox(height: 8),
              const Text(
                '3. Tap Import and pick the file',
                textAlign: TextAlign.center,
                style: _stepStyle,
              ),
              const SizedBox(height: 8),
              TextButton(
                // The exact MyAccount portal path is being fixed elsewhere;
                // link the host root rather than the dead /myaccount/my-usage
                // path.
                onPressed: () => Utils.launchURI(Uri(
                  scheme: 'https',
                  host: 'www.momentumenergy.com.au',
                  path: '/',
                )),
                child: const Text('www.momentumenergy.com.au'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<CsvState>().importFile(),
                child: const Text('Import'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
