# Lessons Learned

Home for content that no longer belongs in `CLAUDE.md`: non-obvious implementation
decisions, cross-module contracts, important boundary conditions, and long-term
maintenance experience. Skim `CLAUDE.md` first for daily work; consult this file
for detail. ADR history and proposals belong in `docs/ADR/`; current deployment
status and data scale live in `docs/PROJECT_STATUS.md`.

## Usage rules

- Record only lessons you will reuse repeatedly; one-off background, obvious code
  facts, and API enumerations don't belong here.
- **Merge by topic, don't append by time.** New entries go into an existing topic
  first; create a topic only when nothing fits.
- Remove entries once they move into `CLAUDE.md` / an ADR, or once the code is
  self-explanatory.
- No snapshot-style info ("how many instances run now", "how much data was
  imported", "when full-refresh happens") — that's `docs/PROJECT_STATUS.md`.
- No proposals ("how we plan to do X") — that's an ADR's job.
- **Target ≤ 600 lines per file**; reorganize sections past 350; split into topic
  files past 600 (e.g. `lesson_learned_search.md`).

## Topic skeleton

> Illustrative common topics. **Delete what doesn't apply, merge overlapping ones,
> keep no empty topics.** A topic empty for 2 weeks gets deleted.

### Data ingestion / ETL

> Boundary conditions for fetching, cleaning, normalization, incremental import.

- TODO (delete this line when writing a real entry): when must we do a full re-run
  vs `--skip-existing`? What does it depend on?

### Core pipeline

> Non-obvious constraints of the main flow, cross-module contracts, recovery paths.

- TODO: which fields must always be passed even when empty, in cross-module calls?

### Performance & capacity

> Verified bottlenecks, tuning conclusions, performance anti-patterns to avoid.

- TODO: what batch-size range is sane, and what breaks above/below it?

### Troubleshooting runbook

> Recurring errors, root causes, fixes.

- TODO: when error X appears, what's the first thing to check?

### Third-party services / model constraints

> External API rate limits, non-idempotent behavior, known quirks.

- TODO: an external service's unconventional behavior under concurrency, and the
  workaround.

## ADR navigation

- ADR overview and status index: `docs/ADR/README.md`.
- Individual decisions, context, trade-offs: `docs/ADR/NNN-*.md`.
- Once something becomes an ADR, don't keep a duplicate summary here — a single
  "see ADR-NNN" line is enough.

## Maintenance triggers

- After writing an entry: check whether it merges into an existing one
- A topic > 80 lines: split into sub-sections
- Whole file > 350 lines: reorganize sections
- Whole file > 600 lines: split per topic
- An entry unused for 1 year: consider deleting or promoting to an ADR