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
PROJECT_GLOSSARY_MAX=150
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

check_behavior_pointer() {
    # 检查 CLAUDE.md 是否含有指向 ai-collab-agent-behavior.md 的指针
    # 这是 .ai-collab 引入"行为约束层"后必须的下游适配点
    local file="$TARGET_DIR/CLAUDE.md"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    if grep -q 'ai-collab-agent-behavior\.md' "$file" 2>/dev/null; then
        PASSED+=("CLAUDE.md 已指向 ai-collab-agent-behavior.md")
        printf "  \033[32m[ OK ]\033[0m CLAUDE.md 已指向 ai-collab-agent-behavior.md\n"
    else
        local msg="CLAUDE.md 未指向 .ai-collab/docs/ai-collab-agent-behavior.md（行为约束层指针缺失）"
        SOFT_WARNS+=("$msg")
        printf "  \033[33m[WARN]\033[0m %s\n" "$msg"
        printf "        建议在文档索引表里加一行指向该文件，避免 agent 漏掉行为约束。\n"
    fi
}

check_claude_skills_symlink() {
    # If project has .cursor/skills, .claude/skills should symlink to it
    # so Claude Code can discover the same skills as Cursor.
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
    elif [[ -e "$claude_skills" ]]; then
        SOFT_WARNS+=(".claude/skills 存在但不是 symlink；Cursor / Claude Code 会读到不同的 skill 副本")
        printf "  \033[33m[WARN]\033[0m .claude/skills 不是 symlink\n"
    else
        SOFT_WARNS+=(".cursor/skills 存在但 .claude/skills 缺失；Claude Code 看不到这些 skill。修：bash .ai-collab/scripts/init_ai_collab_docs.sh \"$TARGET_DIR\"")
        printf "  \033[33m[WARN]\033[0m .claude/skills 缺失（Claude Code 看不到 skills）\n"
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
# 拆出来的 lesson_learned_<topic>.md 也受治理：每个 ≤ LESSON_SOFT
shopt -s nullglob
for f in "$TARGET_DIR"/lesson_learned_*.md; do
    label="${f#$TARGET_DIR/}"
    check_lines "$f" "$LESSON_SOFT" "$label (软建议)" 0
    check_lines "$f" "$LESSON_HARD" "$label (硬上限)"
done
shopt -u nullglob
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

section "行为约束层指针检查"
check_behavior_pointer

section "共享语言层（PROJECT_GLOSSARY）检查"
check_glossary

section "Skills 跨 agent 可见性检查（.cursor/skills 与 .claude/skills）"
check_claude_skills_symlink

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
            *.cursorrules*超长*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • .cursorrules 超长 → 这是极简提醒层，把详情挪到 lesson_learned.md 对应主题，留下一句话导航。\n"
                ;;
            *CLAUDE.md*超长*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • CLAUDE.md 超长 → 把不稳定/状态类内容迁到 docs/PROJECT_STATUS.md，深细节迁到 lesson_learned.md。\n"
                ;;
            *AGENTS.md*超长*)
                if (( printed == 0 )); then
                    printf "\n\033[36m[修复建议]\033[0m\n"
                    printed=1
                fi
                printf "  • AGENTS.md 超长 → 仅保留入口指引，技术细节进 backend/AGENT.md 等子目录文件。\n"
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
