---
name: adr-maintenance
description: Add or update an Architecture Decision Record (ADR) and keep its index page in sync. Use when the user asks to "create an ADR", "record this decision as an ADR", "write up ADR-NNN", or when an existing ADR's status changes (Proposed → Accepted, Accepted → Superseded / Deprecated). Covers the full five-point sync to `docs/ADR/README.md` (or whatever index file the project uses) so the index never drifts from the actual ADR files.
---

# ADR Maintenance

> **Canonical source: `.ai-collab/skills/adr-maintenance/SKILL.md`** (bundled with [ai-collab-standard](https://github.com/alexchenyu/ai-collab-standard)). The copy under `.cursor/skills/adr-maintenance/SKILL.md` is auto-installed by `init_ai_collab_docs.sh` and **will be overwritten** by future updates. Edit upstream and PR back; do not edit the local copy in-place.

ADRs (Architecture Decision Records, Michael Nygard 2011) are immutable once accepted. The most common drift is **the index page falls out of sync** with the actual ADR files: counts wrong, new ADR missing from the table, status header stale, decisions no longer grouped under their topic. This skill enforces the **five-point sync** every time an ADR is added or changes status.

## When to invoke

- Adding a new ADR file (`docs/ADR/NNN-slug.md`)
- Changing an existing ADR's status (Proposed → Accepted, Accepted → Superseded by NNN, Accepted → Deprecated)
- Splitting one ADR into several, or merging several into one
- User says "record this as an ADR", "create ADR-NNN", "supersede ADR-NNN", "mark ADR-NNN deprecated"

If the project has no ADR index page yet (only loose `NNN-*.md` files in `docs/ADR/`), still create the new ADR file but tell the user the index page is missing — offer to scaffold one.

## Pre-flight: locate the canonical files

Run these checks first; do not assume layout:

1. ADR directory — usually `docs/ADR/` or `docs/adr/`. Glob `**/ADR/*.md` to confirm.
2. ADR template — usually `docs/ADR/000-template.md`. Use it as the starting point; never write a new ADR from scratch.
3. ADR index — usually `docs/ADR/README.md`. If present, this skill's five-point sync applies.
4. Next ADR number — `ls docs/ADR/ | sort` and pick the next free integer. Watch out for **reserved blocks** (e.g. some projects skip 055-059 and use 060+ for a different topic) — read the existing index's section headers before assigning a number.

## Workflow

### Step 1 — Create the ADR file

1. `cp docs/ADR/000-template.md docs/ADR/NNN-slug.md`
2. Fill in the four required sections (Status / Date / 背景 / 决策 / 理由 / 后果). Drop unused template sections rather than leaving stub headings.
3. Initial status is almost always **Proposed** — only mark Accepted if the work is already shipped.
4. Cross-link related ADRs in the header (Supersedes / Superseded-by / 相关 ADR).

### Step 2 — Five-point index sync (the actual contribution of this skill)

If `docs/ADR/README.md` (or equivalent index) exists, **all five** of the following must be updated in the same edit. Missing any one of them is the failure mode this skill prevents.

| # | What to update | Where to look in the index |
|---|---|---|
| 1 | **Top-of-file "last updated" line** | First non-heading paragraph, usually `> 最后更新：YYYY-MM-DD（...）` or `> Last updated: ...` |
| 2 | **Status totals table** | A table near the top with columns like `Active / Draft / Superseded / Deprecated` and counts. Increment the cell that matches the new ADR's status. |
| 3 | **Total decision count sentence** | A line like `ADR 决策总数：N（ADR-001 ~ ADR-NNN, ...）`. Bump N and extend the range, **excluding** numbered "implementation plan" files if the project's convention does so. |
| 4 | **Status section table row** | Add one row in the matching `## Active` / `## Draft` / `## Superseded` / `## Deprecated` table. Include link, title, status phrase, and topic column. |
| 5 | **Topic / quick-grouping section** | A section like `## 快速分组` or `## Topics`. Add the new ADR under whichever topic(s) apply (Infrastructure, RAG, Tooling, Security…). |

Status transitions (not just new ADRs) also touch points 1, 2, 4, 5. Example: moving ADR-NNN from Draft to Active means Draft count −1, Active count +1, remove the Draft table row, add an Active row, possibly re-bucket under topics.

### Step 3 — Verify

```bash
# Index integrity quick-check (no formal tool yet, eyeball-grade):
rg -n "总数|Active|Draft|Superseded|Deprecated|最后更新|Last updated" docs/ADR/README.md
ls docs/ADR/*.md | wc -l   # should match 'total decision count' + template + impl-plans
```

Run any project-level lint / format hooks before committing (Markdown lint, Prettier, etc.).

### Step 4 — Commit (only if user asked)

Single atomic commit with both the new ADR file **and** the README.md update. Never commit one without the other — half-synced indexes are worse than no index.

## Anti-patterns

- ❌ Writing the new ADR file but skipping the README five-point sync ("I'll do it later").
- ❌ Updating the top-of-file date to today without bumping the totals (mismatched signals).
- ❌ Adding the new ADR to the topic grouping but forgetting the status section table (or vice-versa).
- ❌ Bumping the total count past a reserved block without checking the index's section headers (e.g. silently filling a slot a future ADR was earmarked for).
- ❌ Mixing an ADR status change with unrelated index re-organisation in the same commit.

## Review checklist

Before declaring the ADR added, confirm all five points:

- [ ] Top-of-file "last updated" line bumped to today, with a short reason in parens
- [ ] Status totals table count incremented by exactly 1 in the right cell
- [ ] Total decision count sentence bumped (and range extended)
- [ ] Status section table has the new row, with correct topic column
- [ ] Topic / quick-grouping section lists the new ADR under each applicable topic
- [ ] Cross-links in the new ADR header (Supersedes / Superseded-by / 相关 ADR) match what the older ADRs already say
- [ ] If status change, the **previous** status's count was decremented and the previous status's table row was removed
