# {{PROJECT_NAME}} Glossary (shared language)

> Canonical dictionary of project jargon. When an agent reads any file and hits an
> unfamiliar term, it should look here first instead of guessing.
> Size limit: **≤ 150 lines**. Only include terms reused in ≥ 2 lesson_learned /
> docs / code files; single-use terms stay where they appear.
> Entry format: `**Term** — one-line definition. Anchor: xxx`. The anchor is the
> most authoritative source (lesson topic / ADR / code module).

## TODO categories

> Split sections by this project's actual domains, e.g.: retrieval pipeline /
> data storage / models / ops / evaluation / governance.
> Section examples (trim as needed):

## Core pipeline

- TODO: **Core term 1** — one-line definition. Anchor: `docs/xxx.md` or `lesson_learned_xx.md` § topic
- TODO: **Core term 2** — one-line definition. Anchor: xxx

## Data / storage

- TODO: database table names / primary-key conventions / schema nouns
- TODO: index / collection naming rules

## Services / models

- TODO: main external services, models, inference engines

## Governance / meta

- **canonical source** — the single authoritative home of a fact; every other
  location keeps at most a one-line "see X" pointer. Anchor: `.ai-collab/docs/ai-collab-doc-governance.md`
- **behavior layer** — agent behavior rules (think before coding / terse / minimal
  diff / goal-driven). Anchor: `.ai-collab/docs/ai-collab-agent-behavior.md`

---

**Maintenance rules**:

- Before adding an entry, confirm it appears in ≥ 2 files and will be reused;
  single-use terms stay in place.
- Anchors must point at files / sections that still exist; update on renames.
- Split per section past 150 lines (e.g. `PROJECT_GLOSSARY_<topic>.md`); don't
  append forever.