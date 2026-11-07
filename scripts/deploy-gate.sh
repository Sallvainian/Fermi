#!/usr/bin/env bash
# Decides whether deploy.yml's daily run deploys: prints `deploy=false` only when
# the site's updates/latest.json already names the given commit, and
# `deploy=true` otherwise. It fails open: a missing file or any non-200
# response (even one whose body names the commit), the SPA's HTML, bad JSON or
# a network error all print `deploy=true`, because an extra deploy of an
# unchanged commit is harmless and a missed one leaves a merge unshipped.
#
# Usage: scripts/deploy-gate.sh <site-url> <commit>
# Exit 0 with one `deploy=...` line on stdout (append it to GITHUB_OUTPUT);
#      2 bad usage.
set -euo pipefail

if [ "$#" -ne 2 ] || [ -z "$2" ]; then
  echo "usage: $0 <site-url> <commit>" >&2
  exit 2
fi

site="${1%/}"
commit="$2"

live="$(curl -sS --fail -L --max-time 30 "$site/updates/latest.json" 2>/dev/null \
  | jq -r 'if type == "object" then (.version // "" | tostring) else "" end' 2>/dev/null || true)"

if [ -n "$live" ] && [ "$live" = "$commit" ]; then
  echo "::notice::Commit $commit is already live; nothing to deploy." >&2
  echo "deploy=false"
else
  echo "The live update is '${live:-none}'; deploying $commit." >&2
  echo "deploy=true"
fi
