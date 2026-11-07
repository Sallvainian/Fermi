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
status: done 2026-11-06
resolution: resolved by story 1.3
resolution-undo: 59de52defe7c2e46512b2a8ff64291b5d8476c498e8ee13e5b3a8ba04f0606c9 2026-11-06 7374617475733a206f70656e

### DW-3: Nothing automated guards that anon and authenticated lack USAGE on schemas app and internal, or that neither is added to [api] schemas, until the pgTAP lane and the privilege fixture exist.
origin: spec-deferred c0804412c0ba
location: supabase/migrations/20261106190000_create_app_and_internal_schemas.sql
source_spec: `tickets/epic-platform-baseline/tickets/story-the-empty-app-ships-to-workers-dev-from-a-push-to-main-plan.md`
severity: medium
reason: The migration's check ran once on a scratch local stack (2 schemas, 0 objects, has_schema_privilege false x4, PGRST106). Story 3 owns the pgTAP lane and story 6 the catalog test; a schema-privilege case belongs in the first of them.
status: done 2026-11-06
resolution: resolved by story 1.3
resolution-undo: 59de52defe7c2e46512b2a8ff64291b5d8476c498e8ee13e5b3a8ba04f0606c9 2026-11-06 7374617475733a206f70656e

### DW-4: The Capacitor template's Info.plist adds UIRequiredDeviceCapabilities = armv7, which the live Flutter build's Info.plist does not have.
origin: spec-deferred 84a633284180
location: app/ios/App/App/Info.plist
source_spec: `tickets/epic-platform-baseline/tickets/story-the-ios-shell-runs-in-the-simulator-under-fermi-s-bundle-plan.md`
severity: medium
reason: grep -c UIRequiredDeviceCapabilities ios/Runner/Info.plist is 0. Whether App Store Connect refuses an update that adds this key (it excludes no device that runs iOS 15) is UNVERIFIED; Capacitor apps ship with it routinely. Settled at epic-app-store-release's first TestFlight upload, or by removing the key in a native build before then. (declared severity: medium (unverified))
status: open

### DW-5: The iOS project ships Capacitor's placeholder app icon and splash images, which would replace Fermi's icon on the listing if uploaded as is.
origin: spec-deferred 133f23344436
location: app/ios/App/App/Assets.xcassets
source_spec: `tickets/epic-platform-baseline/tickets/story-the-ios-shell-runs-in-the-simulator-under-fermi-s-bundle-plan.md`
severity: low
reason: AppIcon-512@2x.png and the three identical splash-2732x2732 PNGs are the template defaults. This epic builds for the Simulator only; App Store builds are epic-app-store-release's (epic Boundaries), which needs real icon and splash assets before its first upload.
status: open

### DW-6: A twice-daily keep-alive sees only the last 6 hours of pg_net responses, because pg_net deletes net._http_response rows after pg_net.ttl.
origin: spec-deferred ed8bfe938c4d
location: supabase/migrations/20261106230000_enable_cron_net_and_job_health.sql (http source of public.job_health)
source_spec: `tickets/epic-platform-baseline/tickets/story-the-keep-alive-keeps-the-free-project-awake-and-reports-fail-plan.md`
severity: medium
reason: Local stack: show pg_net.ttl = 6 hours, context sighup; alter database / alter role ... set pg_net.ttl as postgres fail ("cannot be changed now"), so no migration can raise it. R8 and AD-21 fix the cadence at twice daily. Fix options for the owner or architect: check every 6 hours or less, or add a pg_cron job that copies non-2xx responses into internal.job_failures. No pg_net call exists until a later epic (sweep-storage, send-push) adds one.
status: open

### DW-7: The monthly re-enable call made with github.token may make GitHub send failed scheduled-run emails to github-actions[bot] instead of the owner.
origin: spec-deferred 7ec2def5483e
location: .github/workflows/keep-alive.yml (re-enable job)
source_spec: `tickets/epic-platform-baseline/tickets/story-the-keep-alive-keeps-the-free-project-awake-and-reports-fail-plan.md`
severity: high
reason: GitHub's notification docs: when a scheduled workflow is disabled and then re-enabled, notifications go to the user who re-enabled it. Whether PUT /actions/workflows/{id}/enable on an already-enabled workflow counts is undocumented. Settles it: after a manual keep-alive run (which runs the re-enable job), a failing scheduled run emails the owner. If it does not, call the enable endpoint with the owner's token, or drop the call and rely on other repository activity. (declared severity: high (unverified))
status: open

### DW-8: A native change passes the check when it raises MIN_NATIVE_BUILD to a value at or below a build number that already shipped without that change.
origin: spec-deferred 77cb954e51a0
location: scripts/check-native-build.sh:390
source_spec: `tickets/epic-platform-baseline/tickets/story-each-deploy-publishes-a-live-update-with-its-minimum-native-plan.md`
severity: medium
reason: scripts/check-native-build.sh requires head MIN > base MIN and MIN <= every CURRENT_PROJECT_VERSION, as the ticket and this plan's intent define "raised". Once a web-only App Store build puts CURRENT_PROJECT_VERSION above MIN (e.g. Xcode 10, MIN 8), a native change raising MIN to 9 and leaving the pbxproj at 10 passes; installs on build 10, which lack the new native code, would then accept the bundle that needs it. AGENTS.md says a native change raises both numbers, which would close it (new MIN above the base's highest CURRENT_PROJECT_VERSION). Not reachable today (8/8, no App Store build until epic-app-store-release). Settling it changes AD-18's / the ticket's rule, which is the owner's or architect's call.
status: open
