#!/usr/bin/env bash
# 按主题拆分 lesson_learned.md
#
# 用法:
#   bash .ai-collab/scripts/split_lesson.sh                 # 干跑（dry-run），打印计划，不写文件
#   bash .ai-collab/scripts/split_lesson.sh --apply         # 实际拆分
#
# 拆分规则：
#   - 每个 "## N. <topic>" 一节（来自 lesson_learned.md）拆到独立文件
#   - 文件名根据节标题做 slug：## 1. 数据收集与爬虫 -> lesson_learned_01_data_collection.md
#   - 原 lesson_learned.md 保留 "## 使用约定" + "## ADR 导航" + 一份导航索引
#   - slug 规则尽量稳定；如果 slug 已存在且来自不同主题，会报冲突让你手动指定
#
# 设计意图：
#   - check.sh 报硬失败时，给用户的就是"运行这一行"，不再要求人脑判断怎么拆
#   - 拆完后 lesson_learned.md 只剩导航 + 元章节，重新跑 check.sh 必然通过
#   - 子文件继续受治理（每个 ≤ LESSON_SOFT 行；超出继续提示按 ### 子主题再拆）
set -uo pipefail

# This script uses associative arrays (declare -A), which require bash 4+.
# macOS ships bash 3.2 by default; users must `brew install bash` first.
if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
    echo "Error: this script requires bash 4 or newer (found: ${BASH_VERSION:-unknown})." >&2
    echo "On macOS install a newer bash with: brew install bash" >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SOURCE="$REPO_ROOT/lesson_learned.md"
APPLY=0

for arg in "$@"; do
    case "$arg" in
        --apply) APPLY=1 ;;
        -h|--help)
            sed -n '2,15p' "$0"
            exit 0
            ;;
        *)
            printf "未知参数: %s\n" "$arg" >&2
            exit 2
            ;;
    esac
done

if [[ ! -f "$SOURCE" ]]; then
    printf "[split] 找不到 %s\n" "$SOURCE" >&2
    exit 1
fi

# 用 awk 一次扫描，把每个 "## " 节的内容缓存到临时文件
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# 把所有 "## " 节切成单独的 chunk 文件
awk -v outdir="$tmpdir" '
    BEGIN { idx=0; outfile="" }
    /^## / {
        idx++
        outfile = sprintf("%s/%03d.section", outdir, idx)
        # 第一行写入：标题
        print $0 > outfile
        next
    }
    {
        if (outfile != "") print $0 >> outfile
        else {
            # 标题前的前言写入 _preamble
            print $0 >> outdir "/_preamble"
        }
    }
' "$SOURCE"

# slug 表：主题中文/英文 -> 文件名后缀
slug_for() {
    local heading="$1"
    # 去掉前缀 "## " 和编号 "N. "
    local body="${heading#\#\# }"
    body="${body#*. }"
    # 简单关键词匹配，稳定的英文 slug
    local lower="$(printf '%s' "$body" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *使用约定*|*usage*) echo "" ;;     # 不拆，留原文
        *adr*导航*|*adr*nav*) echo "" ;;   # 不拆
        *数据收集*|*爬虫*|*crawl*) echo "data_collection" ;;
        *chunking*|*chunk*) echo "chunking" ;;
        *qdrant*) echo "qdrant" ;;
        *elasticsearch*|*es*混合*|*hybrid*) echo "elasticsearch" ;;
        *rag*pipeline*|*rag*生成*|*rag*agent*|*rag*) echo "rag_agent" ;;
        *数据库*|*mssql*|*postgres*|*sql*) echo "database" ;;
        *embedding*|*reranker*|*llm*服务*) echo "embedding_llm" ;;
        *运维*|*pipeline*|*脚本治理*) echo "ops_pipeline" ;;
        *文档规范*|*数据集*) echo "docs_dataset" ;;
        *安全*|*sso*|*权限*|*acl*) echo "security_acl" ;;
        *)
            # 兜底：取标题前 24 个 [a-z0-9_]
            printf '%s' "$lower" | tr -c 'a-z0-9_' '_' | sed 's/__*/_/g; s/^_//; s/_$//' | cut -c1-24
            ;;
    esac
}

# 根据 idx 顺序生成目标 slug 表
declare -A SECTION_TO_SLUG=()
declare -a SECTION_ORDER=()
declare -A SLUG_TO_SECTION=()
for f in "$tmpdir"/*.section; do
    [[ -f "$f" ]] || continue
    section_id="$(basename "$f" .section)"
    SECTION_ORDER+=("$section_id")
    heading="$(head -n 1 "$f")"
    slug="$(slug_for "$heading")"
    SECTION_TO_SLUG["$section_id"]="$slug"
    if [[ -n "$slug" ]]; then
        if [[ -n "${SLUG_TO_SECTION[$slug]:-}" ]]; then
            printf "[split][冲突] slug=%s 同时被两个章节命中：%s 和 %s\n" \
                "$slug" \
                "$(head -n 1 "$tmpdir/${SLUG_TO_SECTION[$slug]}.section")" \
                "$heading" >&2
        fi
        SLUG_TO_SECTION["$slug"]="$section_id"
    fi
done

# 序号：让 lesson_learned_01_xxx.md 这样有序
seq_num=0
declare -A SECTION_TO_FILE=()
declare -A SECTION_TO_NUM=()
for section_id in "${SECTION_ORDER[@]}"; do
    slug="${SECTION_TO_SLUG[$section_id]}"
    if [[ -z "$slug" ]]; then
        SECTION_TO_FILE["$section_id"]=""   # 不拆
        continue
    fi
    seq_num=$((seq_num + 1))
    fname="$(printf 'lesson_learned_%02d_%s.md' "$seq_num" "$slug")"
    SECTION_TO_FILE["$section_id"]="$fname"
    SECTION_TO_NUM["$section_id"]="$seq_num"
done

# 打印计划
printf "\n\033[1;36m[split] 拆分计划（%s）\033[0m\n" \
    "$([[ $APPLY -eq 1 ]] && echo "APPLY: 会实际写盘" || echo "DRY-RUN: 不写文件")"
printf "源文件: %s\n" "$SOURCE"
printf "%-4s  %-50s  %s\n" "第" "主题（## ...）" "→ 目标文件"
printf '%.0s-' {1..96}; printf '\n'
for section_id in "${SECTION_ORDER[@]}"; do
    heading="$(head -n 1 "$tmpdir/$section_id.section")"
    slug="${SECTION_TO_SLUG[$section_id]}"
    fname="${SECTION_TO_FILE[$section_id]}"
    if [[ -z "$slug" ]]; then
        printf "%-4s  %-50s  保留在 lesson_learned.md\n" "$section_id" "${heading:0:48}"
    else
        printf "%-4s  %-50s  %s\n" "$section_id" "${heading:0:48}" "$fname"
    fi
done

if (( APPLY == 0 )); then
    printf "\n\033[33m[split] 这是干跑。确认无冲突后用 --apply 真正执行。\033[0m\n"
    exit 0
fi

# 真写盘
new_main_lines="$tmpdir/_new_main"
{
    [[ -f "$tmpdir/_preamble" ]] && cat "$tmpdir/_preamble"
} > "$new_main_lines"

# 把不拆的章节继续留在主文件
for section_id in "${SECTION_ORDER[@]}"; do
    fname="${SECTION_TO_FILE[$section_id]}"
    if [[ -z "$fname" ]]; then
        cat "$tmpdir/$section_id.section" >> "$new_main_lines"
        echo >> "$new_main_lines"
    fi
done

# 在主文件最后加一段导航
{
    echo
    echo "---"
    echo
    echo "## 主题文件导航"
    echo
    echo "lesson_learned.md 已按主题拆分，详细经验请到对应文件查找："
    echo
    for section_id in "${SECTION_ORDER[@]}"; do
        fname="${SECTION_TO_FILE[$section_id]}"
        [[ -z "$fname" ]] && continue
        heading="$(head -n 1 "$tmpdir/$section_id.section")"
        title="${heading#\#\# }"
        echo "- [$title](./$fname)"
    done
} >> "$new_main_lines"

# 写出每个子文件
for section_id in "${SECTION_ORDER[@]}"; do
    fname="${SECTION_TO_FILE[$section_id]}"
    [[ -z "$fname" ]] && continue
    target="$REPO_ROOT/$fname"
    {
        echo "# Lessons Learned — $(head -n 1 "$tmpdir/$section_id.section" | sed 's/^## //')"
        echo
        echo "拆自 \`lesson_learned.md\`。新经验请合并到本文件已有 \`### 小节\`，避免按时间顺序追加。"
        echo
        # 跳过原 ## 标题那一行（避免和 H1 重复），其余原样保留
        tail -n +2 "$tmpdir/$section_id.section"
    } > "$target"
done

mv "$new_main_lines" "$SOURCE"

printf "\n\033[32m[split] 已写入：\033[0m\n"
for section_id in "${SECTION_ORDER[@]}"; do
    fname="${SECTION_TO_FILE[$section_id]}"
    [[ -z "$fname" ]] && continue
    lines="$(wc -l < "$REPO_ROOT/$fname")"
    printf "  %-50s  %4d 行\n" "$fname" "$lines"
done
printf "  %-50s  %4d 行  (重写)\n" "lesson_learned.md" "$(wc -l < "$SOURCE")"

printf "\n下一步：\n"
printf "  1. \033[36mbash .ai-collab/scripts/check.sh\033[0m  确认治理通过\n"
printf "  2. \033[36mgit add lesson_learned*.md && git commit\033[0m\n"
