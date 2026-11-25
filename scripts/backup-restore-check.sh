#!/usr/bin/env bash
# Proves a plaintext dump from scripts/backup-dump.sh restores: starts a
# throwaway local Supabase database, restores the five files into it in one
# transaction, then compares every table the data files COPY in (but a skipped
# block, below) with the rows the restored table holds.
#
# The database is the only target: project "fermi-restore-check" on ports
# 575xx (563xx is Fermi's local stack, 543xx My-Love's), in a temp dir. The trap
# stops it and deletes the dir, which holds at most a copy of data.sql with
# skipped blocks (below).
#
# schema.sql never defines the auth and storage schemas' tables: Supabase's own
# services create them, so the throwaway database has those of the pinned CLI's
# images, and hosted Supabase can run a newer service with a table or a column
# they lack.
# An empty COPY block for such a table restores nothing, so it is skipped and
# named in the log (its two lines become comments, keeping line numbers). One
# that holds rows fails the check: this database could not hold them.
#
# The restore runs as supabase_admin: as postgres, roles.sql's
# GRANT SET ON PARAMETER fails locally (postgres is not a superuser there).
#
# The log never shows row data. psql runs with VERBOSITY=sqlstate and its stderr
# goes to a temp file, of which only "file:line SQLSTATE code" lines print. The
# comparison prints totals and, for a mismatch, the table name and both counts.
#
# COPY text format puts one row per line (newlines inside a value are escaped),
# so a table's rows are the lines between its COPY ... FROM stdin; and \.
#
# Exits 2 on wrong arguments, 1 if the restore or a comparison fails.
# Needs: the Supabase CLI (2.122.0), Docker, psql, awk.
# Usage: scripts/backup-restore-check.sh <dump-dir>
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: $0 <dump-dir>" >&2
  exit 2
fi
dump="$1"
files=(roles.sql schema.sql data.sql history_schema.sql history_data.sql)
for file in "${files[@]}"; do
  if [ ! -s "$dump/$file" ]; then
    echo "::error::$dump/$file is missing or empty."
    exit 1
  fi
done

root="$(cd "$(dirname "$0")/.." && pwd)"
project=fermi-restore-check
work="$(mktemp -d)"
db_url="postgresql://supabase_admin:postgres@127.0.0.1:57522/postgres"

stop_db() { supabase stop --no-backup --workdir "$work" >/dev/null 2>&1 || true; }
cleanup() {
  stop_db
  rm -rf "$work"
}
trap cleanup EXIT

# Prints the error lines of a psql stderr file that carry no row data: the
# position and SQLSTATE of an SQL error, a meta-command error, and a failed
# connection. Paths are cut to the file name.
print_psql_errors() {  # <stderr file>
  sed -nE \
    -e 's#^psql:.*/([^/:]+):([0-9]+): ERROR:  ([0-9A-Z]{5})$#\1:\2 SQLSTATE \3#p' \
    -e 's#^psql:.*/([^/:]+):([0-9]+): (invalid command .*)$#\1:\2 \3#p' \
    -e '/^psql: error: /p' "$1"
}

major="$(sed -nE 's/^major_version = ([0-9]+)$/\1/p' "$root/supabase/config.toml" | head -n 1)"
if [ -z "$major" ]; then
  echo "::error::supabase/config.toml has no major_version."
  exit 1
fi

supabase init --yes --workdir "$work" >"$work/init.log" 2>&1 || {
  cat "$work/init.log"
  echo "::error::supabase init failed."
  exit 1
}
config="$work/supabase/config.toml"
sed -E -i.bak \
  -e "s/^project_id = .*/project_id = \"$project\"/" \
  -e 's/^((shadow_)?port = )543([0-9]{2})$/\1575\3/' \
  -e "s/^major_version = .*/major_version = $major/" \
  "$config"
rm -f "$config.bak"

# An earlier run that was killed before its trap leaves the container behind.
stop_db
echo "Starting the throwaway database (project $project, port 57522)."
supabase db start --workdir "$work" >/dev/null 2>"$work/start.log" || {
  cat "$work/start.log"
  echo "::error::The throwaway database did not start."
  exit 1
}

# Table name and COPY row count of each block, in dump order.
for file in data.sql history_data.sql; do
  awk '
    inblock && $0 == "\\." { print name "\t" rows; inblock = 0; next }
    inblock { rows++; next }
    /^COPY "/ {
      name = $2
      inblock = 1
      rows = 0
    }
  ' "$dump/$file"
done >"$work/expected.tsv"

# data.sql's auth and storage tables that the throwaway database lacks, or lacks
# a column of (see the header): name, COPY row count and column list. One query
# per table, in the order of service.tsv. The column list ("a", "b") is also the
# inside of an array literal.
awk '
  inblock && $0 == "\\." { if (service) print name "\t" rows "\t" cols; inblock = 0; next }
  inblock { rows++; next }
  /^COPY "/ {
    name = $2
    service = (name ~ /^"(auth|storage)"\./)
    cols = $0
    if (!sub(/^COPY [^ ]+ \(/, "", cols) || !sub(/\) FROM stdin;$/, "", cols)) cols = ""
    inblock = 1
    rows = 0
  }
' "$dump/data.sql" >"$work/service.tsv"
: >"$work/skip.txt"
if [ -s "$work/service.tsv" ]; then
  # Prints "table" for a missing table, else its missing columns, else "-".
  sed "s/'/''/g" "$work/service.tsv" | awk -F'\t' -v q="'" '{
    name = q $1 q
    printf "select case when to_regclass(%s) is null then %stable%s else coalesce((", name, q, q
    printf "select string_agg(c, %s, %s order by c) from unnest(%s{%s}%s::text[]) c ", q, q, q, $3, q
    printf "where not exists (select from pg_attribute where attrelid = to_regclass(%s) ", name
    printf "and attname = c and attnum > 0 and not attisdropped)), %s-%s) end;\n", q, q
  }' >"$work/exists.sql"
  psql "$db_url" -X -qAt -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate \
    -f "$work/exists.sql" >"$work/missing.txt" 2>"$work/exists.err" || {
    echo "::error::Checking the throwaway database's auth and storage tables failed:"
    print_psql_errors "$work/exists.err"
    exit 1
  }
  # name, rows, and what is missing in words ("-" for nothing).
  cut -f1,2 "$work/service.tsv" | paste - "$work/missing.txt" | awk -F'\t' '
    $3 == "table" { print $1 "\t" $2 "\thas no such table"; next }
    $3 == "-" { print; next }
    { print $1 "\t" $2 "\tlacks its column(s) " $3 }
  ' >"$work/service-missing.tsv"
  if ! awk -F'\t' '
    $3 != "-" && $2 > 0 {
      printf "::error::%s holds %d rows, but the throwaway database %s: hosted Supabase runs a newer service than the pinned CLI'"'"'s image.\n", $1, $2, $3
      bad++
    }
    END { exit bad ? 1 : 0 }
  ' "$work/service-missing.tsv"; then
    exit 1
  fi
  awk -F'\t' '$3 != "-" { print $1 }' "$work/service-missing.tsv" >"$work/skip.txt"
fi

data_file="$dump/data.sql"
if [ -s "$work/skip.txt" ]; then
  awk -F'\t' '$3 != "-" { printf "skipped %s: empty, and the throwaway database %s\n", $1, $3 }' \
    "$work/service-missing.tsv"
  data_file="$work/data.sql"
  # Data lines are passed through before any COPY test, so a row that reads
  # like a COPY line is never taken for one.
  awk '
    NR == FNR { skip[$0] = 1; next }
    inblock && $0 == "\\." {
      print (inskip ? "-- end of skipped block" : $0)
      inblock = 0
      inskip = 0
      next
    }
    inblock { print; next }
    /^COPY "/ {
      inblock = 1
      if ($2 in skip) { print "-- skipped COPY " $2; inskip = 1; next }
    }
    { print }
  ' "$work/skip.txt" "$dump/data.sql" >"$data_file"
  awk -F'\t' 'NR == FNR { skip[$0] = 1; next } !($1 in skip)' \
    "$work/skip.txt" "$work/expected.tsv" >"$work/expected.kept"
  mv "$work/expected.kept" "$work/expected.tsv"
fi

psql_args=(-X -q --single-transaction -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate)
set +e
psql "$db_url" "${psql_args[@]}" \
  -f "$dump/roles.sql" -f "$dump/schema.sql" \
  -c 'SET session_replication_role = replica' -f "$data_file" \
  -f "$dump/history_schema.sql" -f "$dump/history_data.sql" \
  >/dev/null 2>"$work/restore.err"
status=$?
set -e
if [ "$status" -ne 0 ]; then
  echo "::error::The restore failed (psql exit $status):"
  # Never the message text of an SQL error: it can quote a row.
  print_psql_errors "$work/restore.err"
  exit 1
fi

tables="$(wc -l <"$work/expected.tsv" | tr -d ' ')"
if [ "$tables" -eq 0 ]; then
  echo "::error::The dump files hold no COPY block; nothing to compare."
  exit 1
fi

# COPY "s"."t" (...): the table name is the second field of the COPY line.
# One count(*) per table, in the order of expected.tsv.
cut -f1 "$work/expected.tsv" |
  sed -E 's/^(.*)$/select count(*) from \1;/' >"$work/count.sql"
psql "$db_url" -X -qAt -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate \
  -f "$work/count.sql" >"$work/actual.txt" 2>"$work/count.err" || {
  echo "::error::Counting the restored rows failed:"
  print_psql_errors "$work/count.err"
  exit 1
}

paste "$work/expected.tsv" "$work/actual.txt" |
  awk -F'\t' -v tables="$tables" '
    { total += $3 }
    $2 != $3 {
      printf "::error::%s: the dump has %d rows, the restored table has %d.\n", $1, $2, $3
      bad++
    }
    END {
      if (bad) { printf "%d of %d tables differ.\n", bad, tables; exit 1 }
      printf "restored %d tables, %d rows\n", tables, total
    }
  '
