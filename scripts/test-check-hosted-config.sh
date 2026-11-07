#!/usr/bin/env bash
# Tests scripts/check-hosted-config.sh, the hosted Auth and Realtime config check.
#
# Serves fixture JSON with python3 -m http.server at
# v1/projects/<ref>/config/{auth,realtime}, one project ref per case, and runs
# the checker against it with SUPABASE_API_URL pointed there:
#   - every setting right                 -> must pass
#   - anonymous sign-ins on               -> must fail naming anonymous sign-ins
#   - sign-up on                          -> must fail naming sign-up
#   - email sign-in off                   -> must fail naming email sign-in
#   - private_only false / null / absent  -> must fail naming Realtime private-only
#   - two wrong settings                  -> must fail naming both
#   - unknown project ref (HTTP 404)      -> must fail naming HTTP 404
#   - HTTP 200 with a body that is not JSON -> must fail naming "not a JSON object"
# A failing case passes only when the checker fails for that case's reason.
#
# Usage, from anywhere in the repo: scripts/test-check-hosted-config.sh
#   PORT  port for the fixture server (default 4181)
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
port="${PORT:-4181}"
work="$(mktemp -d)"
pid=""
failures=0
cases=0

cleanup() {
  if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT

# fixture <ref> <email> <anonymous> <disable_signup> <private_only-json-or-absent>
fixture() {
  local dir="$work/v1/projects/$1/config" realtime
  mkdir -p "$dir"
  printf '{"external_email_enabled":%s,"external_anonymous_users_enabled":%s,"disable_signup":%s,"site_url":"http://localhost:3000"}\n' \
    "$2" "$3" "$4" >"$dir/auth"
  if [ "$5" = absent ]; then
    realtime='{"max_concurrent_users":200}'
  else
    realtime="{\"max_concurrent_users\":200,\"private_only\":$5}"
  fi
  printf '%s\n' "$realtime" >"$dir/realtime"
}

#         ref        email  anon   nosignup private_only
fixture   good       true   false  true     true
fixture   anon-on    true   true   true     true
fixture   signup-on  true   false  false    true
fixture   email-off  false  false  true     true
fixture   po-false   true   false  true     false
fixture   po-null    true   false  true     null
fixture   po-absent  true   false  true     absent
fixture   two-wrong  true   true   false    true
# A 200 reply whose body is not JSON.
mkdir -p "$work/v1/projects/not-json/config"
echo '<html>maintenance</html>' >"$work/v1/projects/not-json/config/auth"

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work" >"$work/server.log" 2>&1 &
pid=$!
for _ in $(seq 1 60); do
  if curl -s -o /dev/null "http://127.0.0.1:$port/"; then break; fi
  if ! kill -0 "$pid" 2>/dev/null; then
    cat "$work/server.log"
    echo "::error::The fixture server did not start on port $port."
    exit 1
  fi
  sleep 0.25
done
if ! curl -s -o /dev/null "http://127.0.0.1:$port/"; then
  echo "::error::The fixture server did not answer on port $port."
  exit 1
fi

check() {  # <ref>
  SUPABASE_ACCESS_TOKEN=dummy-token SUPABASE_API_URL="http://127.0.0.1:$port" \
    "$root/scripts/check-hosted-config.sh" "$1" >"$work/out.log" 2>&1
}

expect_pass() {  # <case> <ref>
  cases=$((cases + 1))
  if check "$2"; then
    echo "ok: $1 passes"
  else
    echo "::error::$1 should pass but check-hosted-config.sh failed:"
    cat "$work/out.log"
    failures=$((failures + 1))
  fi
}

expect_fail() {  # <case> <ref> <reason it must give>...
  local name="$1" ref="$2" reason
  shift 2
  cases=$((cases + 1))
  if check "$ref"; then
    echo "::error::$name should fail but check-hosted-config.sh passed."
    failures=$((failures + 1))
    return
  fi
  for reason in "$@"; do
    if ! grep -qF -- "$reason" "$work/out.log"; then
      echo "::error::$name failed, but not with '$reason':"
      cat "$work/out.log"
      failures=$((failures + 1))
      return
    fi
  done
  echo "ok: $name fails: $*"
}

expect_pass 'every setting right' good
expect_fail 'anonymous sign-ins on' anon-on 'anonymous sign-ins is wrong'
expect_fail 'sign-up on' signup-on 'sign-up is wrong'
expect_fail 'email sign-in off' email-off 'email sign-in is wrong'
expect_fail 'private_only false' po-false 'Realtime private-only is wrong' 'private_only is false'
expect_fail 'private_only null' po-null 'Realtime private-only is wrong' 'private_only is null'
expect_fail 'private_only absent' po-absent 'Realtime private-only is wrong' 'private_only is null'
expect_fail 'two wrong settings' two-wrong 'anonymous sign-ins is wrong' 'sign-up is wrong'
expect_fail 'a missing project ref' no-such-ref 'HTTP 404' '/v1/projects/no-such-ref/config/auth'
expect_fail 'a reply that is not JSON' not-json 'not a JSON object' '/v1/projects/not-json/config/auth'

if [ "$failures" -ne 0 ]; then
  echo "$failures of $cases hosted config case(s) did not behave as expected."
  exit 1
fi
echo "All $cases hosted config cases behaved as expected."
