import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momentum_energy/version.dart';

void main() {
  test('About shows the version pubspec.yaml builds', () {
    // 1.5.2+27 shipped with About still reading 1.5.1+26: the release bumped
    // pubspec.yaml and not lib/version.dart.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1);

    expect(appVersion, version);
  });
}
