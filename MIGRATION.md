# Migration Guide: Legacy → 2026 Cross-Tool Standard

This guide is for projects that already use `.ai-collab` with the **legacy
layout** (CLAUDE.md as canonical / `.cursorrules` / subdirectory `AGENT.md`)
and want to upgrade to the **2026 cross-tool standard** (AGENTS.md as
canonical / `.cursor/rules/*.mdc` / subdirectory `AGENTS.md`).

If you are starting fresh, you can skip this file — the new architecture is
default in `init_ai_collab_docs.sh`.

## Why the change

| Concern | Before | After |
|---------|--------|-------|
| Cursor Agent mode | `.cursorrules` was silently ignored | `.cursor/rules/*.mdc` works |
| Codex CLI | Only read `AGENTS.md` (which was 15-line stub — useless) | AGENTS.md is canonical, recursively merged from git root |
| Subdirectory rules | `<dir>/AGENT.md` (singular) — Codex/Cursor never auto-loaded | `<dir>/AGENTS.md` (plural) — Codex/Cursor walk recursively |
| Cross-tool truth | Each tool had its own canonical | One canonical (AGENTS.md), small per-tool stubs |
| Standard | ad-hoc | Linux Foundation Agentic AI Foundation (60k+ repos) |

## TL;DR — automated path

```bash
# Update .ai-collab to latest
git -C .ai-collab fetch origin
default_branch="$(git -C .ai-collab symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')"
git -C .ai-collab checkout "origin/${default_branch:-main}"

# Run migration + rewrite scaffolding
bash .ai-collab/scripts/init_ai_collab_docs.sh . --migrate-legacy --force
```

`--migrate-legacy` does:

1. **Renames `.cursorrules` → `.cursorrules.legacy.bak`** (does NOT delete content; you decide what to keep).
2. **Renames every subdirectory `AGENT.md` → `AGENTS.md`** (idempotent; skips if target exists).
3. **Detects oversized CLAUDE.md** and prints a one-line hint (does NOT auto-truncate; you keep editorial control).

`--force` re-renders all templates so you get the new AGENTS.md / CLAUDE.md
stub / `.cursor/rules/00-core.mdc` skeleton in place. Existing customisation in
those files will be **overwritten**, so do this on a clean branch.

## Manual migration (recommended for non-trivial projects)

### Step 1: Promote CLAUDE.md content into AGENTS.md

Old layout: CLAUDE.md was the canonical rules file (≤ 150 lines).
New layout: AGENTS.md is canonical (≤ 200 lines / ≤ 8 KiB).

```bash
# Back up your existing CLAUDE.md
cp CLAUDE.md CLAUDE.md.legacy.bak

# Move all project-rule content into AGENTS.md
# Keep in CLAUDE.md only Claude-Code-specific notes (usually empty)
```

The new CLAUDE.md should be a ~30-line stub that says "Read AGENTS.md first".
Use `.ai-collab/docs/CLAUDE.template.md` as the starting point.

### Step 2: Migrate `.cursorrules` content into `.cursor/rules/00-core.mdc`

Cursor Agent mode silently ignores `.cursorrules`. Move content:

```bash
mkdir -p .cursor/rules
# Copy your .cursorrules content + add MDC frontmatter:
cat > .cursor/rules/00-core.mdc <<'EOF'
---
description: Core project context — always inject.
alwaysApply: true
---

(your .cursorrules content here, but trim heavily — this eats every-session token budget)
EOF
rm .cursorrules   # or: mv .cursorrules .cursorrules.legacy.bak
```

Recommended size: ≤ 60 lines. Anything larger should be split into more
`.mdc` files with `globs:` patterns instead of `alwaysApply: true`.

### Step 3: Rename subdirectory AGENT.md → AGENTS.md

```bash
find . -name AGENT.md -not -path './.ai-collab/*' -not -path './node_modules/*' \
    -exec sh -c 'git mv "$1" "$(dirname "$1")/AGENTS.md"' _ {} \;
```

Codex CLI walks from the git repo root down to your CWD, automatically loading
each directory's `AGENTS.md`. This is the whole point of the rename.

### Step 4: Update subdirectory AGENTS.md to point at root `AGENTS.md` (not `CLAUDE.md`)

```bash
# Find references to root CLAUDE.md and update them
rg -l '\.\./.*CLAUDE\.md|ROOT_CLAUDE_PATH' --glob '**/AGENTS.md'
# Edit each to point at root AGENTS.md instead.
```

### Step 5: Verify

```bash
bash .ai-collab/scripts/check.sh
```

Expected pass items:

- `AGENTS.md (canonical)` line count ≤ 200
- `CLAUDE.md (stub)` line count ≤ 30
- `.cursor/rules/` has at least one `alwaysApply: true` rule
- Codex 32 KiB total budget OK
- No legacy `AGENT.md` (singular) found
- No legacy `.cursorrules` found

## Codex-specific extras (optional)

After migration, you can take advantage of new Codex features:

### Global personal config

`~/.codex/AGENTS.md` (≤ 2-3 KB) for cross-project preferences:

```markdown
# Personal Codex preferences

- Always use rg over grep / find
- Prefer pathlib.Path in Python
- Run pytest from repo root, never with `cd subdir && pytest`
```

### Temporary debug override

In a project, drop `AGENTS.override.md` next to `AGENTS.md` for a single debug
session. It **replaces** AGENTS.md at that scope (does not append). Delete when
done.

### Raise the byte budget

`~/.codex/config.toml`:

```toml
project_doc_max_bytes = 65536  # 64 KiB instead of default 32 KiB
project_doc_fallback_filenames = ["CLAUDE.md", "CONTRIBUTING.md"]
```

`project_doc_fallback_filenames` lets Codex also read CLAUDE.md (useful if a
collaborator still has Claude-only content there).

## Rolling back

The migration is non-destructive:

- `.cursorrules.legacy.bak` keeps your old content
- `CLAUDE.md.legacy.bak` (if you ran the manual backup) keeps the canonical
- Subdirectory rename is just `git mv`; revert with `git revert` or by hand

If you decide to roll back, also pin your `.ai-collab` submodule to a
pre-migration commit so future `init` runs do not regenerate the new layout.

## FAQ

**Q: Will my Claude Code stop working?**
A: No. Claude Code still reads `CLAUDE.md`. The new CLAUDE.md is just a
stub that explicitly tells Claude to also read `AGENTS.md`. You may want to
manually `@AGENTS.md` reference once if Claude is being lazy.

**Q: Will my Cursor stop working?**
A: It will work _better_. `.cursorrules` was already silently ignored in Agent
mode (a Cursor product decision). The new `.cursor/rules/*.mdc` is what Agent
mode actually loads.

**Q: I have a Codex CI agent that already uses AGENTS.md as canonical.**
A: Then this migration is trivial — you already have what we recommend. Just
make sure CLAUDE.md is a stub (or just link AGENTS.md from CLAUDE.md so
Claude Code on contributors' laptops sees the same rules).

**Q: My `.cursorrules` is 200 lines of important rules. Where do they go?**
A: Most should go in `AGENTS.md` (cross-tool). Cursor-specific stuff (e.g.
"prefer Composer over Chat for X") goes in `.cursor/rules/00-core.mdc`. Truly
file-type-specific rules go in their own `.cursor/rules/*.mdc` with
`globs: ["**/*.tsx"]` instead of `alwaysApply: true`.
