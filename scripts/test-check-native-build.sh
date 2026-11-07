#!/usr/bin/env bash
# Tests scripts/check-native-build.sh and scripts/package-live-update.sh (AD-18).
#
# Builds a throwaway git repo per case with fixture copies of dependabot.yml,
# app/package.json, app/MIN_NATIVE_BUILD, app/capacitor.config.ts and the Xcode
# project file, changes it the way a pull request would, and runs the check
# between the base commit and the changed one. A case passes only when the exit
# code and a message substring both match, so a case cannot pass because the
# script crashed. Packaging runs against a fake dist/ and its zip and
# latest.json are opened and re-hashed.
#
# Needs git, jq, yq (mikefarah v4), zip, unzip. No network, no secret.
# Usage, from anywhere in the repo: scripts/test-check-native-build.sh
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cases=0
failures=0
rc=0
out=""

g() {  # git with an identity and no signing, whatever the machine's config
  git -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false "$@"
}

# A fresh fixture repo with one commit; prints its path.
new_repo() {
  local dir
  dir="$(mktemp -d "$work/repo.XXXXXX")"
  mkdir -p "$dir/.github" "$dir/app/ios/App/App.xcodeproj" "$dir/app/ios/App/App" "$dir/app/src" "$dir/scripts"
  cp "$root/scripts/check-native-build.sh" "$root/scripts/package-live-update.sh" "$dir/scripts/"
  cat >"$dir/.github/dependabot.yml" <<'EOF'
version: 2
updates:
  - package-ecosystem: 'npm'
    directory: '/app'
    groups:
      native:
        patterns:
          - '@capacitor/*'
          - '@capgo/*'
      other:
        patterns:
          - '*'
  - package-ecosystem: 'github-actions'
    directory: '/'
    groups:
      actions:
        patterns:
          - '*'
EOF
  cat >"$dir/app/package.json" <<'EOF'
{
  "name": "fixture",
  "dependencies": {
    "@capacitor/core": "8.0.0",
    "@capgo/capacitor-updater": "8.0.0",
    "react": "19.0.0"
  },
  "devDependencies": {
    "vite": "7.0.0"
  }
}
EOF
  echo 8 >"$dir/app/MIN_NATIVE_BUILD"
  echo "export default {};" >"$dir/app/capacitor.config.ts"
  echo "<plist/>" >"$dir/app/ios/App/App/Info.plist"
  echo "export const x = 1;" >"$dir/app/src/App.tsx"
  write_pbxproj "$dir" 8 8
  g -C "$dir" init -q -b main
  g -C "$dir" add -A
  g -C "$dir" commit -q -m base
  echo "$dir"
}

write_pbxproj() {  # <repo> <debug build> <release build>
  cat >"$1/app/ios/App/App.xcodeproj/project.pbxproj" <<EOF
		504EC3171FED79650016851F /* Debug */ = {
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = $2;
				MARKETING_VERSION = 1.0.0;
			};
			name = Debug;
		};
		504EC3181FED79650016851F /* Release */ = {
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = $3;
				MARKETING_VERSION = 1.0.0;
			};
			name = Release;
		};
EOF
}

set_dependency() {  # <repo> <section> <name> <version>
  local file="$1/app/package.json"
  jq --arg s "$2" --arg n "$3" --arg v "$4" '.[$s][$n] = $v' "$file" >"$file.new"
  mv "$file.new" "$file"
}

drop_dependency() {  # <repo> <section> <name>
  local file="$1/app/package.json"
  jq --arg s "$2" --arg n "$3" 'del(.[$s][$n])' "$file" >"$file.new"
  mv "$file.new" "$file"
}

commit_change() {  # <repo>
  g -C "$1" add -A
  g -C "$1" commit -q -m change
}

# Run a command in a directory; sets $rc and $out (stdout and stderr).
run() {  # <dir> <command...>
  local dir="$1"
  shift
  rc=0
  out="$(cd "$dir" && "$@" 2>&1)" || rc=$?
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

# check <case> <repo> <exit code> <substring>...: base commit against HEAD
check() {
  local name="$1" dir="$2" want="$3"
  shift 3
  run "$dir" scripts/check-native-build.sh "$(g -C "$dir" rev-list --max-parents=0 HEAD)" HEAD
  expect "$name" "$want" "$@"
}

# -- check-native-build.sh ----------------------------------------------------

r="$(new_repo)"
echo "export const x = 2;" >"$r/app/src/App.tsx"
commit_change "$r"
check 'no native change passes' "$r" 0 'No native change'

r="$(new_repo)"
set_dependency "$r" dependencies react 19.1.0
set_dependency "$r" devDependencies vite 7.1.0
commit_change "$r"
check 'a non-native version bump passes' "$r" 0 'No native change'

r="$(new_repo)"
set_dependency "$r" dependencies '@capacitor/app' 8.6.0
commit_change "$r"
check 'a plugin without a raise fails' "$r" 1 '@capacitor/app' 'MIN_NATIVE_BUILD'

r="$(new_repo)"
set_dependency "$r" dependencies '@capacitor/app' 8.6.0
echo 9 >"$r/app/MIN_NATIVE_BUILD"
write_pbxproj "$r" 9 9
commit_change "$r"
check 'a plugin with a raise passes' "$r" 0 'was raised (8 to 9)'

r="$(new_repo)"
set_dependency "$r" dependencies '@capacitor/core' 8.1.0
commit_change "$r"
check 'a native package version change without a raise fails' "$r" 1 '@capacitor/core'

r="$(new_repo)"
drop_dependency "$r" dependencies '@capgo/capacitor-updater'
commit_change "$r"
check 'a removed native package without a raise fails' "$r" 1 '@capgo/capacitor-updater'

r="$(new_repo)"
set_dependency "$r" devDependencies '@capacitor/cli' 8.0.0
commit_change "$r"
check 'a native devDependency without a raise fails' "$r" 1 '@capacitor/cli'

r="$(new_repo)"
echo "<plist>changed</plist>" >"$r/app/ios/App/App/Info.plist"
commit_change "$r"
check 'an iOS file without a raise fails' "$r" 1 'app/ios/App/App/Info.plist'

r="$(new_repo)"
echo "export default { changed: true };" >"$r/app/capacitor.config.ts"
commit_change "$r"
check 'capacitor.config without a raise fails' "$r" 1 'app/capacitor.config.ts'

r="$(new_repo)"
echo "export default { changed: true };" >"$r/app/capacitor.config.ts"
echo 9 >"$r/app/MIN_NATIVE_BUILD"
write_pbxproj "$r" 9 9
commit_change "$r"
check 'capacitor.config with a raise passes' "$r" 0 'was raised (8 to 9)'

r="$(new_repo)"
echo 7 >"$r/app/MIN_NATIVE_BUILD"
echo "<plist>changed</plist>" >"$r/app/ios/App/App/Info.plist"
commit_change "$r"
check 'a lowered MIN_NATIVE_BUILD is not a raise' "$r" 1 'app/ios/App/App/Info.plist'

r="$(new_repo)"
yq -i '.updates[0].groups.native.patterns += ["capacitor-foo"]' "$r/.github/dependabot.yml"
set_dependency "$r" dependencies capacitor-foo 1.0.0
commit_change "$r"
check 'a plugin under a new pattern in the head fails' "$r" 1 'capacitor-foo'

r="$(new_repo)"
yq -i 'del(.updates[0].groups.native.patterns[] | select(. == "@capgo/*"))' "$r/.github/dependabot.yml"
drop_dependency "$r" dependencies '@capgo/capacitor-updater'
commit_change "$r"
check 'dropping a pattern and its package to escape fails' "$r" 1 '@capgo/capacitor-updater'

r="$(new_repo)"
echo 9 >"$r/app/MIN_NATIVE_BUILD"
write_pbxproj "$r" 9 8
commit_change "$r"
check 'MIN above the Release build number fails' "$r" 1 'MIN_NATIVE_BUILD 9 is above CURRENT_PROJECT_VERSION 8'

r="$(new_repo)"
echo 9 >"$r/app/MIN_NATIVE_BUILD"
write_pbxproj "$r" 9 8
commit_change "$r"
run "$r" scripts/check-native-build.sh
expect 'MIN above Xcode fails with no base' 1 'MIN_NATIVE_BUILD 9 is above CURRENT_PROJECT_VERSION 8'

r="$(new_repo)"
run "$r" scripts/check-native-build.sh
expect 'no base, MIN equal to Xcode passes' 0 'OK: native build rules hold'

r="$(new_repo)"
echo "eight" >"$r/app/MIN_NATIVE_BUILD"
commit_change "$r"
run "$r" scripts/check-native-build.sh
expect 'a MIN_NATIVE_BUILD that is not an integer is bad input' 2 'not an integer'

r="$(new_repo)"
echo "// no build numbers" >"$r/app/ios/App/App.xcodeproj/project.pbxproj"
commit_change "$r"
run "$r" scripts/check-native-build.sh
expect 'a project file without build numbers is bad input' 2 'no CURRENT_PROJECT_VERSION entries'

r="$(new_repo)"
write_pbxproj "$r" 8 "\$(inherited)"
commit_change "$r"
run "$r" scripts/check-native-build.sh
expect 'a build number that is not an integer is bad input' 2 'is not an integer'

r="$(new_repo)"
echo "updates: [unclosed" >"$r/.github/dependabot.yml"
commit_change "$r"
check 'an unreadable dependabot.yml is bad input' "$r" 2 'dependabot.yml'

r="$(new_repo)"
printf 'version: 2\nupdates: []\n' >"$r/.github/dependabot.yml"
commit_change "$r"
check 'a dependabot.yml with no native patterns is bad input' "$r" 2 'no groups.native.patterns'

r="$(new_repo)"
run "$r" scripts/check-native-build.sh no-such-rev HEAD
expect 'an unknown revision is bad input' 2 'no-such-rev'

# -- package-live-update.sh ---------------------------------------------------

sha256_of() {  # <file>
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# A fake build whose script holds "<id>" as a quoted literal.
fake_dist() {  # <dir> <id>
  mkdir -p "$1/assets"
  echo '<!doctype html><title>fixture</title>' >"$1/index.html"
  echo "export const id = \"$2\";" >"$1/assets/x.js"
}

package() {  # <repo> <dist> <id> [extra env assignments...]
  local dir="$1" dist="$2" id="$3"
  shift 3
  run "$dir" env -u GITHUB_SHA -u DIST -u UPDATE_BASE_URL GITHUB_SHA="$id" DIST="$dist" \
    UPDATE_BASE_URL="https://example.test/" "$@" scripts/package-live-update.sh
}

r="$(new_repo)"
fake_dist "$work/dist-good" abc123
mkdir -p "$work/dist-good/updates"
echo stale >"$work/dist-good/updates/old.txt"
package "$r" "$work/dist-good" abc123
expect 'packaging a matching build succeeds' 0 'Live update abc123 packaged'

cases=$((cases + 1))
bad=""
manifest="$work/dist-good/updates/latest.json"
zip_file="$work/dist-good/updates/bundle-abc123.zip"
if [ ! -f "$manifest" ] || [ ! -f "$zip_file" ]; then
  bad="latest.json or the zip is missing"
else
  [ "$(jq -r .version "$manifest")" = abc123 ] || bad="version is not abc123"
  [ "$(jq -r .url "$manifest")" = "https://example.test/updates/bundle-abc123.zip" ] || bad="${bad:+$bad; }url is wrong"
  [ "$(jq -r '.min_native_build | if type == "number" then . else "not a number" end' "$manifest")" = 8 ] || bad="${bad:+$bad; }min_native_build is not the number 8"
  [ "$(jq -r .checksum "$manifest")" = "$(sha256_of "$zip_file")" ] || bad="${bad:+$bad; }checksum is not the zip's sha256"
  # Re-hash what the zip holds: index.html at the root, the assets, and no updates/.
  entries="$(unzip -Z1 "$zip_file")"
  grep -qx 'index.html' <<<"$entries" || bad="${bad:+$bad; }index.html is not at the zip root"
  grep -qx 'assets/x.js' <<<"$entries" || bad="${bad:+$bad; }assets/x.js is not in the zip"
  if grep -q '^updates' <<<"$entries"; then bad="${bad:+$bad; }the zip holds updates/"; fi
  mkdir "$work/unzipped"
  unzip -q "$zip_file" -d "$work/unzipped"
  [ "$(sha256_of "$work/unzipped/assets/x.js")" = "$(sha256_of "$work/dist-good/assets/x.js")" ] || bad="${bad:+$bad; }the zipped x.js differs from the build's"
  [ ! -e "$work/dist-good/updates/old.txt" ] || bad="${bad:+$bad; }the previous updates/ folder was kept"
fi
if [ -z "$bad" ]; then
  echo "ok: the packaged zip, checksum, url and min_native_build are right"
else
  echo "::error::the packaged output is wrong: $bad"
  failures=$((failures + 1))
fi

fake_dist "$work/dist-id" abc123
package "$r" "$work/dist-id" deadbeef
expect 'a build id not in the build fails and names it' 1 'deadbeef'
cases=$((cases + 1))
if [ -e "$work/dist-id/updates" ]; then
  echo "::error::a failed package wrote dist/updates"
  failures=$((failures + 1))
else
  echo "ok: a failed package writes nothing"
fi

fake_dist "$work/dist-bare" abc123
echo 'const a = "xabc123x"; onabc123;' >"$work/dist-bare/assets/x.js"
package "$r" "$work/dist-bare" abc123
expect 'a build id that is only a substring fails' 1 'abc123'

package "$r" "$work/no-such-dist" abc123
expect 'a missing dist is bad input' 2 'holds no build'

fake_dist "$work/dist-env" abc123
run "$r" env -u GITHUB_SHA DIST="$work/dist-env" scripts/package-live-update.sh
expect 'an unset GITHUB_SHA is bad input' 2 'GITHUB_SHA'

r="$(new_repo)"
echo 9 >"$r/app/MIN_NATIVE_BUILD"
commit_change "$r"
fake_dist "$work/dist-min" abc123
package "$r" "$work/dist-min" abc123
expect 'MIN above the Xcode build number fails and names both' 1 'MIN_NATIVE_BUILD 9 is above CURRENT_PROJECT_VERSION 8'
cases=$((cases + 1))
if [ -e "$work/dist-min/updates" ]; then
  echo "::error::a refused package wrote dist/updates"
  failures=$((failures + 1))
else
  echo "ok: a refused package writes nothing"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures of $cases native build case(s) did not behave as expected."
  exit 1
fi
echo "All $cases native build cases behaved as expected."
