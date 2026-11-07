#!/usr/bin/env bash
# Calls public.job_health through the Data API with the secret key and fails,
# naming each failure, when the hosted project reports any scheduled-job
# failure (a job_failures row, a failed pg_cron run or a non-2xx pg_net call)
# since the previous check. The call is also the real query that keeps the Free
# project from pausing, and it moves the check window forward, so it is made
# once and never retried: a retry after a lost response would skip the failures
# the first response already carried.
#
# Fails (exit 1) when:
#   - the API answers anything but HTTP 200 (the first 500 characters of the
#     body are printed), or does not answer in 30 seconds
#   - the body is not a JSON object with a `failures` array
#   - `failures` is not empty (one ::error:: line per failure)
# Exit 2 when an environment variable is missing.
# Needs only curl and jq. Writes a table of the failures to $GITHUB_STEP_SUMMARY
# when it is set.
#
# Usage: scripts/check-job-health.sh
#   SUPABASE_URL         project URL, e.g. https://<ref>.supabase.co (required)
#   SUPABASE_SECRET_KEY  secret API key (required); sent only as the apikey header
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ]; then
  echo "SUPABASE_URL is not set" >&2
  exit 2
fi
if [ -z "${SUPABASE_SECRET_KEY:-}" ]; then
  echo "SUPABASE_SECRET_KEY is not set" >&2
  exit 2
fi

url="${SUPABASE_URL%/}/rest/v1/rpc/job_health"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
body_file="$work/body"
header_file="$work/headers"

# The key goes in a file, not on the command line, so it is not in the process list.
printf 'apikey: %s\nContent-Type: application/json\n' "$SUPABASE_SECRET_KEY" >"$header_file"

# A single attempt: no --retry (see the header).
# curl can exit non-zero after it printed a status (--max-time mid-body), so a
# printed status is kept and 000 is the fallback only when it printed nothing.
status="$(curl -sS --max-time 30 -X POST -H @"$header_file" -d '{}' \
  -o "$body_file" -w '%{http_code}' "$url")" || true
status="${status:-000}"

if [ "$status" != "200" ]; then
  # The first 500 characters of the body carry PostgREST's error code, which
  # says whether the key, the grant or the migration is wrong.
  detail="$(head -c 500 "$body_file" 2>/dev/null | tr -d '\000' | tr '\r\n' '  ')" || detail=""
  detail="${detail//%/%25}"
  echo "::error::$url returned HTTP $status (expected 200): $detail" >&2
  exit 1
fi
if ! jq -e 'type == "object" and (.failures | type == "array")' "$body_file" >/dev/null 2>&1; then
  echo "::error::$url returned HTTP $status but not a JSON object with a failures array" >&2
  exit 1
fi

since="$(jq -r '.since // "the start"' "$body_file")"
until_at="$(jq -r '.until // "unknown"' "$body_file")"
count="$(jq '.failures | length' "$body_file")"
echo "Job health window: $since to $until_at; $count failure(s)"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Job health"
    echo
    echo "Window: $since to $until_at, $count failure(s)."
    if [ "$count" -ne 0 ]; then
      echo
      echo "| Source | Job | Error | At |"
      echo "| --- | --- | --- | --- |"
      jq -r '.failures[]
        | [.source, .job, .error, .at]
        | map(tostring | gsub("[|]"; "\\|") | gsub("\r?\n"; " "))
        | "| " + join(" | ") + " |"' "$body_file"
    fi
  } >>"$GITHUB_STEP_SUMMARY"
fi

if [ "$count" -ne 0 ]; then
  # Workflow-command escaping, so an error text cannot end the annotation early.
  jq -r '.failures[]
    | "::error::" + (
        "\(.source) failure: \(.job) at \(.at): \(.error)"
        | gsub("%"; "%25") | gsub("\r"; "%0D") | gsub("\n"; "%0A"))' "$body_file"
  echo "$count scheduled-job failure(s) since $since." >&2
  exit 1
fi
echo "OK: no scheduled-job failures since $since"
