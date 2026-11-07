#!/usr/bin/env bash
# Tests scripts/check-site.sh, the deploy health check (DW-2, closed by story 3).
#
# Builds the shell with a known build id, serves it locally with
# `vite preview` (which, like Cloudflare, answers a missing file with the
# app's HTML), and runs check-site.sh against it:
#   - the build's own id                      -> must pass
#   - a stale id                              -> must fail: the meta tag differs
#   - the page's JavaScript file missing      -> must fail: answered as HTML
#   - the id missing from the JavaScript      -> must fail: the bundle lacks it
#   - no updates/ folder                      -> must fail: answered as HTML
#   - latest.json naming a stale version      -> must fail: not the expected id
#   - latest.json with a wrong checksum       -> must fail: not the zip's sha256
#   - latest.json with another min_native_build -> must fail: not MIN_NATIVE_BUILD
#   - latest.json whose url is off the site   -> must fail: not under the base URL
# The good build is packaged with scripts/package-live-update.sh first.
# Then scripts/deploy-gate.sh, deploy.yml's daily decision, against the same
# builds: `deploy=false` only when latest.json names the given commit, and
# `deploy=true` for another commit, no live update, a latest.json that is not
# valid JSON, or no server at all.
# A failing case passes only when check-site.sh fails for that case's reason,
# so a case cannot pass because the server was down.
#
# Usage, from anywhere in the repo, after `npm ci` in app/: scripts/test-check-site.sh
#   PORT  port for vite preview (default 4180)
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
port="${PORT:-4180}"
work="$(mktemp -d)"
build_id="site-check-$(date +%s)-$$"
pid=""
failures=0

cleanup() {
  if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT

cd "$root/app"

echo "Building the shell with build id $build_id"
GITHUB_SHA="$build_id" npx vite build --outDir "$work/good" --emptyOutDir --logLevel warn

js_ref="$(grep -o '/assets/[^"]*\.js' "$work/good/index.html" | head -n 1)"
if [ -z "$js_ref" ] || ! grep -qF "$build_id" "$work/good${js_ref}"; then
  echo "::error::The test build has no /assets/*.js reference carrying the build id; the cases below would prove nothing."
  exit 1
fi

# The live update, as the deploy packages it. Its urls point at this server.
GITHUB_SHA="$build_id" DIST="$work/good" UPDATE_BASE_URL="http://localhost:$port" \
  "$root/scripts/package-live-update.sh"

# The page names a script file that does not exist.
cp -R "$work/good" "$work/missing-js"
perl -pi -e "s{\Q$js_ref\E}{/assets/missing-$build_id.js}g" "$work/missing-js/index.html"

# The script file no longer carries the id; the meta tag still does.
cp -R "$work/good" "$work/no-id-in-js"
perl -pi -e "s{\Q$build_id\E}{not-the-build-id}g" "$work/no-id-in-js${js_ref}"

# The good build with no live update: the SPA fallback answers the manifest.
cp -R "$work/good" "$work/no-updates"
rm -rf "$work/no-updates/updates"

# The good build with latest.json changed by a jq filter.
tamper_manifest() {  # <dir> <jq filter>
  cp -R "$work/good" "$1"
  jq "$2" "$work/good/updates/latest.json" >"$1/updates/latest.json"
}
tamper_manifest "$work/stale-version" '.version = "stale-version"'
tamper_manifest "$work/bad-checksum" ".checksum = \"$(printf '0%.0s' $(seq 1 64))\""
tamper_manifest "$work/other-min" '.min_native_build += 1'
other_min="$(jq '.min_native_build' "$work/other-min/updates/latest.json")"
tamper_manifest "$work/foreign-url" '.url = "https://elsewhere.test/updates/bundle.zip"'

# The good build whose latest.json is not JSON.
cp -R "$work/good" "$work/bad-json"
echo 'not json{' >"$work/bad-json/updates/latest.json"

serve() {
  # vite itself, not `npx`: on Linux npx leaves a sh between it and node, so
  # $! would be npm, and killing it would leave the server holding the port.
  "$root/app/node_modules/.bin/vite" preview --outDir "$1" --port "$port" --strictPort >"$work/preview.log" 2>&1 &
  pid=$!
  for _ in $(seq 1 60); do
    if curl -sf -o /dev/null "http://localhost:$port/"; then return 0; fi
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.5
  done
  cat "$work/preview.log"
  echo "::error::vite preview did not start on port $port."
  exit 1
}

stop() {
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  pid=""
}

check() {
  ATTEMPTS=1 RETRY_DELAY=0 "$root/scripts/check-site.sh" "http://localhost:$port/" "$1" >"$work/out.log" 2>&1
}

expect_pass() {  # <case> <dir> <expected-id>
  serve "$2"
  if check "$3"; then
    echo "ok: $1 passes"
  else
    echo "::error::$1 should pass but check-site.sh failed:"
    cat "$work/out.log"
    failures=$((failures + 1))
  fi
  stop
}

expect_fail() {  # <case> <dir> <expected-id> <reason it must give>
  serve "$2"
  if check "$3"; then
    echo "::error::$1 should fail but check-site.sh passed."
    failures=$((failures + 1))
  elif grep -qF -- "$4" "$work/out.log"; then
    echo "ok: $1 fails: $4"
  else
    echo "::error::$1 failed, but not with '$4':"
    cat "$work/out.log"
    failures=$((failures + 1))
  fi
  stop
}

expect_pass 'the right build id' "$work/good" "$build_id"
expect_fail 'a stale build id' "$work/good" "stale-$build_id" "the site serves build $build_id, not the expected stale-$build_id"
expect_fail 'a missing JavaScript file' "$work/missing-js" "$build_id" "(expected JavaScript); the file is missing and the SPA fallback answered"
expect_fail 'the id missing from the JavaScript' "$work/no-id-in-js" "$build_id" "does not contain the expected build id $build_id"
expect_fail 'no live update' "$work/no-updates" "$build_id" "/updates/latest.json served as 'text/html"
expect_fail 'a stale live-update version' "$work/stale-version" "$build_id" "latest.json version is 'stale-version', not the expected $build_id"
expect_fail 'a wrong live-update checksum' "$work/bad-checksum" "$build_id" "does not match the sha256 of"
expect_fail 'another min_native_build' "$work/other-min" "$build_id" "latest.json min_native_build is '$other_min'"
expect_fail 'a live-update url off the site' "$work/foreign-url" "$build_id" "does not start with http://localhost:$port/"

# deploy-gate.sh: <case> <dir, or - for no server> <commit> <expected line>
expect_gate() {
  [ "$2" = - ] || serve "$2"
  local got
  got="$("$root/scripts/deploy-gate.sh" "http://localhost:$port/" "$3" 2>"$work/gate.log")" || got="exit $?"
  if [ "$got" = "$4" ]; then
    echo "ok: deploy gate, $1: $4"
  else
    echo "::error::deploy gate, $1: printed '$got', expected '$4':"
    cat "$work/gate.log"
    failures=$((failures + 1))
  fi
  [ "$2" = - ] || stop
}

expect_gate 'the live commit' "$work/good" "$build_id" 'deploy=false'
expect_gate 'main ahead of the live commit' "$work/good" "newer-$build_id" 'deploy=true'
expect_gate 'no live update (SPA answers)' "$work/no-updates" "$build_id" 'deploy=true'
expect_gate 'a latest.json that is not JSON' "$work/bad-json" "$build_id" 'deploy=true'
expect_gate 'no server' - "$build_id" 'deploy=true'

if [ "$failures" -ne 0 ]; then
  echo "$failures health check case(s) did not behave as expected."
  exit 1
fi
echo "All 14 health check and deploy gate cases behaved as expected."
