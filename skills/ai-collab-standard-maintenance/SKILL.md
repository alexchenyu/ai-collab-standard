---
name: ai-collab-standard-maintenance
description: Maintain AI Collab Docs Standard files consistently. Use when editing .ai-collab governance docs, agent behavior rules, templates, cursorrules.template, init/check scripts, or when the user asks to add AI collaboration rules.
---
# AI Collab Standard Maintenance

> **Canonical source: `.ai-collab/skills/ai-collab-standard-maintenance/SKILL.md`** (bundled with [ai-collab-standard](https://github.com/alexchenyu/ai-collab-standard)). The copy under `.cursor/skills/ai-collab-standard-maintenance/SKILL.md` is auto-installed by `init_ai_collab_docs.sh` and **will be overwritten**. Edit upstream and PR back.

Use this when changing the AI collaboration standard itself, not ordinary project docs.

## Workflow

1. Identify the canonical layer:
   - information placement / routing -> `docs/ai-collab-doc-governance.md`
   - agent behavior -> `docs/ai-collab-agent-behavior.md`
   - user-facing overview -> `README.md`
   - generated downstream defaults -> `docs/*.template.md` or `docs/cursorrules.template`
   - enforceable checks / bootstrap behavior -> `scripts/bootstrap.sh`, `scripts/init_ai_collab_docs.sh`, or `scripts/check.sh`

2. Keep mirrors synchronized:
   - If editing `docs/ai-collab-doc-governance.md`, apply the same semantic change to `docs/ai-collab-doc-governance.template.md`.
   - If the change affects onboarding, update `README.md`.
   - If the change affects generated `.cursorrules`, update `docs/cursorrules.template` and keep it within the 10-line budget.

3. Prefer active routing rules over vague advice:
   - Say where information goes.
   - Say what must not go into `.cursorrules`.
   - Say when an agent should create / update a skill instead of only suggesting one.

4. Add automation only when the rule is checkable:
   - Put health checks in `scripts/check.sh`.
   - Put bootstrap/default setup in `scripts/init_ai_collab_docs.sh`.
   - Keep script changes POSIX-ish Bash and validate with `bash -n`.

5. Verify before finishing:

```bash
bash -n .ai-collab/scripts/init_ai_collab_docs.sh && bash -n .ai-collab/scripts/check.sh
bash .ai-collab/scripts/check.sh .
git diff --check
git -C .ai-collab diff --check
```

6. Report:
   - rules changed
   - templates synchronized
   - automation changed, if any
   - checks run

## Guardrails

- Do not make `.cursorrules` a canonical source.
- Do not add long theory to `CLAUDE.md`; it is usually already at the line budget.
- Do not leave governance docs and templates semantically different.
- Do not create a new skill for a one-off lesson; route that to `lesson_learned*.md`.
