# ADR Index

> Last updated: YYYY-MM-DD

`docs/ADR/` stores individual Architecture Decision Records. This page is only
navigation and status overview — it does not duplicate each ADR's details; open
the corresponding file for background, trade-offs, and implementation detail.

## Usage rules

- For a new ADR, copy `docs/ADR/000-template.md` first, then trim sections as
  needed.
- One ADR per file, named `NNN-slug.md`.
- `README.md` keeps only the index, status, and navigation; don't pile full
  summaries back in here.
- `lesson_learned.md` keeps lessons that are still in active reuse; ADR history
  and proposals live under `docs/ADR/`.

## ADR list

| ADR | Title | Status | Date | Topic |
| --- | ----- | ------ | ---- | ----- |
<!-- Add one row per new ADR: | [NNN](NNN-slug.md) | Title | Status | Date | Topic | -->

## Quick groups

<!-- Group ADRs by topic for fast lookup -->
- Foundational principles: TODO
- Capabilities: TODO
- Infrastructure: TODO

## Maintenance rules

- Evolve the template at `docs/ADR/000-template.md`; don't invent per-ADR formats.
- For a new ADR, add both `docs/ADR/NNN-*.md` and one index row on this page.
- When an ADR lands or its status changes, update the ADR file and this page
  first; stop maintaining duplicate summaries in `lesson_learned.md`.