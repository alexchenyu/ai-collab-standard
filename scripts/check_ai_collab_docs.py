"""Pre-commit governance checks for AI collaboration docs.

The checks inspect staged content only.  A normal commit is not blocked unless
one of the governed files is part of the commit.

Layout (post-2026 cross-tool standard):
- AGENTS.md is canonical (Codex/Cursor/Copilot/Windsurf/Amp/Devin all read it).
- CLAUDE.md is a thin stub for Claude Code (which does not yet auto-read AGENTS.md).
- .cursor/rules/*.mdc replaces .cursorrules (legacy, ignored in Cursor Agent mode).
"""

from __future__ import annotations

import argparse
import datetime
import os
import subprocess
import sys
from pathlib import Path


AGENTS_PATH = "AGENTS.md"
CLAUDE_PATH = "CLAUDE.md"
CURSORRULES_PATH = ".cursorrules"
CURSOR_RULES_DIR = ".cursor/rules"

# AGENTS.md is canonical now -> generous cap; the *real* hard cap is the Codex
# 32 KiB total-bytes budget enforced by check.sh, not a per-file line count.
DEFAULT_MAX_AGENTS_LINES = 250
# CLAUDE.md is a thin stub now (was 150 when it was canonical).
DEFAULT_MAX_CLAUDE_LINES = 60
# .cursorrules is legacy; if a commit still adds to it, suggest migration.
DEFAULT_MAX_CURSORRULES_LINES = 40

ALLOW_LONG_AGENTS_ENV = "AI_COLLAB_ALLOW_LONG_AGENTS"
ALLOW_LONG_CLAUDE_ENV = "AI_COLLAB_ALLOW_LONG_CLAUDE"
ALLOW_LEGACY_CURSORRULES_ENV = "AI_COLLAB_ALLOW_LEGACY_CURSORRULES"
VERBOSE_ENV = "AI_COLLAB_HOOK_VERBOSE"


def _verbose() -> bool:
    return os.environ.get(VERBOSE_ENV) == "1"


def _vprint(msg: str) -> None:
    if _verbose():
        print(msg)


def run_git(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        check=check,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def staged_file_changed(path: str) -> bool:
    result = run_git(["diff", "--cached", "--name-only", "--", path])
    return bool(result.stdout.strip())


def read_staged_file(path: str) -> str | None:
    result = run_git(["show", f":{path}"], check=False)
    if result.returncode != 0:
        return None
    return result.stdout


def line_count(text: str) -> int:
    return len(text.splitlines()) if text else 0


def log_bypass(allow_env: str, detail: str) -> None:
    """Append one line to the bypass ledger (.ai-collab/runtime/bypass.log).

    Escape hatches must leave a trace: silently lowering the quality bar is
    how gates rot. The periodic review reads this ledger — a gate bypassed
    3+ times means either widen the limit deliberately or fix the root cause.
    Never raises: the ledger must not break the check itself.
    """
    try:
        result = run_git(["rev-parse", "--show-toplevel"], check=False)
        root = Path(result.stdout.strip()) if result.returncode == 0 else Path.cwd()
        ledger = root / ".ai-collab" / "runtime" / "bypass.log"
        ledger.parent.mkdir(parents=True, exist_ok=True)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with ledger.open("a", encoding="utf-8") as fh:
            fh.write(f"{stamp} {allow_env} {detail}\n")
    except Exception:
        pass


def _check_size(
    path: str,
    label: str,
    max_lines: int,
    allow_env: str,
    overflow_advice: list[str],
) -> int:
    if not staged_file_changed(path):
        _vprint(f"[ai-collab] no staged {path} change; skipping")
        return 0

    staged_text = read_staged_file(path)
    if staged_text is None:
        _vprint(f"[ai-collab] staged {path} was deleted; skipping line-count check")
        return 0

    lines = line_count(staged_text)
    if lines <= max_lines:
        _vprint(f"[ai-collab] staged {path} ok: {lines}/{max_lines} lines")
        return 0

    if os.environ.get(allow_env) == "1":
        _vprint(f"[ai-collab] {allow_env}=1; allowing oversized {path}")
        log_bypass(allow_env, f"{path} {lines}/{max_lines}")
        return 0

    print("\nAI collab docs governance check failed:", file=sys.stderr)
    print(f"- staged {path} has {lines} lines; limit is {max_lines}.", file=sys.stderr)
    for line in overflow_advice:
        print(f"- {line}", file=sys.stderr)
    print(f"- Deliberate exception for one commit: set {allow_env}=1.", file=sys.stderr)
    return 1


def check_agents(max_lines: int) -> int:
    return _check_size(
        AGENTS_PATH,
        "AGENTS.md",
        max_lines,
        ALLOW_LONG_AGENTS_ENV,
        [
            "AGENTS.md is the cross-tool canonical (Codex/Cursor/Copilot/etc.).",
            "Move stable subdirectory rules to <subdir>/AGENTS.md (Codex auto-loads recursively).",
            "Move implementation lessons to lesson_learned.md, decisions to docs/ADR/.",
            "Codex truncates once total AGENTS.md bytes exceed 32 KiB; keep root lean.",
        ],
    )


def check_claude(max_lines: int) -> int:
    return _check_size(
        CLAUDE_PATH,
        "CLAUDE.md",
        max_lines,
        ALLOW_LONG_CLAUDE_ENV,
        [
            "CLAUDE.md is now a thin stub for Claude Code; the canonical lives in AGENTS.md.",
            "Move project rules into AGENTS.md so Codex/Cursor/Copilot/etc. see them too.",
            "Keep CLAUDE.md to: 'Read AGENTS.md first' + Claude-Code-specific notes only.",
        ],
    )


def check_legacy_cursorrules(max_lines: int) -> int:
    """Warn (then block if huge) when staging changes to legacy .cursorrules.

    Cursor Agent mode silently ignores .cursorrules; staging changes to it is
    almost always a mistake. We block if the file is being grown beyond
    max_lines so users notice.
    """
    if not staged_file_changed(CURSORRULES_PATH):
        return 0

    if os.environ.get(ALLOW_LEGACY_CURSORRULES_ENV) == "1":
        _vprint(f"[ai-collab] {ALLOW_LEGACY_CURSORRULES_ENV}=1; allowing legacy .cursorrules")
        log_bypass(ALLOW_LEGACY_CURSORRULES_ENV, CURSORRULES_PATH)
        return 0

    staged_text = read_staged_file(CURSORRULES_PATH)
    if staged_text is None:
        _vprint("[ai-collab] staged .cursorrules was deleted; that's the recommended action")
        return 0

    lines = line_count(staged_text)
    print(
        "\n[ai-collab] WARNING: staging changes to legacy .cursorrules.",
        file=sys.stderr,
    )
    print(
        "  Cursor Agent mode silently ignores this file; project rules go in",
        file=sys.stderr,
    )
    print("  .cursor/rules/*.mdc instead. See .ai-collab/MIGRATION.md.", file=sys.stderr)

    if lines > max_lines:
        print(
            f"\nAI collab docs governance check failed:\n"
            f"- staged {CURSORRULES_PATH} has {lines} lines (> {max_lines}); .cursorrules is legacy.\n"
            f"- Route content into AGENTS.md / lesson_learned.md / skills / .cursor/rules/*.mdc, then `rm .cursorrules`.\n"
            f"- One-shot bypass: {ALLOW_LEGACY_CURSORRULES_ENV}=1.",
            file=sys.stderr,
        )
        return 1

    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--max-agents-lines",
        type=int,
        default=DEFAULT_MAX_AGENTS_LINES,
        help="Maximum allowed staged line count for root AGENTS.md (canonical).",
    )
    parser.add_argument(
        "--max-claude-lines",
        type=int,
        default=DEFAULT_MAX_CLAUDE_LINES,
        help="Maximum allowed staged line count for CLAUDE.md (thin stub).",
    )
    parser.add_argument(
        "--max-cursorrules-lines",
        type=int,
        default=DEFAULT_MAX_CURSORRULES_LINES,
        help="Maximum allowed staged line count for legacy .cursorrules.",
    )
    args = parser.parse_args()

    return max(
        check_agents(args.max_agents_lines),
        check_claude(args.max_claude_lines),
        check_legacy_cursorrules(args.max_cursorrules_lines),
    )


if __name__ == "__main__":
    raise SystemExit(main())
