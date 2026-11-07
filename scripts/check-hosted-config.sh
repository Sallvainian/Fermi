#!/usr/bin/env bash
# Reads the hosted Supabase project's Auth and Realtime config back through the
# Management API and fails, naming each wrong setting, unless:
#   - email sign-in is on         (auth config: external_email_enabled)
#   - anonymous sign-ins are off  (auth config: external_anonymous_users_enabled)
#   - sign-up is off              (auth config: disable_signup)
#   - the site URL is the workers.dev origin (auth config: site_url)
#   - every redirect URL is on that origin, and there is at least one
#                                 (auth config: uri_allow_list, a comma-separated
#                                 string; null, absent or blank counts as empty)
#   - Realtime is private-only    (realtime config: private_only; null or absent fails)
# The origin is pinned here (AD-7), not read from the deploy's vars.
# Needs only curl and jq, no Supabase CLI.
#
# Usage: scripts/check-hosted-config.sh <project-ref>
#   SUPABASE_ACCESS_TOKEN  Management API token (required)
#   SUPABASE_API_URL       API base URL (default https://api.supabase.com)
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <project-ref>" >&2
  exit 2
fi
if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "SUPABASE_ACCESS_TOKEN is not set" >&2
  exit 2
fi

ref="$1"
origin="https://fermi-plus.sallvain.workers.dev"
api="${SUPABASE_API_URL:-https://api.supabase.com}"
api="${api%/}"

body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT

# GET <api>/v1/projects/<ref>/config/<kind> into $body_file; exit 1 naming the
# URL and status unless it answers 200 with JSON.
fetch_config() {
  local url="$api/v1/projects/$ref/config/$1" status
  status="$(curl -sS --retry 3 --max-time 30 -o "$body_file" -w '%{http_code}' \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" "$url")" || status="000"
  if [ "$status" != "200" ]; then
    echo "::error::$url returned HTTP $status (expected 200)" >&2
    exit 1
  fi
  if ! jq -e 'type == "object"' "$body_file" >/dev/null 2>&1; then
    echo "::error::$url returned HTTP $status but not a JSON object" >&2
    exit 1
  fi
}

failures=0

# check <what> <field> <expected> -- compares the field of $body_file as JSON.
check() {
  local what="$1" field="$2" expected="$3" actual
  actual="$(jq -c --arg f "$field" '.[$f]' "$body_file")"
  if [ "$actual" = "$expected" ]; then
    echo "OK: $what ($field = $actual)"
  else
    echo "::error::$what is wrong: $field is $actual, expected $expected"
    failures=$((failures + 1))
  fi
}

fetch_config auth
check 'email sign-in' external_email_enabled true
check 'anonymous sign-ins' external_anonymous_users_enabled false
# epic-invite-sign-in replaces this assertion with the sign-in hook URI one.
check 'sign-up' disable_signup true
check 'site URL' site_url "\"$origin\""

# Each redirect URL must be the origin itself or a path on it; a bare prefix
# match would let https://fermi-plus.sallvain.workers.dev.evil.com through.
redirects=()
while IFS= read -r url; do
  redirects+=("$url")
done < <(jq -r '(.uri_allow_list // "") | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")) | .[]' "$body_file")
if [ "${#redirects[@]}" -eq 0 ]; then
  echo "::error::redirect URLs is wrong: uri_allow_list is empty, expected paths on $origin"
  failures=$((failures + 1))
else
  off_origin=0
  for url in "${redirects[@]}"; do
    if [ "$url" != "$origin" ] && [ "${url#"$origin"/}" = "$url" ]; then
      echo "::error::redirect URLs is wrong: uri_allow_list holds $url, which is not on $origin"
      off_origin=1
    fi
  done
  if [ "$off_origin" -eq 0 ]; then
    echo "OK: redirect URLs (uri_allow_list = $(IFS=,; echo "${redirects[*]}"))"
  else
    failures=$((failures + 1))
  fi
fi

fetch_config realtime
check 'Realtime private-only' private_only true

if [ "$failures" -ne 0 ]; then
  echo "$failures hosted setting(s) on project $ref are wrong." >&2
  exit 1
fi
echo "OK: project $ref has the expected Auth and Realtime config"
