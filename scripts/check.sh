#!/usr/bin/env bash
# AI 协作文档治理健康检查
# 用法：
#   bash .ai-collab/scripts/check.sh [TARGET_DIR]
#   默认 TARGET_DIR 是当前目录的 git 仓库根
#
# 检查项：
#   1. 四大主文件行数 vs 目标上限（软警告 / 硬失败）
#   2. CLAUDE.md / .cursorrules 是否混入了"状态快照类数字"
#   3. 各文件是否残留 TODO 占位符
#   4. 同一条长字符串是否在多个主文件里同时出现（canonical 冲突启发式）
#   5. lesson_learned.md 单主题行数上限
#
# 退出码：
#   0  全部通过
#   1  有硬失败（建议 pre-commit 阻断）
#   2  仅软警告
set -uo pipefail

TARGET_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

CLAUDE_MAX=150
CURSORRULES_MAX=10
AGENTS_MAX=15
LESSON_SOFT=350
LESSON_HARD=600
PROJECT_STATUS_MAX=120
AGENT_MD_SOFT=80
LESSON_TOPIC_MAX=80

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

check_agent_md_files() {
    local -a files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(find "$TARGET_DIR" \
        \( -path '*/node_modules' -o -path '*/.git' -o -path '*/venv' -o -path '*/.venv' -o -path '*/docs/archive*' -o -path '*/.ai-collab*' \) -prune -o \
        \( -name 'AGENT.md' -o -name 'AGENTS.md' \) -type f -print 2>/dev/null)
    if (( ${#files[@]} == 0 )); then
        PASSED+=("未发现目录级 AGENT.md / AGENTS.md")
        printf "  \033[32m[ OK ]\033[0m 未发现目录级 AGENT.md / AGENTS.md\n"
        return 0
    fi
    for f in "${files[@]}"; do
        # 根 AGENTS.md 用更严格的上限
        if [[ "$f" == "$TARGET_DIR/AGENTS.md" ]]; then
            check_lines "$f" "$AGENTS_MAX" "根 AGENTS.md"
        else
            check_lines "$f" "$AGENT_MD_SOFT" "${f#$TARGET_DIR/}" 0
            check_todo_residue "$f" "${f#$TARGET_DIR/}" 0
        fi
    done
}

check_duplicate_lines() {
    local -a files=()
    for f in "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/.cursorrules" "$TARGET_DIR/AGENTS.md" "$TARGET_DIR/lesson_learned.md"; do
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

section "体积检查"
check_lines "$TARGET_DIR/CLAUDE.md" "$CLAUDE_MAX" "CLAUDE.md"
check_lines "$TARGET_DIR/.cursorrules" "$CURSORRULES_MAX" ".cursorrules"
check_lines "$TARGET_DIR/AGENTS.md" "$AGENTS_MAX" "AGENTS.md"
check_lines "$TARGET_DIR/lesson_learned.md" "$LESSON_HARD" "lesson_learned.md (硬上限)"
check_lines "$TARGET_DIR/lesson_learned.md" "$LESSON_SOFT" "lesson_learned.md (软建议)" 0
check_lines "$TARGET_DIR/docs/PROJECT_STATUS.md" "$PROJECT_STATUS_MAX" "docs/PROJECT_STATUS.md" 0

section "状态快照污染检查（CLAUDE.md / .cursorrules 不应混入数字）"
check_no_snapshot_numbers "$TARGET_DIR/CLAUDE.md" "CLAUDE.md"
check_no_snapshot_numbers "$TARGET_DIR/.cursorrules" ".cursorrules"

section "TODO 残留检查"
check_todo_residue "$TARGET_DIR/CLAUDE.md" "CLAUDE.md" 0
check_todo_residue "$TARGET_DIR/.cursorrules" ".cursorrules" 0
check_todo_residue "$TARGET_DIR/lesson_learned.md" "lesson_learned.md" 0
check_todo_residue "$TARGET_DIR/docs/PROJECT_STATUS.md" "docs/PROJECT_STATUS.md" 0

section "lesson_learned.md 主题长度检查"
check_lesson_topics "$TARGET_DIR/lesson_learned.md"

section "目录级 AGENT.md / AGENTS.md 检查"
check_agent_md_files

section "跨文件重复检查（canonical 冲突启发式）"
check_duplicate_lines

# =========================
# 汇总
# =========================

section "汇总"
printf "通过：%d 项\n" "${#PASSED[@]}"
printf "软警告：%d 项\n" "${#SOFT_WARNS[@]}"
printf "硬失败：%d 项\n" "${#HARD_FAILS[@]}"

if (( ${#HARD_FAILS[@]} > 0 )); then
    printf "\n\033[31m硬失败列表：\033[0m\n"
    for f in "${HARD_FAILS[@]}"; do
        printf "  - %s\n" "$f"
    done
    exit 1
fi

if (( ${#SOFT_WARNS[@]} > 0 )); then
    printf "\n\033[33m软警告列表：\033[0m\n"
    for w in "${SOFT_WARNS[@]}"; do
        printf "  - %s\n" "$w"
    done
    exit 2
fi

printf "\n\033[32m全部通过\033[0m\n"
exit 0
