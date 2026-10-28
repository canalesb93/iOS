#!/bin/sh
# Builds the iOS app for the simulator without signing. Pass a derived-data path as $1 so parallel
# builds (e.g. from separate worktrees) don't trample each other.
set -e
cd "$(dirname "$0")/../.."
DD="${1:-$HOME/dev/ha-ios-dd}"
SIM="${SIM_NAME:-iPhone 17 Pro}"
# The acknowledgements script phase shells out to `ruby`; any installed Ruby handles it.
RBENV_VERSION="${RBENV_VERSION:-2.7.5}" xcodebuild -project HomeAssistant.xcodeproj -scheme App-Debug \
  -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning: .*(Redesign|Sidebar)|BUILD (SUCCEEDED|FAILED)" | grep -v "^warning: '" | head -60
