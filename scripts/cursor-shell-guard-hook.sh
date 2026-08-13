#!/usr/bin/env bash
# Cursor beforeShellExecution hook: deterministic gate for shell discipline.
#
# Enforces machine-checkable behavior rules (ai-collab-agent-behavior.md R6 by
# default: use `uv run python` / `uv add`, never bare python/pip) by denying
# the command *before* it runs, instead of hoping the agent remembers prose.
#
# Protocol (see https://cursor.com/docs/hooks):
#   stdin : JSON envelope carrying the proposed command (key: "command")
#   stdout: {"permission":"allow"} or {"permission":"deny","userMessage":...}
#
# Configuration:
#   <repo-root>/.ai-collab-shell-deny.txt  — optional override, one POSIX ERE
#   per line ('#' comments and blank lines ignored). When the file exists, its
#   patterns REPLACE the built-in R6 check entirely (match against the full
#   command string). An empty/comment-only file disables the guard — useful
#   for non-Python projects or projects with different discipline.
#
# Fail-open by design: any parse error, missing python3, or hook bug must
# never block normal work. Only an explicit pattern match denies.

set -uo pipefail

# Bash 3.2+ compatible (no associative arrays / mapfile).
if (( ${BASH_VERSINFO[0]:-0} < 3 )); then
    echo '{"permission":"allow"}'
    exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || { echo '{"permission":"allow"}'; exit 0; }

if ! command -v python3 >/dev/null 2>&1; then
    echo '{"permission":"allow"}'
    exit 0
fi

DENYLIST_FILE="$REPO_ROOT/.ai-collab-shell-deny.txt"

# NOTE: never `python3 - <<heredoc` here — that redirects the heredoc into
# stdin and silently discards Cursor's JSON envelope (same pitfall documented
# in cursor-doc-check-hook.sh). Load the program into a variable via command
# substitution (whose heredoc only feeds the inner cat), then `python3 -c`.
GUARD_PY="$(cat <<'PY'
import json
import re
import shlex
import sys

ALLOW = '{"permission":"allow"}'


def deny(reason: str) -> None:
    print(json.dumps({
        "permission": "deny",
        "userMessage": reason,
        "agentMessage": reason,
    }))
    sys.exit(0)


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        print(ALLOW)
        return

    command = payload.get("command")
    if not isinstance(command, str) or not command.strip():
        print(ALLOW)
        return

    denylist_path = sys.argv[1]
    custom_patterns = load_custom_patterns(denylist_path)
    if custom_patterns is not None:
        # Project override: custom EREs replace the built-in check entirely.
        for pattern in custom_patterns:
            try:
                if re.search(pattern, command):
                    deny(
                        "Blocked by .ai-collab shell guard "
                        f"(.ai-collab-shell-deny.txt pattern: {pattern}). "
                        "See docs/QUALITY_GATES.md."
                    )
            except re.error:
                continue  # bad pattern: skip, never block on config typos
        print(ALLOW)
        return

    # Built-in default: R6 uv-only Python discipline.
    reason = check_r6(command)
    if reason:
        deny(reason)
    print(ALLOW)


def load_custom_patterns(path: str):
    """Return list of patterns if the override file exists, else None."""
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except FileNotFoundError:
        return None
    except Exception:
        return []  # unreadable override file: treat as "guard disabled"
    return [ln.strip() for ln in lines if ln.strip() and not ln.strip().startswith("#")]


def check_r6(command: str):
    """Detect bare python/pip usage. Returns deny reason or None.

    Tokenize with shlex (quote-aware, so `echo "pip install x"` is safe),
    split into pipeline/command segments at shell operators, then inspect
    each segment's leading executable after stripping env assignments and
    common wrappers.
    """
    try:
        tokens = shlex.split(command, posix=True)
    except ValueError:
        return None  # unparseable (heredoc etc): fail open

    operators = {"&&", "||", ";", "|", "&"}
    segments, current = [], []
    for tok in tokens:
        if tok in operators:
            if current:
                segments.append(current)
            current = []
        else:
            current.append(tok)
    if current:
        segments.append(current)

    wrappers = {"sudo", "command", "exec", "nohup", "time", "env"}
    for seg in segments:
        words = [w for w in seg if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w)]
        while words and (words[0] in wrappers or words[0].startswith("-")):
            words.pop(0)
        if not words:
            continue
        head = words[0].rsplit("/", 1)[-1]
        if head in ("pip", "pip3") and "install" in words[1:]:
            return (
                "R6: bare pip install is not allowed in this project. "
                "Use `uv add <pkg>` (deps go to pyproject.toml). "
                "See .ai-collab/docs/ai-collab-agent-behavior.md R6."
            )
        if head in ("python", "python3"):
            return (
                "R6: bare python/python3 is not allowed in this project. "
                "Use `uv run python ...`. "
                "See .ai-collab/docs/ai-collab-agent-behavior.md R6."
            )
    return None


main()
PY
)"

if ! python3 -c "$GUARD_PY" "$DENYLIST_FILE"; then
    # Python crashed before printing a verdict: fail open, never block work.
    echo '{"permission":"allow"}'
fi
exit 0
