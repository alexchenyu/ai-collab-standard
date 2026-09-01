#!/usr/bin/env bash
set -euo pipefail

# This script uses associative arrays (declare -A), which require bash 4+.
# macOS ships bash 3.2 by default; users must `brew install bash` and run with
# `/opt/homebrew/bin/bash` (Apple Silicon) or `/usr/local/bin/bash` (Intel).
if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
    echo "Error: this script requires bash 4 or newer (found: ${BASH_VERSION:-unknown})." >&2
    echo "On macOS the default bash is 3.2; install a newer one with:" >&2
    echo "  brew install bash" >&2
    echo "Then re-run with: /opt/homebrew/bin/bash $0 ..." >&2
    echo "(Apple Silicon path; on Intel macOS use /usr/local/bin/bash)" >&2
    exit 1
fi

usage() {
    cat <<'EOF'
Usage:
  bash scripts/init_ai_collab_docs.sh TARGET_DIR [options]
  bash scripts/init_ai_collab_docs.sh --check [TARGET_DIR]

Bootstrap reusable AI collaboration docs into TARGET_DIR.
Existing files are preserved by default. Generates the modern layout
(AGENTS.md as canonical, CLAUDE.md as Claude-Code stub, .cursor/rules/00-core.mdc
as Cursor always-apply pointer); subdirectories use AGENTS.md (recursive Codex/Cursor
discovery). Adds .gitignore rules for local scratchpad and installs bundled skills
from .ai-collab/skills into .cursor/skills.

Options:
  --project-name NAME    Override project name (default: basename TARGET_DIR)
  --summary TEXT         One-line project summary for AGENTS.md
  --agent-dir DIR        Create DIR/AGENTS.md from template (repeatable)
  --no-agent-dir         Do not auto-detect per-directory runbooks (AGENTS.md)
  --config-path PATH     Config file path in AGENTS.md (default: auto-detect or TODO)
  --lang LANG            Default language rule: zh | en (default: zh)
  --force                Overwrite existing layout files (AGENTS.md, CLAUDE.md,
                         .cursor/rules/00-core.mdc, governance docs, hook).
                         Does NOT touch user-content files (lesson_learned.md,
                         docs/PROJECT_STATUS.md, docs/PROJECT_GLOSSARY.md,
                         docs/ADR/README.md, subdir AGENTS.md) once they exist.
  --dry-run              Print planned actions without writing files
  --install-hook         Install pre-commit hook into .git/hooks (copies pre-commit.sh)
  --install-cursor-hook  Install .cursor/hooks.json (afterFileEdit governance check +
                         beforeShellExecution shell-discipline gate; see
                         .ai-collab/templates/cursor-hooks.json.template)
  --enable-codex-skills  Opt in to .codex/skills -> ../.cursor/skills symlink
                         (auto-detected if ~/.codex/ exists; pass --no-codex-skills to override)
  --no-codex-skills      Disable Codex skills auto-symlink even if ~/.codex/ exists
  --migrate-legacy       Detect and migrate legacy CLAUDE.md-canonical / AGENT.md /
                         .cursorrules layout into the new AGENTS.md-canonical layout
  --check                Run the governance health check on TARGET_DIR instead of initializing
  -h, --help             Show this help

Examples:
  bash scripts/init_ai_collab_docs.sh ../my-project
  bash scripts/init_ai_collab_docs.sh ../my-project --agent-dir backend --agent-dir frontend
  bash scripts/init_ai_collab_docs.sh ../my-project --project-name "Acme API" --lang en
  bash scripts/init_ai_collab_docs.sh --check ../my-project
  bash scripts/init_ai_collab_docs.sh ../my-project --install-hook
  bash scripts/init_ai_collab_docs.sh ../my-project --enable-codex-skills
  bash scripts/init_ai_collab_docs.sh ../my-project --migrate-legacy
EOF
}

command -v python3 >/dev/null 2>&1 || { echo "python3 is required but not found" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/docs"
BUILTIN_SKILLS_DIR="$REPO_ROOT/skills"

TARGET_DIR=""
PROJECT_NAME=""
PROJECT_SUMMARY="TODO: 用一句话描述项目"
CONFIG_PATH=""
LANG_OPTION="zh"
FORCE=0
DRY_RUN=0
INSTALL_HOOK=0
INSTALL_CURSOR_HOOK=0
CHECK_ONLY=0
# 0 = off, 1 = explicit on, -1 = explicit off; auto-detect resolves 0 to 1 when ~/.codex exists.
ENABLE_CODEX_SKILLS=0
MIGRATE_LEGACY=0
NO_AGENT_DIR=0
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
        --no-agent-dir)
            NO_AGENT_DIR=1
            shift
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
        --install-cursor-hook)
            INSTALL_CURSOR_HOOK=1
            shift
            ;;
        --enable-codex-skills)
            ENABLE_CODEX_SKILLS=1
            shift
            ;;
        --no-codex-skills)
            ENABLE_CODEX_SKILLS=-1
            shift
            ;;
        --migrate-legacy)
            MIGRATE_LEGACY=1
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

# Detect Windows-ish environments (Git Bash / MSYS2 / Cygwin). On real Windows
# `ln -s` either silently creates a useless copy or needs Developer Mode +
# Git's `core.symlinks=true`; we fall back to copying in that case.
is_windows_env() {
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
    esac
    return 1
}

# Cross-platform "create a link from $1 (target, relative to link parent) at
# $2 (link path)". Tries `ln -s`; on Windows or when the result is not a
# working symlink, falls back to copying and warns the user.
os_link_or_copy() {
    local target="$1"
    local linkpath="$2"
    local resolved_target

    # On Windows fall back directly to copy; symlinks are too unreliable
    # without Developer Mode + the right git config.
    if is_windows_env; then
        resolved_target="$(cd "$(dirname "$linkpath")" 2>/dev/null && cd "$target" 2>/dev/null && pwd)" || true
        if [[ -z "$resolved_target" ]]; then
            note "warning (windows): cannot resolve symlink target '$target' from '$linkpath'; skip"
            return 1
        fi
        rm -rf "$linkpath"
        cp -R "$resolved_target" "$linkpath"
        note "windows fallback: copied $resolved_target -> $linkpath (symlinks unreliable on Windows; rerun init after upstream skills change)"
        return 0
    fi

    if ln -s "$target" "$linkpath" 2>/dev/null; then
        return 0
    fi

    # ln failed (e.g. exFAT / iCloud Drive / certain network mounts).
    note "warning: ln -s failed at $linkpath; falling back to copy. Rerun init after upstream skills change to keep in sync."
    resolved_target="$(cd "$(dirname "$linkpath")" 2>/dev/null && cd "$target" 2>/dev/null && pwd)" || true
    if [[ -z "$resolved_target" ]]; then
        note "warning: cannot resolve symlink target '$target' from '$linkpath'; skip"
        return 1
    fi
    rm -rf "$linkpath"
    cp -R "$resolved_target" "$linkpath"
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

# Language-aware template selection: when --lang en is requested, prefer the
# "<name>.en.md" variant sitting next to the default (zh) template; templates
# without an EN variant fall back silently. Affects scaffold content language
# only; rule files (AGENTS.md, 00-core.mdc) get their language rule separately.
resolve_template() {
    local src="$1"
    if [[ "${LANG_OPTION:-zh}" == "en" && -f "${src%.md}.en.md" ]]; then
        printf '%s\n' "${src%.md}.en.md"
    else
        printf '%s\n' "$src"
    fi
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
        placeholder_count=$(grep -oE '\{\{[A-Z0-9_]+\}\}' "$src" 2>/dev/null | wc -l || true)
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

# Like render_template but **never overwrites** an existing file, even with --force.
# Use for user-data files (lesson_learned.md, PROJECT_STATUS.md, PROJECT_GLOSSARY.md,
# docs/ADR/README.md) where the template is only a first-time scaffold and any
# subsequent content is project-specific. Avoids data loss when users run
# `--migrate-legacy --force` to swap layout files.
render_template_protected() {
    local src="$1"
    local dst="$2"
    shift 2

    if [[ -e "$dst" ]]; then
        if [[ "$FORCE" -eq 1 ]]; then
            note "preserve user content (--force ignored): $dst"
        else
            note "skip existing: $dst"
        fi
        SKIPPED_FILES+=("$dst")
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        local placeholder_count
        placeholder_count=$(grep -oE '\{\{[A-Z0-9_]+\}\}' "$src" 2>/dev/null | wc -l || true)
        note "render (protected, first-time only): $src -> $dst ($placeholder_count placeholders)"
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

relative_root_path() {
    # Compute the relative path from a subdirectory back to the repo root file
    # named $2 (e.g. "AGENTS.md"). Used by subdirectory AGENTS.md templates.
    python3 - "$1" "$2" <<'PY'
from pathlib import PurePosixPath
import sys

target_filename = sys.argv[2]
parts = [p for p in PurePosixPath(sys.argv[1]).parts if p not in ("", ".")]
if not parts:
    print(target_filename)
else:
    print("/".join([".."] * len(parts) + [target_filename]))
PY
}

if [[ "${#AGENT_DIRS[@]}" -eq 0 && "$NO_AGENT_DIR" -ne 1 ]]; then
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

# Optional legacy migration: detect old layout and clean it up before rendering.
maybe_migrate_legacy() {
    if (( MIGRATE_LEGACY != 1 )); then
        return 0
    fi

    note "migration: scanning legacy artifacts in $TARGET_DIR"

    # 1. .cursorrules is silently ignored in Cursor Agent mode now. We do not
    #    delete the old file (user may want to route content manually); we just
    #    rename it to .cursorrules.legacy.bak so FORCE-overwrite of the modern
    #    .cursor/rules/*.mdc layout can proceed.
    if [[ -f "$TARGET_DIR/.cursorrules" && ! -f "$TARGET_DIR/.cursorrules.legacy.bak" ]]; then
        if (( DRY_RUN == 1 )); then
            note "(dry-run) would archive .cursorrules -> .cursorrules.legacy.bak"
        else
            mv "$TARGET_DIR/.cursorrules" "$TARGET_DIR/.cursorrules.legacy.bak"
            note "migration: archived .cursorrules -> .cursorrules.legacy.bak (review and route content into AGENTS.md, lesson_learned.md, skills, or .cursor/rules/*.mdc)"
        fi
    fi

    # 2. Subdirectory AGENT.md (singular) is not auto-loaded by Codex/Cursor;
    #    rename to AGENTS.md (plural) which is the recursive-discovery standard.
    while IFS= read -r f; do
        local subdir
        subdir="$(dirname "$f")"
        if [[ -f "$subdir/AGENTS.md" ]]; then
            note "migration: skip $f (target $subdir/AGENTS.md already exists)"
            continue
        fi
        if (( DRY_RUN == 1 )); then
            note "(dry-run) would rename $f -> $subdir/AGENTS.md"
        else
            mv "$f" "$subdir/AGENTS.md"
            note "migration: renamed $f -> $subdir/AGENTS.md"
        fi
    done < <(find "$TARGET_DIR" \
        \( -path '*/node_modules' -o -path '*/.git' -o -path '*/.venv' -o -path '*/.ai-collab*' \) -prune -o \
        -name 'AGENT.md' -type f -print 2>/dev/null)

    # 3. Old CLAUDE.md was canonical (≤150 lines); new CLAUDE.md is ≤30-line
    #    stub. Only flag if the file looks substantive — we do not auto-truncate.
    if [[ -f "$TARGET_DIR/CLAUDE.md" ]]; then
        local existing_lines
        existing_lines=$(wc -l < "$TARGET_DIR/CLAUDE.md" | tr -d ' ')
        if (( existing_lines > 50 )); then
            note "migration: existing CLAUDE.md is $existing_lines lines (new layout expects a ≤30-line stub)."
            note "          Suggested: copy CLAUDE.md content into AGENTS.md, then re-run init with --force to install the new stub."
            note "          See .ai-collab/MIGRATION.md for details."
        fi
    fi
}
maybe_migrate_legacy

# AGENTS.md is the canonical project rules file (cross-tool standard).
render_template \
    "$TEMPLATE_DIR/AGENTS.template.md" \
    "$TARGET_DIR/AGENTS.md" \
    "{{PROJECT_NAME}}=$PROJECT_NAME" \
    "{{PROJECT_ONE_LINE_SUMMARY}}=$PROJECT_SUMMARY" \
    "{{LANG_RULE}}=$LANG_RULE" \
    "{{DIR_LIST}}=$DIR_LIST"

# CLAUDE.md is now a thin stub pointing back at AGENTS.md (Claude Code only).
render_template \
    "$TEMPLATE_DIR/CLAUDE.template.md" \
    "$TARGET_DIR/CLAUDE.md" \
    "{{PROJECT_NAME}}=$PROJECT_NAME"

# Cursor's modern always-apply rule. Lives in .cursor/rules/ as .mdc.
render_template \
    "$TEMPLATE_DIR/cursor-rule-core.mdc.template" \
    "$TARGET_DIR/.cursor/rules/00-core.mdc" \
    "{{PROJECT_NAME}}=$PROJECT_NAME" \
    "{{LANG_RULE}}=$LANG_RULE"

# User-content files: scaffold once, never auto-overwrite (even with --force).
# These accumulate real project lessons / status / terms / ADR catalog.
render_template_protected \
    "$(resolve_template "$TEMPLATE_DIR/lesson_learned.template.md")" \
    "$TARGET_DIR/lesson_learned.md"

render_template_protected \
    "$(resolve_template "$TEMPLATE_DIR/PROJECT_STATUS.template.md")" \
    "$TARGET_DIR/docs/PROJECT_STATUS.md"

render_template_protected \
    "$(resolve_template "$TEMPLATE_DIR/PROJECT_GLOSSARY.template.md")" \
    "$TARGET_DIR/docs/PROJECT_GLOSSARY.md" \
    "{{PROJECT_NAME}}=$PROJECT_NAME"

# Case-collision guard: with a pre-existing lowercase docs/adr store, creating
# uppercase docs/ADR would collide on case-insensitive filesystems (macOS /
# Windows). Scaffold a pointer index that routes readers to docs/adr instead.
if [[ -d "$TARGET_DIR/docs/adr" && ! -e "$TARGET_DIR/docs/ADR/README.md" ]]; then
    render_template_protected \
        "$TEMPLATE_DIR/ADR-README-lowercase-pointer.template.md" \
        "$TARGET_DIR/docs/ADR/README.md"
else
    render_template_protected \
        "$(resolve_template "$TEMPLATE_DIR/ADR-README.template.md")" \
        "$TARGET_DIR/docs/ADR/README.md"
fi

# Quality gates inventory: which deterministic constraints exist, at which
# stage, how strict, and what the escape hatch is. User content after first
# scaffold (projects register their own lint/test/CI gates here).
render_template_protected \
    "$(resolve_template "$TEMPLATE_DIR/QUALITY_GATES.template.md")" \
    "$TARGET_DIR/docs/QUALITY_GATES.md" \
    "{{PROJECT_NAME}}=$PROJECT_NAME"

# Governance + ADR template are managed docs (track upstream); --force ok.
render_template \
    "$TEMPLATE_DIR/ai-collab-doc-governance.template.md" \
    "$TARGET_DIR/docs/ai-collab-doc-governance.md"

render_template \
    "$TEMPLATE_DIR/ADR-000-template.md" \
    "$TARGET_DIR/docs/ADR/000-template.md"

# Subdirectory runbooks: AGENTS.md (plural) so Codex/Cursor pick them up
# automatically when working under that directory. Protected: scaffold once,
# don't trample user-customized runbook content on subsequent --force runs.
for dir in "${AGENT_DIRS[@]}"; do
    root_agents_path="$(relative_root_path "$dir" "AGENTS.md")"
    render_template_protected \
        "$TEMPLATE_DIR/AGENTS-subdir.template.md" \
        "$TARGET_DIR/$dir/AGENTS.md" \
        "{{DIR_NAME}}=$dir" \
        "{{ROOT_AGENTS_PATH}}=$root_agents_path"
done

install_builtin_skills() {
    if [[ ! -d "$BUILTIN_SKILLS_DIR" ]]; then
        return 0
    fi

    local skill_dir
    local skill_name
    local src
    local dst

    # Bundled skills are managed artifacts (canonical lives in .ai-collab/skills/).
    # Always re-install: cheap (cp -R), idempotent, picks up upstream updates after
    # `git -C .ai-collab pull`. Each bundled SKILL.md should carry a banner telling
    # users not to edit the installed copy in-place.
    for skill_dir in "$BUILTIN_SKILLS_DIR"/*; do
        [[ -d "$skill_dir" ]] || continue
        [[ -f "$skill_dir/SKILL.md" ]] || continue

        skill_name="$(basename "$skill_dir")"
        src="$skill_dir"
        dst="$TARGET_DIR/.cursor/skills/$skill_name"

        if (( DRY_RUN == 1 )); then
            note "(dry-run) would install bundled skill: $src -> $dst"
            continue
        fi

        mkdir -p "$(dirname "$dst")"
        # Compare first; only rewrite when content actually differs (avoids
        # touching mtimes / triggering watchers when nothing changed).
        if [[ -e "$dst" ]] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
            note "bundled skill already up-to-date: $dst"
            SKIPPED_FILES+=("$dst")
            continue
        fi

        rm -rf "$dst"
        cp -R "$src" "$dst"
        CREATED_FILES+=("$dst")
        note "installed/updated bundled skill: $dst"
    done
}

# Install baseline agent capabilities (e.g. Devin-style task scratchpad).
install_builtin_skills

link_claude_skills() {
    # Make .cursor/skills/ also visible to Claude Code by symlinking
    # .claude/skills -> ../.cursor/skills.
    # Skip silently if .cursor/skills doesn't exist (project hasn't adopted skills yet).
    #
    # ── Why only Claude, not Codex? ─────────────────────────────────────
    # Cursor scans .cursor/skills + .agents/skills + .claude/skills + .codex/skills
    # without dedup -- every additional symlink causes Cursor to load the same
    # skill twice, burning context. We accept the 1× duplicate cost for Claude
    # (concrete, current value) but DON'T add .agents/skills for Codex (no
    # current user, would add a second Cursor double-scan, and Cursor's
    # .agents/skills path has a known slash-command bug).
    # Re-evaluate when: Codex actually gets used / Cursor fixes dedup / skill
    # count grows past ~15 (then switch to 3-copy + sync approach).
    # See lesson_learned_11_agent_collab.md § 跨 agent skills 共享 for full rationale.
    # ────────────────────────────────────────────────────────────────────
    local cursor_skills="$TARGET_DIR/.cursor/skills"
    local claude_dir="$TARGET_DIR/.claude"
    local claude_skills="$claude_dir/skills"
    local gitignore="$TARGET_DIR/.gitignore"

    if [[ ! -d "$cursor_skills" ]]; then
        return 0
    fi

    if [[ -e "$claude_skills" || -L "$claude_skills" ]]; then
        # Already exists -- only act if it's our exact symlink, never overwrite
        # a real directory or someone else's symlink target without --force.
        local current_target
        current_target="$(readlink "$claude_skills" 2>/dev/null || true)"
        if [[ "$current_target" == "../.cursor/skills" ]]; then
            note "claude skills symlink already correct: $claude_skills -> ../.cursor/skills"
        elif (( FORCE == 1 )); then
            if (( DRY_RUN == 1 )); then
                note "(dry-run) would replace $claude_skills (current: ${current_target:-<dir>}) with symlink to ../.cursor/skills"
            else
                rm -rf "$claude_skills"
                os_link_or_copy "../.cursor/skills" "$claude_skills"
                note "replaced (--force): $claude_skills -> ../.cursor/skills"
            fi
        else
            note "warning: $claude_skills already exists (target: ${current_target:-<dir>}); use --force to replace"
        fi
    else
        if (( DRY_RUN == 1 )); then
            note "(dry-run) would create symlink: $claude_skills -> ../.cursor/skills"
        else
            mkdir -p "$claude_dir"
            os_link_or_copy "../.cursor/skills" "$claude_skills"
            note "linked: $claude_skills -> ../.cursor/skills"
        fi
    fi

    # Patch .gitignore so the symlink survives clones even when .claude/ is
    # globally ignored (the common case -- Claude Code writes settings.local.json there).
    if [[ -f "$gitignore" ]]; then
        # Already negated? skip.
        if grep -qE '^!\.claude/skills/?$' "$gitignore" 2>/dev/null; then
            note "gitignore already whitelists .claude/skills"
            return 0
        fi
        # .claude/ blanket-ignored? add a more granular block.
        if grep -qE '^\.claude/?\*?$' "$gitignore" 2>/dev/null; then
            if (( DRY_RUN == 1 )); then
                note "(dry-run) would relax .claude/ in .gitignore so .claude/skills is tracked"
            else
                python3 - "$gitignore" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
lines = path.read_text().splitlines()
out = []
for line in lines:
    stripped = line.strip()
    if stripped in (".claude/", ".claude"):
        out.append(".claude/*")
        out.append("!.claude/skills")
    else:
        out.append(line)
text = "\n".join(out)
if not text.endswith("\n"):
    text += "\n"
path.write_text(text)
PY
                note "patched .gitignore: .claude/ -> .claude/* + !.claude/skills"
            fi
        fi
    fi
}

# Wire .cursor/skills into Claude Code's discovery path
link_claude_skills

link_codex_skills() {
    # Codex support is opt-in. Cursor may scan .cursor/skills, .claude/skills,
    # .codex/skills, and .agents/skills without dedup, so creating every
    # compatibility symlink by default can load the same skill multiple times.
    local cursor_skills="$TARGET_DIR/.cursor/skills"
    local codex_dir="$TARGET_DIR/.codex"
    local codex_skills="$codex_dir/skills"
    local gitignore="$TARGET_DIR/.gitignore"

    # Codex skills resolution:
    #   ENABLE_CODEX_SKILLS == 1   -> explicit --enable-codex-skills, always on
    #   ENABLE_CODEX_SKILLS == -1  -> explicit --no-codex-skills, always off
    #   ENABLE_CODEX_SKILLS == 0   -> auto-detect: enable iff ~/.codex/ exists OR
    #                                 `codex` is on PATH (user has Codex installed)
    if (( ENABLE_CODEX_SKILLS == -1 )); then
        return 0
    fi
    if (( ENABLE_CODEX_SKILLS == 0 )); then
        if [[ -d "$HOME/.codex" ]] || command -v codex >/dev/null 2>&1; then
            note "auto-detected Codex (~/.codex or codex on PATH); enabling .codex/skills symlink"
        else
            return 0
        fi
    fi

    if [[ ! -d "$cursor_skills" ]]; then
        note "warning: codex skills requested but .cursor/skills does not exist; skip codex skills link"
        return 0
    fi

    if [[ -e "$codex_skills" || -L "$codex_skills" ]]; then
        local current_target
        current_target="$(readlink "$codex_skills" 2>/dev/null || true)"
        if [[ "$current_target" == "../.cursor/skills" ]]; then
            note "codex skills symlink already correct: $codex_skills -> ../.cursor/skills"
        elif (( FORCE == 1 )); then
            if (( DRY_RUN == 1 )); then
                note "(dry-run) would replace $codex_skills (current: ${current_target:-<dir>}) with symlink to ../.cursor/skills"
            else
                rm -rf "$codex_skills"
                os_link_or_copy "../.cursor/skills" "$codex_skills"
                note "replaced (--force): $codex_skills -> ../.cursor/skills"
            fi
        else
            note "warning: $codex_skills already exists (target: ${current_target:-<dir>}); use --force to replace"
        fi
    else
        if (( DRY_RUN == 1 )); then
            note "(dry-run) would create symlink: $codex_skills -> ../.cursor/skills"
        else
            mkdir -p "$codex_dir"
            os_link_or_copy "../.cursor/skills" "$codex_skills"
            note "linked: $codex_skills -> ../.cursor/skills"
        fi
    fi

    if [[ -f "$gitignore" ]]; then
        if grep -qE '^!\.codex/skills/?$' "$gitignore" 2>/dev/null; then
            note "gitignore already whitelists .codex/skills"
            return 0
        fi
        if grep -qE '^\.codex/?\*?$' "$gitignore" 2>/dev/null; then
            if (( DRY_RUN == 1 )); then
                note "(dry-run) would relax .codex/ in .gitignore so .codex/skills is tracked"
            else
                python3 - "$gitignore" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
lines = path.read_text().splitlines()
out = []
for line in lines:
    stripped = line.strip()
    if stripped in (".codex/", ".codex"):
        out.append(".codex/*")
        out.append("!.codex/skills")
    else:
        out.append(line)
text = "\n".join(out)
if not text.endswith("\n"):
    text += "\n"
path.write_text(text)
PY
                note "patched .gitignore: .codex/ -> .codex/* + !.codex/skills"
            fi
        fi
    fi
}

# Optional Codex discovery path. Do not enable by default due duplicate-scan risk.
link_codex_skills

ensure_scratchpad_ignored() {
    local gitignore="$TARGET_DIR/.gitignore"
    local -a entries=(".agent-scratchpad.local.md" ".ai-collab/runtime/")
    local -a missing=()
    local entry

    if [[ -f "$gitignore" ]]; then
        for entry in "${entries[@]}"; do
            if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
                missing+=("$entry")
            fi
        done
    else
        missing=("${entries[@]}")
    fi

    if (( ${#missing[@]} == 0 )); then
        note "scratchpad ignore rules already present"
        return 0
    fi

    if (( DRY_RUN == 1 )); then
        note "(dry-run) would add local scratchpad ignore rules to $gitignore: ${missing[*]}"
        return 0
    fi

    mkdir -p "$(dirname "$gitignore")"
    python3 - "$gitignore" "${missing[@]}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
missing = sys.argv[2:]
text = path.read_text() if path.exists() else ""
if text and not text.endswith("\n"):
    text += "\n"
if text and not text.endswith("\n\n"):
    text += "\n"
text += "# AI collab local scratchpads\n"
text += "\n".join(missing)
text += "\n"
path.write_text(text)
PY
    note "patched .gitignore with local scratchpad rules: ${missing[*]}"
}

# Keep transient task memory local-only
ensure_scratchpad_ignored

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

# Optionally install Cursor afterFileEdit hook (.cursor/hooks.json + script)
if (( INSTALL_CURSOR_HOOK == 1 )); then
    CURSOR_HOOK_TPL="$REPO_ROOT/templates/cursor-hooks.json.template"
    CURSOR_HOOK_DST="$TARGET_DIR/.cursor/hooks.json"
    if [[ ! -f "$CURSOR_HOOK_TPL" ]]; then
        note "warning: cursor-hooks.json.template not found at $CURSOR_HOOK_TPL, skip"
    elif [[ "$DRY_RUN" -eq 1 ]]; then
        note "(dry-run) would install Cursor hooks to $CURSOR_HOOK_DST"
    else
        mkdir -p "$TARGET_DIR/.cursor"
        if [[ -f "$CURSOR_HOOK_DST" && "$FORCE" -ne 1 ]]; then
            note "Cursor hooks.json already exists at $CURSOR_HOOK_DST; use --force to overwrite"
        else
            cp "$CURSOR_HOOK_TPL" "$CURSOR_HOOK_DST"
            note "installed Cursor hooks: $CURSOR_HOOK_DST (afterFileEdit doc check + beforeShellExecution shell guard)"
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
    if (( INSTALL_CURSOR_HOOK == 0 )); then
        note "tip:  bash $SCRIPT_DIR/init_ai_collab_docs.sh \"$TARGET_DIR\" --install-cursor-hook  # Cursor afterFileEdit governance check"
    fi
fi
