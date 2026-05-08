"""Pre-commit governance checks for AI collaboration docs.

The checks inspect staged content only.  A normal commit is not blocked unless
one of the governed files is part of the commit.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys


CURSORRULES_PATH = ".cursorrules"
AGENTS_PATH = "AGENTS.md"
DEFAULT_MAX_CURSORRULES_LINES = 80
DEFAULT_MAX_AGENTS_LINES = 40
ALLOW_LONG_CURSORRULES_ENV = "AI_COLLAB_ALLOW_LONG_CURSORRULES"
ALLOW_LONG_AGENTS_ENV = "AI_COLLAB_ALLOW_LONG_AGENTS"
VERBOSE_ENV = "AI_COLLAB_HOOK_VERBOSE"


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


def check_cursorrules(max_lines: int) -> int:
    if not staged_file_changed(CURSORRULES_PATH):
        if os.environ.get(VERBOSE_ENV) == "1":
            print("[ai-collab] no staged .cursorrules change; skipping governance check")
        return 0

    if os.environ.get(ALLOW_LONG_CURSORRULES_ENV) == "1":
        if os.environ.get(VERBOSE_ENV) == "1":
            print(f"[ai-collab] {ALLOW_LONG_CURSORRULES_ENV}=1; allowing long .cursorrules")
        return 0

    staged_text = read_staged_file(CURSORRULES_PATH)
    if staged_text is None:
        if os.environ.get(VERBOSE_ENV) == "1":
            print("[ai-collab] staged .cursorrules was deleted; skipping line-count check")
        return 0

    lines = line_count(staged_text)
    if lines <= max_lines:
        if os.environ.get(VERBOSE_ENV) == "1":
            print(f"[ai-collab] staged .cursorrules ok: {lines}/{max_lines} lines")
        return 0

    print("\nAI collab docs governance check failed:", file=sys.stderr)
    print(
        f"- staged {CURSORRULES_PATH} has {lines} lines; limit is {max_lines}.",
        file=sys.stderr,
    )
    print(
        "- Keep .cursorrules as a thin Cursor reminder layer, not a second manual.",
        file=sys.stderr,
    )
    print(
        "- Move stable repo rules to CLAUDE.md / AGENTS.md, implementation lessons "
        "to lesson_learned.md, and decisions to docs/ADR/.",
        file=sys.stderr,
    )
    print(
        f"- Deliberate exception for one commit: set {ALLOW_LONG_CURSORRULES_ENV}=1.",
        file=sys.stderr,
    )
    return 1


def check_agents(max_lines: int) -> int:
    if not staged_file_changed(AGENTS_PATH):
        if os.environ.get(VERBOSE_ENV) == "1":
            print("[ai-collab] no staged AGENTS.md change; skipping governance check")
        return 0

    if os.environ.get(ALLOW_LONG_AGENTS_ENV) == "1":
        if os.environ.get(VERBOSE_ENV) == "1":
            print(f"[ai-collab] {ALLOW_LONG_AGENTS_ENV}=1; allowing long AGENTS.md")
        return 0

    staged_text = read_staged_file(AGENTS_PATH)
    if staged_text is None:
        if os.environ.get(VERBOSE_ENV) == "1":
            print("[ai-collab] staged AGENTS.md was deleted; skipping line-count check")
        return 0

    lines = line_count(staged_text)
    if lines <= max_lines:
        if os.environ.get(VERBOSE_ENV) == "1":
            print(f"[ai-collab] staged AGENTS.md ok: {lines}/{max_lines} lines")
        return 0

    print("\nAI collab docs governance check failed:", file=sys.stderr)
    print(
        f"- staged {AGENTS_PATH} has {lines} lines; limit is {max_lines}.",
        file=sys.stderr,
    )
    print(
        "- Keep root AGENTS.md as a Codex/cross-agent entry point, not a second manual.",
        file=sys.stderr,
    )
    print(
        "- Move repo rules to CLAUDE.md, implementation lessons to lesson_learned.md, "
        "and decisions to docs/ADR/.",
        file=sys.stderr,
    )
    print(
        f"- Deliberate exception for one commit: set {ALLOW_LONG_AGENTS_ENV}=1.",
        file=sys.stderr,
    )
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--max-cursorrules-lines",
        type=int,
        default=DEFAULT_MAX_CURSORRULES_LINES,
        help="Maximum allowed staged line count for .cursorrules.",
    )
    parser.add_argument(
        "--max-agents-lines",
        type=int,
        default=DEFAULT_MAX_AGENTS_LINES,
        help="Maximum allowed staged line count for root AGENTS.md.",
    )
    args = parser.parse_args()

    return max(
        check_cursorrules(args.max_cursorrules_lines),
        check_agents(args.max_agents_lines),
    )


if __name__ == "__main__":
    raise SystemExit(main())
