#!/usr/bin/env bash
# Decides whether a Dependabot pull request touches a native package (AD-18).
#
# The native packages are the `native` group's `patterns` in the `/app` npm
# entry of dependabot.yml, read at run time, so the list lives in one place. A
# pull request is matched on every package it changes, never on its group name:
# an ungrouped security update has no group, yet moves a native package.
#
# Usage: scripts/dependabot-native-hold.sh <dependabot.yml> <names>
#   <names>  comma-separated package names (fetch-metadata's dependency-names)
#
# Prints each package that matches a native pattern, one per line.
# Exit 0  no package is native
#     3   at least one package is native (hold the pull request)
#     2   bad input: missing config, no native patterns, or no package names
#         (callers fail closed on 2)
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <dependabot.yml> <names>" >&2
  exit 2
fi

config="$1"
names="$2"

if [ ! -f "$config" ]; then
  echo "dependabot-native-hold: $config not found" >&2
  exit 2
fi

patterns="$(yq '.updates[] | select(.["package-ecosystem"] == "npm" and .directory == "/app") | .groups.native.patterns[]' "$config")" || {
  echo "dependabot-native-hold: could not read $config" >&2
  exit 2
}
if [ -z "$patterns" ]; then
  echo "dependabot-native-hold: no groups.native.patterns for the npm /app entry in $config" >&2
  exit 2
fi

matches=""
count=0
IFS=',' read -r -a parts <<< "$names"
for part in ${parts[@]+"${parts[@]}"}; do
  # Trim surrounding whitespace.
  name="${part#"${part%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  [ -n "$name" ] || continue
  count=$((count + 1))
  while IFS= read -r pattern; do
    # shellcheck disable=SC2053  # the unquoted right side is the glob
    if [[ "$name" == $pattern ]]; then
      matches="${matches}${name}"$'\n'
      break
    fi
  done <<< "$patterns"
done

if [ "$count" -eq 0 ]; then
  echo "dependabot-native-hold: no package names given" >&2
  exit 2
fi

if [ -n "$matches" ]; then
  printf '%s' "$matches"
  exit 3
fi
exit 0
