---
name: task-scratchpad
description: Maintain Devin-style short-term task memory without polluting canonical docs. Use for multi-step implementation, debugging, long-running work, or when a task needs explicit plan/progress tracking across tool calls.
---
# Task Scratchpad

> **Canonical source: `.ai-collab/skills/task-scratchpad/SKILL.md`** (bundled with [ai-collab-standard](https://github.com/alexchenyu/ai-collab-standard)). The copy under `.cursor/skills/task-scratchpad/SKILL.md` is auto-installed by `init_ai_collab_docs.sh` and **will be overwritten**. Edit upstream and PR back; do not edit the local copy in-place.

Use this for non-trivial tasks where a short-lived plan, assumptions, progress, or verification checklist would reduce drift.

## Scratchpad Path

Default path:

```text
.agent-scratchpad.local.md
```

Use `.ai-collab/runtime/scratchpad.local.md` only if the project already keeps AI collaboration runtime files under `.ai-collab/runtime/`.

Scratchpad files are local working memory:

- must be ignored by git
- are never canonical source
- must not be referenced from committed docs as truth
- must be cleared or deleted when the task ends

## Start Of Task

Create or overwrite the scratchpad for the current task:

```markdown
# Task Scratchpad

## Goal
<one sentence>

## Assumptions
- <assumption or "none">

## Plan
- [ ] <step> -> verify: <check>
- [ ] <step> -> verify: <check>

## Progress
- Started: <short note>

## Durable Findings To Route
- <empty until something reusable appears>
```

Do not use scratchpad for trivial one-step edits.

## During Task

Update progress after meaningful milestones:

- mark completed plan items
- add changed assumptions
- record verification results
- capture reusable findings under "Durable Findings To Route"

Keep it short. If the scratchpad grows large, summarize and delete stale lines.

## End Of Task

Before final response:

1. Review "Durable Findings To Route".
2. Move reusable lessons to `lesson_learned*.md`.
3. Move decisions / proposals to `docs/ADR/`.
4. Move current status numbers to `docs/PROJECT_STATUS.md`.
5. If the work revealed a reusable multi-step workflow, create or update a skill under `.cursor/skills/`.
6. Clear or delete the scratchpad.

## Guardrails

- Do not write scratchpad content into `.cursorrules`.
- Do not commit scratchpad files.
- Do not preserve one-off task notes as lessons.
- Do not create a skill for a one-off workaround.
