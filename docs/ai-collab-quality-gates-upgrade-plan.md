# Quality Gates 升级计划（prose 规则 → 机器约束）

> **Status:** 已实施（2026-08-13，P0–P3 全部落地）
> **Origin:** [Agentic Code Quality — Addy Osmani, 2026-08](https://x.com/addyosmani/article/2087427868343373919)
> **Scope:** `.ai-collab` 标准本身的升级；实施后随 submodule 分发到所有下游项目。
> 实施完成后本文件应删除或压缩为 CHANGELOG 条目——计划文档不是长期 canonical source。

## 背景与差距

文章核心论点：agent 时代的代码质量不靠"人读每一行"，靠三件事——

1. **确定性约束（quality gates）**决定 agent 的提案能否落地，而不是 prose 规则 + agent 自觉；
2. **Back-pressure 贯穿全流程**（edit-time → commit → CI），越早越好，不要堆到管道末端；
3. **人类注意力是稀缺资源**，只导向 gate 判不了的主观问题（taste / intent / architecture）；gate 能判的不消耗人。

对照 `.ai-collab` 现状：

| | 现状 | 差距 |
|---|---|---|
| 文档治理维度 | ✅ 已是 gate 形态：`check.sh` 确定性检查 + pre-commit 阻断 + Cursor `afterFileEdit` hook + `AI_COLLAB_ALLOW_*` 逃生舱 | — |
| 行为约束 R1–R10 | ❌ 全是 prose，靠 agent 自觉。R6（uv-only）完全可机检却停在文字层 | P0-1 |
| 逃生舱使用 | ❌ 无留痕。"降低质量 bar"静默发生，违反"调松约束必须 deliberate" | P0-2 |
| 约束面全景 | ❌ 各 gate 散在 check.sh 注释 / hooks.json / 项目 Makefile，没人能 30 秒回答"哪个质量维度裸奔" | P1 |
| 规则演化方向 | ❌ 路由树只会把经验路由成更多 prose（lesson / Rn），没有 "prose→gate 棘轮" | P2 |
| Gate 可观测性 | ❌ check.sh 只有人读的彩色输出，无法追踪失败率 / 绕过率趋势 | P3 |

## P0：可机检的 prose 规则降级为机器 gate

### P0-1 shell-guard hook（强制 R6 uv-only）

- 新增 `scripts/cursor-shell-guard-hook.sh`（~60 行 bash）：
  - 读 stdin JSON 的 `command` 字段；
  - 命中裸 `pip install` / `pip3 install` / 行首 `python ` / `python3 `（排除 `uv run python` / `uv pip`）时输出
    `{"permission":"deny","userMessage":"R6: use uv run python / uv add (see ai-collab-agent-behavior.md R6)"}`；
  - 未命中输出 `{"permission":"allow"}`；任何解析失败一律 allow（fail-open，hook 不能阻断正常工作）；
  - denylist 模式可被项目根 `.ai-collab-shell-deny.txt` 覆盖（一行一个 ERE；非 Python 项目可清空或换成别的纪律）。
- `templates/cursor-hooks.json.template` 增加：

```json
"beforeShellExecution": [
  { "command": "bash .ai-collab/scripts/cursor-shell-guard-hook.sh" }
]
```

- `init_ai_collab_docs.sh --install-cursor-hook` 同步安装；已有 hooks.json 的项目提示手动合并（现有"不覆盖用户 hooks.json"的原则不变）。
- 验证：`bash -n`；手工喂 `{"command":"pip install foo"}` 期望 deny，`{"command":"uv run python x.py"}` 期望 allow。

### P0-2 逃生舱留痕（bypass ledger）

- `check_ai_collab_docs.py` 与 `check.sh`：检测到任一 `AI_COLLAB_ALLOW_*=1` 生效时，追加一行到 `.ai-collab/runtime/bypass.log`：

```
2026-08-13T21:40:12Z AI_COLLAB_ALLOW_LONG_AGENTS AGENTS.md 259/250
```

- `runtime/` 已在 gitignore 治理范围内，不进版本控制。
- `ai-collab-doc-governance.md`"定期回顾流程"追加第 7 步：扫 `bypass.log`；同一 gate 被绕 ≥3 次 → 要么正式调宽上限（改 check.sh 常量，deliberate），要么查根因。绝不允许"一直绕着走"成为常态。

## P1：Quality Gates Manifest（宣言式约束清单）

- 新增 `docs/QUALITY_GATES.template.md`；`init_ai_collab_docs.sh` 安装为下游项目 `docs/QUALITY_GATES.md`（用户内容文件，永不被 `--force` 覆盖）。
- 内容为一张表，回答"每个质量维度：有没有 gate、在哪一层、多严、逃生舱是什么"：

| Gate | 阶段 | 质量维度 | 硬/软 | 逃生舱 |
|---|---|---|---|---|
| shell-guard hook | edit-time | 环境纪律 | 硬 | 改 `.ai-collab-shell-deny.txt` |
| doc-check hook | edit-time | 文档治理 | 软（不阻断） | — |
| pre-commit `check.sh` | commit | 文档治理 | 硬 | `AI_COLLAB_ALLOW_*`（留痕） |
| `make lint` | commit/CI | 风格+正确性 | 硬 | — |
| `make test` / `test-fast` | CI | 正确性 | 硬 | — |
| mutation testing / property tests | CI | 正确性深度 | （建议，未启用） | — |

- 模板同时列"未覆盖维度"占位行（性能 / 安全扫描 / 复杂度阈值），让裸奔的维度显式可见，而不是不存在。
- 根 `AGENTS.md` 模板的文档索引加一行指针：`| 质量约束清单 | docs/QUALITY_GATES.md |`。

## P2：治理文档写入 "prose→gate 棘轮"

三处文档修改（governance 正文与 `.template.md` 镜像同步）：

1. **`ai-collab-doc-governance.md` 路由树新分支**：

```
├── 是"可机器判定的必守规则"？
│     └─► 写成 gate（hook / check.sh 检查项 / lint 规则），文档只留一句指针；
│         prose 版规则视为 gate 建成前的临时态
```

2. **自我学习流程追加第 6 步**：同一条 lesson 被违反 ≥2 次且可机检 → 升级为 gate，原 prose 压缩为指向 gate 的一句导航。防"lesson 越写越长但 agent 照犯"。

3. **`ai-collab-agent-behavior.md` 新增 R11**：

   > **R11. Machine-checkable rules must become gates.** 新增 Rn 或 lesson 前先问：能否写成 hook / check / lint？能则实现 gate，prose 只留指针。同时 R10 的 Reviewer 角色明确接 gate：reviewer 第一步跑 gates（`check.sh` + 项目 lint/test），全绿才进入人工 diff 审读；gate 能判的不消耗人的注意力。

## P3（可选，后做）：Gate 可观测性

- `check.sh --json`：输出 `{"passed":N,"warns":[...],"fails":[...]}` 结构化结果（~40 行）。
- 配合 `bypass.log`，季度回顾可回答：哪个 gate 失败率最高（调松或修根因）、哪个从不失败（太松或无用）。文章的 "scale verification vs. lower the bar" 决策需要数据支撑。

## 明确不做（Non-Goals）

- **不把 `.ai-collab` 变成 CI 框架。** mutation testing、property tests、复杂度阈值属于各项目自己的 Makefile/CI；`.ai-collab` 只提供元层：manifest 模板 + hook 胶水 + prose→gate 棘轮规则。
- **不给 `afterFileEdit` 加自动跑 ruff/pytest。** Cursor agent 本身会跑 lint，hook 重复跑是噪音；edit-time back-pressure 由 shell-guard（拦坏命令）承担。
- **不新增阻断型 gate 而不带逃生舱。** 每个硬 gate 必须有带留痕的 bypass 路径，否则用户只会 `--no-verify` 全绕。

## 实施顺序与验收

| 步骤 | 交付物 | 体量 | 验收 |
|---|---|---|---|
| 1. P0-1 | `cursor-shell-guard-hook.sh` + template + init 接线 | ~60 行 bash + 5 行 | 手工喂 JSON：pip → deny，uv → allow；`bash -n` 通过 |
| 2. P0-2 | 两个 check 脚本的 bypass 留痕 + 回顾流程第 7 步 | ~20 行 | 设 `AI_COLLAB_ALLOW_LONG_AGENTS=1` 提交超长文件 → `bypass.log` 出现记录 |
| 3. P2 | 路由树分支 + 自我学习第 6 步 + R11（正文与 template 镜像同步） | ~30 行 prose | `check.sh` 全通过；governance 正文与 template 无语义漂移 |
| 4. P1 | `QUALITY_GATES.template.md` + init 安装 + AGENTS.md 模板指针 | ~80 行 | 新项目 init 后生成 `docs/QUALITY_GATES.md`；`--force` 不覆盖已有文件 |
| 5. P3 | `check.sh --json` | ~40 行 | `check.sh --json \| jq .` 可解析；人读输出不变 |

全程走 `ai-collab-standard-maintenance` skill 流程（改 canonical → 同步 template 镜像 → `bash -n` → `check.sh` 验证），单独 `feat/quality-gates` 分支，在 `.ai-collab` 上游仓库提 PR 后由父仓库 `git submodule update --remote --merge` 收编。
