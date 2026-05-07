#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${AI_COLLAB_REPO_URL:-https://github.com/alexchenyu/ai-collab-standard.git}"
TARGET_DIR="${AI_COLLAB_TARGET_DIR:-.}"
INSTALL_HOOK=1
ENABLE_CODEX_SKILLS=0
declare -a INIT_ARGS=()

usage() {
    cat <<'EOF'
Usage:
  curl -fsSL https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/master/scripts/bootstrap.sh | bash
  curl -fsSL https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/master/scripts/bootstrap.sh | bash -s -- [options]

Install or update .ai-collab in the current project, run init, then run check.

Options:
  --no-hook              Do not install the pre-commit hook
  --codex                Also enable .codex/skills -> ../.cursor/skills
  --enable-codex-skills  Same as --codex
  -h, --help             Show this help

All other options are passed through to init_ai_collab_docs.sh, for example:
  --project-name "My Project"
  --lang en
  --agent-dir backend
EOF
}

while (($# > 0)); do
    case "$1" in
        --no-hook)
            INSTALL_HOOK=0
            shift
            ;;
        --codex|--enable-codex-skills)
            ENABLE_CODEX_SKILLS=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            INIT_ARGS+=("$1")
            shift
            ;;
    esac
done

note() {
    echo "[ai-collab-bootstrap] $*"
}

cd "$TARGET_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    note "git repo not found; running git init"
    git init
fi

if [[ -d ".ai-collab/.git" || -f ".ai-collab/.git" ]]; then
    note "updating existing .ai-collab"
    git -C .ai-collab fetch origin
    git -C .ai-collab checkout origin/master
elif [[ -e ".ai-collab" ]]; then
    echo ".ai-collab exists but is not a git checkout; move it aside or remove it first" >&2
    exit 1
else
    note "adding .ai-collab submodule"
    git submodule add "$REPO_URL" .ai-collab
fi

cmd=(bash .ai-collab/scripts/init_ai_collab_docs.sh .)
if (( INSTALL_HOOK == 1 )); then
    cmd+=(--install-hook)
fi
if (( ENABLE_CODEX_SKILLS == 1 )); then
    cmd+=(--enable-codex-skills)
fi
cmd+=("${INIT_ARGS[@]}")

note "running init"
"${cmd[@]}"

note "running check"
bash .ai-collab/scripts/check.sh .
