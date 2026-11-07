#!/usr/bin/env bash
# Runs every lane of .github/workflows/test.yml on this machine, in the same
# order and with the same commands, and stops at the first failure.
#
# Needs: Node 24, Deno 2, Docker, Supabase CLI 2.122.0, `npm ci` and
# `npx playwright install chromium webkit` done in app/.
# Usage, from anywhere in the repo: scripts/ci-local.sh
# Burn-in is left out: it needs committed changes; run
# `npm run test:burn-in -- --base-branch=main` in app/ for it.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

step() { printf '\n=== %s\n' "$1"; }

step 'Lint & Type Check'
(cd app && npm run lint && npm run typecheck)

step 'Unit Tests'
(cd app && npm run test:unit:coverage)

step 'Migration Check'
node scripts/check-migrations.ts

step 'Edge Function Tests'
if [ -d supabase/functions ]; then
  deno test --no-lock --permit-no-files supabase/functions
else
  echo 'supabase/functions does not exist yet: no edge functions to test.'
fi

step 'Health Check Tests'
scripts/test-check-site.sh
scripts/test-check-hosted-config.sh

step 'Database Tests'
supabase status >/dev/null 2>&1 || supabase start
supabase test db
scripts/test-check-job-health.sh

for project in chromium webkit api; do
  step "Playwright ($project)"
  folder=tests/e2e
  [ "$project" = api ] && folder=tests/api
  # CI=1, as on GitHub's runners: retries, 2 workers, forbidOnly and a fresh server.
  (cd app && CI=1 npx playwright test --project="$project" && scripts/check-test-counts.sh "$project" "$folder")
done

printf '\nAll lanes passed.\n'
