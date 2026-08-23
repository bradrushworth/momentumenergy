import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momentum_energy/screenshots_mobile.dart'
    if (dart.library.io) 'package:momentum_energy/screenshots_mobile.dart'
    if (dart.library.js) 'package:momentum_energy/screenshots_other.dart';
import 'package:momentum_energy/state/csv_state.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode && kIsWeb,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => CsvState()..loadDefaultAsset(),
        child: const MyApp(),
      ), // Wrap your app
      tools: !kReleaseMode && kIsWeb
          ? [...DevicePreview.defaultTools, simpleScreenShotModesPlugin]
          : [],
    ),
  );
}

// Minimal, compiling stub: the UI overhaul deletes the old single-screen
// HomePage (dropdown + MyCard grid + footer) and the dead light/dark theme
// toggle here. HomeShell (the real tabbed shell, wired to CsvState) lands in
// a later task; until then this just proves CsvState loads and the app
// boots.
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momentum Energy Dashboard',
      debugShowCheckedModeBanner: false,
      // For DevicePreview
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData.dark().copyWith(
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
        ),
      ),
      home: const Scaffold(
        backgroundColor: Color(0xFF20202A),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
