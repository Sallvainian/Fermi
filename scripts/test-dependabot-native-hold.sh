#!/usr/bin/env bash
# Tests scripts/dependabot-native-hold.sh, the AD-18 native hold (story 13).
#
# Runs each case against the real .github/dependabot.yml, plus a copy with the
# native patterns removed, and checks the exit code. The non-Dependabot-author
# case lives in the workflow's `if:`, so it is checked as that guard's text.
#
# Usage, from anywhere in the repo: scripts/test-dependabot-native-hold.sh
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
hold="$root/scripts/dependabot-native-hold.sh"
config="$root/.github/dependabot.yml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Same file with the native group's patterns removed.
no_patterns="$work/no-native-patterns.yml"
yq 'del(.updates[] | select(.["package-ecosystem"] == "npm" and .directory == "/app") | .groups.native.patterns)' "$config" > "$no_patterns"

failures=0
total=0

# <label> <config> <names> <expected exit code>
check() {
  local label="$1" cfg="$2" names="$3" want="$4" got=0
  total=$((total + 1))
  "$hold" "$cfg" "$names" > /dev/null 2>&1 || got=$?
  if [ "$got" -eq "$want" ]; then
    echo "pass  $label (exit $got)"
  else
    echo "FAIL  $label: expected exit $want, got $got" >&2
    failures=$((failures + 1))
  fi
}

check "non-native npm group"          "$config"      'react,react-dom'                                        0
check "vitest group, majors"          "$config"      'vitest,@vitest/coverage-v8'                             0
check "actions group"                 "$config"      'supabase/setup-cli'                                     0
check "native group"                  "$config"      '@capacitor/core,@capacitor/ios,@capacitor/cli'          3
check "ungrouped security update"     "$config"      '@capgo/capacitor-updater'                               3
check "mixed list, spaces"            "$config"      'react, @capacitor/ios'                                  3
check "empty names"                   "$config"      ''                                                       2
check "no native patterns"            "$no_patterns" 'react'                                                  2

# The hold prints the packages it matched, and only those.
total=$((total + 1))
printed="$("$hold" "$config" 'react, @capacitor/ios,@capgo/capacitor-updater' 2> /dev/null || true)"
if [ "$printed" = $'@capacitor/ios\n@capgo/capacitor-updater' ]; then
  echo "pass  prints the matched packages"
else
  echo "FAIL  prints the matched packages: got '$printed'" >&2
  failures=$((failures + 1))
fi

# A pull request opened by anyone but Dependabot skips the job: its guard.
total=$((total + 1))
guard="$(yq '.jobs.dependabot.if' "$root/.github/workflows/dependabot-auto-merge.yml")"
if [ "$guard" = "github.event.pull_request.user.login == 'dependabot[bot]'" ]; then
  echo "pass  non-Dependabot pull request skips the job"
else
  echo "FAIL  non-Dependabot pull request skips the job: guard is '$guard'" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures of $total cases failed" >&2
  exit 1
fi
echo "all $total cases passed"
