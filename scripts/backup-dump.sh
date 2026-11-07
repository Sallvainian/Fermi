#!/usr/bin/env bash
# Dumps a Supabase database to five plaintext SQL files in <out-dir>:
#   roles.sql           roles (supabase db dump --role-only)
#   schema.sql          schema of the user schemas (managed schemas are excluded)
#   data.sql            data of every schema, as COPY blocks (--data-only --use-copy)
#   history_schema.sql  schema of supabase_migrations
#   history_data.sql    migration history rows, as COPY blocks
#
# One dump path for .github/workflows/backup.yml and scripts/test-backup.sh.
# The files are plaintext: <out-dir> must be outside the workspace (mktemp,
# $RUNNER_TEMP) and is never an artifact. Nothing here prints a row.
#
# Exits 2 on wrong arguments, 1 if a dump fails or leaves a file missing or empty.
# Needs: the Supabase CLI (2.122.0) and Docker, which the CLI's pg_dump runs in.
# Usage: scripts/backup-dump.sh <db-url> <out-dir>
set -euo pipefail

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "usage: $0 <db-url> <out-dir>" >&2
  exit 2
fi
db_url="$1"
out="$2"

mkdir -p "$out"

dump() {  # <file> <supabase db dump flag>...
  local file="$1"
  shift
  supabase db dump --db-url "$db_url" -f "$out/$file" "$@" >/dev/null
}

dump roles.sql --role-only
dump schema.sql
dump data.sql --data-only --use-copy
dump history_schema.sql --schema supabase_migrations
dump history_data.sql --data-only --use-copy --schema supabase_migrations

for file in roles.sql schema.sql data.sql history_schema.sql history_data.sql; do
  if [ ! -s "$out/$file" ]; then
    echo "::error::The dump left $file missing or empty."
    exit 1
  fi
done
echo "Dumped 5 files to $out."
