---
title: 'A catalog test fails on any grant the fixture does not list'
type: feature
ticket: '6'
created: '2026-11-06'
status: done
baseline_revision: '6e5f21b54f241f11ba7b5996b1ba04d9c8160270'
route: full
route_source: auto
risk: medium
review: quick
review_source: pinned
lenses_ran: [quick]
review_loop_iteration: 1
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** AD-3 ("locked by default") has no automated guard: a migration can add a function that Postgres grants EXECUTE to PUBLIC (so `anon`), or a table that Supabase's default privileges open to `anon` and `authenticated`, and pgTAP stays green.

**Approach:** Check in a privilege fixture listing the expected grants of every table, column, function and view in schemas `public`, `app` and `internal`, and a pgTAP catalog test, run by the existing `supabase test db` lane, that compares the live catalog to it and fails naming each object that is missing, stale or different, and fails on any grant to `anon` or PUBLIC (P0-006).

## Boundaries & Constraints

**Always:** read effective ACLs (`coalesce(acl, acldefault(...))`, so a function's implicit PUBLIC EXECUTE counts); leave out grants to the object's owner and extension-member objects (`pg_depend.deptype = 'e'`); every object appears in the fixture even with no grants; the whole test runs inside `begin ... rollback`; failure diagnostics name the object as a fixture line the author can paste.

**Never:** change `test.yml`, migrations or the other test files; commit anything to the database; cover schemas other than the three, or sequences and types (the ticket names tables, columns, functions and views).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Clean | catalog matches fixture (today: 0 objects, empty fixture) | 6/6 pass | none |
| Unlisted object | `create function public.f()` with no fixture line | "listed in fixture" test fails showing `function|public.f()|PUBLIC:EXECUTE ...` | — |
| anon grant | `grant execute on function x to anon`, even if the fixture lists it | anon/PUBLIC test fails naming `x` | — |
| Differing grant | fixture `authenticated:SELECT`, catalog adds `UPDATE` | "grants match" test fails with expected and actual | — |
| Stale line | fixture lists a dropped object | "no stale entries" test fails naming it | — |
| internal EXECUTE | `internal.*` function granted to `authenticated` | internal test fails naming it | — |
| Definer view | `create view public.v` without `security_invoker` | view test fails naming it | — |
| Bad fixture | duplicate line or missing file | file errors, `Result: FAIL` | primary key / psql include error |

</intent-contract>

## Code Map

- `supabase/tests/database/00_test_helpers.sql` -- commits schema `tests`; outside the three schemas, so not covered. Read-only.
- `supabase/tests/database/01_schemas.sql` -- style to follow (header comment naming R/AD, `begin; plan(n); ... finish(); rollback;`). Schema USAGE is already tested here; do not duplicate.
- `supabase/migrations/*.sql` -- today create only empty `app`, `internal` and pgtap in `extensions`; local DB has 0 objects in the three schemas, so the fixture starts with no rows.
- `.github/workflows/test.yml` `db-tests` -- runs `supabase test db`; picks up new `NN_*.sql` files with no edit. Files ending `.psql` are not run as tests (probed).
- `app/tests/README.md` -- test docs table and CI section; add the fixture rule.
- Probed on the local stack: `\ir file.psql` works under `supabase test db`, a missing include makes the run FAIL, and `copy ... from stdin` inside the included file reads its data lines.

## Tasks & Acceptance

**Execution:**
- [x] `supabase/tests/database/privilege_fixture.psql` -- header (what it is, line format, examples, "update in the same change as the migration", how to read a failure) then `copy pg_temp.privilege_fixture (kind, object, grants) from stdin with (format csv, delimiter '|', quote e'\x01', header true);`, header line, no data rows, `\.` -- the checked-in fixture.
- [x] `supabase/tests/database/03_privileges.sql` -- create the temp fixture table (primary key kind, object), `\ir privilege_fixture.psql`, build the actual catalog, run the 6 tests below -- the catalog test.
- [x] `app/tests/README.md` -- one short paragraph: every migration that adds or changes a table, column, function or view updates `privilege_fixture.psql`; what the catalog test fails on, naming each object (only tests 1 and 2 print paste-ready fixture lines) -- later epics follow it.

**Acceptance Criteria:**
- Given the branch's migrations on a fresh local stack, when `supabase test db` runs, then `03_privileges.sql` passes 6/6 and the run reports `Result: PASS`.
- Given each injected change in the I/O matrix made inside the test's transaction, when `supabase test db` runs, then it reports `Result: FAIL` and the failing test's diagnostics name the object; after revert, `Result: PASS`.
- Given a table `app.t (id, name)` whose table line is in the fixture but whose `name` column has no line, when `supabase test db` runs, then test 1 fails printing `column|app.t.name|`; with a `column|app.t.id|` and `column|app.t.name|` line added it passes.
- Given an object whose printed name holds a quoted identifier (a table `app."order"`, or a function argument named `limit`), when the line test 1 printed is pasted into the fixture, then the run passes.
- Given a `public` view created `with (security_invoker = t)`, when `supabase test db` runs, then test 6 passes.
- Given the repo tree after the change, when `git status` and `git diff --stat` run, then only the three files above and this plan changed.

## Design Notes

Fixture line: `kind|object|grants`. `kind` is `table`, `view`, `materialized view`, `foreign table`, `column`, `function` (prokind f, a, w) or `procedure`. `object` is `schema.name`, `schema.table.column` or `schema.fn(identity args)` from `pg_get_function_identity_arguments`, built with `format('%I.%I...')`. `grants` is space-separated `grantee:PRIV,PRIV` (grantee `PUBLIC` for oid 0; `PRIV*` when grantable); a relation grantee holding every privilege the owner's `acldefault` holds is written `ALL`; empty means none. Canonicalize both sides with one `pg_temp` function (tokens sorted by grantee, privileges sorted, `collate "C"`), so a fixture author's ordering does not matter.

```
table|app.classes|authenticated:SELECT service_role:ALL
column|app.classes.name|authenticated:UPDATE
function|internal.add_student_as(actor uuid, student uuid)|
```

Every column (`attnum > 0`, not dropped) of every covered relation gets a line, even with no grants; its grants are its column-level ACL (`attacl`) only, empty when none, and table-level grants stay on the table line. So a missing column line fails test 1 like any other object. The fixture's `copy` uses `quote e'\x01'`, a byte no identifier holds, so `"` in a quoted identifier (`app."order"`, `"limit" integer`) reaches the table unchanged. The 6 tests, each `is_empty` so the diagnostics list the rows:
1. every catalog object has a fixture line (rows: the actual fixture line);
2. every fixture line has a catalog object (rows: the stale line);
3. grants match (rows: object, expected, actual);
4. no ACL entry, on any object of the three schemas, grants to `anon` or PUBLIC (AD-3 "anon gets nothing"; holds even when the fixture lists it);
5. no `internal` function is executable by `authenticated` (P0-006);
6. every view in `public` has `security_invoker` true, read with `pg_options_to_table(reloptions)` and `option_value::boolean` so every spelling Postgres accepts counts (AD-3, P0-006).

## Verification

**Commands:**
- `supabase test db` -- expected: `Result: PASS`, `03_privileges.sql` ok
- Injection per I/O matrix row, temporarily at the top of `03_privileges.sql` after `begin;` (or as a fixture line), then reverted -- expected: `Result: FAIL` naming the object each time; `git status --porcelain` empty of injections after
- `git diff --stat <baseline_revision>` -- expected: the three files and this plan

## Implementation Notes

- Built by a Sonnet subagent from this plan; verified by the parent session against the diff and by re-running every matrix row.
- Files: `supabase/tests/database/privilege_fixture.psql` (header, `copy ... from stdin`, no data rows), `supabase/tests/database/03_privileges.sql` (temp fixture table, `\ir`, catalog tables `catalog_obj`/`catalog_acl`, `pg_temp.privilege_canon`, 6 `is_empty` tests), `app/tests/README.md` (one Rules bullet, "Grants are listed").
- Column lines: only columns with column-level grants (`attacl`) get a line, as the Design Notes say; a column with no column-level grant has no line and is not reported missing. The fixture header states this.
- `supabase test db`: `Result: PASS`, 4 files, 20 tests, `03_privileges.sql` 6/6.
- Injections, each inside the test's transaction or as a fixture line, each reverted (tree has only the three files and this plan): unlisted `public.f()` failed tests 1 and 4 (`function|public.f()|PUBLIC:EXECUTE anon:EXECUTE authenticated:EXECUTE service_role:EXECUTE`); EXECUTE to anon on `public.g()` failed tests 1 and 4; `app.t` with SELECT,UPDATE vs fixture SELECT failed test 3 with expected and actual; stale `public.gone()` failed test 2; listed `internal.h()` granted to authenticated failed test 5; `public.v` without `security_invoker` failed test 6; `security_invoker = on` passed; duplicate fixture line failed on the primary key; missing fixture file failed (twice); matching table + column lines written in a different grantee order passed.
- Surprise: the subagent saw one missing-fixture run print PASS; not reproduced in 2 parent runs, both FAIL. A first parent injection harness (python string replace) produced fixture syntax errors; the same lines added with `ed` parsed correctly, so the fault was the harness, not the fixture.
- Fixture parsing uses CSV with the default `"` quote, so a quoted identifier (`"Foo"`) in an object name would be stripped; Fermi's names are snake_case (conventions), so it is left as is.
- Procedures print identity args as `IN x integer`; the failure line shows the exact text to paste.
- Review pass 1 routed bad_plan (column lines): this attempt was saved to the session scratchpad (`attempt1/`) and reverted; code re-derived from the amended plan.
- Re-derivation (loop 1), by a fresh Sonnet subagent starting from `attempt1/`: `03_privileges.sql` adds a `catalog_obj` row for every column (`attnum > 0`, not dropped) of every covered relation, drops the old acl-derived column rows, and test 6 reads `pg_options_to_table` with `::boolean`; the fixture's `copy` adds `quote e'\x01'` and its header says every column has a line; the README bullet says every column has a line and only the first two failures print a paste-ready line.
- Parent verification after loop 1: `supabase test db` `Result: PASS`, 4 files, 20 tests, `03_privileges.sql` ok. `app.t` with only its table line failed test 1 printing `column|app.t.id|` and `column|app.t.name|`; with both column lines, PASS. Unlisted `app."order"`, its column and `internal.lim("limit" integer)` failed test 1; the printed lines pasted (quotes undoubled) passed. A view `with (security_invoker = t)` passed test 6. Unlisted `public.f()` failed tests 1 and 4. The subagent also re-ran the earlier rows (anon listed, differing grant, stale, internal, definer view, duplicate, missing file), each failing as the matrix says; those code paths did not change from attempt 1, which the parent ran.
- pgTAP prints a record holding `"` with doubled quotes (`("table|app.""order""|")`), so for a quoted identifier the line to paste is the undoubled one; snake_case names print bare and paste as shown.

## Plan Change Log

### 2026-11-06 — Review pass 1, bad_plan
- **Trigger:** the README and fixture header promised every column is listed, but the test only saw columns with column-level grants, so a migration adding an ungranted column needed no fixture line and a column line with empty grants was flagged stale (finding 5). The plan caused it: its Always rule said every object appears even with no grants, while its Design Notes made column lines come from `attacl` only. Two findings traced to the plan's own choices too: CSV's default `"` quote strips the quotes from a quoted identifier, so a printed line for `app."order"` could never be pasted back (finding 1, verified: `copy` read `app."order"` as `app.order`); and the four `security_invoker` spellings reject `security_invoker = t`, which Postgres stores as `t` (finding 4, verified).
- **Amended:** Design Notes (every column gets a line, grants from `attacl`, empty when none; `quote e'\x01'`; test 6 by `pg_options_to_table` and `::boolean`); the fixture task's `copy` command; the README task (name each object, only tests 1 and 2 print fixture lines); three acceptance criteria for the column, quoted-identifier and view-spelling cases.
- **Known-bad state avoided:** an unlisted column passing, a column line that is reported stale, a printed line that cannot be pasted back, a valid invoker view failing.
- **KEEP:** the reverted attempt is saved at `/private/tmp/claude-501/-Users-sallvain-Projects-Fermi--bmad-loop-runs-20261106-192429-3aab-worktrees-1-6/60edac3b-4ce4-4822-ab76-a7b5758b3c9d/scratchpad/attempt1/` (`03_privileges.sql`, `privilege_fixture.psql`, `readme.patch`) and passed every I/O-matrix injection; start from it and change only what the amendments name. Keep: the temp fixture table with primary key and `\ir`; `catalog_obj` and `catalog_acl` temp tables; effective ACLs through `acldefault('r'|'f', owner)`; owner and extension-member exclusion; `pg_temp.privilege_canon` used on both sides (grantee order, privilege order, `ALL` collapse, `*` grantable); the six `is_empty` tests and their descriptions; test 1's paste-ready `kind|object|grants` line; the header's format, examples and how-to-read-a-failure text; README bullet placement under Rules ("Grants are listed").

## Review Triage Log

### 2026-11-06 — Review pass
- verdicts: 5 findings — high 0, medium 2, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[bad_plan]` CSV's default `"` quote strips the quotes from a quoted identifier, so a printed line for `app."order"` or an argument named `limit` cannot be pasted back and tests 1 and 2 fail for that object for good — verified on the local stack (`copy` read `app."order"` as `app.order`; `quote e'\x01'` kept it). Amendment: Design Notes and the fixture task use `quote e'\x01'`; a new AC covers it.
  - `[low]` `[patch]` The README bullet says every failure names the object "as a fixture line", but tests 3–6 print other shapes — true for tests 1 and 2 only. Folded into the re-derivation: README task now says the test names each object and only tests 1 and 2 print fixture lines.
  - `[low]` `[reject]` A malformed grants token (`authenticated`, `authenticated:`) canonicalises to empty and is silently accepted — real, but it can never hide a real grant: any grant the catalog holds makes the canonical strings differ and test 3 fail. The fix adds a validation guard to `privilege_canon`.
  - `[low]` `[bad_plan]` Test 6 accepts only `on`, `true`, `yes`, `1`, so `with (security_invoker = t)`, stored as `t`, fails — verified (`reloptions` `{security_invoker=t}`, `option_value::boolean` true). The plan listed those four spellings. Amendment: Design Notes test 6 reads `pg_options_to_table` with `::boolean`; a new AC covers it.
  - `[medium]` `[bad_plan]` The test sees only columns with column-level grants, so a migration adding a column needs no fixture line and nothing fails, while the header's "list every object" makes an empty-grants column line fail as stale — verified in `03_privileges.sql` (`att.attacl is not null`; column `catalog_obj` rows built from `catalog_acl`). The ticket asks for the expected grants of every column. Amendment: Design Notes give every column a line; a new AC covers a missing column line.

### 2026-11-06 — Review pass (loop 1)
- verdicts: 4 findings — high 0, medium 0, low 3, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` The fixture header said to paste the printed line, but pgTAP's `is_empty` prints record text, in parentheses and, for a line with a space, parenthesis or `"`, inside double quotes with inner `"` doubled — seen in this run's output (`(column|app.t.id|)`, `("table|app.""order""|")`). Patched: the header's "Reading a failure" paragraph shows the three printed forms and says to paste the text inside the parentheses, dropping the outer quotes and undoubling inner ones.
  - `[low]` `[patch]` The fixture header said the test prints the offending lines in the fixture's format, but only tests 1 and 2 do (test 3 expected/actual, test 4 one grant per row, tests 5 and 6 the object name). Patched: the same paragraph names which tests print fixture lines and what the others print.
  - `[low]` `[reject]` Implementation Notes lines about attempt 1 (columns from `attacl` only, default CSV quote) contradict the shipped code — the fix edits this build's plan; the notes are append-only and the loop-1 note below them records the re-derivation.
  - `[false]` `[reject]` Nothing notices a fixture that never loads, so an empty schema set would pass with no fixture — a missing or unreadable include stops psql and fails the run: `Result: FAIL` ("You planned 6 tests but ran 0") in two parent runs on attempt 1 and in the loop-1 subagent's run; the include line is unchanged.

## Auto Run Result

Status: built

- **Summary:** AD-3 now has an automated guard. `supabase/tests/database/privilege_fixture.psql` is the checked-in list of expected grants for every table, view, column and function in `public`, `app` and `internal` (empty today, since those schemas hold no objects yet). `supabase/tests/database/03_privileges.sql` compares the live catalog, using effective ACLs so a function's implicit PUBLIC EXECUTE counts, and fails naming the object on: an unlisted object (every column included), a stale line, a different grant, any grant to `anon` or PUBLIC even if listed, an `internal` function executable by `authenticated`, and a `public` view without `security_invoker`. It runs in CI's existing Database Tests job with no workflow change.
- **Files changed:**
  - `supabase/tests/database/privilege_fixture.psql` -- the fixture: format, examples, how to read a failure, and an empty `copy` block.
  - `supabase/tests/database/03_privileges.sql` -- the catalog test, 6 pgTAP tests in one rolled-back transaction.
  - `app/tests/README.md` -- Rules bullet "Grants are listed": every migration updates the fixture in the same change.
  - this plan.
- **Review findings:** pass 1, 5 findings: 3 routed bad_plan (every column needs a line; CSV quote stripped quoted identifiers; view-option spellings), which amended the plan and re-derived the code; 1 low README overclaim folded into the re-derivation; 1 low rejected (a malformed grants token reads as empty, which can never hide a real grant, and the fix adds a guard). Pass 2 (loop 1), 4 findings: 2 low patched (fixture header's paste instructions and which tests print fixture lines); 1 low rejected (fix edits this plan); 1 false (a missing fixture fails the run). Deferred 0.
- **Follow-up review recommended:** false. Patched entries: high 0, medium 0, low 2 (pass 2); pass 1 entries were bad_plan re-derivations, not patches.
- **Verification:** `supabase test db` `Result: PASS`, 4 files, 20 tests, `03_privileges.sql` 6/6. Injected inside the test's transaction or as fixture lines, each reverted: unlisted function failed tests 1 and 4 naming it; EXECUTE to anon failed test 4 (and 3 when listed); differing grant failed test 3 with expected and actual; stale line failed test 2; `internal` function granted to authenticated failed test 5; view without `security_invoker` failed test 6, `= on` and `= t` passed; table without its column lines failed test 1 naming each column, passed once listed; quoted identifiers (`app."order"`, argument `limit`) failed when unlisted and passed once pasted; duplicate fixture line and missing fixture file each failed the run; grantees in a different order passed.
- **Residual risks:** The ticket's check is a CI run: the pgTAP job passing on main and a pull request adding an unlisted function or an anon grant failing it. That is UNVERIFIED until the orchestrator's pull request runs `test.yml`; the local runs used the same `supabase test db` command on the shared local stack. Sequences and types are not covered (out of the ticket's scope), so an identity column's sequence opened by Supabase's default privileges would not be caught. Story 7, next after this one, adds `internal.job_failures` and `public.job_health()` and must add their lines (and every column's) to the fixture in the same change.

