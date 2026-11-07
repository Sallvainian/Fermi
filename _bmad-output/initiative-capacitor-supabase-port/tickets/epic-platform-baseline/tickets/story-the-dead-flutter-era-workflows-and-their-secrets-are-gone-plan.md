---
title: 'The dead Flutter-era workflows and their secrets are gone'
type: chore
ticket: '12'
created: '2026-11-06'
status: done
baseline_revision: '458af4a8a79b34cdb70a0b18cc999f9495af0416'
route: oneshot
route_source: auto
risk: low
review: quick
review_source: pinned
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Four Flutter-era workflows (`01_ci.yml`, `03_windows_release.yml`, `04_macos_release.yml`, `05_Ignore_desktop-release.yml`) are dead or broken: 01_ci fails on every pull request, 04 and 05 fail on every pull request because `apps/fermi` does not exist, and 03 builds a Windows app the new stack does not ship. README.md's CI/CD list still describes them in item 1 (`01_ci.yml`) and item 3 (Platform Releases).

**Approach:** Delete the four workflow files and README.md's CI/CD items 1 and 3, renumbering the one remaining item (Code Review Automation, story 13's to rewrite) so the list reads correctly. The ten repo secrets only these workflows used (ANTHROPIC_API_KEY, APPLE_ID, APPLE_TEAM_ID, APPLE_APP_SPECIFIC_PASSWORD, CSC_LINK, CSC_KEY_PASSWORD, FIREBASE_PROJECT_ID, FIREBASE_FUNCTIONS_REGION, GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET) were already deleted by the owner during setup on 2026-11-06; the build only confirms they are absent. Out of scope: the `01_ci` mentions in `claude.yml` and `claude-code-review.yml` and README item 4's content (story 13); the repo-level Cloudflare secrets (story 1); `deploy.yml`.

</intent-contract>

## Implementation Notes

Oneshot: four file deletions plus about ten README lines, all mechanical, with no behaviour to design. Investigation: README item 2 (`02_deploy_web.yml`) was already removed by story 1, leaving items 1, 3 and 4; no file outside `.github/workflows/`, README.md and `_bmad*` names the four workflows except `claude.yml:42,77` and `claude-code-review.yml:40`, which are story 13's. `gh secret list` at planning shows only CLAUDE_CODE_OAUTH_TOKEN, CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN at repo level, and no remaining workflow reads any of the ten secrets.

Implemented: `git rm` of `.github/workflows/01_ci.yml`, `03_windows_release.yml`, `04_macos_release.yml`, `05_Ignore_desktop-release.yml`; README.md's CI/CD items 1 and 3 removed and item 4 renumbered to 1 with its text untouched, since a Markdown ordered list renders from its first number and would otherwise show "4." as the only item. No secret was touched; the ten were already absent.

## Plan Change Log

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 0 findings — high 0, medium 0, low 0, false 0, maybe-false 0
- findings: none. The quick lens confirmed the four files are gone, no `.github/` file reads any of the ten secrets, README.md names none of the deleted workflows, and the only remaining `01_ci` mentions (`claude.yml:42,77`, `claude-code-review.yml:40`) are story 13's. It marked the live `gh secret list` and test-pull-request checks UNVERIFIED by inspection; `gh secret list` was run in verification (below).

## Verification

**Commands:**
- `ls .github/workflows/ | grep -E '^0[1345]_'` -- expected: no output (exit 1)
- `gh secret list | grep -E '^(ANTHROPIC_API_KEY|APPLE_ID|APPLE_TEAM_ID|APPLE_APP_SPECIFIC_PASSWORD|CSC_LINK|CSC_KEY_PASSWORD|FIREBASE_PROJECT_ID|FIREBASE_FUNCTIONS_REGION|GOOGLE_OAUTH_CLIENT_ID|GOOGLE_OAUTH_CLIENT_SECRET)\b'` -- expected: no output (exit 1)
- `grep -n -E '01_ci|03_windows|04_macos|05_Ignore|Platform Releases|Windows release|macOS release' README.md` -- expected: no output (exit 1)
- `grep -rn -o -E 'secrets\.(ANTHROPIC_API_KEY|APPLE_[A-Z_]+|CSC_[A-Z_]+|FIREBASE_[A-Z_]+|GOOGLE_OAUTH_[A-Z_]+)' .github/` -- expected: no output (exit 1)

**Manual checks (if no CLI):**
- README.md's "GitHub Actions Workflows" list renders as one numbered item, Code Review Automation, with its text unchanged.
- "A test pull request runs none of them" holds once the branch merges, since GitHub runs only workflow files present on the pull request's branch; the orchestrator's own verification covers opening one.

## Auto Run Result

Status: built

**Summary:** Deleted the four dead Flutter-era workflows and README.md's two CI/CD list items that described them. The ten repo secrets only they used were already deleted by the owner on 2026-11-06; this run confirmed they are absent and touched no secret.

**Files changed:**
- `.github/workflows/01_ci.yml` -- deleted (Flutter CI that failed on every pull request)
- `.github/workflows/03_windows_release.yml` -- deleted (Flutter Windows release)
- `.github/workflows/04_macos_release.yml` -- deleted (macOS release; failed on every pull request)
- `.github/workflows/05_Ignore_desktop-release.yml` -- deleted (desktop release; failed on every pull request)
- `README.md` -- removed CI/CD items 1 (`01_ci.yml`) and 3 (Platform Releases); renumbered the remaining Code Review Automation item from 4 to 1, text unchanged
- this plan file -- added

**Review findings:** quick lens, 0 findings. Patches applied: 0. Deferred: 0. Rejected: 0.

**Follow-up review recommended:** false (no patched entries; patched counts high 0, medium 0, low 0).

**Verification:**
- `ls .github/workflows/ | grep -E '^0[1345]_'` -- no output, exit 1 (pass); remaining: `claude-code-review.yml`, `claude.yml`, `deploy.yml`
- `gh secret list | grep -E '^(<ten secrets>)\b'` -- no output, exit 1 (pass); repo level holds only CLAUDE_CODE_OAUTH_TOKEN, CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN
- README grep for the deleted workflow names -- no output, exit 1 (pass)
- `.github/` grep for the ten secrets -- no output, exit 1 (pass)
- Manual: README's GitHub Actions Workflows list now reads as one item, "1. Code Review Automation".

**Residual risks:**
- "A test pull request runs none of them" is not exercised here (no pull request opened); it follows once this branch merges, since GitHub runs only workflow files on the pull request's branch. Left to the orchestrator's verification.
- The repo-level CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN secrets still exist; their removal is story 1's (epic note), not this ticket's.
- `claude.yml` and `claude-code-review.yml` still mention `01_ci.yml` in comments and install Flutter until story 13, as the ticket states.
