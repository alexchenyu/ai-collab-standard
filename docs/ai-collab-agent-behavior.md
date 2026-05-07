# AI Agent Behavior Guidelines

> **Scope:** Cross-project, cross-tool behavioral constraints for AI coding agents.
> **Status:** Canonical source. Other docs (`CLAUDE.md`, `.cursorrules`, `AGENT.md`) only point here, never restate.
> **Tradeoff:** Biased toward caution over speed. For trivial tasks (typo fixes, one-line obvious changes), use judgment — not every change needs the full ceremony.

This file is the companion to `ai-collab-doc-governance.md`:

- `ai-collab-doc-governance.md` answers: **where does information go?**
- `ai-collab-agent-behavior.md` (this file) answers: **how should the agent think and act?**

Inspired by Andrej Karpathy's observations on LLM coding pitfalls (see [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)), adapted and extended with project-specific rules earned through actual incidents in this repository.

---

## The Four Universal Principles

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

LLMs default to silently picking one interpretation and running with it. Counter that:

- **State assumptions explicitly.** If uncertain, ask before writing code.
- **Present multiple interpretations** when ambiguity exists. Don't pick silently.
- **Push back when warranted.** If a simpler approach exists, say so. If the request contradicts an existing constraint, name the contradiction.
- **Stop when confused.** Name what's unclear. Ask. Do not paper over confusion with plausible-looking code.

Trigger to apply: any task where the request leaves room for >1 reasonable implementation, or where the request conflicts with constraints in `CLAUDE.md` / `lesson_learned*.md` / ADRs.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you wrote 200 lines and it could be 50, rewrite it before declaring done.

Self-test: *"Would a senior engineer reviewing this PR say it's overcomplicated?"* If yes, simplify before submitting.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd write it differently.
- If you notice unrelated dead code or smells, **mention them** — don't silently delete or rewrite.

When your changes orphan things:

- Remove imports/variables/functions that **your changes** made unused.
- Do **not** remove pre-existing dead code unless explicitly asked.

The test: every changed line should trace directly back to the user's request.

### 4. Goal-Driven Execution

**Define verifiable success criteria. Loop until verified.**

Transform imperative tasks into declarative, checkable goals:

| Don't say... | Say instead... |
|---|---|
| "Add validation" | "Write tests for invalid inputs, then make them pass." |
| "Fix the bug" | "Write a test that reproduces the bug, then make it pass." |
| "Refactor X" | "Ensure existing tests pass before and after the refactor." |
| "Improve chunking quality" | "Define a measurable metric (e.g., recall@10 on eval set), record baseline, target improvement." |

For multi-step work, state the plan upfront with explicit verification per step:

```
1. [Step]  → verify: [check / test / metric]
2. [Step]  → verify: [check / test / metric]
3. [Step]  → verify: [check / test / metric]
```

Strong success criteria let the agent loop independently. Weak criteria ("make it work") force constant clarification roundtrips.

---

## Project-Specific Behavioral Rules

These are extensions on top of the four principles, derived from concrete incidents in this codebase. Update only when a new class of incident appears, not for one-off bugs (those go to `lesson_learned*.md`).

### R1. Canonical-source discipline overrides "helpfulness"

When you notice a fact that lives in two places, do **not** silently sync them. Identify the canonical source per `ai-collab-doc-governance.md` and either:

- Move the duplicate's content into the canonical source and replace it with a one-line pointer, **or**
- Surface the conflict and ask which is correct.

Never resolve a doc conflict by editing both sides to match — you don't yet know which one was right.

### R2. Reuse persisted derived artifacts by default

Embeddings, chunk JSON, parse outputs, LLM-extracted fields, and crawl manifests are **engineering assets**, not throwaway intermediates.

- Default behavior is **reuse existing output**, not regenerate.
- Only regenerate when (a) inputs changed, (b) generator contract changed, or (c) user explicitly passed `--force` / equivalent.
- "GPU is fast" / "API still has quota" is **not** a justification for re-running. Re-running amplifies cost, latency, **and result drift**.

### R3. Long-running pipelines need progress + verifiable resumability

For any task expected to run >5 minutes (chunking, ingest, eval, large crawls):

- Write progress to a file (manifest / `.progress.json` / DB row), not just stdout.
- Resume logic must cross-check the progress file against **actual output files**, not trust either alone.
- Print periodic status (every N items or every M seconds) so a human or polling agent can detect stalls.

### R4. Don't grow `CLAUDE.md` / `.cursorrules` to "remember" lessons

When you discover a new gotcha, the **default** destination is `lesson_learned*.md` under the matching topic. Promotion to `CLAUDE.md` requires:

- The rule applies to >50% of future tasks, **and**
- Forgetting it causes high-severity errors (data corruption, prod outage, silent quality regression).

Otherwise it stays in `lesson_learned*.md`. See `ai-collab-doc-governance.md` § "新条目路由流程".

### R5. Prefer narrow, testable units over closure-heavy handlers

When a handler / pipeline step grows non-trivial logic, extract a module-level pure helper with a narrow argument surface and add focused unit tests against the helper — instead of testing through the full request / pipeline path. (See `.cursor/skills/extract-testable-helper/` for the pattern.)

### R6. Respect `uv` / `pyproject.toml` boundaries

This is a Python project. Run scripts with `uv run python ...`, not `python` / `python3`. Add deps with `uv add ...`, not bare `pip install`. Touching system Python or creating ad-hoc venvs is a behavioral violation, not a stylistic one.

### R7. Use scratchpad only as short-term working memory

For multi-step tasks, keeping a lightweight plan / progress log can help preserve context. If persistent working memory is needed, use a local scratchpad such as `.agent-scratchpad.local.md` or `.ai-collab/runtime/scratchpad.local.md`.

- Use the bundled `task-scratchpad` skill when it is available; `init_ai_collab_docs.sh` installs it from `.ai-collab/skills/` into `.cursor/skills/`.
- Scratchpad content is never canonical source and must not be committed.
- Keep only current task plan, progress, temporary assumptions, and verification checkpoints there.
- At task end, migrate durable conclusions through `ai-collab-doc-governance.md`: lessons to `lesson_learned*.md`, decisions to ADR, status to `PROJECT_STATUS.md`; then clear or delete the scratchpad.
- Never use `.cursorrules` as scratchpad.

### R8. Learn from corrections through the lesson route

When the user corrects you, or you discover a reusable gotcha while fixing your own mistake, do not append it to `.cursorrules`.

- If it is not reusable, just acknowledge it in the current work.
- If it is reusable, merge it into the matching `lesson_learned*.md` topic.
- Promote it to `CLAUDE.md` only if it is high-frequency and forgetting it causes high-severity errors.

### R9. Package reusable agent workflows as skills

If a workflow is reusable and needs multiple commands, tools, examples, or resources, create or update a skill / runbook instead of expanding repo rules.

- Use `.cursor/skills/<name>/SKILL.md` for reusable agent capabilities.
- When you notice a suitable skill opportunity during implementation, create or update the skill in the same turn if it is small and clearly scoped.
- Ask first if the skill would introduce new dependencies, encode project policy you are unsure about, or require broad restructuring.
- Keep `CLAUDE.md`, `.cursorrules`, and `AGENTS.md` as entry points, not tool manuals.
- Prefer a shared `.claude/skills -> ../.cursor/skills` symlink when Claude Code needs the same capabilities.
- Enable Codex skills only by explicit opt-in (`init_ai_collab_docs.sh --enable-codex-skills`) to avoid duplicate skill scans in Cursor.

### R10. Separate planner, executor, and reviewer roles on risky work

For broad, risky, or ambiguous work, explicitly split the loop even if one agent performs all roles:

1. Planner: clarify assumptions, choose the smallest path, define verification.
2. Executor: make the scoped changes.
3. Reviewer: check diffs, tests, docs routing, and whether any lesson should be persisted.

Use subagents only when the split has concrete value, such as parallel exploration, independent review, or isolated experiments.

---

## How to Tell This Is Working

Healthy signals:

- **Diffs only contain requested changes.** No drive-by formatting, no opportunistic "improvements".
- **Clarifying questions arrive before implementation**, not after a bad first attempt.
- **Plans precede multi-step work**, with explicit verification at each step.
- **Code is shorter than your first instinct**, because you simplified before submitting.
- **Re-runs of expensive pipelines are rare** and always have a stated reason.
- **Scratchpads disappear after the task**, with durable conclusions routed to the right canonical file.
- **Reusable workflows become skills proactively**, not longer `.cursorrules` prose or end-of-task suggestions.

Unhealthy signals (the rules are not landing):

- Agent silently picks one of multiple valid interpretations and writes 300 lines.
- Diff includes refactors of unrelated functions.
- "Done" is declared without a verification step.
- Same fact appears in `CLAUDE.md` and `lesson_learned*.md` with slightly different wording.
- Embeddings / chunks regenerated because nobody checked the existing output.
- `.cursorrules` contains a task plan, Lessons log, or tool manual.
- A repeated multi-step workflow keeps getting re-explained in chat instead of being captured as a skill.

---

## Maintenance

- Universal Principles section: change only with strong cross-project evidence; this is shared across consumers of `.ai-collab/`.
- Project-Specific Rules section: add a new `Rn.` only when a **class** of incident repeats. One-off bugs go to `lesson_learned*.md`.
- Length budget: this file ≤ 250 lines. If it grows past that, split project-specific rules into a separate file.
