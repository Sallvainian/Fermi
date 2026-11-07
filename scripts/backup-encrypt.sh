#!/usr/bin/env bash
# Encrypts the five dump files from scripts/backup-dump.sh into one
# <out-file> (a .tar.gz.age) readable only with the private keys behind the
# recipients. The only copy of the dump that may leave the runner.
#
# <recipients-file> holds one age public key (age1...) per line; blank lines and
# lines starting with # are ignored. An empty file, or a line that is not a key,
# exits 1 before any output is written. A rejected line is named by number, not
# printed.
#
# The owner decrypts with:  age -d -i <identity-file> <out-file> | tar -xz
#
# Exits 2 on wrong arguments, 1 on a bad recipients file or a failed encryption.
# Needs: tar, age.
# Usage: scripts/backup-encrypt.sh <dump-dir> <recipients-file> <out-file>
set -euo pipefail

if [ "$#" -ne 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "usage: $0 <dump-dir> <recipients-file> <out-file>" >&2
  exit 2
fi
dump="$1"
recipients="$2"
out="$3"
files=(roles.sql schema.sql data.sql history_schema.sql history_data.sql)

if [ ! -f "$recipients" ]; then
  echo "::error::The recipients file does not exist."
  exit 1
fi
keys=0
line_no=0
while IFS= read -r line || [ -n "$line" ]; do
  line_no=$((line_no + 1))
  if [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]]; then
    continue
  fi
  if [[ "$line" =~ ^age1[0-9a-z]+$ ]]; then
    keys=$((keys + 1))
  else
    echo "::error::Recipients line $line_no is not an age public key (age1...)."
    exit 1
  fi
done <"$recipients"
if [ "$keys" -eq 0 ]; then
  echo "::error::The recipients file holds no age public key."
  exit 1
fi

for file in "${files[@]}"; do
  if [ ! -s "$dump/$file" ]; then
    echo "::error::$dump/$file is missing or empty."
    exit 1
  fi
done

partial="$out.partial"
rm -f "$out" "$partial"
trap 'rm -f "$partial"' EXIT
tar -czf - -C "$dump" "${files[@]}" | age -R "$recipients" -o "$partial"

if [ "$(head -n 1 "$partial" | tr -d '\r')" != "age-encryption.org/v1" ]; then
  echo "::error::The output is not an age file."
  exit 1
fi
mv "$partial" "$out"
echo "Encrypted to $keys recipient(s): $(basename "$out")."
