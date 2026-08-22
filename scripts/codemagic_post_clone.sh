#!/bin/bash
# Codemagic "Post-clone script" for the momentumenergy Flutter app.
# The dashboard's Post-clone field should contain exactly:
#   ./scripts/codemagic_post_clone.sh
# so this file is the single source of truth for the post-clone phase.
set -e

cd "$FCI_BUILD_DIR"

# ---------------------------------------------------------------------------
# Build gate: only spend a full build when the app version changed since the
# last SUCCESSFUL build. This covers both desired cases:
#   - a version bump in pubspec.yaml triggers a build;
#   - after a failed build, the last-successful commit still predates the
#     bump, so retry pushes keep building until one succeeds.
# Doc/code pushes after a green release build are canceled early.
#
# Requires a CODEMAGIC_API_TOKEN (secret) env var on the app so the build can
# cancel itself; without it (or on the first build) the gate is skipped and
# everything builds as before.
# ---------------------------------------------------------------------------
PREV_COMMIT="${CM_PREVIOUS_COMMIT:-$FCI_PREVIOUS_COMMIT}"
BUILD_ID="${CM_BUILD_ID:-$FCI_BUILD_ID}"
if [ -n "$PREV_COMMIT" ] && [ -n "$CODEMAGIC_API_TOKEN" ] \
    && git cat-file -e "$PREV_COMMIT" 2>/dev/null; then
  if git diff "$PREV_COMMIT"..HEAD -- pubspec.yaml | grep -q '^+version:'; then
    echo "==> App version changed since last successful build; building"
  else
    echo "==> No version change since last successful build ($PREV_COMMIT); canceling build"
    curl -s -X POST -H "x-auth-token: $CODEMAGIC_API_TOKEN" \
      "https://api.codemagic.io/builds/$BUILD_ID/cancel" || true
    # Give the cancellation time to take effect; if it does not, fail fast
    # rather than burning a full build.
    sleep 90
    echo "==> Cancel request did not take effect; exiting"
    exit 1
  fi
else
  echo "==> Build gate inactive (first build, or CODEMAGIC_API_TOKEN not set); building"
fi

echo "==> flutter pub get (regenerates ios/Flutter/Generated.xcconfig etc.)"
flutter pub get

# Fixes the iOS CocoaPods build failure:
#   "The sandbox is not in sync with the Podfile.lock. Run 'pod install'..."
# Cause: ios/Podfile.lock is NOT committed (only pubspec.lock is). After a
# dependency bump that shifts the native pod graph, the Codemagic macOS
# worker's cached Pods/ can be out of sync with the freshly resolved
# Podfile.lock, so the [CP] Check Pods Manifest.lock phase fails.
if [ -d ios ]; then
  echo "==> Cleaning stale CocoaPods sandbox for iOS"
  rm -rf ios/Pods ios/Podfile.lock
  echo "==> pod install (no repo update - keeps the build fast)"
  (cd ios && pod install)
else
  echo "==> No ios/ directory; skipping CocoaPods step"
fi

echo "==> Post-clone script complete"
