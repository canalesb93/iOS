#!/bin/sh
# Builds and installs the fork on a physical device, signed with the owner's team under its own bundle prefix.
# Needs an Apple account in Xcode ▸ Settings ▸ Accounts for automatic provisioning.
# Usage: DEVICE_ID=<udid> Tools/redesign/build-device.sh [configuration]
set -e
cd "$(dirname "$0")/../.."
TEAM="${TEAM_ID:-84VG9Y72DN}"
PREFIX="${BUNDLE_PREFIX:-com.canalesb93}"
CONFIGURATION="${1:-Debug}"
DD="${DD:-$HOME/dev/ha-ios-dd-device}"
# Team and prefix go on the command line: a few targets pin the upstream team in the project file itself.
RBENV_VERSION="${RBENV_VERSION:-2.7.5}" xcodebuild -project HomeAssistant.xcodeproj -scheme App-Debug \
  -configuration "$CONFIGURATION" -destination "id=${DEVICE_ID:?device UDID}" -derivedDataPath "$DD" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" BUNDLE_ID_PREFIX="$PREFIX" build 2>&1 \
  | tee "$DD/last-build.log" | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | sort -u | head -40
grep -q "BUILD SUCCEEDED" "$DD/last-build.log" || exit 1
APP=$(find "$DD/Build/Products/$CONFIGURATION-iphoneos" -maxdepth 1 -name "*.app" | head -1)
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
