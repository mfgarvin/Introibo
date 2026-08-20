#!/usr/bin/env bash
#
# Build the iOS release IPA with a version Apple will accept.
#
# CFBundleShortVersionString must be purely numeric — one to three
# dot-separated integers — so the pubspec's prerelease suffix ("1.0.0-beta.7")
# is stripped here and the beta identity is carried by the build number, which
# is all TestFlight requires to increase. Same build-number rule as Android:
# the git commit count, floored by the `+N` committed in pubspec.yaml, so a
# rewritten history can never lower it.
#
#   tool/ios_build.sh              build the IPA
#   tool/ios_build.sh --dry-run    print the version it would use and stop
#
# macOS + Xcode only. Upload the result with Transporter.app, or via
# Xcode → Organizer. See docs/ios-testflight.md.
set -euo pipefail

cd "$(dirname "$0")/.."

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

if [ "$(uname -s)" != "Darwin" ] && [ "$DRY_RUN" -eq 0 ]; then
  echo "error: iOS builds need macOS + Xcode (use --dry-run to check the version)" >&2
  exit 1
fi

version_line=$(grep -E '^version:' pubspec.yaml | head -1)
current=$(echo "${version_line#version:}" | tr -d '[:space:]')

if [[ ! "$current" =~ ^([0-9]+\.[0-9]+\.[0-9]+)(-[0-9A-Za-z.-]+)?(\+([0-9]+))?$ ]]; then
  echo "error: cannot parse version '$current' in pubspec.yaml" >&2
  exit 1
fi
build_name="${BASH_REMATCH[1]}"
floor="${BASH_REMATCH[4]:-1}"

commit_count=$(git rev-list --count HEAD)
build_number=$(( commit_count > floor ? commit_count : floor ))

echo "pubspec version : $current"
echo "CFBundleShortVersionString: $build_name   (numeric; the pubspec's prerelease suffix is dropped)"
echo "CFBundleVersion : $build_number"

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "would run: flutter build ipa --release --build-name=$build_name --build-number=$build_number"
  exit 0
fi

echo
flutter build ipa --release \
  --build-name="$build_name" \
  --build-number="$build_number"

# Refuse to hand Transporter anything that isn't AOT-compiled. A debug build
# mocks the device location (see kDevLocation), so shipping one to testers
# silently pins everybody to Lakewood — the failure this check exists for.
ipa=$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1)
if [ -z "$ipa" ]; then
  echo "error: no IPA produced in build/ios/ipa/" >&2
  exit 1
fi

if unzip -l "$ipa" | grep -q "kernel_blob.bin"; then
  echo "error: $ipa contains kernel_blob.bin — that is a DEBUG build." >&2
  echo "       Do not upload it: debug builds mock the device location." >&2
  exit 1
fi

echo
echo "Release build confirmed (no debug kernel snapshot): $ipa"
echo
echo "Next: upload it with Transporter.app,"
echo "      then enable it for internal testing in App Store Connect."
