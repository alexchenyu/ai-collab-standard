#!/usr/bin/env bash
# AI 协作文档治理 pre-commit hook
# 只在本次 commit 涉及协作文档时，运行 check.sh；硬失败时阻断 commit。
#
# 接入方式（二选一）：
#   A. 复制到 .git/hooks/pre-commit 并赋可执行权限
#        cp .ai-collab/scripts/pre-commit.sh .git/hooks/pre-commit
#        chmod +x .git/hooks/pre-commit
#   B. 让仓库 pre-commit 转发到本脚本（若项目已有 pre-commit 框架）
#        在 hook 中追加：bash .ai-collab/scripts/pre-commit.sh "$@"
#
# 绕过：git commit --no-verify （仅在明确必要时）
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# 1. 看本次 commit 的 staged 改动是否涉及协作文档
STAGED=$(git diff --cached --name-only 2>/dev/null || true)

NEED_CHECK=0
while IFS= read -r f; do
    case "$f" in
        CLAUDE.md|AGENTS.md|.cursorrules|lesson_learned.md|\
        lesson_learned_*.md|docs/PROJECT_STATUS.md|docs/ai-collab-doc-governance.md|\
        docs/ADR/*|**/AGENT.md|**/AGENTS.md)
            NEED_CHECK=1
            break
            ;;
    esac
done <<< "$STAGED"

if (( NEED_CHECK == 0 )); then
    exit 0
fi

printf "\n[ai-collab pre-commit] 本次改动涉及协作文档，运行健康检查...\n\n"

if [[ ! -x "$REPO_ROOT/.ai-collab/scripts/check.sh" ]]; then
    printf "\033[33m[ai-collab pre-commit] 找不到 .ai-collab/scripts/check.sh，跳过检查\033[0m\n"
    exit 0
fi

bash "$REPO_ROOT/.ai-collab/scripts/check.sh" "$REPO_ROOT"
RC=$?

if (( RC == 1 )); then
    printf "\n\033[31m[ai-collab pre-commit] 硬失败，commit 被阻断。\033[0m\n"
    printf "  修复上方 [FAIL] 项后重新 commit，或使用 git commit --no-verify 绕过（不推荐）。\n\n"
    exit 1
fi

if (( RC == 2 )); then
    printf "\n\033[33m[ai-collab pre-commit] 有软警告，但不阻断 commit；建议尽快处理。\033[0m\n\n"
fi

exit 0
