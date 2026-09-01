# {{PROJECT_NAME}} — Quality Gates inventory

> This file answers one question: **for every quality dimension, is there a
> deterministic constraint (gate), at which layer, how strict, and what's the
> escape hatch?**
> Whether an agent's proposal may land is decided by gates, not by prose rules +
> agent goodwill (behavior rule R11).
> When adding a machine-checkable must-follow rule: build the gate first, then
> document the pointer; see `.ai-collab/docs/ai-collab-doc-governance.md` § new
> entry routing flow.

## Current gates

| Gate | Stage | Quality dimension | Hard/Soft | Escape hatch |
| ---- | ----- | ----------------- | --------- | ------------ |
| shell-guard hook (`cursor-shell-guard-hook.sh`, Cursor `beforeShellExecution`) | edit-time | environment discipline (default R6 uv-only) | hard (deny) | project-root `.ai-collab-shell-deny.txt` override/emptied |
| doc-check hook (`cursor-doc-check-hook.sh`, Cursor `afterFileEdit`) | edit-time | doc governance | soft (report only) | — |
| pre-commit `check.sh` / `check_ai_collab_docs.py` | commit | doc governance (line counts / budgets / canonical conflicts) | hard (blocks commit) | `AI_COLLAB_ALLOW_*=1` (logged to bypass ledger) |
| TODO: `make lint` (or equivalent lint command) | commit / CI | style + static correctness | hard | — |
| TODO: `make test` (or equivalent test command) | CI | correctness | hard | — |

## Dimensions not yet covered (explicit no-gate list)

> A dimension without a gate isn't absent — it's unguarded. Keep it visible here;
> move it into the table above once covered.

| Dimension | Current state | Candidate gate |
| --------- | ------------- | -------------- |
| Correctness depth | regular tests only | mutation testing (e.g. mutmut) / property tests (e.g. hypothesis) |
| Security | TODO | secret scanning / dependency vulnerability scanning (CI layer) |
| Performance | TODO | key-path benchmarks + regression thresholds |
| Complexity / readability | TODO | cyclomatic complexity / function-length thresholds (lint layer) |

## Maintenance rules

- Every **hard gate must have an escape hatch**, and escape-hatch usage must be
  logged (`.ai-collab/runtime/bypass.log`); a hard gate without one only teaches
  everyone `--no-verify`.
- Tightening or loosening any gate is a deliberate decision: edit this table and
  the corresponding script constants in the same commit.
- Review the bypass ledger regularly (see governance doc § periodic review): the
  same gate bypassed ≥ 3 times → formally widen it or fix the root cause.
- This file only registers gates (what / which layer / how strict); gate
  implementation details and troubleshooting go into script comments and
  `lesson_learned*.md`.