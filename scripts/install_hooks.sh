#!/usr/bin/env bash
set -euo pipefail

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

if [[ -f "$REPO_ROOT/.ai-collab/scripts/check_ai_collab_docs.py" ]]; then
    CHECKER_SCRIPT=".ai-collab/scripts/check_ai_collab_docs.py"
elif [[ -f "$REPO_ROOT/scripts/check_ai_collab_docs.py" ]]; then
    CHECKER_SCRIPT="scripts/check_ai_collab_docs.py"
else
    echo "Cannot find check_ai_collab_docs.py in target repo: $REPO_ROOT" >&2
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
set -eu

repo_root="\$(git rev-parse --show-toplevel)"
cd "\$repo_root"

checker_script="$CHECKER_SCRIPT"

if command -v uv >/dev/null 2>&1; then
    uv run python "\$checker_script"
elif command -v python3 >/dev/null 2>&1; then
    python3 "\$checker_script"
elif command -v python >/dev/null 2>&1; then
    python "\$checker_script"
elif command -v py >/dev/null 2>&1; then
    py -3 "\$checker_script"
else
    echo "AI collab pre-commit hook requires uv or Python 3." >&2
    exit 1
fi
EOF

chmod +x "$HOOK_PATH" 2>/dev/null || true
echo "[ai-collab-hooks] installed: $HOOK_PATH"
