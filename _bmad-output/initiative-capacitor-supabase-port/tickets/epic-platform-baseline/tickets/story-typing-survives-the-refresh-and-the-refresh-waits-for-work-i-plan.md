---
title: 'Typing survives the refresh, and the refresh waits for work in progress'
type: feature
ticket: '17'
created: '2026-11-07'
status: done
baseline_revision: 'b5bca950a2727a0b2d93fcd332ff89f73292a4e1'
route: full
route_source: auto
risk: medium
review: quick
review_source: pinned
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** AD-24's refresh page (story 16) reloads the page, and nothing keeps what a user was typing or tells the page that an upload or CSV import is still running. Every later epic's content forms and uploads need one draft store (AD-26) and one busy registry (AD-24) to build on, and AD-27 needs a draft wipe at sign-out and on every `SIGNED_OUT`.

**Approach:** Add `draftKey()` (the only builder of `fermi:draft:<user id>:…` keys, with a typed feature list), the one `useDraft` hook over `sessionStorage`, the wipe, and a session store in `app/src/api/auth.ts` whose listener runs the wipe on `SIGNED_OUT`; add the one busy registry. Start the auth listener when the app starts. No form or flow uses them yet.

## Boundaries & Constraints

**Always:** Storage is `sessionStorage` only, never `localStorage`; every storage call is in try/catch (a throwing or full storage degrades to in-memory, `console.warn`). Values are JSON (string, number, boolean, null, arrays, plain objects); `File` or `Blob` anywhere in a value throws a `TypeError`. Keys are `fermi:draft:<user id>:<feature>:<scope ids…>:<field>`; the literal `fermi:draft:` appears only in `app/src/drafts/draftKey.ts`. Nothing is read or written before the session resolves (`INITIAL_SESSION`) or while signed out. The busy registry is framework-free and releases in `finally`. `app/src/api/` keeps ≥80% line coverage. Pinned versions unchanged.

**Never:** No new npm dependency. No form, screen, refresh page or update check (story 16). No `signOut()` (epic-invite-sign-in, AD-27). No change to `client.ts`, `errors.ts`, `env.ts`, any workflow, `deferred-work.md` or any ticket file. No `app/src/features/` folder.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Key shape | user `u1`, `draftKey('fixture', 'c1', 'body')` | storage key `fermi:draft:u1:fixture:c1:body` | — |
| New row | `draftKey('fixture', newRowScope('c1'), 'title')` | `…:fixture:new:c1:title` | — |
| Bad key | unknown feature, no field, empty or `:`-containing segment, field matching `/password/i` | — | throws `Error` naming the problem |
| Write | signed in, `setValue('hi')` | `sessionStorage` holds `"hi"` at once; `localStorage` untouched | storage throws → value kept in memory, `console.warn` |
| Restore | remount after a write, same user and key | value `'hi'`, `restored: true` | corrupt JSON → initial value, `restored: false` |
| Fresh | no stored draft | initial value, `restored: false`; typing keeps `restored: false` | — |
| Loading | session not resolved | initial value; `setValue` updates only memory; storage untouched | — |
| Signed out | session resolved with no user | same as Loading | — |
| Clear | `clear()` (send, save, cancel, Discard) | key removed, initial value, `restored: false`; next change writes again | — |
| File | `setValue(file)` or `{ a: [blob] }` | — | throws `TypeError` |
| File names | `draftFileNames([File 'a.pdf', File 'b.png'])` | `['a.pdf', 'b.png']`, storable | — |
| SIGNED_OUT | event fires (this tab or broadcast from another) | every `fermi:draft:` key removed, other keys kept; mounted hooks show initial values | — |
| Busy | `runBusy(fn)` resolving or rejecting; two at once; `holdBusy()` release called twice | `isBusy()` true while any runs, false after all end; rejection rethrown; subscribers notified on each change | double release harmless |

</intent-contract>

## Code Map

- `app/src/api/client.ts` -- `supabase()` lazy singleton; use it, do not change it. Its comment says the shell never builds the client; after this story `main.tsx` does, via `startAuth()`.
- `app/src/api/env.ts` -- with no `VITE_SUPABASE_*` set, the client targets the local stack; tests must not hit the network (pass a fake client).
- `@supabase/supabase-js` 2.119.0: `client.auth.onAuthStateChange((event, session) => …)` returns `{ data: { subscription } }`; the first event is `INITIAL_SESSION` (session or null), which is "session resolved"; `SIGNED_OUT` is also broadcast to other tabs (BroadcastChannel). Never `await` a Supabase call inside the callback.
- `app/src/main.tsx` -- add `startAuth()` after `render(...)`, so the wipe listener runs in every tab from startup.
- `app/eslint.config.js` -- `react-hooks` v7 recommended rules (no setState in effects, no ref reads in render); adjust state during render with a guard, or `useSyncExternalStore`. Supabase imports allowed only in `src/api/**` and `tests/**`.
- `app/vitest.config.ts` -- happy-dom, `restoreMocks`, includes `tests/unit/**` and `src/**`; coverage threshold on `src/api/**`.
- `app/tests/unit/App.test.tsx` -- component-test pattern (Testing Library, no globals; `tests/setup.ts` cleans up).
- `app/tsconfig.test.json` -- tests get `node` types, so a test may read `src/` with `node:fs`.
- Worktree has no `node_modules`: run `npm ci` in `app/` first.

## Tasks & Acceptance

**Execution:**
- [ ] `app/src/drafts/draftKey.ts` -- `DRAFT_FEATURES = ['fixture'] as const` (comment: the tests' feature; each epic adds its `app/src/features/<area>` folder name), `DraftFeature`, branded `DraftKey`, `draftKey(feature, ...scopeIdsAndField)` validating per the Bad key row, `newRowScope(parentId)`, `draftStorageKey(userId, key)`, `wipeDrafts()` (removes every `fermi:draft:` key from `sessionStorage`, try/catch), and a `subscribeDraftWipe(listener)` so mounted hooks reset after a wipe.
- [ ] `app/src/drafts/useDraft.ts` -- `useDraft<T extends DraftValue>(key, initial)` → `{ value, setValue, restored, clear }` per the matrix; `DraftValue` JSON type; `draftFileNames(files: Iterable<File>)`; File/Blob guard walks arrays and objects.
- [ ] `app/src/api/auth.ts` -- `SessionState` (`loading` | `signed-out` | `signed-in` with `userId`), `sessionState()`, `subscribeSession(listener)` (cached snapshots for `useSyncExternalStore`), `startAuth(client = supabase())` idempotent: one `onAuthStateChange` listener that sets the state from any event's session and calls `wipeDrafts()` on `SIGNED_OUT`; a test-only reset export is allowed.
- [ ] `app/src/busy/busy.ts` -- `holdBusy()` → idempotent release, `runBusy(fn)`, `isBusy()`, `subscribeBusy(listener)`.
- [ ] `app/src/main.tsx` -- call `startAuth()` after render.
- [ ] `app/tests/unit/draftKey.test.ts`, `useDraft.test.tsx`, `auth.test.ts`, `busy.test.ts` -- Vitest for every matrix row, plus: every `DRAFT_FEATURES` entry other than `fixture` is a folder under `app/src/features/`; no file under `app/src/` other than `drafts/draftKey.ts` contains `fermi:draft:`. Use a fake auth client that captures the callback. Tests live in `tests/unit/` so `app/src` holds the literal once.
- [ ] `app/tests/README.md` -- one short "Drafts and busy work" paragraph: forms use `useDraft` with `draftKey`, multi-call flows use `runBusy`/`holdBusy`, and where they live.

**Acceptance Criteria:**
- Given the branch, when `npm run test:unit:coverage` runs in `app/`, then the draftKey, hook, wipe and busy cases pass, including a value restored after remount, nothing stored while signed out, a `SIGNED_OUT` wiping every `fermi:draft:` key, and the registry released after a failed flow; `src/api/**` stays ≥80% lines.
- Given `app/src`, when `grep -rn "fermi:draft:" app/src` runs, then the only match is in `app/src/drafts/draftKey.ts`.
- Given the built shell, when the Playwright `chromium` shell spec runs, then it still passes with no failed network request from `startAuth()`.

## Implementation Notes

- Implemented by a Sonnet subagent from this plan; the parent re-ran every verification command.
- `newRowScope(parentId)` returns `{ newRowOf }` rather than the string `new:<id>`, because a scope id containing `:` is refused; `draftKey` expands it into the two segments `new`, `<id>`, giving the matrix's `…:fixture:new:c1:title`.
- `draftKey.ts` also exports `draftWipeEpoch()` beside `subscribeDraftWipe()`: mounted hooks read it through `useSyncExternalStore` and reset to their initial value when it moves.
- `useDraft` settles state during render (guarded `setSlot`), not in an effect, to satisfy react-hooks v7. Text typed while the session is loading is kept in memory when it resolves, unless a stored draft exists, which wins; nothing is written until the next change.
- `useDraft(key, '')` widens the top-level literal type so `setValue` takes any string; nested literal fields need an explicit type argument (a recursive widening hit TypeScript's depth limit).
- happy-dom's `Storage` ignores prototype spies, so storage-failure tests swap the global through `tests/unit/stub-storage.ts`; the fake auth client is `tests/unit/fake-auth-client.ts`.
- `main.tsx` now calls `startAuth()`, so the shell builds the Supabase client at startup; `client.ts`'s comment "the shell never builds it" is now stale but the plan forbade touching that file. The build now warns that a chunk passes 500 kB, since supabase-js joins the shell bundle.
- Verification run by the parent: `npm run lint` and `npm run typecheck` exit 0; `npm run test:unit:coverage` 141/141 (draftKey 18, auth 9, useDraft 18, busy 7), all files 100% lines, `src/api` 100% lines; `grep -rn "fermi:draft:" app/src` matches only `app/src/drafts/draftKey.ts:4`; no `localStorage` in `app/src`; Playwright `chromium` `tests/e2e/shell.spec.ts` 1/1 passed (network error monitor active).

## Plan Change Log

## Review Triage Log

### 2026-11-07 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` A `setValue` held across an await wrote `fermi:draft:<old user>:…` after a `SIGNED_OUT`, user switch or wipe, since it used the storage key captured at render — confirmed in `useDraft.ts` (no call-time check). `setValue` now writes only when `sessionState()` still yields the same storage key and `draftWipeEpoch()` the same epoch; test added (held setter after sign-out, user switch and wipe stores nothing).
  - `[low]` `[patch]` A key change while loading or signed out was not detected (slot tracked only `storageKey`, `null` in both states), so key A's text became key B's value and was later written under B — confirmed by tracing `settle`. The slot now records the `DraftKey`, re-settles on change, and carries loading-time text only for the same key; test added.
  - `[low]` `[reject]` A literal scope id `'new'` yields the same key as `newRowScope(id)` — real, but scope ids are row ids (UUIDs) and `new` is never a row id in everyday use, and the fix adds a guard.

## Design Notes

`draftKey` is pure and returns a branded `DraftKey` without the user id, so forms can build keys during render before the session resolves; the hook adds the user id through `draftStorageKey`, which lives in the same module, so the module stays the only builder. Per-user keys mean a second user on the same tab never sees the first user's drafts even before the wipe.

```tsx
const body = useDraft(draftKey('fixture', classId, 'body'), '');
<textarea value={body.value} onChange={(e) => body.setValue(e.target.value)} />
{body.restored && <button onClick={body.clear}>Discard</button>}
```

`setValue` writes synchronously, not in an effect, so `clear()` resetting to the initial value is never written back. The auth listener starts at app start (not on first hook mount): after a refresh a tab may hold drafts with no form mounted, and a sign-out in another tab must still wipe them.

## Verification

**Commands:**
- `cd app && npm ci` -- expected: exit 0.
- `cd app && npm run lint && npm run typecheck` -- expected: exit 0.
- `cd app && npm run test:unit:coverage` -- expected: all pass; `src/api/**` ≥80% lines.
- `grep -rn "fermi:draft:" app/src` -- expected: matches only in `app/src/drafts/draftKey.ts`.
- `grep -rn "localStorage" app/src` -- expected: no match.
- `cd app && npx playwright install chromium && npm run test:e2e -- --project=chromium tests/e2e/shell.spec.ts` -- expected: pass (skip with a note if the local stack or browsers are unavailable).

## Auto Run Result

Status: built

**Summary:** The one draft store and the one busy registry exist for story 16 and every later epic. `draftKey(feature, ...scopeIds, field)` is the only builder of `fermi:draft:<user id>:…` keys (typed `DRAFT_FEATURES` list holding the tests' `fixture`, `newRowScope(parentId)` for `new:<parent id>`, refusing unknown features, empty or `:`-containing segments and password fields). `useDraft(key, initial)` keeps any JSON value in `sessionStorage`, written on each change, only after the session resolves and never while signed out; it reports `restored` for a Discard control, `clear()` covers send, save, cancel and Discard, `File`/`Blob` values throw, and `draftFileNames()` keeps picked files' names. `app/src/api/auth.ts` holds the session store and the one `onAuthStateChange` listener, which wipes every `fermi:draft:` key on `SIGNED_OUT` (this tab or broadcast from another); `wipeDrafts()` is exported for epic-invite-sign-in's `signOut()`; `main.tsx` starts the listener at app start. `app/src/busy/busy.ts` gives `holdBusy()`, `runBusy(fn)`, `isBusy()` and `subscribeBusy()`.

**Files changed:**
- `app/src/drafts/draftKey.ts` — `draftKey`, `DRAFT_FEATURES`, `newRowScope`, `draftStorageKey`, `wipeDrafts`, wipe subscription and epoch.
- `app/src/drafts/useDraft.ts` — the draft hook, `DraftValue`, `draftFileNames`.
- `app/src/api/auth.ts` — session store, `startAuth()`, SIGNED_OUT wipe.
- `app/src/busy/busy.ts` — the busy registry.
- `app/src/main.tsx` — calls `startAuth()` after render.
- `app/tests/unit/draftKey.test.ts`, `useDraft.test.tsx`, `auth.test.ts`, `busy.test.ts`, `fake-auth-client.ts`, `stub-storage.ts` — Vitest and helpers.
- `app/tests/README.md` — "Drafts and busy work" paragraph.

**Review findings:** 3 from the quick lens. Patched 2 (1 medium: a held `setValue` could write after sign-out; 1 low: a key change while loading kept the old key's text). Deferred 0. Rejected 1 (low): a literal `'new'` scope id collides with `newRowScope` — scope ids are row ids, never `new`, and the fix adds a guard.

**Follow-up review recommended: false** — patched one medium and one low; no high.

**Verification:** `npm run lint` and `npm run typecheck` exit 0; `npm run test:unit:coverage` 143/143, all files 100% lines, `src/api` 100% lines; `grep -rn "fermi:draft:" app/src` matches only `app/src/drafts/draftKey.ts:4`; no `localStorage` in `app/src`; Playwright `chromium` `tests/e2e/shell.spec.ts` 1/1 with the network error monitor on.

**Residual risks:** No GitHub CI run of these tests yet (the ticket's verify reads CI's Vitest lane). The shell now builds the Supabase client at startup, so the build warns that a chunk passes 500 kB, and `client.ts`'s comment that the shell never builds the client is stale. In the owner's shell, which exports another project's `VITE_SUPABASE_URL` without the key (story 5's note), a local `npm run dev` now throws at startup from `startAuth()`; CI and the deploy are unaffected. A literal `'new'` scope id would collide with a new-row key. Nested literal types in an object draft need an explicit type argument.
