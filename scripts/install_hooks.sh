#!/usr/bin/env bash
set -euo pipefail

# Bash 3.2+ compatible (no associative arrays / mapfile / case-modify expansions).
if (( ${BASH_VERSINFO[0]:-0} < 3 )); then
    echo "install_hooks.sh requires Bash 3.2+; you have ${BASH_VERSION:-unknown}." >&2
    exit 1
fi

usage() {
    cat <<'EOF'
Usage:
  bash .ai-collab/scripts/install_hooks.sh [TARGET_DIR] [options]

Install local Git hooks that enforce AI collaboration doc governance.

Options:
  --force      Overwrite an existing pre-commit hook
  --dry-run    Print planned actions without writing files
  -h, --help   Show this help
EOF
}

TARGET_DIR="."
FORCE=0
DRY_RUN=0

while (($# > 0)); do
    case "$1" in
        --force)
            FORCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
if ! git -C "$TARGET_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Target is not inside a Git repository: $TARGET_DIR" >&2
    exit 1
fi

REPO_ROOT="$(git -C "$TARGET_DIR" rev-parse --show-toplevel)"
HOOK_PATH="$(git -C "$REPO_ROOT" rev-parse --git-path hooks/pre-commit)"
HOOK_DIR="$(dirname "$HOOK_PATH")"

if [[ -f "$REPO_ROOT/.ai-collab/scripts/check.sh" ]]; then
    CHECKER_SCRIPT=".ai-collab/scripts/check.sh"
elif [[ -f "$REPO_ROOT/scripts/check.sh" ]]; then
    CHECKER_SCRIPT="scripts/check.sh"
else
    echo "Cannot find check.sh in target repo: $REPO_ROOT" >&2
    exit 1
fi

if [[ -e "$HOOK_PATH" && "$FORCE" -ne 1 ]]; then
    if grep -q "AI_COLLAB_PRE_COMMIT" "$HOOK_PATH" 2>/dev/null; then
        echo "[ai-collab-hooks] already installed: $HOOK_PATH"
        exit 0
    fi
    echo "Refusing to overwrite existing hook: $HOOK_PATH" >&2
    echo "Re-run with --force after merging any existing pre-commit logic." >&2
    exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[ai-collab-hooks] would write: $HOOK_PATH"
    echo "[ai-collab-hooks] checker: $CHECKER_SCRIPT"
    exit 0
fi

mkdir -p "$HOOK_DIR"
cat > "$HOOK_PATH" <<EOF
#!/usr/bin/env sh
# AI_COLLAB_PRE_COMMIT
# Doc-governance gate: run bash check.sh so the hook and the manual
# 'check.sh' invocation share ONE implementation. Exit codes: 0 pass,
# 1 hard fail (block commit), 2 soft warnings only (allow, but surface).
set -u

repo_root="\$(git rev-parse --show-toplevel)"
cd "\$repo_root"

check_script="$CHECKER_SCRIPT"

rc=0
bash "\$check_script" || rc=\$?
if [ "\$rc" -eq 2 ]; then
    echo "[ai-collab] doc-governance soft warnings only; allowing commit (run 'bash \$check_script' to view)."
    exit 0
fi
exit "\$rc"
EOF

chmod +x "$HOOK_PATH" 2>/dev/null || true
echo "[ai-collab-hooks] installed: $HOOK_PATH"
