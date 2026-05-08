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
DEFAULT_MAX_CURSORRULES_LINES = 80
ALLOW_LONG_CURSORRULES_ENV = "AI_COLLAB_ALLOW_LONG_CURSORRULES"


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
        return 0

    if os.environ.get(ALLOW_LONG_CURSORRULES_ENV) == "1":
        return 0

    staged_text = read_staged_file(CURSORRULES_PATH)
    if staged_text is None:
        return 0

    lines = line_count(staged_text)
    if lines <= max_lines:
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--max-cursorrules-lines",
        type=int,
        default=DEFAULT_MAX_CURSORRULES_LINES,
        help="Maximum allowed staged line count for .cursorrules.",
    )
    args = parser.parse_args()

    return check_cursorrules(args.max_cursorrules_lines)


if __name__ == "__main__":
    raise SystemExit(main())
