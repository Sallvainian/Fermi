#!/usr/bin/env bash
# Tests scripts/write-latest-json.sh, which writes dist/updates/latest.json.
#
# Runs the script against fake dist/ folders and judges each run by its exit
# code and a message substring, so a case cannot pass because the script
# crashed. The refused cases also check that nothing was written.
#
# Needs bash and jq. No network, no secret, no git repo.
# Usage, from any directory: scripts/test-write-latest-json.sh
# Exit 0  every case behaved as expected
#     1  a case did not
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/write-latest-json.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cases=0
failures=0
rc=0
out=""

# Run the script with GITHUB_SHA and DIST set as given (an empty id leaves
# GITHUB_SHA unset); sets $rc and $out (stdout and stderr).
write() {  # <dist> <id>
  rc=0
  if [ -n "$2" ]; then
    out="$(env -u GITHUB_SHA -u DIST GITHUB_SHA="$2" DIST="$1" "$script" 2>&1)" || rc=$?
  else
    out="$(env -u GITHUB_SHA -u DIST DIST="$1" "$script" 2>&1)" || rc=$?
  fi
}

# Judge the last run: exit code, then every substring must be in the output.
expect() {  # <case> <exit code> <substring>...
  local name="$1" want="$2" bad="" sub
  shift 2
  cases=$((cases + 1))
  [ "$rc" = "$want" ] || bad="exit $rc, expected $want"
  for sub in "$@"; do
    grep -qF -- "$sub" <<<"$out" || bad="${bad:+$bad; }output lacks '$sub'"
  done
  if [ -z "$bad" ]; then
    echo "ok: $name"
  else
    echo "::error::$name: $bad"
    awk '{ print "    " $0 }' <<<"$out"
    failures=$((failures + 1))
  fi
}

expect_wrote_nothing() {  # <case> <dist>
  cases=$((cases + 1))
  if [ -e "$2/updates" ]; then
    echo "::error::$1: wrote $2/updates"
    failures=$((failures + 1))
  else
    echo "ok: $1: wrote nothing"
  fi
}

# A fake build whose script holds "<id>" as a quoted literal.
fake_dist() {  # <dir> <id>
  mkdir -p "$1/assets"
  echo '<!doctype html><title>fixture</title>' >"$1/index.html"
  echo "export const id = \"$2\";" >"$1/assets/x.js"
}

fake_dist "$work/dist-good" abc123
mkdir -p "$work/dist-good/updates"
echo stale >"$work/dist-good/updates/old.txt"
write "$work/dist-good" abc123
expect 'a matching build is written' 0 'latest.json written for abc123'

cases=$((cases + 1))
bad=""
manifest="$work/dist-good/updates/latest.json"
if [ ! -f "$manifest" ]; then
  bad="latest.json is missing"
else
  [ "$(jq -cS . "$manifest")" = '{"version":"abc123"}' ] || bad="latest.json is not exactly {\"version\":\"abc123\"}"
  [ "$(ls "$work/dist-good/updates")" = latest.json ] || bad="${bad:+$bad; }updates/ holds more than latest.json"
fi
if [ -z "$bad" ]; then
  echo "ok: updates/ holds only latest.json, exactly {\"version\":\"abc123\"}"
else
  echo "::error::the written output is wrong: $bad"
  failures=$((failures + 1))
fi

fake_dist "$work/dist-id" abc123
mkdir -p "$work/dist-id/updates"
echo stale >"$work/dist-id/updates/latest.json"
write "$work/dist-id" deadbeef
expect 'a build id not in the build fails and names it' 1 'deadbeef'
expect_wrote_nothing 'a build id not in the build' "$work/dist-id"

fake_dist "$work/dist-bare" abc123
echo 'const a = "xabc123x"; onabc123;' >"$work/dist-bare/assets/x.js"
write "$work/dist-bare" abc123
expect 'a build id that is only a substring fails' 1 'abc123'
expect_wrote_nothing 'a build id that is only a substring' "$work/dist-bare"

write "$work/no-such-dist" abc123
expect 'a missing dist is bad input' 2 'holds no build'
expect_wrote_nothing 'a missing dist' "$work/no-such-dist"

fake_dist "$work/dist-env" abc123
write "$work/dist-env" ''
expect 'an unset GITHUB_SHA is bad input' 2 'GITHUB_SHA'
expect_wrote_nothing 'an unset GITHUB_SHA' "$work/dist-env"

if [ "$failures" -ne 0 ]; then
  echo "$failures of $cases write-latest-json case(s) did not behave as expected."
  exit 1
fi
echo "All $cases write-latest-json cases behaved as expected."
