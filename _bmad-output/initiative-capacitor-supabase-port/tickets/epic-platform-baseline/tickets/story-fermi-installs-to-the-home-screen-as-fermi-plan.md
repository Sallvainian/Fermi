---
title: 'Fermi installs to the Home Screen as Fermi+'
type: feature
ticket: '15'
created: '2026-11-07'
status: done
baseline_revision: '05c8cd4892b1dede778a33d7012e40572389a13f'
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
closes_deferred: [DW-5]
operator_actions:
  - 'After this branch merges to main, open the Deploy run for that push, confirm it is green, and confirm https://fermi-plus.sallvain.workers.dev/manifest.webmanifest is served as JSON with name Fermi+ and display standalone, and that https://fermi-plus.sallvain.workers.dev/icons/icon-192.png, /icons/icon-512.png and /apple-touch-icon.png load as PNG images.'
  - 'On your iPhone, open https://fermi-plus.sallvain.workers.dev/ in Safari, tap Share then Add to Home Screen, and confirm it offers the name Fermi+ with Fermi''s icon (the purple F under the infinity sign on black).'
  - 'Tap the saved Fermi+ icon on the Home Screen and confirm Fermi opens with no Safari address bar or toolbar.'
---

<intent-contract>

## Intent

**Problem:** `app/` serves no web app manifest and no icon, so Fermi saved to an iPhone Home Screen from Safari opens in a Safari frame under a generic name and screenshot icon, and iPhone web push (parent R11) reaches only a standalone Home Screen web app (R14). DW-5's concern, a placeholder replacing Fermi's icon, now applies here.

**Approach:** Add `app/public/manifest.webmanifest` (name and short_name `Fermi+`, display `standalone`, start_url and scope `/`, background `#000000` and theme `#8B5CF6`, Fermi's colours from the Flutter `web/manifest.json`), icons at 192 and 512 and an `apple-touch-icon.png` at 180, all resized with `sips` from the Flutter app's `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`; link the manifest and the touch icon from `app/index.html` and set `apple-mobile-web-app-title` to `Fermi+`. A Playwright e2e spec (chromium and iPhone WebKit) proves the links, the manifest's fields and that every icon is served as a PNG of its stated size.

</intent-contract>

## Implementation Notes

Oneshot: four small text edits (index.html, the manifest, one spec) plus three generated PNGs, under 100 lines.

- Files: `app/index.html` (manifest link, `apple-touch-icon` link with `sizes="180x180"`, `apple-mobile-web-app-title` meta); `app/public/manifest.webmanifest`; `app/public/apple-touch-icon.png` (180), `app/public/icons/icon-192.png`, `app/public/icons/icon-512.png`; `app/tests/e2e/home-screen.spec.ts`.
- The touch icon sits at `/apple-touch-icon.png`, the path iOS also requests when no link names one.
- The source icon is opaque RGB (no alpha), so iOS shows it as is with no black fill; it is full-bleed black, matching `background_color`.
- wrangler's `not_found_handling: single-page-application` answers a missing PNG with `index.html` and a 200, so the spec checks each icon's PNG signature and IHDR width and height, not only the status.
- `apiRequest` parses only `application/json` and `text/*` bodies and returns no headers, so it reads neither `application/manifest+json` nor PNG bytes; the spec uses Playwright's `request` fixture under a `// playwright-utils deviation:` comment (AGENTS.md).
- The spec runs signed out (`authSessionEnabled: false`): the Home Screen install happens before sign-in, and no Supabase call is needed.
- Built as planned. Icons made with `sips -z <n> <n>` from the 1024px source; all three are opaque RGB PNGs of 180, 192 and 512.
- The spec imports nothing from `@playwright/test`, not even a type (AGENTS.md): a pure `pngSize` helper and one loop over the manifest's icons plus the touch icon; the deviation comment sits at the first `request.get`.
- Negative check: pointing the 512 icon at `/icons/missing.png` failed the spec with `content type Expected "image/png" Received "text/html"` (the SPA fallback); reverted.
- Run: lint, typecheck, build exit 0; `dist/` holds the manifest and three PNGs; Playwright chromium and webkit 4/4 (both specs); Vitest 89/89; `scripts/test-check-site.sh` 11/11; sips sizes 180, 192, 512.
- `check-test-counts.sh` counts git-tracked specs, so the new spec counts in CI once committed.

## Verification

**Commands:**
- `cd app && npm ci && npm run lint && npm run typecheck && npm run build` -- expected: exit 0, and `app/dist/` holds `manifest.webmanifest`, `apple-touch-icon.png`, `icons/icon-192.png`, `icons/icon-512.png`.
- `cd app && npx playwright test tests/e2e/home-screen.spec.ts --project=webkit --project=chromium` -- expected: all pass.
- `cd app && npx playwright test --project=chromium --project=webkit` -- expected: all pass (the shell spec too).
- `sips -g pixelWidth -g pixelHeight app/public/apple-touch-icon.png app/public/icons/*.png` -- expected: 180, 192 and 512 square.

**Manual checks (if no CLI):**
- Owner, after the merge: Safari on the iPhone, Share, Add to Home Screen offers Fermi+ with Fermi's icon, and the saved icon opens with no Safari bar (ticket note: the iPhone half of the verify is the owner's).

## Review Triage Log

### 2026-11-07 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` Implementation Notes' first line miscounts the edits ("four" for three) and the size ("under 100 lines"; the diff adds 122 outside the plan) — true, but it is the plan's own record and leaves the code unaffected; its only fix edits this build's plan, which triage rejects.

## Auto Run Result

Status: awaiting-operator

**Summary:** Fermi now serves a web app manifest (`/manifest.webmanifest`: Fermi+, standalone, start_url and scope `/`, background `#000000`, theme `#8B5CF6`) linked from `app/index.html`, with a 180px apple-touch-icon and 192 and 512 manifest icons resized from Fermi's own 1024px icon, and `apple-mobile-web-app-title` set to Fermi+. A Playwright spec proves the links, the manifest fields and every icon's PNG type and size on Desktop Chrome and iPhone WebKit. Closes DW-5 (`closes_deferred`).

**Files changed:**
- `app/index.html` -- manifest link, 180x180 apple-touch-icon link, apple-mobile-web-app-title meta, and a comment naming the icon source.
- `app/public/manifest.webmanifest` -- the web app manifest.
- `app/public/apple-touch-icon.png`, `app/public/icons/icon-192.png`, `app/public/icons/icon-512.png` -- Fermi's icon at 180, 192 and 512 (sips from `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`).
- `app/tests/e2e/home-screen.spec.ts` -- the e2e spec (chromium and webkit projects).

**Review:** quick lens, 1 finding. Patches applied: 0. Deferred: 0. Rejected: 1 (the plan note's line miscount; its fix edits this build's plan).

**Follow-up review recommended:** false. Patched entries: high 0, medium 0, low 0.

**Verification:** `npm ci`, `npm run lint`, `npm run typecheck`, `npm run build` exit 0, and `dist/` holds the manifest and the three PNGs. `playwright test --project=chromium --project=webkit` passes 4/4: home-screen and shell, each on both projects. Vitest passes 89/89. `scripts/test-check-site.sh` passes 11/11. sips reads the icons as 180, 192 and 512 square. In a negative check, the 512 icon was pointed at a missing path: the spec failed on the SPA fallback's `text/html`, and the change was reverted.

**Residual risks:** The Home Screen install itself (Safari's Add to Home Screen, the standalone launch) is not automated. WebKit in Playwright is not iOS Safari (test design TC-8), so the owner checks it on the iPhone after the merge (operator_actions). The deployed manifest's content type on Cloudflare is not checked here and is UNVERIFIED until the post-merge check.

## Operator Confirmation

Confirmed 2026-11-07: the external actions this story owed were carried out.

- After this branch merges to main, open the Deploy run for that push, confirm it is green, and confirm https://fermi-plus.sallvain.workers.dev/manifest.webmanifest is served as JSON with name Fermi+ and display standalone, and that https://fermi-plus.sallvain.workers.dev/icons/icon-192.png, /icons/icon-512.png and /apple-touch-icon.png load as PNG images.
- On your iPhone, open https://fermi-plus.sallvain.workers.dev/ in Safari, tap Share then Add to Home Screen, and confirm it offers the name Fermi+ with Fermi's icon (the purple F under the infinity sign on black).
- Tap the saved Fermi+ icon on the Home Screen and confirm Fermi opens with no Safari address bar or toolbar.

_Appended by the bmad-loop orchestrator (`bmad-loop confirm`, #335): a human confirmed these external actions out of band, and the story was advanced from `awaiting-operator` to `done`._
