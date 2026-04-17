#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  bash scripts/init_ai_collab_docs.sh TARGET_DIR [options]
  bash scripts/init_ai_collab_docs.sh --check [TARGET_DIR]

Bootstrap reusable AI collaboration docs into TARGET_DIR.
By default, existing files are preserved.

Options:
  --project-name NAME    Override project name (default: basename TARGET_DIR)
  --summary TEXT         One-line project summary for CLAUDE.md
  --agent-dir DIR        Create DIR/AGENT.md from template (repeatable)
  --config-path PATH     Config file path in CLAUDE.md (default: auto-detect or TODO)
  --lang LANG            Default language rule: zh | en (default: zh)
  --force                Overwrite existing files
  --dry-run              Print planned actions without writing files
  --install-hook         Install pre-commit hook into .git/hooks (copies pre-commit.sh)
  --check                Run the governance health check on TARGET_DIR instead of initializing
  -h, --help             Show this help

Examples:
  bash scripts/init_ai_collab_docs.sh ../my-project
  bash scripts/init_ai_collab_docs.sh ../my-project --agent-dir backend --agent-dir frontend
  bash scripts/init_ai_collab_docs.sh ../my-project --project-name "Acme API" --lang en
  bash scripts/init_ai_collab_docs.sh --check ../my-project
  bash scripts/init_ai_collab_docs.sh ../my-project --install-hook
EOF
}

command -v python3 >/dev/null 2>&1 || { echo "python3 is required but not found" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/docs"

TARGET_DIR=""
PROJECT_NAME=""
PROJECT_SUMMARY="TODO: 用一句话描述项目"
CONFIG_PATH=""
LANG_OPTION="zh"
FORCE=0
DRY_RUN=0
INSTALL_HOOK=0
CHECK_ONLY=0
declare -a AGENT_DIRS=()

require_arg() {
    if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
        echo "$1 requires a value" >&2
        exit 1
    fi
}

while (($# > 0)); do
    case "$1" in
        --project-name)
            require_arg "$1" "${2:-}"
            PROJECT_NAME="$2"
            shift 2
            ;;
        --summary)
            require_arg "$1" "${2:-}"
            PROJECT_SUMMARY="$2"
            shift 2
            ;;
        --agent-dir)
            require_arg "$1" "${2:-}"
            AGENT_DIRS+=("$2")
            shift 2
            ;;
        --config-path)
            require_arg "$1" "${2:-}"
            CONFIG_PATH="$2"
            shift 2
            ;;
        --lang)
            require_arg "$1" "${2:-}"
            LANG_OPTION="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --install-hook)
            INSTALL_HOOK=1
            shift
            ;;
        --check)
            CHECK_ONLY=1
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
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
                shift
            else
                echo "Unexpected extra argument: $1" >&2
                usage
                exit 1
            fi
            ;;
    esac
done

if (( CHECK_ONLY == 1 )); then
    CHECK_DIR="${TARGET_DIR:-$(pwd)}"
    CHECK_DIR="${CHECK_DIR/#\~/$HOME}"
    exec bash "$SCRIPT_DIR/check.sh" "$CHECK_DIR"
fi

if [[ -z "$TARGET_DIR" ]]; then
    usage
    exit 1
fi

TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
if [[ -z "$PROJECT_NAME" ]]; then
    abs_target="$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")"
    PROJECT_NAME="$(basename "$abs_target")"
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "Template directory not found: $TEMPLATE_DIR" >&2
    exit 1
fi

declare -a CREATED_FILES=()
declare -a SKIPPED_FILES=()

note() {
    echo "[init-ai-docs] $*"
}

describe_dir() {
    case "$1" in
        core|src|app|backend|server|api)
            echo "核心业务与运行时逻辑"
            ;;
        frontend|web|ui)
            echo "前端界面与用户交互"
            ;;
        tests|test)
            echo "自动化测试"
            ;;
        docs)
            echo "文档与设计记录"
            ;;
        infra|deploy|ci|cd|.github)
            echo "部署与基础设施"
            ;;
        scripts|tools|bin)
            echo "脚本与开发工具"
            ;;
        config|configs)
            echo "配置管理"
            ;;
        lib|pkg|packages|shared)
            echo "共享库与公共模块"
            ;;
        *)
            echo "TODO: 描述 \`$1/\` 的职责"
            ;;
    esac
}

dedupe_dirs() {
    declare -A seen=()
    local dir
    local -a result=()
    for dir in "${AGENT_DIRS[@]}"; do
        dir="${dir%/}"
        [[ -n "$dir" ]] || continue
        if [[ -z "${seen[$dir]+x}" ]]; then
            result+=("$dir")
            seen["$dir"]=1
        fi
    done
    AGENT_DIRS=("${result[@]}")
}

auto_detect_agent_dirs() {
    local dir
    for dir in core server backend frontend src app web api ui pkg cmd packages services lib; do
        if [[ -d "$TARGET_DIR/$dir" ]]; then
            AGENT_DIRS+=("$dir")
        fi
    done
}

render_template() {
    local src="$1"
    local dst="$2"
    shift 2

    if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
        note "skip existing: $dst"
        SKIPPED_FILES+=("$dst")
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        local placeholder_count
        placeholder_count=$(grep -oP '\{\{[A-Z0-9_]+\}\}' "$src" 2>/dev/null | wc -l || true)
        note "render: $src -> $dst ($placeholder_count placeholders)"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    python3 - "$src" "$dst" "$@" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
text = src.read_text()
for item in sys.argv[3:]:
    key, value = item.split("=", 1)
    text = text.replace(key, value)
dst.write_text(text)
PY
    CREATED_FILES+=("$dst")
    note "wrote: $dst"
}

write_text() {
    local dst="$1"
    local content="$2"

    if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
        note "skip existing: $dst"
        SKIPPED_FILES+=("$dst")
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        note "write (dynamic): $dst"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    printf "%s" "$content" > "$dst"
    CREATED_FILES+=("$dst")
    note "wrote: $dst"
}

relative_claude_path() {
    python3 - "$1" <<'PY'
from pathlib import PurePosixPath
import sys

parts = [p for p in PurePosixPath(sys.argv[1]).parts if p not in ("", ".")]
if not parts:
    print("CLAUDE.md")
else:
    print("/".join([".."] * len(parts) + ["CLAUDE.md"]))
PY
}

build_agents_md() {
    local dst="$1"
    local text="# Agent Entry Points"$'\n'
    text+="- Repo 级规则：\`CLAUDE.md\`"$'\n'

    local dir
    for dir in "${AGENT_DIRS[@]}"; do
        text+="- \`$dir/\` 局部 runbook：\`$dir/AGENT.md\`"$'\n'
    done

    text+="- 当前有效经验：\`lesson_learned.md\`"$'\n'
    text+="- 架构决策索引：\`docs/ADR/README.md\`"$'\n'

    write_text "$dst" "$text"

    if [[ "${#AGENT_DIRS[@]}" -gt 6 ]]; then
        note "warning: ${#AGENT_DIRS[@]} agent dirs listed in AGENTS.md; consider consolidating to keep it scannable"
    fi
}

if [[ "${#AGENT_DIRS[@]}" -eq 0 ]]; then
    auto_detect_agent_dirs
fi
dedupe_dirs

# Auto-detect config path if not specified
if [[ -z "$CONFIG_PATH" ]]; then
    for candidate in .env.example .env.sample config/settings.yaml pyproject.toml; do
        if [[ -e "$TARGET_DIR/$candidate" ]]; then
            CONFIG_PATH="$candidate"
            break
        fi
    done
    CONFIG_PATH="${CONFIG_PATH:-TODO: 补充项目配置文件路径}"
fi

# Build dynamic directory list for CLAUDE.md
DIR_LIST=""
for dir in "${AGENT_DIRS[@]}"; do
    DIR_LIST+="- \`$dir/\`：$(describe_dir "$dir")"$'\n'
done
DIR_LIST+="- \`docs/\`：$(describe_dir docs)"$'\n'
DIR_LIST+="- \`${CONFIG_PATH}\`：TODO: 描述配置文件的作用"

# Resolve language rule text
case "$LANG_OPTION" in
    zh) LANG_RULE="默认使用中文与用户沟通；只有用户明确要求时才切换语言。" ;;
    en) LANG_RULE="Default language is English; switch only when the user explicitly requests it." ;;
    *)  LANG_RULE="默认使用中文与用户沟通；只有用户明确要求时才切换语言。" ;;
esac

note "target: $TARGET_DIR"
note "project: $PROJECT_NAME"
note "lang: $LANG_OPTION"
if [[ "${#AGENT_DIRS[@]}" -gt 0 ]]; then
    note "agent dirs: ${AGENT_DIRS[*]}"
else
    note "agent dirs: none auto-detected; root docs only"
fi

render_template \
    "$TEMPLATE_DIR/CLAUDE.template.md" \
    "$TARGET_DIR/CLAUDE.md" \
    "{{PROJECT_NAME}}=$PROJECT_NAME" \
    "{{PROJECT_ONE_LINE_SUMMARY}}=$PROJECT_SUMMARY" \
    "{{LANG_RULE}}=$LANG_RULE" \
    "{{DIR_LIST}}=$DIR_LIST"

build_agents_md "$TARGET_DIR/AGENTS.md"

render_template \
    "$TEMPLATE_DIR/cursorrules.template" \
    "$TARGET_DIR/.cursorrules"

render_template \
    "$TEMPLATE_DIR/lesson_learned.template.md" \
    "$TARGET_DIR/lesson_learned.md"

render_template \
    "$TEMPLATE_DIR/ai-collab-doc-governance.template.md" \
    "$TARGET_DIR/docs/ai-collab-doc-governance.md"

render_template \
    "$TEMPLATE_DIR/PROJECT_STATUS.template.md" \
    "$TARGET_DIR/docs/PROJECT_STATUS.md"

render_template \
    "$TEMPLATE_DIR/ADR-README.template.md" \
    "$TARGET_DIR/docs/ADR/README.md"

render_template \
    "$TEMPLATE_DIR/ADR-000-template.md" \
    "$TARGET_DIR/docs/ADR/000-template.md"

for dir in "${AGENT_DIRS[@]}"; do
    claude_path="$(relative_claude_path "$dir")"
    render_template \
        "$TEMPLATE_DIR/AGENT.template.md" \
        "$TARGET_DIR/$dir/AGENT.md" \
        "{{DIR_NAME}}=$dir" \
        "{{ROOT_CLAUDE_PATH}}=$claude_path"
done

# Optionally install pre-commit hook
if (( INSTALL_HOOK == 1 )); then
    HOOK_SRC="$SCRIPT_DIR/pre-commit.sh"
    HOOK_DST="$TARGET_DIR/.git/hooks/pre-commit"
    if [[ ! -f "$HOOK_SRC" ]]; then
        note "warning: pre-commit.sh not found at $HOOK_SRC, skip hook install"
    elif [[ ! -d "$TARGET_DIR/.git" ]]; then
        note "warning: $TARGET_DIR is not a git repo, skip hook install"
    elif [[ "$DRY_RUN" -eq 1 ]]; then
        note "(dry-run) would install pre-commit hook to $HOOK_DST"
    else
        mkdir -p "$TARGET_DIR/.git/hooks"
        if [[ -f "$HOOK_DST" && "$FORCE" -ne 1 ]]; then
            note "pre-commit hook already exists at $HOOK_DST; use --force to overwrite"
        else
            cp "$HOOK_SRC" "$HOOK_DST"
            chmod +x "$HOOK_DST"
            note "installed pre-commit hook: $HOOK_DST"
        fi
    fi
fi

note "done"
if [[ "$DRY_RUN" -eq 1 ]]; then
    note "(dry-run, nothing was written)"
else
    note "created: ${#CREATED_FILES[@]}"
    note "skipped: ${#SKIPPED_FILES[@]}"
    note "next: rg -n '\{\{[A-Z0-9_]+\}\}' \"$TARGET_DIR\"  # verify remaining placeholders"
    note "next: rg -n 'TODO' \"$TARGET_DIR\"  # fill in project-specific content"
    note "next: bash $SCRIPT_DIR/check.sh \"$TARGET_DIR\"  # run governance health check"
    if (( INSTALL_HOOK == 0 )); then
        note "tip:  bash $SCRIPT_DIR/init_ai_collab_docs.sh \"$TARGET_DIR\" --install-hook  # enable pre-commit guardrail"
    fi
fi
