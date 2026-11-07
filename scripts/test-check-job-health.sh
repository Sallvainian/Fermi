#!/usr/bin/env bash
# Tests scripts/check-job-health.sh against the local Supabase stack, through
# the real Data API path (secret key -> PostgREST -> public.job_health).
#
# Takes the API URL, DB URL and keys from `supabase status -o env` and refuses
# an API URL that is not 127.0.0.1 or localhost. Cases:
#   - a call after a priming call, nothing failed       -> must pass
#   - an internal.job_failures row                      -> must fail naming the job and error
#   - the next call                                     -> must pass (reported once)
#   - a failed cron.job_run_details row                 -> must fail naming the job id and message
#   - a 500 net._http_response row                      -> must fail naming the request and HTTP 500
#     (both dated 11 minutes ago so the 10 minute settle lag has passed, with the
#     check log rewound to an hour ago so the window reaches them)
#   - the publishable key, a wrong key                  -> must fail with HTTP 401 or 403, and
#     print the response body
#   - an API that does not answer                       -> must fail naming HTTP 000
#   - HTTP 200 with HTML, or JSON with no failures array -> must fail naming the shape
#   - a missing SUPABASE_SECRET_KEY                     -> must exit 2
# A failing case passes only when the checker fails for that case's reason.
#
# The priming call moves the shared stack's check window to now, so failures
# that other work left unreported before this run are not reported afterwards,
# and each cron and http case replaces the stack's check log with one row.
# The rows this script inserts are marked (job 'test-check-job-health', cron
# runid and HTTP id 990000001, cron jobid 999999998) and deleted on exit.
#
# Needs: the local stack running (`supabase start`), psql, curl, jq, python3.
#   PORT  port for the fake API that answers 200 with a wrong body (default 4182)
# Usage, from anywhere in the repo: scripts/test-check-job-health.sh
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
marker=test-check-job-health
row_id=990000001
cron_jobid=999999998
work="$(mktemp -d)"
port="${PORT:-4182}"
pid=""
failures=0
cases=0

# API_URL, DB_URL, SECRET_KEY and PUBLISHABLE_KEY of the local stack.
eval "$(supabase status -o env 2>/dev/null | grep -E '^(API_URL|DB_URL|SECRET_KEY|PUBLISHABLE_KEY)=')"
for name in API_URL DB_URL SECRET_KEY PUBLISHABLE_KEY; do
  if [ -z "${!name:-}" ]; then
    echo "::error::supabase status did not print $name; is the local stack running?"
    exit 1
  fi
done
case "$API_URL" in
  http://127.0.0.1[:/]* | http://localhost[:/]*) ;;
  *)
    echo "::error::API_URL is $API_URL; this test inserts rows and runs only against 127.0.0.1 or localhost."
    exit 1
    ;;
esac

sql() { psql "$DB_URL" -v ON_ERROR_STOP=1 -qAt -c "$1" >/dev/null; }

delete_rows() {
  sql "delete from internal.job_failures where job = '$marker';
       delete from cron.job_run_details where runid = $row_id;
       delete from net._http_response where id = $row_id;"
}

# Makes the last check one hour old, so the window of the next call reaches back
# over rows dated 11 minutes ago. Back to back calls have windows milliseconds
# wide, and public.job_health reads cron and http rows 10 minutes behind them.
# Records the timestamp it inserts, so cleanup deletes exactly that row.
rewound=""
rewind_checks() {
  local ts
  sql "delete from internal.job_health_checks;"
  ts="$(psql "$DB_URL" -v ON_ERROR_STOP=1 -qAt \
    -c "insert into internal.job_health_checks (checked_at) values (now() - interval '1 hour') returning checked_at;" |
    head -n 1)"
  rewound="$rewound'$ts'::timestamptz,"
}

cleanup() {
  if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  if [ -n "$rewound" ]; then
    sql "delete from internal.job_health_checks where checked_at in (${rewound%,});" ||
      echo "::warning::Could not delete the check rows the test inserted."
  fi
  delete_rows || echo "::warning::Could not delete the test rows (job '$marker', runid and id $row_id)."
  rm -rf "$work"
}
trap cleanup EXIT

# Start clean in case an earlier run was killed before its cleanup.
delete_rows

run_check() {  # <url> <key>
  SUPABASE_URL="$1" SUPABASE_SECRET_KEY="$2" "$root/scripts/check-job-health.sh" >"$work/out.log" 2>&1
}

expect_pass() {  # <case> <url> <key>
  cases=$((cases + 1))
  if run_check "$2" "$3"; then
    echo "ok: $1 passes"
  else
    echo "::error::$1 should pass but check-job-health.sh failed:"
    cat "$work/out.log"
    failures=$((failures + 1))
  fi
}

expect_fail() {  # <case> <url> <key> <reason (extended regex) it must give>...
  local name="$1" url="$2" key="$3" reason
  shift 3
  cases=$((cases + 1))
  if run_check "$url" "$key"; then
    echo "::error::$name should fail but check-job-health.sh passed:"
    cat "$work/out.log"
    failures=$((failures + 1))
    return
  fi
  for reason in "$@"; do
    if ! grep -qE -- "$reason" "$work/out.log"; then
      echo "::error::$name failed, but not with '$reason':"
      cat "$work/out.log"
      failures=$((failures + 1))
      return
    fi
  done
  echo "ok: $name fails: $*"
}

# Prime: moves the window to now. Its result is not a case.
run_check "$API_URL" "$SECRET_KEY" || true

expect_pass 'a call with nothing failed' "$API_URL" "$SECRET_KEY"

sql "insert into internal.job_failures (job, error_code) values ('$marker', 'boom-job-failure');"
expect_fail 'a job_failures row' "$API_URL" "$SECRET_KEY" "job_failures failure: $marker" 'boom-job-failure'

expect_pass 'the next call (reported once)' "$API_URL" "$SECRET_KEY"

delete_rows
rewind_checks
sql "insert into cron.job_run_details (jobid, runid, status, return_message, start_time, end_time)
     values ($cron_jobid, $row_id, 'failed', 'boom-cron-failure', now() - interval '11 minutes', now() - interval '11 minutes');"
expect_fail 'a failed cron run' "$API_URL" "$SECRET_KEY" "cron failure: job $cron_jobid" 'boom-cron-failure'

delete_rows
rewind_checks
sql "insert into net._http_response (id, status_code, created) values ($row_id, 500, now() - interval '11 minutes');"
expect_fail 'a 500 pg_net response' "$API_URL" "$SECRET_KEY" "http failure: request $row_id" 'HTTP 500'

expect_pass 'a call after all three were reported' "$API_URL" "$SECRET_KEY"

expect_fail 'the publishable key' "$API_URL" "$PUBLISHABLE_KEY" 'returned HTTP 40[13] ' '"code":"42501"'
expect_fail 'a wrong secret key' "$API_URL" 'sb_secret_wrong' 'returned HTTP 40[13] '
expect_fail 'an API that does not answer' 'http://127.0.0.1:1' "$SECRET_KEY" 'returned HTTP 000 '

# A fake API answering every request with HTTP 200 and the body named by the
# path's first segment: /html/... an HTML page, /nofailures/... a JSON object
# with no failures array.
cat >"$work/fake_api.py" <<'PY'
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

BODIES = {
    'html': (b'<html>maintenance</html>', 'text/html'),
    'nofailures': (b'{"since": null, "until": "2030-01-01T00:00:00+00:00"}', 'application/json'),
}


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length') or 0))
        body, kind = BODIES.get(self.path.split('/')[1], (b'{}', 'application/json'))
        self.send_response(200)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    do_GET = do_POST

    def log_message(self, *args):
        pass


HTTPServer(('127.0.0.1', int(sys.argv[1])), Handler).serve_forever()
PY
python3 -I "$work/fake_api.py" "$port" >"$work/server.log" 2>&1 &
pid=$!
for _ in $(seq 1 60); do
  if curl -s -o /dev/null "http://127.0.0.1:$port/"; then break; fi
  if ! kill -0 "$pid" 2>/dev/null; then
    cat "$work/server.log"
    echo "::error::The fake API did not start on port $port."
    exit 1
  fi
  sleep 0.25
done
expect_fail 'HTTP 200 with an HTML body' "http://127.0.0.1:$port/html" "$SECRET_KEY" \
  'returned HTTP 200 but not a JSON object with a failures array'
expect_fail 'HTTP 200 with no failures array' "http://127.0.0.1:$port/nofailures" "$SECRET_KEY" \
  'returned HTTP 200 but not a JSON object with a failures array'

cases=$((cases + 1))
if env -u SUPABASE_SECRET_KEY SUPABASE_URL="$API_URL" "$root/scripts/check-job-health.sh" >"$work/out.log" 2>&1; then
  echo "::error::a missing SUPABASE_SECRET_KEY should fail but check-job-health.sh passed."
  failures=$((failures + 1))
else
  code=$?
  if [ "$code" -eq 2 ]; then
    echo "ok: a missing SUPABASE_SECRET_KEY exits 2"
  else
    echo "::error::a missing SUPABASE_SECRET_KEY should exit 2 but exited $code:"
    cat "$work/out.log"
    failures=$((failures + 1))
  fi
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures of $cases job health case(s) did not behave as expected."
  exit 1
fi
echo "All $cases job health cases behaved as expected."
