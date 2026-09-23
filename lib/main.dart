import 'dart:async' show unawaited;

import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momentum_energy/screens/home_shell.dart';
import 'package:momentum_energy/screenshots_mobile.dart'
    if (dart.library.io) 'package:momentum_energy/screenshots_mobile.dart'
    if (dart.library.js) 'package:momentum_energy/screenshots_other.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:momentum_energy/tariffs.dart';
import 'package:momentum_energy/theme.dart';
import 'package:provider/provider.dart';

/// The app's only theme — the light theme and the runtime toggle
/// (`MyThemeModel`) were removed in the UI overhaul; every screen is painted
/// against [MomentumPalette] — Momentum Energy's own indigo and mint, so the
/// app looks like it belongs to the account the export came from.
///
/// Material's dark defaults are what leaked the stock lilac into chips,
/// buttons and the navigation bar, so the accent roles are pinned to the mint
/// here rather than tinted from a seed. Public (not `_darkTheme`) only so
/// `test/home_shell_test.dart` can pump the shell under the real theme.
final ThemeData darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: MomentumPalette.indigo,
  primaryColor: MomentumPalette.mint,
  colorScheme: const ColorScheme.dark(
    primary: MomentumPalette.mint,
    onPrimary: MomentumPalette.indigo,
    secondary: MomentumPalette.mint,
    onSecondary: MomentumPalette.indigo,
    surface: MomentumPalette.indigo,
    onSurface: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: MomentumPalette.mutedBright, fontSize: 13),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: MomentumPalette.surface,
    indicatorColor: MomentumPalette.mint,
    iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? MomentumPalette.indigo
            : MomentumPalette.muted)),
    labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.bold
            : FontWeight.normal,
        color: states.contains(WidgetState.selected)
            ? Colors.white
            : MomentumPalette.muted)),
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: MomentumPalette.surface,
    selectedColor: MomentumPalette.mint,
    labelStyle: TextStyle(color: Colors.white),
    secondaryLabelStyle: TextStyle(color: MomentumPalette.indigo),
    checkmarkColor: MomentumPalette.indigo,
    side: BorderSide.none,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: MomentumPalette.mint,
      foregroundColor: MomentumPalette.indigo,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: MomentumPalette.mint),
  ),
  // The textTheme above replaces dark()'s wholesale, so a dialog's title
  // inherits no colour and draws near-black on the indigo surface.
  dialogTheme: const DialogThemeData(
    backgroundColor: MomentumPalette.surface,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    contentTextStyle: TextStyle(color: MomentumPalette.mutedBright, fontSize: 14),
  ),
);

/// Hydrates the mutable `tariffs` singleton from SharedPreferences before the
/// app starts rendering. Fire-and-forget: charts draw off the compile-time
/// defaults on the very first frame and pick up any saved rates once this
/// resolves (mirrors the old `HomePageState._loadTariffs`, which this
/// rewrite otherwise deleted along with the rest of HomePage — without this,
/// a user's saved rates would silently never be re-applied on relaunch).
/// Exposed (not inlined into `main()`) so it's directly testable without
/// booting the whole app.
Future<void> loadSavedTariffs() => tariffs.load();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(loadSavedTariffs());
  runApp(
    DevicePreview(
      enabled: !kReleaseMode && kIsWeb,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => CsvState()..restore(),
        child: const MyApp(),
      ), // Wrap your app
      tools: !kReleaseMode && kIsWeb
          ? [...DevicePreview.defaultTools, simpleScreenShotModesPlugin]
          : [],
    ),
  );
}

/// Thin root: the UI overhaul deleted the old single-screen HomePage
/// (dropdown + MyCard grid + footer) and the light/dark theme toggle, leaving
/// the tabbed [HomeShell] as the only screen this file knows about.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momentum Energy Dashboard',
      debugShowCheckedModeBanner: false,
      // For DevicePreview
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: darkTheme,
      home: const HomeShell(),
    );
  }
}
