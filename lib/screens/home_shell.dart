import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/csv_state.dart';
import 'data_tab.dart';
import 'history_tab.dart';
import 'onboarding.dart';
import 'settings_screen.dart';

/// Root screen: an app bar (app name + the loaded file's date range + import
/// and Settings actions) over a three-tab body (Data / Days / Weeks) driven by
/// a [NavigationBar].
///
/// When the CSV failed to parse and no rows survive, the body is [Onboarding]
/// instead of the tabs — Momentum ships a bundled sample, so that only happens
/// after a genuinely unreadable import (or an unreadable bundle).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const Color _background = Color(0xFF20202A);
  static const Color _surface = Color(0xFF1A1A26);
  static const Color _indicator = Color(0xFF2E2E3E);
  static const Color _muted = Color(0xFF9595A4);

  static final DateFormat _dayFormat = DateFormat('E d MMM');

  int _tab = 0;

  /// The [CsvState.errorMessage] the user has already dismissed. The error
  /// banner reappears as soon as the message *changes* (a new failure), but a
  /// dismissed message stays hidden while the same error keeps being re-set
  /// (e.g. retrying the same broken file).
  String? _dismissedError;

  /// `Mon 7 Jul – Tue 8 Jul` for the loaded export; empty until a parse has
  /// actually produced dates (the shell renders during `loading` too).
  String _contextLine(CsvState state) {
    final first = state.firstDate;
    final last = state.lastDate;
    if (state.status != CsvStatus.ready || first == null || last == null) {
      return '';
    }
    return '${_dayFormat.format(first)} – ${_dayFormat.format(last)}';
  }

  Widget _title(CsvState state) {
    final line = _contextLine(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Momentum',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        if (line.isNotEmpty)
          Text(
            line,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
      ],
    );
  }

  /// The only surface for an import failure that lands on top of already-good
  /// data: the tabs keep rendering the previous file, so without this the
  /// failed import would look like nothing happened at all.
  Widget _errorBanner(String message) {
    return MaterialBanner(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      dividerColor: Colors.transparent,
      leading: const Icon(Icons.error_outline, color: Colors.redAccent),
      content: Text(message, style: const TextStyle(color: Colors.white)),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissedError = message),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CsvState>();

    // A parse error that left nothing to show: the tab bar would be inert
    // over three identical error bodies, so walk the user through importing
    // a good export instead.
    final bool onboarding =
        state.status == CsvStatus.error && state.rows.isEmpty;

    // A bad import over good data keeps the tabs (they still show the last
    // good file) and reports the failure above them.
    final String? error = state.errorMessage;
    final bool showError = !onboarding &&
        state.status == CsvStatus.error &&
        error != null &&
        error != _dismissedError;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        title: _title(state),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: _muted),
            tooltip: 'Import export',
            onPressed: () => context.read<CsvState>().importFile(),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: _muted),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (showError) _errorBanner(error),
          Expanded(
            child: onboarding
                ? const Onboarding()
                : IndexedStack(
                    index: _tab,
                    children: const [
                      DataTab(),
                      HistoryTab(weeks: false),
                      HistoryTab(weeks: true),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: onboarding
          ? null
          : NavigationBar(
              backgroundColor: _surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: _indicator,
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.description), label: 'Data'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_view_day), label: 'Days'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_view_week), label: 'Weeks'),
              ],
            ),
    );
  }
}
