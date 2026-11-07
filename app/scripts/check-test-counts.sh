#!/usr/bin/env bash
# Fails a CI job whose Playwright run quietly ran less than the suite holds.
#
# A test job goes red only when a test fails, so a run that stopped picking up
# most of its tests (a config filter, a moved folder) passes, and faster.
# TEA's CI rule: reconcile what ran against what exists. After a green run:
#   1. every spec file tracked under the project's folder is one Playwright
#      finds for the project (catches a config that stopped matching files);
#   2. the tests this run reported in its JUnit file equal the tests Playwright
#      lists for the same project (catches a run that executed fewer).
# Skipped tests are listed and reported alike, so they never cause a mismatch.
#
# Adapted from My-Love's scripts/check-test-counts.sh (no shards here yet).
# Usage, from app/: scripts/check-test-counts.sh <project> <folder>
# Reads test-results/junit.xml, which playwright.config.ts's junit reporter
# writes on every run (JUNIT_FILE overrides the path).
set -euo pipefail

project="$1"
folder="$2"
junit="${JUNIT_FILE:-test-results/junit.xml}"

# Read the run's own count FIRST. A plain `playwright test --list` still runs
# every reporter in the config, so the junit reporter would overwrite this file
# with the listed tests, making the two counts equal by construction. The list
# run below passes --reporter=list, which writes no report files.
if [[ ! -f "$junit" ]]; then
  echo "::error::$junit is missing, so the tests this run executed cannot be counted."
  exit 1
fi
ran=$(grep -o -m1 '<testsuites[^>]*' "$junit" | sed -nE 's/.* tests="([0-9]+)".*/\1/p')

on_disk=$(git ls-files -- "$folder" | grep -cE '\.(spec|test)\.(ts|tsx|js|jsx)$' || true)

total=$(npx playwright test --list --reporter=list --project="$project" | tail -1)
listed_files=$(sed -nE 's/^Total: [0-9]+ tests? in ([0-9]+) files?$/\1/p' <<<"$total")
listed_tests=$(sed -nE 's/^Total: ([0-9]+) tests? in [0-9]+ files?$/\1/p' <<<"$total")

if [[ -z "$listed_files" || -z "$listed_tests" || -z "$ran" ]]; then
  echo "::error::Could not read a count (listed files '${listed_files}', listed tests '${listed_tests}', ran '${ran}'). Playwright printed: '${total}'."
  exit 1
fi

echo "$project: $on_disk spec files tracked under $folder, $listed_files found by Playwright; $listed_tests tests listed, $ran ran."

rc=0
if [[ "$on_disk" != "$listed_files" ]]; then
  echo "::error::$folder tracks $on_disk spec files but Playwright finds $listed_files for project '$project'. A config change has dropped files from the run."
  rc=1
fi
if [[ "$ran" != "$listed_tests" ]]; then
  echo "::error::Playwright lists $listed_tests tests for project '$project' but this run reported $ran."
  rc=1
fi
exit "$rc"
