<!-- bmad:context -->
<!-- Verified 2026-11-07 against 10fef35. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## Fermi

A web app: a Vite + React app in `app/` on Supabase (`supabase/`: migrations, pgTAP tests, edge functions), served by Cloudflare. Planning and tickets live in `_bmad-output/initiative-capacitor-supabase-port/`; test docs in `app/tests/README.md`.

## Policy

- Main merges only on green CI: the Main ruleset requires `Test Summary` and `Dependency Review`. A check that must block a merge is a job in `.github/workflows/test.yml` listed in `Test Summary`'s `needs`, added in the same change as the job.
- `test.yml` reads no repo or environment secret, so Dependabot pull requests run every lane. A lane that needs a secret goes in a deploy or scheduled workflow, never in `test.yml`.

## Conventions that differ from defaults

- Playwright specs import from `app/tests/support/merged-fixtures.ts` and use `@seontechnologies/playwright-utils` for every capability it covers; never import `@playwright/test` directly. A vanilla Playwright equivalent needs a `// playwright-utils deviation: <reason>` comment.

<!-- /bmad:context -->
