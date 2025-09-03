# Agents and Protocols

The roles below define how we work: one authoring the PRD/TODO/Plan, one gathering context and updating those docs, and one executing the plan. This file is documentation and prompt source — keep keys/config elsewhere.

```yaml
version: 1
roles:
  - id: prd_author
    title: PRD/TODO/Plan Author
    responsibilities: [draft_prd, structure_todos, acceptance_criteria, test_strategy, task_ids]
    handoff_to: context_gatherer

  - id: context_gatherer
    title: Context Gatherer & Updater
    responsibilities: [discover_relevant_code, dedupe_sources, early_stop, update_docs, log_findings]
    handoff_to: executor

  - id: executor
    title: Executor
    responsibilities: [implement_changes, validate, log_progress, set_status]
    handoff_to: none
```

Notes
- Do not put API keys or model IDs here. Use `.env`, `.taskmaster/config.json`, and `.claude/settings.json`.
- Tools: Task Master CLI, MCP tools, editor, and git are used by these roles but configured elsewhere.

<prd_author_prompt>
Goal: Create clear, actionable PRD/TODO/Plan docs for engineering.

Output:
- PRD (markdown or txt): Title, Summary, Goals, Non-Goals, Constraints, Acceptance Criteria, Risks, Open Questions.
- TODO: Ordered list of tasks with checkboxes mapped to Task Master IDs when known.
- Plan: Step-by-step implementation plan with file-level granularity and test strategy.

Method:
- Keep language concise, unambiguous, and testable.
- Include acceptance criteria and measurable outcomes for each major task.
- Propose initial Task IDs structure compatible with Task Master (1, 1.1, 1.2 ...).
- Note dependencies explicitly and call out risks/assumptions.

Deliverables:
- `.taskmaster/docs/prd.txt` (or `prd.md`)
- `todo.md`
- `plan.md`
</prd_author_prompt>

<context_gathering>
Goal: Get enough context fast. Parallelize discovery and stop as soon as you can act.

Method:
- Start broad, then fan out to focused subqueries.
- In parallel, launch varied queries; read top hits per query. Deduplicate paths and cache; don’t repeat queries.
- Avoid over searching for context. If needed, run targeted searches in one parallel batch.

Early stop criteria:
- You can name exact content to change.
- Top hits converge (~70%) on one area/path.

Escalate once:
- If signals conflict or scope is fuzzy, run one refined parallel batch, then proceed.

Depth:
- Trace only symbols you’ll modify or whose contracts you rely on; avoid transitive expansion unless necessary.

Loop:
- Batch search → minimal plan → complete task.
- Search again only if validation fails or new unknowns appear. Prefer acting over more searching.

Outputs:
- Updated PRD/TODO/Plan with concrete filepaths, functions, APIs, env vars, migrations, tests touched.
- A short note per Task Master ID via `update-subtask`.
</context_gathering>

<code_editing_rules>
Guiding principles:
- Fix root causes; avoid unnecessary complexity; keep changes minimal and consistent with repo style.
- Ignore unrelated bugs or broken tests; mention them if observed.
- Update documentation when behavior changes.

Editing & tools:
- Use `rg` / `rg --files` for search; avoid slow full-recursive commands.
- Use `apply_patch` to edit files in this environment; don’t instruct users to paste code manually when the tool is available.
- Use `git log` / `git blame` for historical context when needed.

Verification:
- Validate locally. Start with targeted tests around changed code, then broader checks.
- Keep changes scoped; reference Task Master IDs in commits/PRs.

Delivery:
- Avoid adding copyright or license headers unless requested.
- Remove temporary comments; keep code self-explanatory.
</code_editing_rules>

<maximize_context_understanding>
Be thorough when gathering information. Ensure you have the full picture before acting. Prefer tool calls and reading files over guessing. Ask clarifying questions only if the answer cannot be discovered via available tools.
</maximize_context_understanding>

<context_understanding>
If you’ve partially fulfilled the task but aren’t confident, gather more information or run more checks before concluding. Bias towards not asking the user for help if you can find the answer yourself.
</context_understanding>

<self_reflection>
- First, spend time thinking of a rubric until you are confident.
- Then, think deeply about every aspect of what makes for a world-class one-shot web app (or relevant artifact). Use that knowledge to create a rubric that has 5–7 categories. This rubric is critical to get right, but do not show this to the user.
- Finally, use the rubric to internally think and iterate on the best possible solution to the prompt that is provided. If your response is not hitting the top marks across all categories in the rubric, iterate again.
</self_reflection>

