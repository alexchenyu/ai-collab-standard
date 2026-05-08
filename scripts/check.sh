#!/usr/bin/env bash
# AI 协作文档治理健康检查（新架构：AGENTS.md canonical / Cursor MDC / 子目录 AGENTS.md）
# 用法：
#   bash .ai-collab/scripts/check.sh [TARGET_DIR]
#   默认 TARGET_DIR 是当前目录的 git 仓库根
#
# 检查项：
#   1. 主文件行数 / 字节数 vs 目标上限（软警告 / 硬失败）
#   2. AGENTS.md 是否混入了"状态快照类数字"
#   3. 各文件是否残留 TODO 占位符
#   4. 同一条长字符串是否在多个主文件里同时出现（canonical 冲突启发式）
#   5. lesson_learned.md 单主题行数上限
#   6. 本地 scratchpad 是否被 gitignore 忽略
#   7. .cursor/rules/ 至少有一个 alwaysApply mdc 指向 AGENTS.md
#   8. 子目录 runbook 用 AGENTS.md（不是过时的 AGENT.md 单数）
#   9. AGENTS.md 总字节（含递归子目录）≤ Codex project_doc_max_bytes (32 KiB)
#   10. 历史遗留：.cursorrules 还在？提示迁移
#
# 退出码：
#   0  全部通过
#   1  有硬失败（建议 pre-commit 阻断）
#   2  仅软警告
set -uo pipefail

# Bash 3.2+ compatibility: this script intentionally avoids associative arrays
# (declare -A), mapfile/readarray, and ${var^^}/${var,,} so it runs on macOS's
# default Bash 3.2 and Git for Windows. If you add a Bash 4+ feature, raise
# this guard to (( BASH_VERSINFO[0] >= 4 )) and tell users to install bash 4.
if (( ${BASH_VERSINFO[0]:-0} < 3 )); then
    echo "check.sh requires Bash 3.2+; you have ${BASH_VERSION:-unknown}." >&2
    exit 1
fi

TARGET_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# New layout limits (AGENTS.md is canonical, CLAUDE.md is stub).
AGENTS_MAX=200                # was 15 (thin pointer); now canonical
CLAUDE_MAX=30                 # was 150 (canonical); now Claude Code stub
CURSOR_MDC_MAX=60             # .cursor/rules/00-core.mdc; alwaysApply token budget
LESSON_SOFT=350
LESSON_HARD=600
PROJECT_STATUS_MAX=120
PROJECT_GLOSSARY_MAX=150
SUBDIR_AGENTS_SOFT=80
LESSON_TOPIC_MAX=80
CODEX_PROJECT_DOC_MAX_BYTES=32768   # default Codex project_doc_max_bytes (32 KiB)

declare -a HARD_FAILS=()
declare -a SOFT_WARNS=()
declare -a PASSED=()

section() {
    printf "\n\033[1;34m== %s ==\033[0m\n" "$1"
}

check_lines() {
    local file="$1"
    local max="$2"
    local label="$3"
    local hard="${4:-1}"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    local lines
    lines=$(wc -l < "$file" | tr -d ' ')
    if (( lines > max )); then
        local msg="$label 超长：$lines > $max 行 ($file)"
        if (( hard == 1 )); then
            HARD_FAILS+=("$msg")
            printf "  \033[31m[FAIL]\033[0m %s\n" "$msg"
        else
            SOFT_WARNS+=("$msg")
            printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
        fi
    else
        PASSED+=("$label: $lines / $max 行")
        printf "  \033[32m[ OK ]\033[0m %s: %d / %d 行\n" "$label" "$lines" "$max"
    fi
}

check_no_snapshot_numbers() {
    local file="$1"
    local label="$2"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    # 启发式：匹配 "大数字 + 单位" 的快照类数字
    local hits
    hits=$(grep -nE '\b[0-9]+[KMG]?\b *(vectors?|docs?|chunks?|rows?|GB|MB|QPS|req/s|张|卡|实例|端口|port)\b|[0-9]{4}-[0-9]{2}-[0-9]{2}|:\s*[0-9]{4,5}\b' "$file" 2>/dev/null | head -5 || true)
    if [[ -n "$hits" ]]; then
        local msg="$label 疑似混入状态快照数字（日期 / 规模 / 端口 / 实例数），应迁到 PROJECT_STATUS.md"
        SOFT_WARNS+=("$msg")
        printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
        printf "%s\n" "$hits" | sed 's/^/        /'
    else
        PASSED+=("$label 无状态快照数字")
        printf "  \033[32m[ OK ]\033[0m %s 无明显状态快照数字\n" "$label"
    fi
}

check_todo_residue() {
    local file="$1"
    local label="$2"
    local hard="${3:-0}"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    local count=0
    if [[ -f "$file" ]]; then
        count=$(grep -c 'TODO' "$file" 2>/dev/null || true)
        count=$(printf '%s' "$count" | tr -d '[:space:]')
        count="${count:-0}"
    fi
    if (( count > 0 )); then
        local msg="$label 残留 $count 条 TODO 占位符（模板未填实，不应被当作 canonical source）"
        if (( hard == 1 )); then
            HARD_FAILS+=("$msg")
            printf "  \033[31m[FAIL]\033[0m %s\n" "$msg"
        else
            SOFT_WARNS+=("$msg")
            printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
        fi
    else
        PASSED+=("$label 无 TODO 残留")
        printf "  \033[32m[ OK ]\033[0m %s 无 TODO 残留\n" "$label"
    fi
}

check_lesson_topics() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    # 按 ### 开头的章节计算每段行数
    local awk_out
    awk_out=$(awk '
        /^### / { if (h != "") print lines "\t" h; h=$0; lines=0; next }
        { lines++ }
        END { if (h != "") print lines "\t" h }
    ' "$file")
    local bad=0
    while IFS=$'\t' read -r lines title; do
        [[ -z "$title" ]] && continue
        if (( lines > LESSON_TOPIC_MAX )); then
            local msg="lesson_learned.md 主题过长：$title ($lines > $LESSON_TOPIC_MAX 行)"
            SOFT_WARNS+=("$msg")
            printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
            bad=1
        fi
    done <<< "$awk_out"
    if (( bad == 0 )); then
        PASSED+=("lesson_learned.md 所有主题 ≤ $LESSON_TOPIC_MAX 行")
        printf "  \033[32m[ OK ]\033[0m 所有主题 ≤ %d 行\n" "$LESSON_TOPIC_MAX"
    fi
}

check_subdir_agents_files() {
    # Recursive AGENTS.md is the cross-tool standard (Codex + Cursor walk from
    # git root down). Old-style singular AGENT.md is no longer auto-loaded.
    local -a agents_files=()
    local -a legacy_agent_files=()
    while IFS= read -r f; do
        agents_files+=("$f")
    done < <(find "$TARGET_DIR" \
        \( -path '*/node_modules' -o -path '*/.git' -o -path '*/venv' -o -path '*/.venv' -o -path '*/docs/archive*' -o -path '*/.ai-collab*' \) -prune -o \
        -name 'AGENTS.md' -type f -print 2>/dev/null)
    while IFS= read -r f; do
        legacy_agent_files+=("$f")
    done < <(find "$TARGET_DIR" \
        \( -path '*/node_modules' -o -path '*/.git' -o -path '*/venv' -o -path '*/.venv' -o -path '*/docs/archive*' -o -path '*/.ai-collab*' \) -prune -o \
        -name 'AGENT.md' -type f -print 2>/dev/null)

    if (( ${#agents_files[@]} == 0 && ${#legacy_agent_files[@]} == 0 )); then
        PASSED+=("未发现 AGENTS.md / AGENT.md 文件")
        printf "  \033[32m[ OK ]\033[0m 未发现 AGENTS.md / AGENT.md 文件\n"
        return 0
    fi

    # Sub-directory AGENTS.md size cap (root has its own canonical cap, applied elsewhere).
    for f in "${agents_files[@]}"; do
        [[ "$f" == "$TARGET_DIR/AGENTS.md" ]] && continue
        check_lines "$f" "$SUBDIR_AGENTS_SOFT" "${f#$TARGET_DIR/}" 0
        check_todo_residue "$f" "${f#$TARGET_DIR/}" 0
    done

    # Legacy AGENT.md (singular) — Codex/Cursor will not auto-load it.
    for f in "${legacy_agent_files[@]}"; do
        local msg="${f#$TARGET_DIR/} 是过时的 AGENT.md (单数)；Codex/Cursor 不会递归自动加载，请重命名为同目录 AGENTS.md (复数)。修复：bash .ai-collab/scripts/init_ai_collab_docs.sh \"$TARGET_DIR\" --migrate-legacy"
        SOFT_WARNS+=("$msg")
        printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
    done
}

check_behavior_pointer() {
    # AGENTS.md (canonical) and the Cursor mdc rule should both reference the
    # behavior layer; otherwise an agent that only loads one will miss it.
    local agents="$TARGET_DIR/AGENTS.md"
    local mdc="$TARGET_DIR/.cursor/rules/00-core.mdc"
    local missing=0

    if [[ -f "$agents" ]]; then
        if grep -q 'ai-collab-agent-behavior\.md' "$agents" 2>/dev/null; then
            PASSED+=("AGENTS.md 已指向 ai-collab-agent-behavior.md")
            printf "  \033[32m[ OK ]\033[0m AGENTS.md 已指向 ai-collab-agent-behavior.md\n"
        else
            SOFT_WARNS+=("AGENTS.md 未指向 .ai-collab/docs/ai-collab-agent-behavior.md（行为约束层指针缺失）")
            printf "  \033[33m[WARN]\033[0m AGENTS.md 未指向 ai-collab-agent-behavior.md\n"
            missing=1
        fi
    fi

    if [[ -f "$mdc" ]]; then
        if grep -q 'ai-collab-agent-behavior\.md' "$mdc" 2>/dev/null; then
            PASSED+=(".cursor/rules/00-core.mdc 已指向 ai-collab-agent-behavior.md")
            printf "  \033[32m[ OK ]\033[0m .cursor/rules/00-core.mdc 已指向 ai-collab-agent-behavior.md\n"
        else
            SOFT_WARNS+=(".cursor/rules/00-core.mdc 未指向 ai-collab-agent-behavior.md")
            printf "  \033[33m[WARN]\033[0m .cursor/rules/00-core.mdc 未指向 ai-collab-agent-behavior.md\n"
            missing=1
        fi
    fi
}

check_cursor_rules_mdc() {
    # Modern Cursor reads .cursor/rules/*.mdc; .cursorrules is silently
    # ignored in Agent mode. We require at least one alwaysApply mdc rule.
    local rules_dir="$TARGET_DIR/.cursor/rules"
    if [[ ! -d "$rules_dir" ]]; then
        SOFT_WARNS+=(".cursor/rules/ 目录不存在；Cursor Agent 模式下没有任何项目规则被注入。修：bash .ai-collab/scripts/init_ai_collab_docs.sh \"$TARGET_DIR\"")
        printf "  \033[33m[WARN]\033[0m .cursor/rules/ 目录不存在（Cursor Agent 模式无规则）\n"
        return 0
    fi
    local always_apply_count
    always_apply_count=$(grep -lE '^alwaysApply:[[:space:]]*true' "$rules_dir"/*.mdc 2>/dev/null | wc -l | tr -d ' ')
    if (( always_apply_count == 0 )); then
        SOFT_WARNS+=(".cursor/rules/ 没有 alwaysApply: true 的 mdc 文件；Cursor 永远不会自动注入项目规则")
        printf "  \033[33m[WARN]\033[0m .cursor/rules/ 没有 alwaysApply: true 的规则\n"
    else
        PASSED+=(".cursor/rules/ 含 $always_apply_count 个 alwaysApply 规则")
        printf "  \033[32m[ OK ]\033[0m .cursor/rules/ 含 %d 个 alwaysApply 规则\n" "$always_apply_count"
    fi
    # Soft cap on the core mdc size — alwaysApply rules eat token budget.
    local core="$rules_dir/00-core.mdc"
    [[ -f "$core" ]] && check_lines "$core" "$CURSOR_MDC_MAX" ".cursor/rules/00-core.mdc" 0
}

check_legacy_cursorrules() {
    # .cursorrules is silently ignored in Cursor Agent mode (deprecated).
    # If the file still exists with substantive content, suggest migration.
    local file="$TARGET_DIR/.cursorrules"
    if [[ ! -f "$file" ]]; then
        PASSED+=("未发现旧 .cursorrules（已迁移到 .cursor/rules/*.mdc）")
        printf "  \033[32m[ OK ]\033[0m 未发现旧 .cursorrules\n"
        return 0
    fi
    local lines
    lines=$(wc -l < "$file" | tr -d ' ')
    SOFT_WARNS+=(".cursorrules 仍存在 ($lines 行)；Cursor Agent 模式会静默忽略它。迁移：把内容拷到 .cursor/rules/00-core.mdc，然后删除 .cursorrules 或重命名为 .cursorrules.legacy.bak")
    printf "  \033[33m[WARN]\033[0m .cursorrules 仍存在 (%d 行)，Agent 模式不读取\n" "$lines"
}

check_codex_budget() {
    # Codex stops loading AGENTS.md once accumulated bytes hit
    # project_doc_max_bytes (default 32 KiB). Sum the root + recursive subdir
    # files we actually generate; warn if total > 24 KiB (75% headroom).
    local total=0 file size warn_threshold
    warn_threshold=$(( CODEX_PROJECT_DOC_MAX_BYTES * 3 / 4 ))
    while IFS= read -r file; do
        size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
        total=$(( total + size ))
    done < <(find "$TARGET_DIR" \
        \( -path '*/node_modules' -o -path '*/.git' -o -path '*/venv' -o -path '*/.venv' -o -path '*/.ai-collab*' \) -prune -o \
        -name 'AGENTS.md' -type f -print 2>/dev/null)
    if (( total == 0 )); then
        return 0
    fi
    local human_total human_max
    human_total=$(( total / 1024 ))
    human_max=$(( CODEX_PROJECT_DOC_MAX_BYTES / 1024 ))
    if (( total > CODEX_PROJECT_DOC_MAX_BYTES )); then
        HARD_FAILS+=("AGENTS.md 总字节 ${total}B (~${human_total}KiB) > Codex project_doc_max_bytes ${CODEX_PROJECT_DOC_MAX_BYTES}B (~${human_max}KiB); 深层文件会被截断")
        printf "  \033[31m[FAIL]\033[0m AGENTS.md 总字节超 Codex 预算: %d B > %d B\n" "$total" "$CODEX_PROJECT_DOC_MAX_BYTES"
    elif (( total > warn_threshold )); then
        SOFT_WARNS+=("AGENTS.md 总字节 ${total}B 接近 Codex 预算 ${CODEX_PROJECT_DOC_MAX_BYTES}B；考虑把细节挪到 lesson_learned.md / ADR")
        printf "  \033[33m[WARN]\033[0m AGENTS.md 总字节 %d B 接近 Codex 预算 %d B\n" "$total" "$CODEX_PROJECT_DOC_MAX_BYTES"
    else
        PASSED+=("AGENTS.md 总字节 ${total}B 在 Codex 预算 ${CODEX_PROJECT_DOC_MAX_BYTES}B 内")
        printf "  \033[32m[ OK ]\033[0m AGENTS.md 总字节 %d B / %d B (Codex 预算)\n" "$total" "$CODEX_PROJECT_DOC_MAX_BYTES"
    fi
}

check_claude_stub() {
    # CLAUDE.md should now be a thin stub pointing at AGENTS.md, not a 150-line
    # canonical file. If it still looks substantive, warn.
    local file="$TARGET_DIR/CLAUDE.md"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    if grep -q 'AGENTS\.md' "$file" 2>/dev/null; then
        PASSED+=("CLAUDE.md 已指向 AGENTS.md (canonical)")
        printf "  \033[32m[ OK ]\033[0m CLAUDE.md 已指向 AGENTS.md (canonical)\n"
    else
        SOFT_WARNS+=("CLAUDE.md 未提及 AGENTS.md；Claude Code 用户会以为 CLAUDE.md 是 canonical")
        printf "  \033[33m[WARN]\033[0m CLAUDE.md 未提及 AGENTS.md\n"
    fi
}

is_windows_env() {
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
    esac
    return 1
}

check_claude_skills_symlink() {
    # If project has .cursor/skills, .claude/skills should symlink to it
    # so Claude Code can discover the same skills as Cursor.
    # On Windows, init_ai_collab_docs.sh falls back to copy-instead-of-link;
    # in that case we accept a directory if it exists and is non-empty.
    local cursor_skills="$TARGET_DIR/.cursor/skills"
    local claude_skills="$TARGET_DIR/.claude/skills"
    if [[ ! -d "$cursor_skills" ]]; then
        return 0
    fi
    if [[ -L "$claude_skills" ]]; then
        local current_target
        current_target="$(readlink "$claude_skills" 2>/dev/null || true)"
        if [[ "$current_target" == "../.cursor/skills" ]]; then
            PASSED+=(".claude/skills -> .cursor/skills 已配置")
            printf "  \033[32m[ OK ]\033[0m .claude/skills -> .cursor/skills\n"
            return 0
        fi
        SOFT_WARNS+=(".claude/skills 是 symlink 但目标不对：$current_target （期望 ../.cursor/skills）")
        printf "  \033[33m[WARN]\033[0m .claude/skills 目标错误：%s\n" "$current_target"
    elif [[ -d "$claude_skills" ]] && is_windows_env; then
        PASSED+=(".claude/skills 已通过 Windows 复制 fallback 同步")
        printf "  \033[32m[ OK ]\033[0m .claude/skills 已通过 Windows 复制 fallback 同步（symlink 不可用时的预期行为）\n"
        printf "        提醒：上游 .cursor/skills 改动后需重跑 init_ai_collab_docs.sh\n"
    elif [[ -e "$claude_skills" ]]; then
        SOFT_WARNS+=(".claude/skills 存在但不是 symlink；Cursor / Claude Code 会读到不同的 skill 副本")
        printf "  \033[33m[WARN]\033[0m .claude/skills 不是 symlink\n"
    else
        SOFT_WARNS+=(".cursor/skills 存在但 .claude/skills 缺失；Claude Code 看不到这些 skill。修：bash .ai-collab/scripts/init_ai_collab_docs.sh \"$TARGET_DIR\"")
        printf "  \033[33m[WARN]\033[0m .claude/skills 缺失（Claude Code 看不到 skills）\n"
    fi
}

check_codex_skills_symlink() {
    # Codex skills compatibility is opt-in. Only check once a project has
    # created .codex/ or .codex/skills; otherwise default projects stay quiet.
    local cursor_skills="$TARGET_DIR/.cursor/skills"
    local codex_dir="$TARGET_DIR/.codex"
    local codex_skills="$codex_dir/skills"

    if [[ ! -d "$cursor_skills" ]]; then
        return 0
    fi
    if [[ ! -e "$codex_dir" && ! -L "$codex_skills" ]]; then
        PASSED+=("Codex skills 兼容未启用（默认跳过）")
        printf "  \033[32m[ OK ]\033[0m Codex skills 兼容未启用（默认跳过）\n"
        return 0
    fi

    if [[ -L "$codex_skills" ]]; then
        local current_target
        current_target="$(readlink "$codex_skills" 2>/dev/null || true)"
        if [[ "$current_target" == "../.cursor/skills" ]]; then
            PASSED+=(".codex/skills -> .cursor/skills 已配置")
            printf "  \033[32m[ OK ]\033[0m .codex/skills -> .cursor/skills\n"
            return 0
        fi
        SOFT_WARNS+=(".codex/skills 是 symlink 但目标不对：$current_target （期望 ../.cursor/skills）")
        printf "  \033[33m[WARN]\033[0m .codex/skills 目标错误：%s\n" "$current_target"
    elif [[ -d "$codex_skills" ]] && is_windows_env; then
        PASSED+=(".codex/skills 已通过 Windows 复制 fallback 同步")
        printf "  \033[32m[ OK ]\033[0m .codex/skills 已通过 Windows 复制 fallback 同步\n"
    elif [[ -e "$codex_skills" ]]; then
        SOFT_WARNS+=(".codex/skills 存在但不是 symlink；Cursor / Codex 可能读到不同的 skill 副本")
        printf "  \033[33m[WARN]\033[0m .codex/skills 不是 symlink\n"
    else
        SOFT_WARNS+=(".codex/ 存在但 .codex/skills 缺失；若要启用 Codex skills，运行：bash .ai-collab/scripts/init_ai_collab_docs.sh \"$TARGET_DIR\" --enable-codex-skills")
        printf "  \033[33m[WARN]\033[0m .codex/skills 缺失（Codex skills 兼容未完整启用）\n"
    fi
}

check_builtin_skills_installed() {
    local builtin_dir="$TARGET_DIR/.ai-collab/skills"
    local skill_dir
    local skill_name
    local target_skill
    local missing=0

    if [[ ! -d "$builtin_dir" ]]; then
        return 0
    fi

    for skill_dir in "$builtin_dir"/*; do
        [[ -d "$skill_dir" ]] || continue
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        skill_name="$(basename "$skill_dir")"
        target_skill="$TARGET_DIR/.cursor/skills/$skill_name/SKILL.md"
        if [[ -f "$target_skill" ]]; then
            PASSED+=("内置 skill 已安装：$skill_name")
            printf "  \033[32m[ OK ]\033[0m 内置 skill 已安装：%s\n" "$skill_name"
        else
            local msg="内置 skill 未安装到 .cursor/skills：$skill_name；运行 init_ai_collab_docs.sh 同步"
            SOFT_WARNS+=("$msg")
            printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
            missing=1
        fi
    done

    if (( missing == 0 )); then
        PASSED+=("所有内置 skills 已安装")
    fi
}

scratchpad_is_ignored() {
    local rel="$1"
    local gitignore="$TARGET_DIR/.gitignore"

    if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if git -C "$TARGET_DIR" check-ignore -q "$rel" 2>/dev/null; then
            return 0
        fi
    fi

    if [[ -f "$gitignore" ]]; then
        if grep -qxF "$rel" "$gitignore" 2>/dev/null; then
            return 0
        fi
        if [[ "$rel" == .ai-collab/runtime/* ]] && grep -qxF ".ai-collab/runtime/" "$gitignore" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

check_local_scratchpads() {
    local found=0
    local bad=0
    local rel

    for rel in ".agent-scratchpad.local.md" ".ai-collab/runtime/scratchpad.local.md"; do
        if [[ ! -e "$TARGET_DIR/$rel" ]]; then
            continue
        fi
        found=1
        if scratchpad_is_ignored "$rel"; then
            PASSED+=("$rel 已被 gitignore 忽略")
            printf "  \033[32m[ OK ]\033[0m %s 已被 gitignore 忽略\n" "$rel"
        else
            local msg="$rel 是本地 scratchpad，但未被 gitignore 忽略；它不应进入版本控制或成为 canonical source"
            SOFT_WARNS+=("$msg")
            printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
            bad=1
        fi
    done

    if (( found == 0 )); then
        PASSED+=("未发现本地 scratchpad 文件")
        printf "  \033[32m[ OK ]\033[0m 未发现本地 scratchpad 文件\n"
    elif (( bad == 0 )); then
        PASSED+=("本地 scratchpad 均未进入版本控制范围")
    fi
}

check_glossary() {
    # 检查 docs/PROJECT_GLOSSARY.md：体积上限 + CLAUDE.md 指针
    local file="$TARGET_DIR/docs/PROJECT_GLOSSARY.md"
    local claude="$TARGET_DIR/CLAUDE.md"
    if [[ ! -f "$file" ]]; then
        # 没建 glossary 不算硬错，但提醒一句
        SOFT_WARNS+=("未建 docs/PROJECT_GLOSSARY.md（共享语言层），可用 .ai-collab/docs/PROJECT_GLOSSARY.template.md 起手")
        printf "  \033[33m[WARN]\033[0m 未建 docs/PROJECT_GLOSSARY.md\n"
        return 0
    fi
    check_lines "$file" "$PROJECT_GLOSSARY_MAX" "docs/PROJECT_GLOSSARY.md" 0
    check_todo_residue "$file" "docs/PROJECT_GLOSSARY.md" 0
    if [[ -f "$claude" ]]; then
        if grep -q 'PROJECT_GLOSSARY\.md' "$claude" 2>/dev/null; then
            PASSED+=("CLAUDE.md 已指向 PROJECT_GLOSSARY.md")
            printf "  \033[32m[ OK ]\033[0m CLAUDE.md 已指向 PROJECT_GLOSSARY.md\n"
        else
            SOFT_WARNS+=("CLAUDE.md 未指向 docs/PROJECT_GLOSSARY.md（共享语言层指针缺失）")
            printf "  \033[33m[WARN]\033[0m CLAUDE.md 未指向 docs/PROJECT_GLOSSARY.md\n"
        fi
    fi
    # 锚点新鲜度（启发式）：抽 glossary 里出现的 lesson_learned_*.md / docs/*.md 路径，验证文件存在
    local stale=0
    while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        local target="$TARGET_DIR/$ref"
        if [[ ! -e "$target" ]]; then
            SOFT_WARNS+=("PROJECT_GLOSSARY.md 锚点失效：$ref 不存在")
            printf "  \033[33m[WARN]\033[0m 锚点失效：%s\n" "$ref"
            stale=1
        fi
    done < <(grep -oE '`(lesson_learned[^`]*\.md|docs/[A-Za-z0-9_/-]+\.md|backend/[A-Za-z0-9_/.-]+|scripts/[A-Za-z0-9_/.-]+)`' "$file" 2>/dev/null \
             | tr -d '`' | sort -u)
    if (( stale == 0 )); then
        PASSED+=("PROJECT_GLOSSARY.md 锚点全部存在")
        printf "  \033[32m[ OK ]\033[0m PROJECT_GLOSSARY.md 锚点全部存在\n"
    fi
}

check_duplicate_lines() {
    local -a files=()
    for f in "$TARGET_DIR/AGENTS.md" "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/.cursor/rules/00-core.mdc" "$TARGET_DIR/lesson_learned.md"; do
        [[ -f "$f" ]] && files+=("$f")
    done
    if (( ${#files[@]} < 2 )); then
        return 0
    fi
    # 只看非空、非标题、长度 ≥ 30 字符的行；在多个文件里同时出现即报重复
    local dup
    dup=$(awk 'FNR==1{fname=FILENAME} length($0) >= 30 && !/^#/ && !/^\s*$/ && !/^---/ && !/^[\|\- ]+$/ { key=$0; if (seen[key] && seen[key] != fname) { print seen[key] " <-> " fname ":  " $0; } else { seen[key]=fname } }' "${files[@]}" | head -10)
    if [[ -n "$dup" ]]; then
        local msg="发现跨文件重复长行，疑似 canonical 冲突（只应保留一份，其它改为单行导航）"
        SOFT_WARNS+=("$msg")
        printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
        printf "%s\n" "$dup" | sed 's/^/        /'
    else
        PASSED+=("主文件间无明显长行重复")
        printf "  \033[32m[ OK ]\033[0m 主文件间无明显长行重复\n"
    fi
}

# =========================
# 主流程
# =========================

printf "\033[1;36mAI 协作文档治理健康检查\033[0m\n"
printf "目标目录：%s\n" "$TARGET_DIR"

section "体积检查（新架构：AGENTS.md canonical / CLAUDE.md stub / Cursor MDC）"
check_lines "$TARGET_DIR/AGENTS.md" "$AGENTS_MAX" "AGENTS.md (canonical)"
check_lines "$TARGET_DIR/CLAUDE.md" "$CLAUDE_MAX" "CLAUDE.md (stub)" 0
check_lines "$TARGET_DIR/.cursor/rules/00-core.mdc" "$CURSOR_MDC_MAX" ".cursor/rules/00-core.mdc" 0
check_lines "$TARGET_DIR/lesson_learned.md" "$LESSON_HARD" "lesson_learned.md (硬上限)"
check_lines "$TARGET_DIR/lesson_learned.md" "$LESSON_SOFT" "lesson_learned.md (软建议)" 0
shopt -s nullglob
for f in "$TARGET_DIR"/lesson_learned_*.md; do
    label="${f#$TARGET_DIR/}"
    check_lines "$f" "$LESSON_SOFT" "$label (软建议)" 0
    check_lines "$f" "$LESSON_HARD" "$label (硬上限)"
done
shopt -u nullglob
check_lines "$TARGET_DIR/docs/PROJECT_STATUS.md" "$PROJECT_STATUS_MAX" "docs/PROJECT_STATUS.md" 0

section "状态快照污染检查（AGENTS.md / CLAUDE.md 不应混入数字）"
check_no_snapshot_numbers "$TARGET_DIR/AGENTS.md" "AGENTS.md"
check_no_snapshot_numbers "$TARGET_DIR/CLAUDE.md" "CLAUDE.md"

section "TODO 残留检查"
check_todo_residue "$TARGET_DIR/AGENTS.md" "AGENTS.md" 0
check_todo_residue "$TARGET_DIR/CLAUDE.md" "CLAUDE.md" 0
check_todo_residue "$TARGET_DIR/lesson_learned.md" "lesson_learned.md" 0
check_todo_residue "$TARGET_DIR/docs/PROJECT_STATUS.md" "docs/PROJECT_STATUS.md" 0

section "lesson_learned.md 主题长度检查"
check_lesson_topics "$TARGET_DIR/lesson_learned.md"

section "子目录 AGENTS.md / 旧 AGENT.md 迁移检查"
check_subdir_agents_files

section "Cursor 现代规则检查（.cursor/rules/*.mdc）"
check_cursor_rules_mdc

section "旧 .cursorrules 残留检查（Cursor Agent 模式不读取）"
check_legacy_cursorrules

section "Codex 32 KiB 总预算检查（递归 AGENTS.md 字节累加）"
check_codex_budget

section "CLAUDE.md 桩文件检查（应指向 AGENTS.md）"
check_claude_stub

section "行为约束层指针检查（AGENTS.md + Cursor MDC 都应指）"
check_behavior_pointer

section "共享语言层（PROJECT_GLOSSARY）检查"
check_glossary

section "Skills 跨 agent 可见性检查（.cursor/skills 与 .claude/skills）"
check_claude_skills_symlink

section "内置 Skills 安装检查（.ai-collab/skills -> .cursor/skills）"
check_builtin_skills_installed

section "Codex Skills 兼容检查（opt-in）"
check_codex_skills_symlink

section "本地 Scratchpad 检查"
check_local_scratchpads

section "跨文件重复检查（canonical 冲突启发式）"
check_duplicate_lines

# =========================
# 汇总
# =========================

section "汇总"
printf "通过：%d 项\n" "${#PASSED[@]}"
printf "软警告：%d 项\n" "${#SOFT_WARNS[@]}"
printf "硬失败：%d 项\n" "${#HARD_FAILS[@]}"

# 启发式：根据失败/警告内容打印"一行修复建议"
suggest_fix() {
    local msgs_var="$1"   # 数组名
    local -n msgs="$msgs_var"
    local printed=0
    for msg in "${msgs[@]}"; do
        case "$msg" in
            *"lesson_learned.md"*超长*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • lesson_learned.md 超长 → 按主题自动拆分：\n"
                printf "      \033[1mbash .ai-collab/scripts/split_lesson.sh\033[0m            # 干跑预览拆分计划\n"
                printf "      \033[1mbash .ai-collab/scripts/split_lesson.sh --apply\033[0m    # 真正写盘\n"
                ;;
            *lesson_learned_*超长*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                local file
                file=$(printf '%s' "$msg" | grep -oE 'lesson_learned_[^ )]+\.md' | head -1)
                printf "  • %s 超长 → 按 ### 子主题手动二次拆分到 lesson_learned_<sub>.md，并在原文件留导航。\n" "$file"
                ;;
            *.cursorrules*仍存在*|*.cursorrules*Agent\ 模式*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • .cursorrules 仍存在 → Cursor Agent 模式不读取它。迁移：\n"
                printf "      把内容拷到 \033[1m.cursor/rules/00-core.mdc\033[0m，然后 \033[1mrm .cursorrules\033[0m\n"
                printf "      或自动迁移：\033[1mbash .ai-collab/scripts/init_ai_collab_docs.sh . --migrate-legacy\033[0m\n"
                ;;
            *CLAUDE.md*超长*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • CLAUDE.md 超长 → 现在是 Claude Code 桩文件，只放 ≤30 行内容。\n"
                printf "      把项目规则迁到 \033[1mAGENTS.md\033[0m（canonical），状态数字到 PROJECT_STATUS.md，深细节到 lesson_learned.md。\n"
                ;;
            *AGENTS.md*超长*|*AGENTS.md*总字节超*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • AGENTS.md 超长/超预算 → 把可拆走的细节迁出：\n"
                printf "      技术细节 → 子目录 AGENTS.md（Codex/Cursor 会按目录递归加载）\n"
                printf "      经验/排障 → lesson_learned.md\n"
                printf "      架构决策 → docs/ADR/\n"
                printf "      状态数字 → docs/PROJECT_STATUS.md\n"
                ;;
            *AGENT.md*单数*|*过时的\ AGENT.md*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • 子目录 AGENT.md (单数) → 重命名为 AGENTS.md (复数)。一键迁移：\n"
                printf "      \033[1mbash .ai-collab/scripts/init_ai_collab_docs.sh . --migrate-legacy\033[0m\n"
                ;;
            *.cursor/rules/*没有*alwaysApply*|*.cursor/rules/*目录不存在*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • Cursor Agent 模式无规则注入 → 生成 .cursor/rules/00-core.mdc：\n"
                printf "      \033[1mbash .ai-collab/scripts/init_ai_collab_docs.sh .\033[0m\n"
                ;;
            *"本地 scratchpad"*未被*gitignore*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • 本地 scratchpad 未忽略 → 加到 .gitignore：\n"
                printf "      \033[1mprintf '.agent-scratchpad.local.md\\n.ai-collab/runtime/\\n' >> .gitignore\033[0m\n"
                ;;
            *.codex/skills*|*"Codex skills"*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • Codex skills 兼容未完整启用 → 如需启用，运行：\n"
                printf "      \033[1mbash .ai-collab/scripts/init_ai_collab_docs.sh . --enable-codex-skills\033[0m\n"
                ;;
            *"内置 skill 未安装"*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • 内置 skills 未同步 → 运行：\n"
                printf "      \033[1mbash .ai-collab/scripts/init_ai_collab_docs.sh .\033[0m\n"
                ;;
            *主题过长*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • lesson_learned.md 单个主题超 80 行 → 按 ### 子小节拆，或将该主题整段移出到 lesson_learned_<topic>.md：\n"
                printf "      \033[1mbash .ai-collab/scripts/split_lesson.sh\033[0m\n"
                ;;
        esac
    done
}

if (( ${#HARD_FAILS[@]} > 0 )); then
    printf "\n\033[31m硬失败列表：\033[0m\n"
    for f in "${HARD_FAILS[@]}"; do
        printf "  - %s\n" "$f"
    done
    suggest_fix HARD_FAILS
    exit 1
fi

if (( ${#SOFT_WARNS[@]} > 0 )); then
    printf "\n\033[33m软警告列表：\033[0m\n"
    for w in "${SOFT_WARNS[@]}"; do
        printf "  - %s\n" "$w"
    done
    suggest_fix SOFT_WARNS
    exit 2
fi

printf "\n\033[32m全部通过\033[0m\n"
exit 0
