# AI 协作文档分层治理（2026 跨工具标准）

> TL;DR
> **`AGENTS.md` 是 canonical**（项目级规则唯一真相），被 Codex/Cursor/Copilot/Windsurf/Amp/Devin 原生支持。
> `CLAUDE.md` 现在是 ≤30 行薄 stub，只放 Claude Code 专属内容并指回 AGENTS.md。
> Cursor 现代规则用 `.cursor/rules/*.mdc`（带 `alwaysApply` / `globs` frontmatter）；`.cursorrules` 已弃用（Agent 模式静默忽略）。
> 子目录用 `AGENTS.md`（复数），Codex/Cursor 在该目录工作时**自动叠加**加载。
> 当前经验放 `lesson_learned.md`，状态快照放 `docs/PROJECT_STATUS.md`，架构决策放 `docs/ADR/`，术语表放 `docs/PROJECT_GLOSSARY.md`。
> Codex 总预算：所有 AGENTS.md（根 + 递归）累加 ≤ 32 KiB（`project_doc_max_bytes` 默认值）。
> 当前任务计划放本地 scratchpad（不进 git），可复用工具能力封装成 `.cursor/skills/<name>/SKILL.md`。

这份文档定义当前项目里与 AI 协作相关的几类文档该怎么分工、怎么控制体积、什么内容该写到哪里，避免 `AGENTS.md`、`CLAUDE.md`、`.cursor/rules/`、子目录 `AGENTS.md`、`lesson_learned.md`、ADR 彼此重叠、持续长胖、最后没人敢改。

## 目标

- 让 agent 在 30 秒内知道"先看哪份文档"
- 让高频规则放在最短的地方，低频细节放到更深一层
- 减少重复维护，避免同一条规则同时出现在多个文件里
- 把"当前有效经验"、"历史决策记录"、"当前状态快照"分成三路，不互相污染
- 尽量兼容 Claude Code、Cursor、Codex，而不是把唯一真相锁死在某个工具专属文件里
- 给 agent 留短期工作记忆入口，但防止临时计划污染长期规则
- 把可复用工具能力注册成 skills / runbook，而不是写成长规则
- 把高成本派生成果当工程资产管理，避免 agent 每次都从头重算

## 跨工具兼容原则

- 共享事实写在普通 Markdown 文档里，尽量不要只写在某个工具私有文件中。
- 工具专属文件只做"薄入口"和少量高价值提醒，不做唯一真相来源。
- 出现同一条规则时，必须有一个 canonical source，其它文件只做引用或压缩版提醒。

当前建议的 canonical source 分配（2026 跨工具标准）：

| 信息类型 | Canonical Source | 谁读它 |
| ---- | ---- | ---- |
| **Repo 级高频规则** | **`AGENTS.md`** | Codex / Cursor / Copilot / Windsurf / Amp / Devin |
| Claude Code 专属补丁 | `CLAUDE.md`（≤ 30 行薄 stub，指回 AGENTS.md） | Claude Code |
| Cursor `alwaysApply` 注入 | `.cursor/rules/00-core.mdc`（≤ 60 行薄指针，指回 AGENTS.md） | Cursor (Agent / Composer / Chat) |
| 子目录局部 runbook | 各目录 `AGENTS.md`（复数，递归自动加载） | Codex / Cursor 在该目录工作时 |
| 当前有效经验 | `lesson_learned.md`（按主题；超过 600 行拆分） | 引用即可 |
| 当前状态快照（数据规模 / 端口 / 实例 / 版本） | `docs/PROJECT_STATUS.md` | 引用即可 |
| 项目术语词典（共享语言） | `docs/PROJECT_GLOSSARY.md` | 引用即可 |
| 架构决策 | `docs/ADR/*.md` + `docs/ADR/README.md` | 引用即可 |
| 临时任务工作记忆 | `.agent-scratchpad.local.md` 或 `.ai-collab/runtime/scratchpad.local.md`（不进 git） | 仅 agent 自己 |
| 可复用 agent 工具 / 工作流 | `.cursor/skills/`，并通过 `.claude/skills` symlink 共享；`.ai-collab/skills/` 提供内置 skill | Cursor + Claude Code |
| **已废弃** | ~~`.cursorrules`~~（Cursor Agent 模式静默忽略） | — |

核心原则：**一条信息只能有一个 canonical source。其它位置如果要引用，只能写"见 X"形式的一句话导航；禁止把同一条结论复制两份。** AGENTS.md 是默认入口；只有真正属于某个工具的特化（例如 Claude Code 的 `/agents` 子代理参数）才进 CLAUDE.md / `.cursor/rules/`。

## 分层结论

| 文件 | 作用 | 应该放什么 | 不该放什么 | 建议体积 |
|------|------|-----------|-----------|---------|
| `AGENTS.md` (根) | **canonical**：仓库级最高频执行规则（跨工具入口） | 全局硬约束、目录、常用命令、稳定选型（向量库 / LLM / 主框架）、行为约定 | 历史背景、长解释、提案、重复细节、会变的数字 / 端口 / 实例数 / 版本号 | **≤ 200 行 / ≤ 8 KiB**；含递归子目录后总和 ≤ 32 KiB（Codex 预算） |
| `CLAUDE.md` | Claude Code 桩文件，指回 AGENTS.md | "Read AGENTS.md first" + Claude Code 专属补丁（如 `/agents` 子代理参数） | 项目级规则正文（属于 AGENTS.md）、状态数字、ADR 内容 | **≤ 30 行** |
| `.cursor/rules/00-core.mdc` | Cursor `alwaysApply` 指针 | YAML frontmatter (alwaysApply / description / globs) + 一句话指向 AGENTS.md / behavior 文档 | 项目级规则正文（属于 AGENTS.md）、长段说明（Cursor `alwaysApply` 是每会话 token 预算） | **≤ 60 行**（≈ 2K token） |
| `<dir>/AGENTS.md`（子目录） | 目录级 runbook，Codex/Cursor 在该目录工作时**自动叠加** | 某个子目录独有的入口、命令、坑、交付约束 | 全仓库通用规则（属于根 AGENTS.md）、架构历史 | 每个文件尽量 **< 80 行** |
| `.cursorrules` | **已废弃**（Cursor Agent 模式静默忽略） | — | 任何内容；存在的只能是 `.cursorrules.legacy.bak` | — |
| `lesson_learned.md` | 当前仍有效的非显而易见经验库 | 边界条件、跨模块契约、排障结论、维护经验；按主题组织 | 提案、时间线流水账、已 ADR 化的历史摘要、状态快照 | **≤ 600 行**；超过 350 行先重组章节，超过 600 行按主题拆为独立文件 |
| `docs/PROJECT_STATUS.md` | 当前状态快照 | 部署状态、数据规模、端口、硬件分配、已知容量 / 限流 | 稳定选型、历史演进、架构决策、经验教训 | **≤ 120 行**，以表格为主 |
| `docs/ADR/*.md` | 架构决策记录 | 为什么这么设计、替代方案、状态、影响范围 | 高频执行规则、实现碎片、临时排障笔记 | 一决策一文件 |
| `docs/ADR/README.md` | ADR 索引 | 状态总览、导航、维护规则 | 每份 ADR 的大段摘要 | 纯索引页 |
| `.agent-scratchpad.local.md` / `.ai-collab/runtime/scratchpad.local.md` | 当前任务短期工作记忆 | 当前任务计划、进度、临时假设、下一步检查点 | 稳定规则、经验教训、架构决策、状态快照、任何需要提交的内容 | 不进 git；任务结束清空或归档结论 |
| `.cursor/skills/` | 可复用 agent 能力注册层 | 多步工作流、固定工具调用、复杂排障 runbook、可重复执行的能力说明 | 项目事实唯一真相、临时任务计划、长篇历史记录 | 一个 skill 一个目录 |
| `.ai-collab/skills/` | 标准内置 skills 分发源 | 可随 submodule 分发的通用 agent 能力，如 `task-scratchpad` | 项目私有事实、业务专用流程 | init 时安装到 `.cursor/skills/` |

## 新条目路由流程（防漏水）

每次想往协作文档里加内容时，按这张判定树走；任何一步判错都会立刻让多份文档重新开始膨胀。

```
新条目进来
 ├── 是"当前任务计划 / 进度 / 临时假设"？
 │     └─► 本地 scratchpad（不进 git；任务结束清空或归档结论）
 ├── 是"现在跑到哪了 / 数据多大 / 哪个端口" 类？
 │     └─► docs/PROJECT_STATUS.md（绝对不要进 CLAUDE.md）
 ├── 是"为什么我们选了 X 而不是 Y"？
 │     └─► docs/ADR/NNN-*.md（lesson_learned.md 不记决策过程）
 ├── 是"踩过的坑 / 边界条件 / 排障结论"？
 │     └─► lesson_learned.md 对应主题下合并（新增主题要经过评审）
 ├── 是"被用户纠正后，以后大概率还会复用的经验"？
 │     └─► lesson_learned.md 对应主题；不要写进 .cursor/rules/*.mdc
 ├── 是"可重复使用的工具能力 / 多步工作流"？
 │     └─► 主动创建 / 更新 .cursor/skills/；目录特有则进对应目录 AGENTS.md；浅层文档只留入口
 ├── 是"所有 agent 每次都要知道"的稳定规则？
 │     ├── 属于某个子目录独有？── 是 ──► 对应目录 AGENTS.md
 │     └── 全仓库通用？────────── 是 ──► AGENTS.md（优先改已有条目，不要新增段落）
 ├── 是"Cursor 专属且需要自动注入的一句话提醒"？
 │     └─► .cursor/rules/<name>.mdc（带 frontmatter，保持短小）
 └── 看起来都能放？── 默认放更深层，浅层只留一句导航
```

**硬性规则：**

- 同一条事实只能有一个 canonical source。其它文件最多写一句"详见 X"的指针。
- 在入口规则文件（`AGENTS.md` / `CLAUDE.md` / `.cursor/rules/*.mdc`）里写具体数字（如 "491K vectors"）永远是错的；数字进 `PROJECT_STATUS.md`。
- 在入口规则文件里写"我们修过的 bug 具体怎么修"永远是错的；修复结论进 `lesson_learned.md`。
- 在 `lesson_learned.md` 里写"我们打算未来怎么搞"永远是错的；提案进 `docs/ADR/`。
- 在 `.cursor/rules/*.mdc` 里维护 scratchpad / Lessons / 工具手册永远是错的；scratchpad 本地化，Lessons 进 `lesson_learned.md`，工具进 skills / runbook。

## 合并与消重流程（反膨胀）

新条目落地前必须问的四个问题，缺一不可：

1. **已有条目能不能改而不是新增？** 优先编辑现有段落。
2. **本条内容有没有和其它文档重叠？** 如有，在 canonical source 里保留完整版，其它位置改为单行导航。
3. **本条内容会不会在 3 个月后过期？** 会 ──► 进 `PROJECT_STATUS.md` 或 ADR 的"后果"小节；不会 ──► 才能进 `CLAUDE.md` / `lesson_learned.md`。
4. **本条内容删掉后，agent 出错概率会不会明显上升？** 不会 ──► 不要加。

压缩信号（主动触发压缩）：

- `CLAUDE.md` ≥ 150 行：停止新增，先合并 / 下沉
- `.cursor/rules/00-core.mdc` ≥ 60 行：停止新增，先下沉到 `AGENTS.md` / `lesson_learned.md` / skills
- `lesson_learned.md` 单主题 ≥ 80 行或总行数 ≥ 600：拆文件
- 在 `CLAUDE.md` 发现状态快照类数字：立即迁到 `PROJECT_STATUS.md`
- 在两份文件里发现同一条规则：只保留 canonical source 的那一份

## 临时工作记忆（Scratchpad）

Scratchpad 只解决"当前任务怎么推进"的问题，不解决"项目长期应该记住什么"的问题。

推荐路径：

- `.agent-scratchpad.local.md`：单 agent / 单项目的本地工作记忆。
- `.ai-collab/runtime/scratchpad.local.md`：如果项目已有 `.ai-collab/runtime/` 管理运行时协作状态，用这个路径。

使用规则：

- 必须进 `.gitignore`；默认不提交、不引用、不作为 canonical source。
- 只记录当前任务计划、进度、临时假设、待验证点。
- 任务结束后，把仍有长期价值的结论按路由迁移到 `lesson_learned.md` / ADR / `PROJECT_STATUS.md`，然后清空或删除 scratchpad。
- 不要把 scratchpad 放进 `.cursor/rules/*.mdc`、`CLAUDE.md`、`AGENTS.md`。
- 引入 `.ai-collab` 后，`init_ai_collab_docs.sh` 会安装内置 `task-scratchpad` skill，用它管理 scratchpad 生命周期。

## 自我学习流程（Self-Evolution）

当用户纠正 agent、agent 修复自己犯过的错，或发现非显而易见的维护经验时，按这条路径处理：

1. 先判断是否可复用：未来同类任务是否大概率再次遇到？
2. 不可复用：只在当前对话说明，不写入协作文档。
3. 可复用但低频：合并进 `lesson_learned.md` 对应主题，优先改已有条目。
4. 高频且高风险：先写 `lesson_learned.md`，再评估是否提升为 `CLAUDE.md` 的高频稳定规则。
5. 已经被 ADR 固化或规则吸收的 lesson，应从 `lesson_learned.md` 删除或压缩为导航。

禁止路径：用户纠正 → 直接追加到 `.cursor/rules/*.mdc` 或 legacy `.cursorrules`。这会让工具私有文件变成第二套长期记忆。

## 工具 / 能力注册层

复杂但可复用的 agent 能力，不应该写成长段自然语言规则；应该封装成可发现、可执行、可维护的能力入口。

适合进入 `.cursor/skills/`：

- 固定多步流程（如排障循环、数据流水线、PR 拆分）
- 需要多条命令或工具配合的 workflow
- 需要携带示例、脚本、资源文件的 agent 能力
- 跨 Cursor / Claude Code 都需要复用的操作手册

治理规则：

- 一个 skill 一个目录，入口是 `SKILL.md`。
- `.ai-collab/skills/` 是标准内置 skill 分发源；`init_ai_collab_docs.sh` 会把这些 skills 安装到目标项目 `.cursor/skills/`。
- Agent 在实现过程中发现适合 skill 化的重复工作流时，默认应直接创建或更新 skill，而不是只在总结里建议。
- 只有当 skill 需要新增依赖、写入不确定的项目政策、或会引入大范围结构调整时，才先问用户。
- 根文档只写"有什么能力、从哪里进"，不要复制 skill 正文。
- 如果项目已有 `.cursor/skills/`，应通过 `.claude/skills -> ../.cursor/skills` symlink 让 Claude Code 读到同一份内容。
- Codex skills 兼容必须 opt-in：只有显式运行 `init_ai_collab_docs.sh --enable-codex-skills` 时，才创建 `.codex/skills -> ../.cursor/skills`，避免 Cursor 重复扫描多份 skill。
- 特定目录的工具约束仍可写进该目录 `AGENTS.md`；全仓库通用工具能力优先做 skill。

## 定期回顾流程

每次做重大版本收口或季度回顾时，按这个顺序跑一遍：

1. `bash .ai-collab/scripts/check.sh`（行数 / TODO 残留 / 重复指针自检）
2. 人工扫读 `CLAUDE.md`，把"最近一次还用到过这条规则"无法立刻答出的条目挪到 `lesson_learned.md` 或删除。
3. 人工扫读 `lesson_learned.md`，把已失效经验删掉；已被 ADR 固化的摘要删掉；长主题考虑拆文件。
4. 检查 `PROJECT_STATUS.md` 是否真的是最新的；如果超过 1 个月没动，找出现在到底谁在负责。
5. 清理本地 scratchpad：仍有效的结论完成归档，其余删除。
6. 检查 `.cursor/skills/` 与 `.claude/skills` 是否仍指向同一份能力入口；若项目启用了 Codex skills，也检查 `.codex/skills` symlink。

## 高成本派生成果治理

以下内容不是"算完即弃"的临时中间态，而是默认应持久化的工程资产：

- `embedding` 向量
- chunk JSON / parse result / normalized markdown
- LLM 抽取出的结构化字段
- 批量任务的 progress / manifest / `--skip-existing` 状态

治理规则：

- 只要结果来自高计算成本、外部限流、长耗时流程，或非完全稳定的模型输出，默认必须落盘并可复用。
- 持久化时至少记录 `source identity`（路径 / hash / mtime）和 `generator identity`（模型 / 版本 / 参数 / prompt / schema version）。
- 默认优先复用已有结果；只有输入变化、生成契约变化，或显式 `--force` 时才重算。
- `--incremental` / `--skip-existing` / progress file 不能只信任单一信号，至少要和真实输出文件或已写入结果交叉校验。
- 不要把"GPU 很快"或"API 还能打"当作不落盘的理由；重复计算会同时放大成本、时间和结果漂移。
- 敏感原文、密钥或不该长期保存的上下文不要无脑落盘；优先保存派生结果和最小必要元数据。

## 按任务类型的最短读取顺序

- 服务或目录级 bugfix：`AGENTS.md` → 对应目录的 `AGENTS.md` → `lesson_learned.md` 对应章节 → 相关 ADR
- chunk / embedding / ingest 调优：`AGENTS.md` → 对应专题文档 → `lesson_learned.md` 对应章节 → 相关目录 runbook / ADR
- 当前部署排障：`docs/PROJECT_STATUS.md` → 对应目录 `AGENTS.md` → `lesson_learned.md` 对应章节
- 纯文档治理：`AGENTS.md` → 本文 → `docs/ADR/README.md`（若涉及架构决策）→ 相关专题文档

## 各文件优化策略

### `CLAUDE.md`

保留原则：

- 只做 Claude Code 专属 stub，默认指回 `AGENTS.md`
- 只有 Claude Code 独有能力或限制才写进这里
- **不放项目级规则、状态数字、历史经验**——这些分别进 `AGENTS.md`、`PROJECT_STATUS.md`、`lesson_learned.md`

推荐结构：

1. 声明 `AGENTS.md` 是 canonical source
2. 让 Claude Code 先读 `AGENTS.md` / 行为治理文档
3. Claude Code 专属补充（没有就写"暂无"）

触发精简信号：

- 文件超过 30 行
- 文件开始复述 `AGENTS.md`
- 文件开始出现状态数字、历史演进、提案或排障细节

### `AGENTS.md`

- 它是跨工具入口和 repo 级规则 canonical source。
- 放全仓库高频硬约束、文档索引、核心目录、稳定技术选型、常用命令。
- 不放状态数字、排障流水账、ADR 摘要、临时计划。
- 根文件建议 ≤ 200 行 / ≤ 8 KiB；含递归子目录 `AGENTS.md` 总和 ≤ 32 KiB。

### `.cursor/rules/*.mdc`

- 它不是第二份 `AGENTS.md`，只是 Cursor 的规则注入层。
- `00-core.mdc` 应该是 `alwaysApply: true` 的薄指针，指向 `AGENTS.md` 和行为治理文档。
- 其它 `.mdc` 只放 Cursor 专属、可用 `globs` 或 `alwaysApply` frontmatter 精准控制的提醒。
- 不做 scratchpad，不维护 Lessons，不写工具手册，不承载项目规则唯一真相。

适合写入：默认语言、极少数 Cursor 容易忘的一句话提醒、稳定的文档分层入口、Cursor 专属交互约束

不适合写入：整段架构说明、长列表代码规范、ADR 摘要、scratchpad、Lessons、工具说明、只有特定工具能看到的重要规则正文、具体数字 / 端口 / 实例数

### `.cursorrules`

- 已废弃；Cursor Agent 模式静默忽略。
- 新项目不生成；旧项目只能在迁移期保留为 `.cursorrules.legacy.bak`。
- 迁移时把仍有效且 Cursor 专属的短提醒搬到 `.cursor/rules/*.mdc`，其余按路由进 `AGENTS.md` / `lesson_learned.md` / skills。

### `.cursor/skills/`

- 它是 agent 能力注册层，不是项目事实库。
- skill 适合封装"怎么做一类事"，不适合保存"这个项目现在是什么状态"。
- 如果 skill 里引用项目规则，只写指针，不复制 `CLAUDE.md` / `lesson_learned.md` 正文。
- 跨工具共享时优先用 symlink，避免 Cursor / Claude Code / Codex 读到两份漂移的 skill；Codex symlink 默认不开，按需 opt-in。

### `<dir>/AGENTS.md`

- 只管当前目录，不复述 repo 级规则
- 内容聚焦：入口文件、核心命令、不能碰的边界、提交流程、常见坑
- 只有目录真的有独有 workflow 时才引入
- 带 `TODO` 的模板文件不算已落地规范，也不应被当作 canonical source；首次引入后应尽快补全真实入口、命令、测试和边界

### `lesson_learned.md`

- 只记录"未来大概率还会再次派上用场"的东西
- 按主题组织，不按时间顺序追加
- 如果某条已经进入 `CLAUDE.md` 或 ADR，就从这里删掉
- 不记录项目当前状态（数据规模、端口）——那是 `PROJECT_STATUS.md` 的事

拆分阈值：

- 超过 350 行：先重组章节
- 超过 600 行：按主题拆为独立文件（如 `lesson_learned_search.md`）

### `PROJECT_STATUS.md`

- 只记录定期刷新的状态；稳定选型不进来
- 如果超过 4 周无变化，说明你把规则当状态写了，得搬走
- 优先用表格表达，便于扫读
- 主动维护 "最近更新" 日期，哪怕只是确认没变

### ADR

- ADR 记录的是"为什么"，不是"怎么把代码每一行都实现了"
- 一条 ADR 一个主决策；复杂决策可以在文内拆子决策
- 状态要明确：`提议`、`已采纳`、`已落地`、`已废弃`

## 反模式

- 在 `CLAUDE.md` 里堆实现细节，最后变成长手册
- 在 `CLAUDE.md` 里塞具体数字（数据规模、端口、实例数），每次刷新都要改一大段
- 在 `.cursor/rules/*.mdc` 里复制半份 `AGENTS.md`
- 在 `.cursor/rules/*.mdc` 或 legacy `.cursorrules` 里维护 Scratchpad / Lessons / 工具手册
- 在 `lesson_learned.md` 里维护 ADR 摘要和未来提案
- 在 `lesson_learned.md` 里放部署现状
- 新建一个全仓库 `AGENT.md`（单数），结果内容和 `AGENTS.md` 高度重复
- ADR 索引页重新长成第二套 ADR 全文
- 把可复用的多步工具流程写成规则长文，而不是 skill / runbook
- 默认重算 `embedding` / chunk / parse result，而不是先复用已有产物

## 最小治理规则

如果只保留 12 条元规则，我建议是这 12 条：

1. 根级 `AGENTS.md` 是 repo 级 canonical source，≤ 200 行 / ≤ 8 KiB。
2. `CLAUDE.md` 只做 Claude Code stub，≤ 30 行。
3. `.cursor/rules/00-core.mdc` 只做 Cursor `alwaysApply` 薄指针，≤ 60 行；不再使用 `.cursorrules`。
4. 子目录 `AGENTS.md` 只在目录存在独有 workflow 时才引入。
5. `lesson_learned.md` 只放当前仍有效的非显而易见经验，超过 600 行就拆文件。
6. `PROJECT_STATUS.md` 只放定期刷新的状态快照，超过 4 周没变就说明写错类别了。
7. ADR 只记录架构决策和提案，不记录日常实现碎片。
8. 同一条事实只能有一个 canonical source，其它位置最多写一句导航。
9. 新条目先问"能不能改已有条目"，不能才新增。
10. Scratchpad 只做本地短期工作记忆，不进 git，不当 canonical source。
11. 发现适合 skill 化的可复用 agent 工具能力时，主动创建 / 更新 skill，不塞进 `.cursor/rules/*.mdc`。
12. 高成本派生成果必须有持久化与失效策略，不能把"重跑"当默认路径。
