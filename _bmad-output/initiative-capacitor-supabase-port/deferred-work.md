### DW-1: The hosted project's Auth sign-up and exposed-schemas settings are not set by this story; config.toml governs only the local stack until a config push runs.
origin: spec-deferred 9630ff90f854
location: .github/workflows/deploy.yml
source_spec: `tickets/epic-platform-baseline/tickets/story-the-empty-app-ships-to-workers-dev-from-a-push-to-main-plan.md`
severity: medium
reason: deploy.yml runs supabase link and db push only (no supabase config push, by the plan's Never list and the epic's R2 split). Whether hosted sign-up is currently on is UNVERIFIED; the migration's REVOKE does reach the hosted database. Settled by the story that adds the hosted Auth config push and its health-check assertion. (declared severity: medium (unverified))
status: open

### DW-2: scripts/check-site.sh's failure branches (stale id, asset served as HTML, id missing from JS) have no automated test that runs regularly.
origin: spec-deferred 88f426d3d365
location: scripts/check-site.sh
source_spec: `tickets/epic-platform-baseline/tickets/story-the-empty-app-ships-to-workers-dev-from-a-push-to-main-plan.md`
severity: medium
reason: They were exercised only by this build's verification commands; the repo has no shell test harness and no app/ CI lane yet. The epic gives CI lanes to story 3 (test.yml), where a run against vite preview with a right and a wrong id would cover them.
status: open

### DW-3: Nothing automated guards that anon and authenticated lack USAGE on schemas app and internal, or that neither is added to [api] schemas, until the pgTAP lane and the privilege fixture exist.
origin: spec-deferred c0804412c0ba
location: supabase/migrations/20261106190000_create_app_and_internal_schemas.sql
source_spec: `tickets/epic-platform-baseline/tickets/story-the-empty-app-ships-to-workers-dev-from-a-push-to-main-plan.md`
severity: medium
reason: The migration's check ran once on a scratch local stack (2 schemas, 0 objects, has_schema_privilege false x4, PGRST106). Story 3 owns the pgTAP lane and story 6 the catalog test; a schema-privilege case belongs in the first of them.
status: open
