#!/bin/sh
# Runs the native sidebar UI tour against a local Home Assistant and exports its screenshots and screen
# recording. Credentials come from a key=value file (url, username, password) that never enters the repo.
set -e
cd "$(dirname "$0")/../.."
CREDS="${1:?credentials file}"
OUT="${2:?output directory}"
UDID="${SIM_UDID:?simulator UDID}"
DD="${DD:-$HOME/dev/ha-ios-dd}"
export TEST_RUNNER_E2E_HOME_ASSISTANT_URL="$(sed -n 's/^url=//p' "$CREDS")"
export TEST_RUNNER_E2E_HOME_ASSISTANT_USERNAME="$(sed -n 's/^username=//p' "$CREDS")"
export TEST_RUNNER_E2E_HOME_ASSISTANT_PASSWORD="$(sed -n 's/^password=//p' "$CREDS")"
rm -rf "$OUT" && mkdir -p "$OUT"
RBENV_VERSION="${RBENV_VERSION:-2.7.5}" xcodebuild test -project HomeAssistant.xcodeproj -scheme Tests-UI \
  -only-testing:Tests-UI/NativeSidebarTourTests -destination "id=$UDID" -derivedDataPath "$DD" \
  -resultBundlePath "$OUT/tour.xcresult" 2>&1 | grep -E "error:|Test Case .*(passed|failed)|\*\* TEST" || true
xcrun xcresulttool export attachments --path "$OUT/tour.xcresult" --output-path "$OUT/attachments" >/dev/null
python3 - "$OUT" <<'PY'
import json, os, shutil, sys
out = sys.argv[1]
att = os.path.join(out, "attachments")
for test in json.load(open(os.path.join(att, "manifest.json"))):
    for a in test["attachments"]:
        name = a.get("suggestedHumanReadableName", "")
        src = os.path.join(att, a["exportedFileName"])
        if name.endswith((".png", ".jpeg", ".mp4", ".ips")) or "." not in name:
            ext = os.path.splitext(a["exportedFileName"])[1]
            base = name.split("_")[0].replace(" ", "-")
            shutil.copy(src, os.path.join(out, base if base.endswith(ext) else base + ext))
PY
ls "$OUT"
