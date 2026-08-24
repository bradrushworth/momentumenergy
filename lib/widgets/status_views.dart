import 'package:flutter/material.dart';

import '../state/csv_state.dart';
import 'package:momentum_energy/theme.dart';

const _kMomentumPink = Color(0xFFFF3E8D);
const _kMuted = MomentumPalette.muted;

/// Whether a CsvState-driven screen has nothing of its own to draw and must
/// fall back to [csvStatusView].
///
/// Keyed on the DATA, not on [CsvState.status]: an import that fails over a
/// good file leaves the rows (and `status == ready`) alone precisely so the
/// tabs keep drawing it, and the shell reports the failure once in a banner
/// instead of every tab repeating an error body.
bool csvNeedsStatusView(CsvState s) =>
    s.rows.isEmpty ||
    s.status == CsvStatus.loading ||
    s.status == CsvStatus.cancelled;

/// The compact status widget a CsvState-driven screen shows in place of its
/// real content when [csvNeedsStatusView] is true: a loading spinner, a
/// "cancelled" message, or an error message with a retry-import button.
///
/// Extracted from DataTab so every screen (DataTab, the History tab, …)
/// renders identical loading/cancelled/error UI instead of each keeping its
/// own copy.
///
/// The `error` branch is reachable only with empty rows — the state in which
/// there is genuinely nothing to render. Under `HomeShell` that state routes
/// to onboarding instead, so this branch serves screens hosted on their own
/// (and any future host without an onboarding fallback).
///
/// `CsvStatus.ready` shares the loading placeholder: `ready` with empty rows
/// is not a state `_parse` produces, but a defensive caller may still route
/// that frame through here rather than crashing on `windowTotals`.
Widget csvStatusView(CsvState s) {
  switch (s.status) {
    case CsvStatus.cancelled:
      return const _CompactMessage('Import cancelled — reloading sample…');
    case CsvStatus.error:
      return _ErrorBody(
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

class _CompactMessage extends StatelessWidget {
  final String text;

  const _CompactMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: _kMuted));
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onImport;

  const _ErrorBody({required this.message, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onImport,
            style: FilledButton.styleFrom(backgroundColor: _kMomentumPink),
            icon: const Icon(Icons.upload_file),
            label: const Text('Import new export'),
          ),
        ),
      ],
    );
  }
}
