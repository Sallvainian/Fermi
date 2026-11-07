#!/usr/bin/env bash
# Health check for a deployed site: proves the build that was just pushed is the
# one being served, and that the pieces a browser needs are really there.
#
# Usage: scripts/check-site.sh <base-url> <expected-build-id>
#   ATTEMPTS     tries before giving up (default 6)
#   RETRY_DELAY  seconds between tries (default 10)
# Exit 0 the site passed, 1 it did not within the attempts, 2 bad usage.
#
# Each attempt fails unless:
#   - the base URL answers 200 text/html and its fermi-build meta tag equals the
#     expected id (the meta is written by app/vite.config.ts, so this needs no
#     JavaScript and cannot be satisfied by a stale deploy);
#   - the first /assets/*.js file the page references answers 200 with a
#     JavaScript content type (a missing file would be answered by the SPA
#     fallback with HTML);
#   - that JavaScript file contains the expected id (a dropped __BUILD_ID__
#     define would leave a blank page while the meta still matches);
#   - a deep path answers 200 text/html (the SPA fallback works);
#   - /updates/latest.json (written by scripts/write-latest-json.sh, read by
#     scripts/deploy-gate.sh) answers 200 application/json, is a JSON object,
#     and its version equals the expected id.
# Later stories add their assertions to check_once.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <base-url> <expected-build-id>" >&2
  exit 2
fi

base="${1%/}/"
expected="$2"
attempts="${ATTEMPTS:-6}"
delay="${RETRY_DELAY:-10}"

served="(none)"
reason=""

# GET a URL into $body_file and set $status and $ctype.
fetch() {
  local out
  out="$(curl -sS -L --max-time 30 -o "$body_file" -w '%{http_code} %{content_type}' "$1")" || {
    status="000"
    ctype=""
    return 0
  }
  status="${out%% *}"
  ctype="${out#* }"
}

check_once() {
  served="(none)"

  fetch "$base"
  if [ "$status" != "200" ]; then
    reason="$base returned HTTP $status (expected 200)"
    return 1
  fi
  case "$ctype" in
    text/html*) ;;
    *)
      reason="$base served as '$ctype' (expected text/html)"
      return 1
      ;;
  esac

  served="$(sed -n 's/.*<meta name="fermi-build" content="\([^"]*\)".*/\1/p' "$body_file" | head -n 1)"
  [ -n "$served" ] || served="(no fermi-build meta)"
  if [ "$served" != "$expected" ]; then
    reason="the site serves build $served, not the expected $expected"
    return 1
  fi

  local js
  js="$(grep -o '/assets/[^"]*\.js' "$body_file" | head -n 1 || true)"
  if [ -z "$js" ]; then
    reason="the page references no /assets/*.js file"
    return 1
  fi
  fetch "${base%/}${js}"
  if [ "$status" != "200" ]; then
    reason="${base%/}${js} returned HTTP $status (expected 200)"
    return 1
  fi
  case "$ctype" in
    *javascript*) ;;
    *)
      reason="${base%/}${js} served as '$ctype' (expected JavaScript); the file is missing and the SPA fallback answered"
      return 1
      ;;
  esac
  if ! grep -qF "$expected" "$body_file"; then
    reason="${base%/}${js} does not contain the expected build id $expected"
    served="$served in the HTML, missing from the JavaScript"
    return 1
  fi

  fetch "${base}check-site/deep/path"
  if [ "$status" != "200" ]; then
    reason="deep path returned HTTP $status (expected 200)"
    return 1
  fi
  case "$ctype" in
    text/html*) ;;
    *)
      reason="deep path served as '$ctype' (expected text/html)"
      return 1
      ;;
  esac

  # The version file deploy-gate.sh reads (story 16's update check will too).
  local manifest_url="${base}updates/latest.json"
  fetch "$manifest_url"
  if [ "$status" != "200" ]; then
    reason="$manifest_url returned HTTP $status (expected 200)"
    return 1
  fi
  case "$ctype" in
    application/json*) ;;
    *)
      reason="$manifest_url served as '$ctype' (expected application/json); the file is missing and the SPA fallback answered"
      return 1
      ;;
  esac
  if ! jq -e 'type == "object"' "$body_file" >/dev/null 2>&1; then
    reason="$manifest_url is not a JSON object"
    return 1
  fi
  local live_version
  live_version="$(jq -r '.version | strings' "$body_file")"
  if [ "$live_version" != "$expected" ]; then
    reason="latest.json version is '$live_version', not the expected $expected"
    return 1
  fi

  return 0
}

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT

for ((i = 1; i <= attempts; i++)); do
  echo "Attempt $i/$attempts: $base"
  if check_once; then
    echo "OK: $base serves build $expected"
    exit 0
  fi
  echo "  failed: $reason"
  if [ "$i" -lt "$attempts" ]; then
    echo "  retrying in ${delay}s"
    sleep "$delay"
  fi
done

echo "Health check failed after $attempts attempts: expected build $expected, served $served" >&2
echo "Last failure: $reason" >&2
exit 1
