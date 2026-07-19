#!/bin/bash
# Codemagic "Post-clone script" for the momentumenergy Flutter app.
#
# Fixes the iOS CocoaPods build failure:
#   "The sandbox is not in sync with the Podfile.lock. Run 'pod install'..."
#
# Cause: ios/Podfile.lock is NOT committed (only pubspec.lock is). After a
# dependency bump that shifts the native pod graph, the Codemagic macOS
# worker's cached Pods/ can be out of sync with the freshly resolved
# Podfile.lock, so the [CP] Check Pods Manifest.lock phase fails.
#
# This script forces a clean regeneration of the Pods sandbox right after
# clone, before the Xcode build runs. It is safe to run on Android/web-only
# workers (it only acts when ios/ exists).
set -e

cd "$FCI_BUILD_DIR"

echo "==> flutter pub get (regenerates ios/Flutter/Generated.xcconfig etc.)"
flutter pub get

if [ -d ios ]; then
  echo "==> Cleaning stale CocoaPods sandbox for iOS"
  rm -rf ios/Pods ios/Podfile.lock
  echo "==> pod install (no repo update - keeps the build fast)"
  (cd ios && pod install)
else
  echo "==> No ios/ directory; skipping CocoaPods step"
fi

echo "==> Post-clone iOS pod sync complete"
