#!/usr/bin/env bash
# Build an unsigned iOS IPA locally. No Apple Developer account is required;
# the result cannot be installed on a stock device until it is signed.
#
# Usage:
#   ./scripts/build-ios.sh
#   IOS_SIGNED=1 ./scripts/build-ios.sh   # needs Xcode signing configured
set -euo pipefail

cd "$(dirname "$0")/.."

flutter pub get

if [ "${IOS_SIGNED:-0}" = "1" ]; then
  flutter build ipa --release
  echo "Signed IPA: mobile/build/ios/ipa/"
  ls -1 build/ios/ipa/*.ipa
  exit 0
fi

flutter build ios --release --no-codesign

app="build/ios/iphoneos/Runner.app"
out="build/ios/ipa/caldav-free-ios-unsigned.ipa"
rm -rf build/ios/ipa/Payload
mkdir -p build/ios/ipa/Payload
cp -R "$app" build/ios/ipa/Payload/
(cd build/ios/ipa && zip -qry "$(basename "$out")" Payload)

echo "Unsigned IPA: mobile/$out"
echo "Sign it in Xcode (Runner target -> Signing & Capabilities) before"
echo "installing on a physical device; the simulator build needs no signing."
