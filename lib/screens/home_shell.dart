import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/csv_state.dart';
import '../state/formats.dart';
import 'data_tab.dart';
import 'history_tab.dart';
import 'onboarding.dart';
import 'settings_screen.dart';
import 'package:momentum_energy/theme.dart';

/// Root screen: an app bar (app name + the loaded file's date range + import
/// and Settings actions) over a three-tab body (Data / Days / Weeks) driven by
/// a [NavigationBar].
///
/// With nothing loaded — a first launch, "Remove my data", or a first import
/// that failed to parse — the body is [Onboarding], the how-to-get-your-CSV
/// guide, instead of the tabs. The bundled sample only loads when the user
/// asks for it there, and while it is on screen a mint strip above every tab
/// says so and leads back to the guide.
///
/// When an import fails but a good file is still loaded
/// ([CsvState.importError]), the tabs keep drawing that file and the failure
/// is reported once, here, in a dismissible [MaterialBanner].
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const Color _background = MomentumPalette.indigo;
  static const Color _surface = MomentumPalette.surface;
  static const Color _muted = MomentumPalette.muted;

  int _tab = 0;

  /// The [CsvState.importError] the user has already dismissed. The banner
  /// reappears as soon as the message *changes* (a new failure), but a
  /// dismissed message stays hidden while the same error keeps being re-set
  /// (e.g. retrying the same broken file).
  String? _dismissedError;

  /// `Mon 7 Jul – Tue 8 Jul` for the file currently on screen (prefixed
  /// `Sample ·` for the bundled sample); empty until a parse has actually
  /// produced dates (the shell renders during `loading` too). Keyed on the
  /// rows, so a failed import keeps describing the file the tabs are still
  /// drawing rather than blanking out.
  String _contextLine(CsvState state) {
    final first = state.firstDate;
    final last = state.lastDate;
    if (state.rows.isEmpty || first == null || last == null) {
      return '';
    }
    final range = '${dayFormat.format(first)} – ${dayFormat.format(last)}';
    return state.isSample ? 'Sample · $range' : range;
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

  /// Shell-level surface for an import failure that left the previous file
  /// loaded: the banner sits directly on top of the tabs, which keep drawing
  /// that file. It is the ONLY report of the failure — the tab bodies key off
  /// `rows.isEmpty`, so none of them shows an error body — and being on the
  /// shell it outlives tab switches.
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

  /// Shown above every tab while the bundled sample is on screen, so nobody
  /// mistakes someone else's 2022 usage for their own. Tapping anywhere on it
  /// opens the guide.
  Widget _sampleStrip(BuildContext context) {
    return Material(
      color: MomentumPalette.mint,
      child: InkWell(
        onTap: () => openDataGuide(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _background, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "You're looking at sample data, not yours",
                  style: TextStyle(
                    color: _background,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: _background),
                onPressed: () => openDataGuide(context),
                child: const Text(
                  'Use my data',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: _background,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CsvState>();

    // Nothing to chart yet. While a load is in flight that is a spinner;
    // otherwise (first launch, removed data, or a first import that failed)
    // the tab bar would be inert over three empty bodies, so the guide takes
    // the whole body instead.
    final bool noData = state.rows.isEmpty;
    final bool onboarding = noData && state.status != CsvStatus.loading;

    // A bad import over a good file: the tabs stay mounted and keep drawing
    // the surviving file, with a dismissible report of the failure above.
    final String? error = state.importError;
    final bool showError =
        error != null && state.rows.isNotEmpty && error != _dismissedError;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        title: _title(state),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: _muted),
            tooltip: 'Import usage CSV',
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
          if (state.isSample && !noData) _sampleStrip(context),
          Expanded(
            child: onboarding
                ? const Onboarding()
                : noData
                    ? const Center(child: CircularProgressIndicator())
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
      bottomNavigationBar: noData
          ? null
          : NavigationBar(
              backgroundColor: _surface,
              surfaceTintColor: Colors.transparent,
              // Indicator/icon/label colours come from navigationBarTheme so
              // the mint selection stays defined in one place.
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
