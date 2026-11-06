---
review: adversarial
target: architecture-capacitor-supabase-port.md and epic-map-capacitor-supabase-port.md, update 2026-11-06c (.github audit: epic-platform-baseline takes Dependabot, dependency review, auto-merge, the Main ruleset's required check, the Claude workflows' retarget and the removal of the old workflows, src/index.js and ten secrets; epic-app-store-release keeps Flutter, Firebase, functions/ and the Pages project)
lens: two units one level down that each obey every AD to the letter yet build incompatibly (clashing shapes, two owners of one entity, conflicting state-mutation paths)
reviewed: 2026-11-06
scope: CI and merge gating, workflow ownership and Dependabot across the 13 epics
prior: reviews/review-adversarial-update-2026-11-06.md (U1-U7), reviews/review-adversarial-update-2026-11-06b.md (N1-N10); none repeated here
---

# Adversarial review: the .github audit moves CI ownership into epic 1

## Verdict

**Needs amendment before the next epic plans against it.** The ownership move is right and internally consistent between the epic map row 1, row 13 and epic 1's stories 1, 12 and 13. But the change put a merge gate and unattended auto-merge into the system without any AD governing them. As a result:

- AD-18's native-change rule now collides with Dependabot auto-merge.
- Nothing says which checks gate a merge, so a lane that a later epic adds can sit outside the gate.
- The Structural Seed's new comment names the wrong owner for `apple-secret.yml`.
- The Apple client secret has two writers.

There are 2 HIGH findings that need a new or tightened AD (F1, F2), 1 HIGH that needs AD-21 and the Secrets row fixed (F3), 2 MEDIUM and 3 LOW.

**Sources read:** the spine (457 lines, `wc -l`) and its diff; the epic map (76 lines) and its diff; the memlog's 2026-11-06c lines; epic-platform-baseline.md (103 lines); its `tickets/tickets.toml` (144 lines, all stories); epic-app-store-release.md (54 lines); the initiative's touch points and Notes (lines 96-97, 138); the current `.github/` tree; and My-Love's `dependabot.yml`, `dependabot-auto-merge.yml`, `test.yml` (change gates, summary job), `deploy.yml` and `package.json`, which stories 1, 3 and 13 copy.

## Findings

### F1. Dependabot auto-merge and AD-18 disagree about Capacitor bumps — HIGH

- **Unit A (epic 1, stories 1 and 13):** `dependabot.yml` "on My-Love's model" groups every production minor/patch update together. In My-Love that group contains `@capacitor/core`, `@capacitor/ios`, `@capacitor/push-notifications` and `@capgo/capacitor-updater`, and the dev group contains `@capacitor/cli`; all of them are dependencies in My-Love's `package.json:40-60`. `dependabot-auto-merge.yml` on My-Love's model auto-merges "every Dependabot PR, including majors". Both obey every AD, since no AD mentions Dependabot.
- **Unit B (epic 1, story 9, and AD-18):** a Capacitor plugin change is a native change that raises `MIN_NATIVE_BUILD`. Story 9 adds "a test.yml check" that fails a PR changing a Capacitor plugin in `app/package.json` without raising it, and packaging refuses a `MIN_NATIVE_BUILD` above the Xcode build number.
- **How they diverge.** Nothing says whether story 9's check is under the summary job (see F2), so both outcomes are reachable:
  - **Check gated:** every weekly production and dev group that carries a Capacitor patch fails forever. `@capgo/capacitor-updater` releases often; the Stack pins 8.54.2. Dependabot cannot raise `MIN_NATIVE_BUILD` or the build number, so the group's web-only updates (supabase-js, React, zod) stall with it. R12's "a Dependabot pull request merges itself" stops holding in steady state.
  - **Check not gated:** the bump auto-merges, deploys and ships as a live update. Every installed shell then runs JS of `@capacitor/core` (or of the updater itself) N+1 against native N. AD-18 exists to prevent exactly that. Before epic 13 the damage is limited to the Simulator; after epic 13 it reaches every App Store user.
- **Later epics widen it.** Epic 6 adds `@capacitor/push-notifications` (Stack line 323), and epics 2 and 4 may add the NativeAuth and picker plugins. A plugin outside the `@capacitor/` scope is caught only if the Dependabot group and story 9's check use the same list.
- **Evidence:**
  - spine AD-18 `architecture-capacitor-supabase-port.md:259`
  - Stack `:322-324`
  - `tickets/epic-platform-baseline/tickets/tickets.toml:7` (story 1: dependabot.yml groups), `:51` (story 13: auto-merge), `:117` (story 9: the check and packaging refusal)
  - `epic-platform-baseline.md:35-36` (R11, R12), `:59` (Done when)
  - `/Users/sallvain/Projects/My-Love/.github/workflows/dependabot-auto-merge.yml:1`
  - `/Users/sallvain/Projects/My-Love/.github/dependabot.yml` (production-dependencies group)
- **Fix (tighten AD-18):** "Native packages are `@capacitor/*`, `@capgo/*` and every Capacitor plugin, listed once in one checked-in pattern list. Bumping one is a native change in any PR, Dependabot's included. That list is used both by `dependabot.yml`, which gives native packages their own group listed first with all update types, and by the `MIN_NATIVE_BUILD` check, which is a lane under the merge gate (AD-23). `dependabot-auto-merge.yml` never merges the native group. The owner raises `MIN_NATIVE_BUILD` and the build number on its branch and merges it by hand. A later epic that adds a plugin adds it to the list in the same change."

### F2. No AD names the merge gate, so a later lane or workflow can sit outside it — HIGH

- **Unit A (epic 1, story 13):** the Main ruleset requires only `test.yml`'s summary job (epic map row 1; R12). Story 3 copies My-Love's summary job. That job gates only the jobs named in its explicit `needs:` list and its `check` calls (My-Love `test.yml:639` and the `check` lines after it). A job missing from either list is not gated.
- **Unit B (any later epic, or story 9):** obeying the Tests row (`:313`), it adds tests as a new job in `test.yml`, or as a new workflow. Examples:
  - story 9's `MIN_NATIVE_BUILD` check (F1);
  - an epic 6 service-worker or `send-push` lane;
  - an epic 13 TestFlight build check.

  The new check turns red, the summary stays green, and the auto-merge from Unit A merges it. No AD is broken: AD-3 and AD-21, which the capability map row K7/K13 (`:433`) cites as governing deploy and tests, say nothing about gating.
- **Second divergence: secrets.** Workflows triggered by Dependabot PRs get no Actions secrets (repo or environment), only Dependabot secrets. A later lane that reads a secret (a hosted-project URL, VAPID keys for a send-push test) obeys the Secrets row (`:315`, "GitHub secrets in CI"). It also turns every Dependabot PR red for good, which stalls R12's auto-merge. My-Love's `test.yml` reads no secret today, but nothing in the spine requires that.
- **Third divergence: change gates.** My-Love's per-lane change gates are allowlists of paths. Story 3 has to rewrite them for `app/`. A later epic that adds code under a path no gate lists (for example a Fermi-hosted Drive picker page, or a web-push service worker) has its lane skipped silently, and the summary accepts "skipped" when the gate is false.
- **Evidence:**
  - epic map row 1 `epic-map-capacitor-supabase-port.md:43`
  - spine Tests row `:313`, Secrets row `:315`, capability row `:433`, AD-21 `:277-288`
  - `tickets.toml:40` (story 3: "one summary job that passes only when every lane passes"), `:117` (story 9: "a test.yml check")
  - `/Users/sallvain/Projects/My-Love/.github/workflows/test.yml:60-160` (gates), `:634-680` (summary)
- **Fix (new AD-23, "One merge gate", binds all epics, owned by epic-platform-baseline):**
  - "The Main ruleset requires exactly one check, `test.yml`'s summary job, whose name is fixed."
  - "Every check that must block a merge is a job in `test.yml`, added to the summary's `needs` and evaluation in the same change that adds the job. A check in another workflow is advisory and its file says so."
  - "`test.yml` reads no repo or environment secret; it runs against the local stack only, so Dependabot and fork PRs run every lane."
  - "Each lane's change gate errs to true: an epic that adds a new source path adds it to the gates of the lanes that test it."
  - Add AD-23 and R12 to the capability row K7/K13.

### F3. The Apple client secret has two writers, and the Secrets row puts it in a store that Auth never reads — HIGH

- **Unit A (epic 1, deploy.yml):** AD-21's deploy order pushes the hosted Auth config with `supabase config push`, with provider secrets through `env()`. Once epic 2 adds `[auth.external.apple] secret = "env(...)"` (My-Love's `supabase/config.toml:303` does the same), every deploy writes whatever the GitHub secret holds into hosted Auth.
- **Unit B (epic 2, `apple-secret.yml`):** AD-21 says it regenerates the Apple client secret from the `.p8` monthly. It cannot update a GitHub secret with `GITHUB_TOKEN`. So, obeying the Secrets row (`:315`, "Supabase function secrets for APNs, VAPID and the Apple secret"), it writes either a function secret or the hosted Auth config directly through the Management API.
  - **Function secret:** Auth never reads it.
  - **Hosted Auth directly:** the next push to main (and Dependabot auto-merge now makes those weekly and unattended) overwrites it with the GitHub secret's older JWT. Once that JWT is past Apple's 6-month limit, teacher sign-in with Apple fails, and the AD-21 health check does not assert it.
- **Evidence:**
  - spine AD-21 `:283` (config push, `env()`), `:287` (Apple secret)
  - Secrets row `:315`
  - epic map row 2 `:44` (`apple-secret.yml`)
  - `tickets/epic-invite-sign-in/epic-invite-sign-in.md:17` ("the Apple secret renewal workflow")
  - `/Users/sallvain/Projects/My-Love/supabase/config.toml:299-303`
  - My-Love has no Apple-secret workflow to copy (`ls .github/workflows`).
- **Fix (tighten AD-21's Apple secret bullet and the Secrets row):**
  - AD-21: "The Apple client secret is derived, never stored. One script mints it from the `.p8`, key id, team id and services id, which are held in the Production environment. Both `deploy.yml`'s config-push step and the monthly `apple-secret.yml` call that script, and `apple-secret.yml` does nothing but rerun the config push."
  - Secrets row: remove "the Apple secret" from function secrets.

### F4. The Structural Seed contradicts the epic map on `apple-secret.yml`, and later epics' edits to epic 1's workflows have no rule — MEDIUM

- **Unit A:** the new Seed comment lists `apple-secret.yml` among the workflows and ends "(all epic-platform-baseline)". AD-21 also binds "epic-platform-baseline owns", and the initiative touch point gives epic 1 "workflows, repo and environment secrets". Under all three, epic 1 owns `apple-secret.yml`, and its story 11 refactor sweep or its closure trace can look for it.
- **Unit B:** epic map row 2 and epic 2's ticket own `apple-secret.yml`. No epic 1 story builds it.
- **Same gap, on deploy.yml.** The map's header (`:11`) says other epics "only use what is listed under Uses", and row 2 uses "Epic 1 pipeline". Yet several later epics must add steps or secrets to epic 1's files:
  - epic 2 adds the hook health-check assertion (stated), the bootstrap admin email into Vault "set by CI", and settings rows;
  - epic 6 adds `send-push`'s `internal.edge_function_settings` row "written by CI per environment" and the APNs and VAPID function secrets;
  - epic 13 may add a TestFlight upload workflow and its signing secrets (its Notes `:54`).
- **How they diverge.** Epic 6, obeying "only use", adds its own workflow to write its settings row. Epic 2's deploy step writes the full row set from its own list. Hosted then has two writers of `internal.edge_function_settings`, and whichever runs second decides the URL and secret. Separately, secrets land at repo level in one epic and in the Production environment in another, but R10 now requires deploy secrets to be in Production only, and environment secrets are invisible to jobs without `environment: Production`.
- **Evidence:**
  - Seed `architecture-capacitor-supabase-port.md:358-362`
  - AD-21 `:279`, `:285`
  - Secrets row `:315`
  - epic map `:11`, `:44`, `:76` (Function settings seam: "CI writes rows" with no file owner)
  - initiative `initiative-capacitor-supabase-port.md:97`
  - `epic-platform-baseline.md:34` (R10), `:71`
  - `epic-app-store-release.md:54`
- **Fix:**
  - Seed: give each workflow its owner. `apple-secret.yml` belongs to epic-invite-sign-in; any TestFlight workflow belongs to epic-app-store-release, if chosen.
  - AD-21 gets an "Extension points" bullet: "Epic-platform-baseline owns every `.github` file and the repo's secret set. A later epic changes them only in the change that needs it and only at these points:
    - the health check's assertions;
    - one `deploy.yml` step that writes `internal.edge_function_settings` from a checked-in list, one entry per function;
    - `test.yml` lanes (AD-23);
    - new secrets, in the Production environment only, never at repo level.

    A new workflow file is added only for a new schedule or trigger, and it is listed in the Seed with its owner."

### F5. Dependency review fails at moderate severity, but the only PRs that merge without a human ignore it — MEDIUM

- **Unit A (story 13):** `dependency-review.yml` runs on every PR and "fails at moderate severity" (R12). It is its own workflow and not a required check.
- **Unit B (story 13):** `dependabot-auto-merge.yml` runs `gh pr merge --auto`. GitHub merges as soon as the required checks pass and ignores other checks that are red. A Dependabot PR that pulls in a transitive dependency with a moderate advisory merges, deploys and ships as a live update, even though R12 says the review "fails".
- **Evidence:**
  - `epic-platform-baseline.md:36` (R12), `:59`
  - `tickets.toml:51`
  - My-Love `dependabot-auto-merge.yml` (only the fallback path inspects other checks)
- **Fix (part of AD-23):** make the dependency review gating, either as a job under the summary's `needs`, or by having the ruleset require both checks. Or state that it is advisory and drop "fails" from R12. The spine has to pick one, because epic 1 alone cannot tell which is intended.

### F6. Epic map row 13 drops the email worker that epic 13 and epic 1's Boundaries still name — LOW

- **Unit A:** epic map row 13 now reads "removal of Flutter, Firebase, `functions/` and the Pages project".
- **Unit B:** epic 13's Description and Done when, and epic 1's Boundaries, list "the email worker" separately. That is MailChannels, `functions/cloudflare-email-worker.js`, which epic 1's boundary hands to epic 13.
- **How they diverge.** The file goes with `functions/`. If it was ever deployed as a Cloudflare Worker, that Worker has no owner in the map, and epic 13 can close row 13 with it still running. Whether a deployed email Worker exists is UNVERIFIED (not checked in Cloudflare). Row 13 also says "Firebase" where the tickets say "Firebase config".
- **Evidence:**
  - `epic-map-capacitor-supabase-port.md:55`
  - `epic-app-store-release.md:17`, `:28`
  - `epic-platform-baseline.md:66`
  - `brief-port-goals.md:46` (D16)
- **Fix:** row 13: "removal of Flutter, Firebase config, `functions/` (including the MailChannels email worker and its deployed Worker, if any) and the Pages project fermi".

### F7. The Stack table says "pinned" while Dependabot moves every version weekly — LOW

- **Unit A (epic 1, story 1, and its Constraints):** "the Stack table's versions are pinned". A later story that adds or touches a package follows the spine's table, for example epic 6 installing `@capacitor/push-notifications` 8.1.3.
- **Unit B (Dependabot, story 13):** the weekly groups auto-merge, so within weeks `app/package-lock.json` is ahead of the table. The two disagree about which version is canonical, and a builder that "restores the pin" downgrades a merged update.
- **Evidence:**
  - spine Stack `:318-340`
  - `epic-platform-baseline.md:49`
  - `tickets.toml:7` ("at the Stack's pinned versions")
- **Fix:** one line under the Stack table: "Initial versions for story 1. Afterwards `app/package-lock.json` is the source of truth and Dependabot moves it. A new package is added at the version that matches its installed family. Majors held on purpose (Capacitor 8 per AD-18, Supabase CLI 2.x per Deferred) are pinned in `dependabot.yml` or in the workflow."

### F8. AD-20's "live for one deploy" no longer measures anything once deploys are unattended — LOW

- **Unit A (any epic):** ships an expand migration and a bundle that stops using the old shape.
- **Unit B (Dependabot auto-merge):** an auto-merged bump deploys an hour later. The contract migration is then "after one deploy" by AD-20's letter, while iOS shells that have not accepted the restart offer (story 10) still run the old bundle against the dropped column.
- **Evidence:**
  - AD-20 `:275`
  - `tickets.toml:128` (restart is offered, not forced)
- **Fix:** AD-20 measures in time, not deploys: "…has been the live update for at least 7 days and no supported App Store build bundles the old shape."
