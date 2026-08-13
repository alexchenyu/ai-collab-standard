# {{PROJECT_NAME}} — Quality Gates 清单

> 本文件回答一个问题：**每个质量维度，现在有没有确定性约束（gate）、在哪一层、多严、逃生舱是什么。**
> Agent 的提案能否落地由 gate 决定，不由 prose 规则 + agent 自觉决定（行为规则 R11）。
> 新增可机检的必守规则时，先建 gate 再写文档指针；见 `.ai-collab/docs/ai-collab-doc-governance.md` § 新条目路由流程。

## 当前 gate 清单

| Gate | 阶段 | 质量维度 | 硬/软 | 逃生舱 |
| ---- | ---- | ---- | ---- | ---- |
| shell-guard hook（`cursor-shell-guard-hook.sh`，Cursor `beforeShellExecution`） | edit-time | 环境纪律（默认 R6 uv-only） | 硬（deny） | 项目根 `.ai-collab-shell-deny.txt` 覆盖/清空模式 |
| doc-check hook（`cursor-doc-check-hook.sh`，Cursor `afterFileEdit`） | edit-time | 文档治理 | 软（只报告，不阻断） | — |
| pre-commit `check.sh` / `check_ai_collab_docs.py` | commit | 文档治理（行数 / 预算 / canonical 冲突） | 硬（阻断 commit） | `AI_COLLAB_ALLOW_*=1`（写入 bypass 账本） |
| TODO: `make lint`（或等价 lint 命令） | commit / CI | 风格 + 静态正确性 | 硬 | — |
| TODO: `make test`（或等价测试命令） | CI | 正确性 | 硬 | — |

## 尚未覆盖的维度（显式裸奔清单）

> 没 gate 的维度不是不存在，是裸奔。留在这里让它可见；补上后移入上表。

| 维度 | 现状 | 候选 gate |
| ---- | ---- | ---- |
| 正确性深度 | 仅常规测试 | mutation testing（如 mutmut）/ property tests（如 hypothesis） |
| 安全 | TODO | secret 扫描 / 依赖漏洞扫描（CI 层） |
| 性能 | TODO | 关键路径基准测试 + 回归阈值 |
| 复杂度 / 可读性 | TODO | 圈复杂度 / 函数长度阈值（lint 层） |

## 维护规则

- 每个**硬 gate 必须有逃生舱**，且逃生舱使用必须留痕（`.ai-collab/runtime/bypass.log`）；没有逃生舱的硬 gate 只会教会大家 `--no-verify`。
- 调紧 / 调松任何 gate 都是 deliberate decision：改这里的表 + 改对应脚本常量，一起提交。
- 定期回顾（见治理文档 § 定期回顾流程）读 bypass 账本：同一 gate 被绕 ≥3 次 → 正式调宽或修根因。
- 本文件只登记 gate（是什么、在哪层、多严），不放 gate 的实现细节和排障经验——那些进脚本注释和 `lesson_learned*.md`。
