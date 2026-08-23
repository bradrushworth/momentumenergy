import 'package:flutter/material.dart';

import '../state/csv_state.dart';

const _kMomentumPink = Color(0xFFFF3E8D);
const _kMuted = Color(0xFF9595A4);

/// The compact status widget every CsvState-driven screen shows in place of
/// its real content while the CSV isn't parsed and ready: a loading spinner,
/// a "cancelled" message, or an error message with a retry-import button.
///
/// Extracted from DataTab so every screen (DataTab, the History tab, …)
/// renders identical loading/cancelled/error UI instead of each keeping its
/// own copy.
///
/// `CsvStatus.ready` falls into the same loading placeholder as
/// `CsvStatus.loading`: callers apply the belt-and-braces "ready but rows
/// still empty" guard themselves (`CsvState._parse` never leaves `ready`
/// with empty rows, but a defensive caller may still route that
/// theoretically-empty frame through here rather than crashing on
/// `windowTotals`).
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
