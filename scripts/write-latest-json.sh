#!/usr/bin/env bash
# Writes the build's version file, <dist>/updates/latest.json:
#   { "version": "<build id>", "app": "<app id>" }
# Readers: deploy.yml's daily gate (scripts/deploy-gate.sh) compares `version`
# with main's head to decide whether to deploy, the health check
# (scripts/check-site.sh) requires it to name the build just pushed, and the
# app's update check (app/src/update/) compares `app` with its own __APP_ID__.
#
# Run after the build, with the same GITHUB_SHA and APP_ID the build saw:
# vite.config.ts bakes them in as __BUILD_ID__ (and the fermi-build meta) and
# __APP_ID__. A latest.json naming another build id fails the health check and
# misleads the daily gate; one naming another app id would show open clients
# the refresh page for a build they already run.
#
# Usage, from any directory: scripts/write-latest-json.sh
#   GITHUB_SHA  the build id (required)
#   APP_ID      the app id, `git rev-parse HEAD:app` (required)
#   DIST        the build output (default <repo>/app/dist)
#
# Nothing is written unless the build id and the app id are each found in
# dist/assets as a quoted literal. Any previous dist/updates/ is removed first,
# even when the check fails, so a refused run leaves no earlier update behind.
# Exit 0  written
#     1   the build id or the app id is not in dist/assets
#     2   bad input: GITHUB_SHA or APP_ID unset, or no build in DIST
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/.." && pwd)"

build_id="${GITHUB_SHA:-}"
if [ -z "$build_id" ]; then
  echo "write-latest-json: GITHUB_SHA must name the build in the dist folder" >&2
  exit 2
fi
app_id="${APP_ID:-}"
if [ -z "$app_id" ]; then
  echo "write-latest-json: APP_ID must name the app in the dist folder (git rev-parse HEAD:app)" >&2
  exit 2
fi
dist="${DIST:-$repo/app/dist}"

if [ ! -f "$dist/index.html" ] || [ ! -d "$dist/assets" ]; then
  echo "write-latest-json: $dist holds no build (index.html and assets/ expected)" >&2
  exit 2
fi
dist="$(cd "$dist" && pwd)"

# Whatever happens next, a previous run's latest.json must not survive to be
# deployed as this build's version.
rm -rf "$dist/updates"

# A build made with another GITHUB_SHA carries a different __BUILD_ID__. Matched
# as a quoted string literal: a bare substring check finds short ids inside
# unrelated code ("nope" in "onopen").
if ! grep -rqF -e "\"$build_id\"" -e "'$build_id'" -e "\`$build_id\`" "$dist/assets"; then
  echo "write-latest-json: $dist/assets does not contain build id $build_id as a quoted literal; build with the same GITHUB_SHA first" >&2
  exit 1
fi

# The same check for the app id (__APP_ID__).
if ! grep -rqF -e "\"$app_id\"" -e "'$app_id'" -e "\`$app_id\`" "$dist/assets"; then
  echo "write-latest-json: $dist/assets does not contain app id $app_id as a quoted literal; build with the same APP_ID first" >&2
  exit 1
fi

mkdir -p "$dist/updates"
jq -n --arg version "$build_id" --arg app "$app_id" '{version: $version, app: $app}' >"$dist/updates/latest.json"

echo "latest.json written for $build_id (app $app_id): $dist/updates/latest.json"
