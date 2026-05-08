---
name: standard-migration
description: Disciplined workflow for migrating a project to a new external standard (cross-tool protocol like AGENTS.md, MCP, OpenAPI version bumps, new skill format, etc.). Research upstream → plan canonical/stub split → ship migration tool + non-destructive backup + MIGRATION.md, all in one pass. Use when the user asks to "follow the new X standard", "migrate to vN", "support tool Y too", or when ecosystem evidence shows our layout is outdated.
---

# Standard Migration

> **Canonical source: `.ai-collab/skills/standard-migration/SKILL.md`** (bundled with [ai-collab-standard](https://github.com/alexchenyu/ai-collab-standard)). The copy under `.cursor/skills/standard-migration/SKILL.md` is auto-installed by `init_ai_collab_docs.sh` and **will be overwritten** by future `--force` runs. Edit the upstream and PR back; do not edit the local copy in-place.

External protocols and AI-tool conventions move fast (Cursor `.cursorrules` → `.cursor/rules/*.mdc`, Codex `AGENTS.md`, MCP server config, Anthropic skill frontmatter, OpenAPI 3.x → 4.x). When upstream changes, do **not** patch in place — that produces a half-migrated repo where new and old layouts coexist forever. Instead run this 6-phase migration so legacy users have a clean upgrade path.

## When to invoke

Trigger when **any** of these are true:

- User says "we should follow the new X standard" / "migrate to vN" / "Codex/Cursor/MCP changed"
- Multiple recent web sources cite a new spec / Linux Foundation adoption / "deprecated in 2026"
- Our current file layout breaks silently in a tool's new mode (e.g. `.cursorrules` ignored in Cursor Agent mode)
- A subdirectory convention we use (`AGENT.md` singular) doesn't match what tools recursively auto-load (`AGENTS.md` plural)

If only one tiny thing changed (a flag rename, a new optional field), prefer a normal patch — this skill is for **architectural** shifts.

## Workflow (6 phases, ~30-90 min for typical scope)

### Phase 1 — Research (don't skip)

Use `WebSearch` for **all 3** of these in parallel before designing anything:

- The new spec itself (`<tool> <feature> 2026 spec`)
- Cross-tool comparison (`AGENTS.md vs CLAUDE.md`, `MCP server vs OpenAI plugin`, etc.)
- Migration / deprecation notes from the upstream tool

Then read the actual upstream source (often a GitHub link from search results — fetch it with `WebFetch` or read the cached agent-tools file). Confirm:

- What is canonical? What is the stub/pointer? What is deprecated?
- Hard limits: byte budget, line count, recursion depth, naming convention.
- Backward compat: does the new format coexist with the old, or is the old silently ignored?

**Output**: a 5-line "key facts" block you'll cite when explaining the change to the user. Cite sources (URLs) at the end of your report, not inline.

### Phase 2 — Decision tree (ask user before coding)

Use `AskQuestion` to lock 3-4 architectural decisions you cannot reverse cheaply later:

- **Canonical vs stub**: which file becomes truth, which becomes pointer?
- **Old artifact disposition**: deprecate-in-place / archive-as-`.legacy.bak` / delete entirely?
- **Naming**: pluralize? rename? both names temporarily?
- **Tool-specific extras**: which advanced features (e.g. Codex `AGENTS.override.md`, `~/.codex/config.toml`) to document/scaffold?

Default to **the most aggressive clean cut** unless the user says otherwise — half-migrated repos are worse than fully migrated ones.

### Phase 3 — Plan (TodoWrite, 8-15 items)

Mandatory items in order:

1. New canonical template (with content from old canonical, restructured)
2. New stub templates (one per tool that needs its own pointer)
3. Rename old artifacts (with `git mv`, not `cp + rm`, to preserve history)
4. Delete deprecated artifacts (`git rm`)
5. Rewrite the init/scaffold script to generate the new layout
6. Add `--migrate-legacy` flag to the same script (idempotent, non-destructive)
7. Update the health-check script (new limits, new files, new failure modes, fix-it hints)
8. Update any pre-commit / CI hook to recognize new + old file names
9. Rewrite README to lead with the new architecture
10. Write MIGRATION.md (see template below)
11. Smoke test on `/tmp/<fake-fresh>` and `/tmp/<fake-legacy>` projects
12. Commit + push

### Phase 4 — Implement migration tool (the critical artifact)

The migration tool must be **idempotent and non-destructive**. Concrete rules:

- **Never `rm` user content.** Rename to `<filename>.legacy.bak` and tell the user where their content went.
- **Never overwrite without `--force`.** Default behavior preserves existing files; `--force` is opt-in.
- **Scope `--force` to layout files only.** Split files into two render paths: `render_template()` (layout file, `--force` overwrites) vs `render_template_protected()` (user-content file, `--force` is **ignored** if file exists). User-content files = anything that accumulates project-specific data after first scaffold (`lesson_learned.md`, `PROJECT_STATUS.md`, `PROJECT_GLOSSARY.md`, `ADR/README.md`, subdir `AGENTS.md`). If `--force` blanket-overwrites these, you wipe out the user's real lessons / status / ADR catalog. **This bug bit `.ai-collab` once — caught and fixed in `init_ai_collab_docs.sh § render_template_protected`.**
- **Detect, don't auto-truncate.** If a file is now expected to be a stub but is currently substantive, *warn* with a one-line hint pointing at MIGRATION.md, do not rewrite it.
- **Use `git mv` when renaming committed files** so history follows.
- **Skip target if it already exists.** Idempotent runs are safe.
- **Print what changed.** Every action gets a `note "migration: ..."` line. For protected files that --force tried to touch, log explicitly: `preserve user content (--force ignored): <path>`.
- **Document `--force` scope in `--help`.** Spell out which files it touches and which it never touches, so users know what backup they need before running it.
- **Every shell script gets a `BASH_VERSINFO` guard at the top.** Cross-platform shell pain is real — macOS ships Bash 3.2 (frozen 2007, no GPLv3); Git for Windows ships Bash 4.4+. Pick the minimum your script actually needs and assert it loudly. Avoid raising the bar unless you actually use a Bash 4+ feature (associative arrays `declare -A`, `mapfile`/`readarray`, `${var^^}`/`${var,,}`, `coproc`, `&>>`); when you do, raise the guard *and* document it inline. Skeleton at the top of every new `.sh`:

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail   # or `set -uo pipefail` if you handle errors yourself

  # Bash 3.2+ compatible (no associative arrays / mapfile / case-modify expansions).
  # Raise to `< 4` when you intentionally add a Bash 4+ feature, and tell macOS
  # users to `brew install bash`.
  if (( ${BASH_VERSINFO[0]:-0} < 3 )); then
      echo "<script-name> requires Bash 3.2+; you have ${BASH_VERSION:-unknown}." >&2
      exit 1
  fi
  ```

  Also: prefer `grep -E` over `grep -P` (BSD grep on macOS has no `-P`); use `python3` instead of `sed -i` for in-place edits (BSD `sed -i` requires a backup-suffix arg, GNU does not); never assume `readlink -f` exists (BSD lacks it — use a Python one-liner or `cd ... && pwd`).

Reference implementation: `.ai-collab/scripts/init_ai_collab_docs.sh` `maybe_migrate_legacy()` + `render_template_protected()` (commit `102b97b` + follow-up). Bash guard pattern: top of `check.sh` / `install_hooks.sh` / `pre-commit.sh`.

#### Hook-specific pitfalls (5 traps that bit us)

These five all share one root cause: **reusing init's code path without re-checking that the new context (per-edit hook, per-commit hook, daemon-style trigger) preserves the assumptions the original code made**. Whenever a new script reuses an existing function or invocation pattern, run this checklist:

1. **`--force` blast radius** — adding a new file to a render loop reuses `render_template`, which `--force` overwrites. **Fix**: ask "would I want this file overwritten on every `--force` run?" — if no, route through `render_template_protected()` (idempotent, ignores `--force` if file exists). Bit us 3× on AGENTS.md re-render before we caught it; we now grep `render_template ` in PRs to check every new call site explicitly.

2. **Heredoc consumes the upstream stdin pipe** — `python3 - <<'PY'` redirects the heredoc into Python's stdin, so the upstream pipe (e.g. Cursor hook JSON, `git diff` output) is silently lost. **Fix**: use `python3 -c '...'` for inline scripts that must read external stdin. The heredoc form is only safe when the script doesn't need stdin.

   ```bash
   # WRONG — Cursor's JSON pipe is eaten by the heredoc
   echo "$cursor_json" | python3 - <<'PY'
   import json, sys; print(json.load(sys.stdin))
   PY

   # RIGHT — -c keeps stdin attached to the upstream pipe
   echo "$cursor_json" | python3 -c 'import json, sys; print(json.load(sys.stdin))'
   ```

3. **`uv run` in a hot path** — `uv run python` initialises/refreshes a `.venv` on every invocation (network + disk + lockfile checks). Acceptable for `make test`, lethal for hooks that fire on every file edit / every commit. **Fix**: in hot paths use plain `python3` (the lightweight checker has zero deps anyway). Save `uv run` for the developer-typed entrypoints.

4. **Hook exit codes have semantics** — Cursor treats non-zero exit from `afterFileEdit` / `beforeShellExecution` as **block the action**; pre-commit treats non-zero as **block the commit**. A check-only hook that wants to *report* (not block) must `exit 0` no matter what the underlying tool returned. **Fix**: end every reporting hook with an unconditional `exit 0`. Use `set +e` around the inner command, or pipe through `|| true`.

5. **Don't assume the upstream tool's JSON shape is stable** — Cursor moved `file_path` between top-level and `tool_input` between 1.6 and 1.7 betas; Codex envelope is different again. **Fix**: probe multiple known field paths and fail open if none match. Today's working example:

   ```python
   for k in ("file_path", "path"):
       if isinstance(payload.get(k), str): return payload[k]
   ti = payload.get("tool_input") or {}
   for k in ("file_path", "path", "target_file"):
       if isinstance(ti.get(k), str): return ti[k]
   return None  # fail open — let the hook no-op rather than crash
   ```

   Same principle for any `git for-each-ref` / `gh api` / shell tool whose output format is "stable enough until it isn't".

Reference implementation of all five: `.ai-collab/scripts/cursor-doc-check-hook.sh` (commit after the `task-scratchpad` banner pass).

### Phase 5 — MIGRATION.md (required, not optional)

Structure:

```markdown
# Migration Guide: Legacy → <new standard name>

## Why the change
<table: before/after for each concern>

## TL;DR — automated path
<one bash block: update submodule + run migration tool>

## Manual migration (for non-trivial projects)
### Step 1: <move canonical content>
### Step 2: <handle deprecated file>
### Step 3: <rename subdir convention>
### Step 4: <update internal references>
### Step 5: Verify
<bash block: run health check; list expected pass items>

## <New tool> advanced extras (optional)
<features the user gains by migrating: global config, override files, larger budgets>

## Rolling back
<list backup file names + how to revert>

## FAQ
<3-5 questions: "Will my <tool> stop working?", "Where do my old <X> rules go?">
```

Cite the migration commit SHA in the README diff so future readers can find the canonical source.

### Phase 6 — Smoke tests (3 scenarios, all required)

Before committing:

1. **Fresh init** on `/tmp/<name>-fresh`: confirm new layout is generated, all files exist, all placeholders rendered, check.sh passes (TODO warnings OK).
2. **Legacy migration** on `/tmp/<name>-legacy` you create from scratch (echo old `.cursorrules`, `mkdir backend && touch backend/AGENT.md`, etc.): confirm `--migrate-legacy --force` renames/archives correctly and check.sh passes.
3. **Real parent project** (the one you're working in): run the **new** check.sh against the **legacy** layout. Confirm it produces clear migration warnings with concrete fix-it commands, and **does not hard-fail** (so existing users aren't suddenly blocked from committing).

If any of those break, fix before committing. Do not ship a migration tool you haven't proven on a fake legacy project.

## Anti-patterns (don't do these)

- ❌ Rename file in place and trust users to fix imports themselves
- ❌ Delete `.cursorrules` / old canonical without `.legacy.bak` archive
- ❌ Auto-rewrite oversized canonical → stub (user loses context, blames you)
- ❌ `--force` blanket-overwrite all templates including user-content files (`lesson_learned.md` / `PROJECT_STATUS.md` / `ADR/README.md`); always split layout-file render path from user-content render path
- ❌ Ship a shell script without a `BASH_VERSINFO` guard — fails silently on macOS Bash 3.2 with cryptic "syntax error near unexpected token" instead of a clear "install bash 4" message
- ❌ Use `grep -P`, `sed -i` (no suffix), or `readlink -f` without realizing they're GNU-only — they break on macOS without warning
- ❌ Hard-fail check.sh on legacy projects after the migration ships (locks out everyone who hasn't upgraded yet)
- ❌ Ship migration tool without MIGRATION.md (users have no recovery path)
- ❌ Skip the legacy smoke test ("it should work")
- ❌ Patch only the README and call it a migration

## Commit message convention

Use `feat!: <new standard name> migration` (the `!` flags BREAKING CHANGE). Body must include:

- Why (1-2 lines, cite upstream evidence)
- New layout table
- Removed files
- Migration command (one bash line)
- Test results (`bash -n` pass / fresh init pass / legacy migration pass / parent project warn-only)

Reference: commit `102b97b` ("feat!: 2026 cross-tool standard (AGENTS.md canonical + Cursor MDC + Codex)") in `alexchenyu/ai-collab-standard`.

## Real example: AGENTS.md migration (May 2026)

The full play-by-play of one application of this skill lives in:

- Migration tool: `.ai-collab/scripts/init_ai_collab_docs.sh` (`--migrate-legacy`)
- Migration doc: `.ai-collab/MIGRATION.md`
- Health check updates: `.ai-collab/scripts/check.sh` (new sections: Cursor MDC, legacy `.cursorrules`, Codex 32 KiB budget, CLAUDE.md stub, subdir AGENTS.md)
- Commit: `102b97b`

Read those files when in doubt about how a phase should look concretely.
