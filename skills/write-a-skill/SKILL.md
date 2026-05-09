---
name: write-a-skill
description: Create new agent skills with proper structure, progressive disclosure, and bundled resources. Use when user wants to create, write, or build a new skill.
---

# Writing Skills

> **Canonical source: `.ai-collab/skills/write-a-skill/SKILL.md`** (bundled with [ai-collab-standard](https://github.com/alexchenyu/ai-collab-standard)). The copy under `.cursor/skills/write-a-skill/SKILL.md` is auto-installed by `init_ai_collab_docs.sh` and **will be overwritten** by future updates. Edit upstream and PR back; do not edit the local copy in-place.

## Step 0 — Decide: upstream skill or project-level skill?

Before drafting anything, answer one question:

> **Would another project that adopts ai-collab-standard also benefit from this skill?**

| Answer | Where the skill lives | Examples |
|--------|----------------------|----------|
| **Yes** — generic AI-collab / engineering practice (any team using the standard could reuse it as-is) | `.ai-collab/skills/<name>/SKILL.md` (canonical, ships with the standard, gets auto-installed into every consuming project's `.cursor/skills/`) | `task-scratchpad`, `standard-migration`, `write-a-skill`, `adr-maintenance` |
| **No** — references project-specific paths, scripts, services, datasets, hardware, or business rules | `.cursor/skills/<name>/SKILL.md` (project-level, lives in this repo only, never synced upstream) | `qwen-chunking-runbook` (specific ports + scripts), `rag-sync-pipeline` (specific data dirs) |

Heuristic test for "generic enough":

- Replace every concrete path / script / service name with a placeholder. Does the skill still make sense and still pull its weight? → **upstream**.
- Otherwise → **project-level**. Don't try to over-generalise; a focused project skill beats a vague upstream one.

If unsure, default to project-level. Promoting a project skill upstream later is cheap (move file + add canonical banner); demoting an over-generalised upstream skill that nobody else can use is awkward.

## Process

1. **Gather requirements** - ask user about:
   - What task/domain does the skill cover?
   - What specific use cases should it handle?
   - Does it need executable scripts or just instructions?
   - Any reference materials to include?

2. **Draft the skill** - create:
   - SKILL.md with concise instructions
   - Additional reference files if content exceeds 500 lines
   - Utility scripts if deterministic operations needed

3. **Review with user** - present draft and ask:
   - Does this cover your use cases?
   - Anything missing or unclear?
   - Should any section be more/less detailed?

## Skill Structure

```
skill-name/
├── SKILL.md           # Main instructions (required)
├── REFERENCE.md       # Detailed docs (if needed)
├── EXAMPLES.md        # Usage examples (if needed)
└── scripts/           # Utility scripts (if needed)
    └── helper.js
```

## SKILL.md Template

```md
---
name: skill-name
description: Brief description of capability. Use when [specific triggers].
---

# Skill Name

## Quick start

[Minimal working example]

## Workflows

[Step-by-step processes with checklists for complex tasks]

## Advanced features

[Link to separate files: See [REFERENCE.md](REFERENCE.md)]
```

## Description Requirements

The description is **the only thing your agent sees** when deciding which skill to load. It's surfaced in the system prompt alongside all other installed skills. Your agent reads these descriptions and picks the relevant skill based on the user's request.

**Goal**: Give your agent just enough info to know:

1. What capability this skill provides
2. When/why to trigger it (specific keywords, contexts, file types)

**Format**:

- Max 1024 chars
- Write in third person
- First sentence: what it does
- Second sentence: "Use when [specific triggers]"

**Good example**:

```
Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when user mentions PDFs, forms, or document extraction.
```

**Bad example**:

```
Helps with documents.
```

The bad example gives your agent no way to distinguish this from other document skills.

## When to Add Scripts

Add utility scripts when:

- Operation is deterministic (validation, formatting)
- Same code would be generated repeatedly
- Errors need explicit handling

Scripts save tokens and improve reliability vs generated code.

## When to Split Files

Split into separate files when:

- SKILL.md exceeds 100 lines
- Content has distinct domains (finance vs sales schemas)
- Advanced features are rarely needed

## Review Checklist

After drafting, verify:

- [ ] Description includes triggers ("Use when...")
- [ ] SKILL.md under 100 lines
- [ ] No time-sensitive info
- [ ] Consistent terminology
- [ ] Concrete examples included
- [ ] References one level deep
