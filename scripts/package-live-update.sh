#!/usr/bin/env bash
# Packages the build as a live update for the iOS shell (story 10's updater):
#   <dist>/updates/bundle-<id>.zip  the built site, index.html at the zip's root
#   <dist>/updates/latest.json      { version, url, checksum, min_native_build }
# The shell downloads the zip when `version` differs from its own build id and
# its native build number is at least `min_native_build` (AD-18).
#
# Run after the build, with the same GITHUB_SHA the build saw: vite.config.ts
# bakes it in as __BUILD_ID__, and a shell running a build whose id differs from
# latest.json's would download its own build again on every launch.
#
# Usage, from any directory: scripts/package-live-update.sh
#   GITHUB_SHA       the build id (required)
#   DIST             the build output (default <repo>/app/dist)
#   UPDATE_BASE_URL  the site's origin, where the zip's url points (default
#                    https://fermi-plus.sallvain.workers.dev; a trailing slash
#                    is dropped)
#
# Nothing is written unless every check passes: scripts/check-native-build.sh
# (MIN_NATIVE_BUILD at most the Xcode build number) and the build id found in
# dist/assets. Any previous dist/updates/ is removed first, even when a check
# fails, so a refused run leaves no earlier update behind.
# Exit 0  packaged
#     1   a check failed (its message names the reason)
#     2   bad input: GITHUB_SHA unset, or no build in DIST
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/.." && pwd)"

build_id="${GITHUB_SHA:-}"
if [ -z "$build_id" ]; then
  echo "package-live-update: GITHUB_SHA must name the build in the dist folder" >&2
  exit 2
fi
dist="${DIST:-$repo/app/dist}"
base_url="${UPDATE_BASE_URL:-https://fermi-plus.sallvain.workers.dev}"
while [ "${base_url%/}" != "$base_url" ]; do base_url="${base_url%/}"; done

if [ ! -f "$dist/index.html" ] || [ ! -d "$dist/assets" ]; then
  echo "package-live-update: $dist holds no build (index.html and assets/ expected)" >&2
  exit 2
fi
dist="$(cd "$dist" && pwd)"

# Whatever happens next, a previous run's latest.json and zip must not survive
# to be deployed as this build's update.
rm -rf "$dist/updates"

# The check reads the repo's HEAD; its own message names the numbers.
(cd "$script_dir" && ./check-native-build.sh)

min_native_build="$(git -C "$repo" show HEAD:app/MIN_NATIVE_BUILD | tr -d '[:space:]')"
min_native_build=$((10#$min_native_build))

# A build made with another GITHUB_SHA carries a different __BUILD_ID__. Matched
# as a quoted string literal: a bare substring check finds short ids inside
# unrelated code ("nope" in "onopen").
if ! grep -rqF -e "\"$build_id\"" -e "'$build_id'" -e "\`$build_id\`" "$dist/assets"; then
  echo "package-live-update: $dist/assets does not contain build id $build_id as a quoted literal; build with the same GITHUB_SHA first" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

zip_name="bundle-$build_id.zip"
# The zip is made outside dist/, so it cannot include itself.
(cd "$dist" && zip -qrX "$work/$zip_name" . -x 'updates/*')

if command -v sha256sum >/dev/null; then
  checksum="$(sha256sum "$work/$zip_name" | cut -d' ' -f1)"
else
  checksum="$(shasum -a 256 "$work/$zip_name" | cut -d' ' -f1)"
fi

mkdir -p "$dist/updates"
mv "$work/$zip_name" "$dist/updates/$zip_name"
jq -n \
  --arg version "$build_id" \
  --arg url "$base_url/updates/$zip_name" \
  --arg checksum "$checksum" \
  --argjson min "$min_native_build" \
  '{version: $version, url: $url, checksum: $checksum, min_native_build: $min}' \
  >"$dist/updates/latest.json"

echo "Live update $build_id packaged: $dist/updates/$zip_name ($(du -h "$dist/updates/$zip_name" | cut -f1), sha256 $checksum, min_native_build $min_native_build)"
