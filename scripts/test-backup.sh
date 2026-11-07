#!/usr/bin/env bash
# Tests scripts/backup-dump.sh, backup-encrypt.sh and backup-restore-check.sh
# against the local Supabase stack. No secret: the dump is of the local stack.
#
# Takes the DB URL from `supabase status -o env` and refuses one that is not
# 127.0.0.1 or localhost. Inserts an internal.job_failures row (job
# 'test-backup', already marked reported, so job health ignores it) whose
# error_code holds a newline and a tab, and deletes it on exit. Cases:
#   - the dump, then the restore check                  -> must pass
#   - encrypting to a fresh age key                     -> the output holds no marker text, and
#     age -d | tar -xz returns files identical to the dump
#   - schema.sql with `select 1/0;` appended            -> restore check must fail naming
#     schema.sql:<line> and SQLSTATE 22012
#   - data.sql with a delete of internal.job_failures   -> restore check must fail naming that
#     table and both counts
#   - an empty recipients file, a line `not-a-key`      -> encrypt must fail and write no output
#   - a dump with a wrong password                      -> dump must exit 1 naming the failed
#     authentication, so backup.yml stops before encrypting or uploading
#   - after the three restore checks                    -> no restore-check container is left
#   - missing arguments                                 -> each script must exit 2
# A failing case passes only when the script fails for that case's reason.
#
# Needs: the local stack running (`supabase start`), Docker, psql, age,
# age-keygen, tar. Takes about a minute: each restore check starts a database.
# Usage, from anywhere in the repo: scripts/test-backup.sh
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
marker='backup-marker-9f3a'
job=test-backup
work="$(mktemp -d)"
failures=0
cases=0

# DB_URL of the local stack.
eval "$(supabase status -o env 2>/dev/null | grep -E '^DB_URL=')"
if [ -z "${DB_URL:-}" ]; then
  echo "::error::supabase status did not print DB_URL; is the local stack running?"
  exit 1
fi
case "$DB_URL" in
  postgresql://*@127.0.0.1[:/]* | postgresql://*@localhost[:/]*) ;;
  *)
    echo "::error::DB_URL is $DB_URL; this test inserts a row and runs only against 127.0.0.1 or localhost."
    exit 1
    ;;
esac

sql() { psql "$DB_URL" -X -v ON_ERROR_STOP=1 -qAt -c "$1" >/dev/null; }

delete_rows() { sql "delete from internal.job_failures where job = '$job';"; }

cleanup() {
  local status=0
  delete_rows || {
    echo "::error::Could not delete the test row (job '$job'); delete it by hand."
    status=1
  }
  rm -rf "$work"
  if [ "$status" -ne 0 ]; then exit 1; fi
}
trap cleanup EXIT

# Start clean in case an earlier run was killed before its cleanup.
delete_rows

pass() { echo "ok: $1"; }
fail() {  # <message> [log file to show]
  echo "::error::$1"
  if [ -n "${2:-}" ]; then cat "$2"; fi
  failures=$((failures + 1))
}

# expect_ok <case> <command>...  -> the command must exit 0
expect_ok() {
  local name="$1"
  shift
  cases=$((cases + 1))
  if "$@" >"$work/out.log" 2>&1; then pass "$name"; else fail "$name should pass but exited non-zero:" "$work/out.log"; fi
}

# expect_fail <case> <exit code> <reason regex>... -- <command>...
expect_fail() {
  local name="$1" want="$2" code=0 reasons=() reason
  shift 2
  while [ "$1" != -- ]; do
    reasons+=("$1")
    shift
  done
  shift
  cases=$((cases + 1))
  "$@" >"$work/out.log" 2>&1 || code=$?
  if [ "$code" -ne "$want" ]; then
    fail "$name should exit $want but exited $code:" "$work/out.log"
    return
  fi
  for reason in "${reasons[@]}"; do
    if ! grep -qE -- "$reason" "$work/out.log"; then
      fail "$name failed, but not with '$reason':" "$work/out.log"
      return
    fi
  done
  pass "$name fails with exit $want: ${reasons[*]}"
}

sql "insert into internal.job_failures (job, error_code, detail, reported_at)
     values ('$job', E'$marker\nsecond line\tafter tab', '{\"note\": \"$marker\"}', now());"

dump="$work/dump"
expect_ok 'the dump' "$root/scripts/backup-dump.sh" "$DB_URL" "$dump"

cases=$((cases + 1))
if grep -q "$marker" "$dump/data.sql"; then
  pass 'the marker row is in data.sql'
else
  fail "data.sql does not hold the marker row; the checks below would prove nothing."
fi

expect_ok 'the restore check' "$root/scripts/backup-restore-check.sh" "$dump"
cat "$work/out.log"

# Encryption to a fresh key.
age-keygen -o "$work/key.txt" >/dev/null 2>&1
age-keygen -y "$work/key.txt" >"$work/recipients.txt"
expect_ok 'the encryption' "$root/scripts/backup-encrypt.sh" "$dump" "$work/recipients.txt" "$work/dump.tar.gz.age"

cases=$((cases + 1))
if [ ! -s "$work/dump.tar.gz.age" ]; then
  fail 'the encrypted file is missing or empty.'
elif grep -aq "$marker" "$work/dump.tar.gz.age"; then
  fail 'the encrypted file holds the marker text.'
else
  pass 'the encrypted file holds no marker text'
fi

cases=$((cases + 1))
mkdir "$work/decrypted"
if age -d -i "$work/key.txt" "$work/dump.tar.gz.age" | tar -xz -C "$work/decrypted" &&
  diff -r "$dump" "$work/decrypted" >"$work/diff.log" 2>&1; then
  pass 'the decrypted files equal the dump'
else
  fail 'the decrypted files differ from the dump (or decryption failed):' "$work/diff.log"
fi

# A dump with a failing statement.
cp -R "$dump" "$work/bad-sql"
printf '\nselect 1/0;\n' >>"$work/bad-sql/schema.sql"
line="$(wc -l <"$work/bad-sql/schema.sql" | tr -d ' ')"
expect_fail 'a dump with a failing statement' 1 "schema\\.sql:$line SQLSTATE 22012" -- \
  "$root/scripts/backup-restore-check.sh" "$work/bad-sql"

# A dump whose restored table loses rows.
cp -R "$dump" "$work/bad-count"
printf '\ndelete from "internal"."job_failures";\n' >>"$work/bad-count/data.sql"
expect_fail 'a dump that deletes restored rows' 1 \
  '"internal"\."job_failures": the dump has [1-9][0-9]* rows, the restored table has 0' -- \
  "$root/scripts/backup-restore-check.sh" "$work/bad-count"

# After the last restore check: the passing run and both failing runs.
cases=$((cases + 1))
if docker ps -a --format '{{.Names}}' | grep -q 'fermi-restore-check'; then
  fail 'a restore check left its database container behind.'
else
  pass 'the three restore checks left no container'
fi

# Bad recipients: no output file.
: >"$work/empty.txt"
printf 'not-a-key\n' >"$work/bad-key.txt"
for case_file in empty.txt bad-key.txt; do
  expect_fail "recipients file $case_file" 1 'recipients|Recipients' -- \
    "$root/scripts/backup-encrypt.sh" "$dump" "$work/$case_file" "$work/$case_file.age"
  cases=$((cases + 1))
  if [ -e "$work/$case_file.age" ] || [ -e "$work/$case_file.age.partial" ]; then
    fail "recipients file $case_file: encrypt wrote an output file."
  else
    pass "recipients file $case_file: no output written"
  fi
done

# A database that refuses the connection (the pooler down, a wrong password).
bad_url="$(printf '%s' "$DB_URL" | sed -E 's#^(postgresql://[^:]+):[^@]*@#\1:wrong-password@#')"
expect_fail 'a dump with a wrong password' 1 'password authentication failed' -- \
  "$root/scripts/backup-dump.sh" "$bad_url" "$work/refused"

# Missing arguments.
for script in backup-dump.sh backup-encrypt.sh backup-restore-check.sh; do
  expect_fail "$script without arguments" 2 'usage' -- "$root/scripts/$script"
done

if [ "$failures" -ne 0 ]; then
  echo "$failures of $cases backup case(s) did not behave as expected."
  exit 1
fi
echo "All $cases backup cases behaved as expected."
