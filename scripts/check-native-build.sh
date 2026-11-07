#!/usr/bin/env bash
# Fails a change that touches native code without raising app/MIN_NATIVE_BUILD
# (AD-18), and a MIN_NATIVE_BUILD above the Xcode build number.
#
# Usage, from anywhere inside the repo to check:
#   scripts/check-native-build.sh [<base-rev> [<head-rev>]]
#   <head-rev>  the revision to judge (default HEAD)
#   <base-rev>  what it is compared with. Without it, only the Xcode rule runs.
# Every file is read with `git show <rev>:<path>`, so the working tree does not
# matter.
#
# A native change is any of:
#   - a changed path under app/ios/;
#   - a changed app/capacitor.config.*;
#   - a native package added, removed or changed in `dependencies` or
#     `devDependencies` of app/package.json.
# The native packages are the `native` group's `patterns` of the npm /app entry
# in .github/dependabot.yml (the one list, as in dependabot-native-hold.sh). The
# check takes the union of the base's and the head's patterns, so a pull request
# can neither drop a pattern to escape the check nor add a plugin under a new
# pattern unchecked.
#
# A native change must raise MIN_NATIVE_BUILD: the head's value is greater than
# the base's. In every mode MIN_NATIVE_BUILD must be at most every
# CURRENT_PROJECT_VERSION in app/ios/App/App.xcodeproj/project.pbxproj, since a
# shell built below it would never accept the live update that needs it.
#
# Exit 0  the rules hold
#     1   a rule is broken (each is printed)
#     2   bad input: an unknown revision, an unreadable file, a MIN_NATIVE_BUILD
#         or build number that is not an integer, no native patterns, or no
#         CURRENT_PROJECT_VERSION entries (callers treat non-zero as failure)
set -euo pipefail

if [ "$#" -gt 2 ]; then
  echo "usage: $0 [<base-rev> [<head-rev>]]" >&2
  exit 2
fi

base_rev="${1:-}"
head_rev="${2:-HEAD}"

die() {
  echo "check-native-build: $*" >&2
  exit 2
}

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
cd "$root"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pbxproj='app/ios/App/App.xcodeproj/project.pbxproj'
dependabot='.github/dependabot.yml'

resolve() {  # <rev> -> commit id
  git rev-parse --verify --quiet "$1^{commit}" || die "revision '$1' not found"
}

show() {  # <rev> <path>
  git show "$1:$2" 2>/dev/null || die "cannot read $2 at $1"
}

# The integer in app/MIN_NATIVE_BUILD at a revision.
min_at() {  # <rev>
  local raw
  raw="$(show "$1" app/MIN_NATIVE_BUILD)" || exit 2
  raw="$(printf '%s' "$raw" | tr -d '[:space:]')"
  case "$raw" in
    '' | *[!0-9]*) die "app/MIN_NATIVE_BUILD at $1 is '$raw', not an integer" ;;
  esac
  [ "${#raw}" -le 9 ] || die "app/MIN_NATIVE_BUILD at $1 is '$raw', too long to be a build number"
  echo "$((10#$raw))"
}

# The native patterns, one per line, from dependabot.yml at a revision.
patterns_at() {  # <rev>
  local file="$work/dependabot-$2.yml" patterns
  show "$1" "$dependabot" >"$file" || exit 2
  patterns="$(yq '.updates[] | select(.["package-ecosystem"] == "npm" and .directory == "/app") | .groups.native.patterns[]' "$file")" \
    || die "could not read $dependabot at $1"
  [ -n "$patterns" ] || die "no groups.native.patterns for the npm /app entry in $dependabot at $1"
  echo "$patterns"
}

# "name<TAB>section<TAB>version" for every dependency, sorted.
packages_at() {  # <rev> <tag>
  local file="$work/package-$2.json"
  show "$1" app/package.json >"$file" || exit 2
  jq -r '(.dependencies // {} | to_entries[] | "\(.key)\tdependencies\t\(.value)"),
         (.devDependencies // {} | to_entries[] | "\(.key)\tdevDependencies\t\(.value)")' "$file" \
    | LC_ALL=C sort || die "could not read app/package.json at $1"
}

head_commit="$(resolve "$head_rev")" || exit 2
head_min="$(min_at "$head_commit")" || exit 2

rc=0
fail() {
  echo "FAIL: $*"
  rc=1
}

if [ -n "$base_rev" ]; then
  base_commit="$(resolve "$base_rev")" || exit 2
  base_min="$(min_at "$base_commit")" || exit 2

  patterns="$(
    {
      patterns_at "$base_commit" base
      patterns_at "$head_commit" head
    } | LC_ALL=C sort -u
  )" || exit 2

  is_native() {  # <package name>
    local pattern
    while IFS= read -r pattern; do
      # shellcheck disable=SC2053  # the unquoted right side is the glob
      if [[ "$1" == $pattern ]]; then return 0; fi
    done <<<"$patterns"
    return 1
  }

  reasons=()

  while IFS= read -r changed; do
    [ -n "$changed" ] || continue
    case "$changed" in
      app/ios/*) reasons+=("$changed changed") ;;
      *)
        if [[ "$changed" =~ ^app/capacitor\.config\.[^/]+$ ]]; then
          reasons+=("$changed changed")
        fi
        ;;
    esac
  done < <(git -c core.quotepath=off diff --name-only --no-renames "$base_commit" "$head_commit")

  base_packages="$(packages_at "$base_commit" base)" || exit 2
  head_packages="$(packages_at "$head_commit" head)" || exit 2
  # Lines only in one list are an added, removed or changed dependency.
  changed_names="$(
    LC_ALL=C comm -3 <(printf '%s\n' "$base_packages") <(printf '%s\n' "$head_packages") \
      | sed 's/^[[:space:]]*//' | cut -f1 | LC_ALL=C sort -u
  )"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if is_native "$name"; then
      reasons+=("native package $name added, removed or changed in app/package.json")
    fi
  done <<<"$changed_names"

  echo "MIN_NATIVE_BUILD: $base_min at base, $head_min at head"
  if [ "${#reasons[@]}" -eq 0 ]; then
    echo "No native change between $base_rev and $head_rev."
  else
    printf 'Native change: %s\n' "${reasons[@]}"
    if [ "$head_min" -gt "$base_min" ]; then
      echo "MIN_NATIVE_BUILD was raised ($base_min to $head_min)."
    else
      fail "a native change needs app/MIN_NATIVE_BUILD raised above $base_min (it is $head_min at head), with CURRENT_PROJECT_VERSION raised to match"
    fi
  fi
else
  echo "MIN_NATIVE_BUILD: $head_min at $head_rev (no base given; only the Xcode rule runs)"
fi

# MIN_NATIVE_BUILD against the Xcode build number, Debug and Release alike.
builds="$(show "$head_commit" "$pbxproj" | sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION = \(.*\);[[:space:]]*$/\1/p')" \
  || exit 2
[ -n "$builds" ] || die "no CURRENT_PROJECT_VERSION entries in $pbxproj at $head_rev"
lowest=""
while IFS= read -r build; do
  case "$build" in
    '' | *[!0-9]*) die "CURRENT_PROJECT_VERSION '$build' in $pbxproj is not an integer" ;;
  esac
  build=$((10#$build))
  if [ -z "$lowest" ] || [ "$build" -lt "$lowest" ]; then lowest="$build"; fi
done <<<"$builds"
echo "CURRENT_PROJECT_VERSION: $(printf '%s' "$builds" | paste -sd, - | sed 's/,/, /g') in $pbxproj"
if [ "$head_min" -gt "$lowest" ]; then
  fail "MIN_NATIVE_BUILD $head_min is above CURRENT_PROJECT_VERSION $lowest in $pbxproj; a shell built at $lowest could never take the update that needs $head_min"
fi

if [ "$rc" -eq 0 ]; then
  echo "OK: native build rules hold"
fi
exit "$rc"
