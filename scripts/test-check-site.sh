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

# The page names a script file that does not exist.
cp -R "$work/good" "$work/missing-js"
perl -pi -e "s{\Q$js_ref\E}{/assets/missing-$build_id.js}g" "$work/missing-js/index.html"

# The script file no longer carries the id; the meta tag still does.
cp -R "$work/good" "$work/no-id-in-js"
perl -pi -e "s{\Q$build_id\E}{not-the-build-id}g" "$work/no-id-in-js${js_ref}"

serve() {
  npx vite preview --outDir "$1" --port "$port" --strictPort >"$work/preview.log" 2>&1 &
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

if [ "$failures" -ne 0 ]; then
  echo "$failures health check case(s) did not behave as expected."
  exit 1
fi
echo "All 4 health check cases behaved as expected."
