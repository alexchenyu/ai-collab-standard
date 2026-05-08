#!/usr/bin/env bash
# Cursor afterFileEdit hook: runs a fast governance check when an AI-collab doc
# is edited. Reads a JSON event from stdin (Cursor hook protocol), inspects the
# edited file path, and only invokes check_ai_collab_docs.py when the file is
# one we govern. Other edits return immediately so the hook stays cheap.
#
# Wire up via .cursor/hooks.json:
#   {"version":1,"hooks":{"afterFileEdit":[{"command":"bash .ai-collab/scripts/cursor-doc-check-hook.sh"}]}}
#
# See https://cursor.com/docs/hooks for the full hook event/JSON spec.

set -uo pipefail

# Bash 3.2+ compatible (no associative arrays / mapfile / case-modify expansions).
if (( ${BASH_VERSINFO[0]:-0} < 3 )); then
    echo "cursor-doc-check-hook.sh requires Bash 3.2+; you have ${BASH_VERSION:-unknown}." >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

# Cursor sends a JSON envelope on stdin; we only need the edited file path.
# Use python (already required by the broader stack) to avoid jq dependency.
EDITED_PATH=""
if command -v python3 >/dev/null 2>&1; then
    # NOTE: don't use heredoc with `python3 -`: that consumes the upstream pipe
    # (Cursor's stdin JSON) by redirecting heredoc into stdin. Use -c instead.
    EDITED_PATH="$(python3 -c '
import json, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)
# Cursor afterFileEdit envelope (as of 2026-05) carries the path under one of
# "file_path" / "path" at the top level, or nested under "tool_input".
for k in ("file_path", "path"):
    v = payload.get(k)
    if isinstance(v, str):
        print(v); sys.exit(0)
ti = payload.get("tool_input") or {}
for k in ("file_path", "path", "target_file"):
    v = ti.get(k)
    if isinstance(v, str):
        print(v); sys.exit(0)
')"
fi

# If we couldn't parse the path, fail open (no-op) — never block Cursor on hook
# bugs. Logging stays available via Cursor's hook output panel.
if [[ -z "$EDITED_PATH" ]]; then
    exit 0
fi

# Normalize relative path
case "$EDITED_PATH" in
    "$REPO_ROOT"/*) EDITED_PATH="${EDITED_PATH#$REPO_ROOT/}" ;;
esac

# Match AI-collab governed files; everything else exits cheap.
case "$EDITED_PATH" in
    AGENTS.md|CLAUDE.md|.cursorrules|\
    lesson_learned.md|lesson_learned_*.md|\
    docs/PROJECT_STATUS.md|docs/PROJECT_GLOSSARY.md|\
    docs/ai-collab-doc-governance.md|\
    .cursor/rules/*.mdc|\
    */AGENTS.md|*/AGENT.md)
        ;;
    *)
        exit 0
        ;;
esac

# Run the lightweight Python checker (fast; same one pre-commit uses).
CHECKER=".ai-collab/scripts/check_ai_collab_docs.py"
[[ -f "$CHECKER" ]] || CHECKER="scripts/check_ai_collab_docs.py"
[[ -f "$CHECKER" ]] || exit 0   # fail open if checker missing

# Prefer plain python3 over `uv run` for a per-edit hook: `uv run` would
# initialise/refresh a .venv on every invocation, which is way too heavy for
# something firing on every governed-file edit. The checker has zero deps
# beyond stdlib.
if command -v python3 >/dev/null 2>&1; then
    python3 "$CHECKER" 2>&1 | sed 's/^/[ai-collab-hook] /'
elif command -v python >/dev/null 2>&1; then
    python "$CHECKER" 2>&1 | sed 's/^/[ai-collab-hook] /'
else
    echo "[ai-collab-hook] no python3 found; skipping check" >&2
fi

# Always exit 0 from afterFileEdit — Cursor treats non-zero as a block, and we
# only want to *report* governance issues, not interrupt the agent's flow.
exit 0
