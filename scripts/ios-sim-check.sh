#!/usr/bin/env bash
# Proves the iOS shell builds and runs in the Simulator, and that what a person
# sees on screen is this commit's web build. Needs only Xcode, Node and git; it
# does no signing, provisioning or archiving.
#
# Usage: scripts/ios-sim-check.sh
#   GITHUB_SHA         build id to build and look for (default: git rev-parse HEAD)
#   SIM_DEVICE         Simulator UDID or exact name (default: first available iPhone,
#                      skipping the dual-display "iPhone Duo", which simctl cannot
#                      screenshot without a --display choice)
#   ATTEMPTS           screenshots to try before giving up (default 10)
#   RETRY_DELAY        seconds between screenshots (default 2)
#   CHECK_SCREENSHOT   path to a PNG: skip the build and the Simulator, recognise
#                      that file once and match it against the id
#
# Steps: build app/ with the id, `cap sync ios`, xcodebuild for the Simulator,
# install and launch com.academic-tools.fermi, then screenshot the screen and
# recognise its text (scripts/ocr-text.swift) until the id appears. Whitespace is
# ignored in the comparison because a 40-character id may wrap. The Simulator is
# left booted. Build output and the screenshot go to app/ios/DerivedData (ignored).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$root/app"
derived="$app_dir/ios/DerivedData"
bundle_id="com.academic-tools.fermi"
attempts="${ATTEMPTS:-10}"
delay="${RETRY_DELAY:-2}"

expected="${GITHUB_SHA:-$(git -C "$root" rev-parse HEAD 2>/dev/null || true)}"
[ -n "$expected" ] || { echo "no build id: GITHUB_SHA is unset and git rev-parse HEAD failed" >&2; exit 1; }
if [ -z "${GITHUB_SHA:-}" ] && [ -z "${CHECK_SCREENSHOT:-}" ] && [ -n "$(git -C "$root" status --porcelain -- app 2>/dev/null || true)" ]; then
  echo "warning: app/ has uncommitted changes; the build is labelled $expected but is not exactly that commit" >&2
fi

mkdir -p "$derived"
ocr_bin="$derived/ocr-text"
text=""

# Compile the OCR helper once into DerivedData.
build_ocr() {
  if [ ! -x "$ocr_bin" ] || [ "$root/scripts/ocr-text.swift" -nt "$ocr_bin" ]; then
    echo "Compiling scripts/ocr-text.swift"
    swiftc -O "$root/scripts/ocr-text.swift" -o "$ocr_bin"
  fi
}

# Recognise $1 into $text and succeed when it contains the id.
screen_has_id() {
  text="$("$ocr_bin" "$1")" || return 1
  [[ "$(printf '%s' "$text" | tr -d '[:space:]')" == *"$expected"* ]]
}

fail_mismatch() {
  echo "FAIL: screen does not show build id $expected" >&2
  echo "Expected: $expected" >&2
  echo "Recognised text:" >&2
  printf '%s\n' "$text" >&2
  exit 1
}

if [ -n "${CHECK_SCREENSHOT:-}" ]; then
  [ -f "$CHECK_SCREENSHOT" ] || { echo "CHECK_SCREENSHOT not found: $CHECK_SCREENSHOT" >&2; exit 1; }
  build_ocr
  if screen_has_id "$CHECK_SCREENSHOT"; then
    echo "OK: $CHECK_SCREENSHOT shows build $expected"
    exit 0
  fi
  fail_mismatch
fi

echo "Building web app for $expected"
(cd "$app_dir" && GITHUB_SHA="$expected" npm run build && npx cap sync ios)

# Pick the device: SIM_DEVICE by UDID or exact name, else the first available iPhone.
devices="$(xcrun simctl list devices available)"
udid=""
if [ -n "${SIM_DEVICE:-}" ]; then
  # Match the name literally: names contain parentheses and dots.
  udid="$(printf '%s\n' "$devices" | grep -F "    $SIM_DEVICE (" | sed -nE 's/.*\(([0-9A-F-]{36})\) .*/\1/p' | head -n 1 || true)"
  if [ -z "$udid" ] && printf '%s\n' "$devices" | grep -qF "($SIM_DEVICE)"; then
    udid="$SIM_DEVICE"
  fi
  [ -n "$udid" ] || { echo "no available simulator matches SIM_DEVICE=$SIM_DEVICE" >&2; exit 1; }
else
  udid="$(printf '%s\n' "$devices" | grep -v 'iPhone Duo' | sed -nE 's/^ *iPhone.* \(([0-9A-F-]{36})\) .*/\1/p' | head -n 1)"
  [ -n "$udid" ] || { echo "no available iPhone simulator; install an iOS runtime with an iPhone in Xcode" >&2; exit 1; }
fi
echo "Simulator: $udid"

xcodebuild -project "$app_dir/ios/App/App.xcodeproj" -scheme App -configuration Debug \
  -destination "id=$udid" -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO build

app_path="$derived/Build/Products/Debug-iphonesimulator/App.app"
[ -d "$app_path" ] || { echo "built app not found at $app_path" >&2; exit 1; }
plist="$app_path/Info.plist"
built_id="$(plutil -extract CFBundleIdentifier raw "$plist")"
built_version="$(plutil -extract CFBundleShortVersionString raw "$plist")"
built_build="$(plutil -extract CFBundleVersion raw "$plist")"
echo "Bundle id: $built_id"
echo "Version:   $built_version"
echo "Build:     $built_build"
if [ "$built_id" != "$bundle_id" ]; then
  echo "FAIL: built bundle id is $built_id, expected $bundle_id" >&2
  exit 1
fi
min_build="$(tr -d '[:space:]' < "$app_dir/MIN_NATIVE_BUILD")"
for n in "$min_build" "$built_build"; do
  case "$n" in
    '' | *[!0-9]*) echo "FAIL: build number '$built_build' or app/MIN_NATIVE_BUILD '$min_build' is not an integer" >&2; exit 1 ;;
  esac
done
if [ "$built_build" -lt "$min_build" ]; then
  echo "FAIL: build number $built_build is below app/MIN_NATIVE_BUILD $min_build" >&2
  exit 1
fi

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" "$app_path"
xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
xcrun simctl launch "$udid" "$bundle_id"

build_ocr
shot="$derived/sim-check-$expected.png"
for ((i = 1; i <= attempts; i++)); do
  echo "Attempt $i/$attempts: screenshot $shot"
  rm -f "$shot"
  xcrun simctl io "$udid" screenshot "$shot" >/dev/null || true
  if [ -f "$shot" ] && screen_has_id "$shot"; then
    echo "OK: the Simulator shows build $expected"
    echo "Screenshot: $shot"
    exit 0
  fi
  if [ "$i" -lt "$attempts" ]; then
    sleep "$delay"
  fi
done

fail_mismatch
