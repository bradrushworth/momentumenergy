import 'package:flutter/material.dart';

import '../state/csv_state.dart';
import 'package:momentum_energy/theme.dart';

const _kMuted = MomentumPalette.muted;

/// Whether a CsvState-driven screen has nothing of its own to draw and must
/// fall back to [csvStatusView].
///
/// Keyed on the DATA, not on [CsvState.status]: an import that fails over a
/// good file leaves the rows (and `status == ready`) alone precisely so the
/// tabs keep drawing it, and the shell reports the failure once in a banner
/// instead of every tab repeating an error body.
bool csvNeedsStatusView(CsvState s) =>
    s.rows.isEmpty || s.status == CsvStatus.loading;

/// The compact status widget a CsvState-driven screen shows in place of its
/// real content when [csvNeedsStatusView] is true: a loading spinner, or a
/// message (no file yet, or why the file failed) with an import button.
///
/// Extracted from DataTab so every screen (DataTab, the History tab, …)
/// renders identical loading/empty/error UI instead of each keeping its own
/// copy.
///
/// The `empty` and `error` branches are reachable only with empty rows — the
/// state in which there is genuinely nothing to render. Under `HomeShell`
/// that state routes to onboarding instead, so these branches serve screens
/// hosted on their own (and any future host without an onboarding fallback).
///
/// `CsvStatus.ready` shares the loading placeholder: `ready` with empty rows
/// is not a state `_parse` produces, but a defensive caller may still route
/// that frame through here rather than crashing on `windowTotals`.
Widget csvStatusView(CsvState s) {
  switch (s.status) {
    case CsvStatus.empty:
      return _MessageBody(
        message: 'No usage file loaded yet.',
        color: _kMuted,
        onImport: s.importFile,
      );
    case CsvStatus.error:
      return _MessageBody(
        message: s.errorMessage ?? 'Something went wrong.',
        onImport: s.importFile,
      );
    case CsvStatus.loading:
    case CsvStatus.ready:
      return const _StatusPlaceholder(child: CircularProgressIndicator());
  }
}

class _StatusPlaceholder extends StatelessWidget {
  final Widget child;

  const _StatusPlaceholder({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 240, child: Center(child: child));
  }
}

class _MessageBody extends StatelessWidget {
  final String message;
  final Color color;
  final VoidCallback onImport;

  const _MessageBody({
    required this.message,
    this.color = Colors.redAccent,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: TextStyle(color: color)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            // Mint, from filledButtonTheme; the hardcoded pink that was here
            // predated the brand palette.
            onPressed: onImport,
            icon: const Icon(Icons.upload_file),
            label: const Text('Import my CSV'),
          ),
        ),
      ],
    );
  }
}
