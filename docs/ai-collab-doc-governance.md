# AI 协作文档分层治理

> TL;DR
> `CLAUDE.md` 放 repo 级主规则，`AGENTS.md` 只做跨 agent 入口。
> 目录细节放目录级 `AGENT.md`，当前经验放 `lesson_learned.md`。
> 架构决策放 `docs/ADR/`，`.cursorrules` 只留 Cursor 专属极简提醒。
> 任何工具私有文件都不应成为唯一真相源。
> `embedding`、chunk JSON、解析结果这类高成本派生成果默认要落盘并复用，不把“重跑”当默认路径。

这份文档定义当前项目里与 AI 协作相关的几类文档该怎么分工、怎么控制体积、什么内容该写到哪里，避免 `CLAUDE.md`、`.cursorrules`、`AGENT.md`、`lesson_learned.md`、ADR 彼此重叠、持续长胖、最后没人敢改。

## 目标

- 让 agent 在 30 秒内知道“先看哪份文档”
- 让高频规则放在最短的地方，低频细节放到更深一层
- 减少重复维护，避免同一条规则同时出现在多个文件里
- 把“当前有效经验”和“历史决策记录”分开
- 尽量兼容 Claude Code、Cursor、Codex，而不是把唯一真相锁死在某个工具专属文件里
- 把高成本派生成果当工程资产管理，避免 agent 每次都从头重算

## 跨工具兼容原则

不同 agent / IDE 对规则文件的发现机制并不完全一致，所以这套文档要遵守一个原则：

- 共享事实写在普通 Markdown 文档里，尽量不要只写在某个工具私有文件中。
- 工具专属文件只做“薄入口”和少量高价值提醒，不做唯一真相来源。
- 出现同一条规则时，必须有一个 canonical source，其它文件只做引用或压缩版提醒。

当前建议的 canonical source 分配：

- repo 级高频规则：`CLAUDE.md`
- 根级兼容入口：`AGENTS.md`（仅指针，不承载正文）
- 目录级局部 runbook：各目录的 `AGENT.md`
- 当前有效经验：`lesson_learned.md`
- 架构决策：`docs/ADR/*.md` + `docs/ADR/README.md`
- 工具特定提醒：`.cursorrules`

对 `.cursorrules` 的额外要求：

- 它应被当作 Cursor 专属提醒层，而不是主规范。
- 能放进 `CLAUDE.md` / `AGENT.md` / `lesson_learned.md` / ADR 的正文，不要只放在 `.cursorrules`。
- 推荐长期保持在 3-5 条，最好不超过 10 行正文。

## 分层结论

| 文件 | 作用 | 应该放什么 | 不该放什么 | 建议体积 |
|------|------|-----------|-----------|---------|
| `CLAUDE.md` | 仓库级最高频执行规则 | 全局硬约束、目录、常用命令、最关键的行为约定 | 历史背景、长解释、提案、重复细节 | 1-2 屏，可快速扫完 |
| `AGENTS.md` | 根级跨工具入口 | 3-6 行指针，指向 canonical docs | 规则正文、目录级细节、重复手册 | 3-6 行 |
| `.cursorrules` | Cursor 持久提醒层 | 极少量、必须长期记住的补充提醒 | 成段规范、完整手册、和 `CLAUDE.md` 大段重复 | 3-5 条最佳 |
| `AGENT.md` / `AGENTS.md` | 目录级或场景级 runbook | 某个子目录独有的入口、命令、坑、交付约束 | 全仓库通用规则、架构历史、和 `CLAUDE.md` 重复内容 | 每个文件尽量 < 80 行，且尽量通用 |
| `lesson_learned.md` | 当前仍有效的非显而易见经验库 | 边界条件、跨模块契约、排障结论、维护经验 | 提案、时间线流水账、已 ADR 化的历史摘要 | 按主题组织，超过 250 行就拆 |
| `docs/ADR/*.md` | 架构决策记录 | 为什么这么设计、替代方案、状态、影响范围 | 高频执行规则、实现碎片、临时排障笔记 | 一决策一文件 |
| `docs/ADR/README.md` | ADR 索引 | 状态总览、导航、维护规则 | 每份 ADR 的大段摘要 | 纯索引页 |

## 路由规则

新信息进仓库前，先问 6 个问题：

1. 这是所有 agent 几乎每次都需要知道的吗？
   是：写 `CLAUDE.md`
2. 这是给不同 agent 一个统一入口、但不想复制正文吗？
   是：写根级 `AGENTS.md`
3. 这是 Cursor/agent 很容易忘、但只需要一句话提醒的吗？
   是：写 `.cursorrules`
4. 这是某个目录或子系统特有的操作方式吗？
   是：写对应目录的 `AGENT.md` / `AGENTS.md`
5. 这是当前仍然有效、但不够高频的实现细节或边界经验吗？
   是：写 `lesson_learned.md`
6. 这是一个“为什么这么设计”的架构选择或提案吗？
   是：写 ADR

如果同一条内容能同时被放进两个地方，默认放更深层，浅层只留一句导航。

## 高成本派生成果治理

以下内容不是“算完即弃”的临时中间态，而是默认应持久化的工程资产：

- `embedding` 向量
- chunk JSON / parse result / normalized markdown
- LLM 抽取出的结构化字段
- 批量任务的 progress / manifest / `--skip-existing` 状态

治理规则：

- 只要结果来自高计算成本、外部限流、长耗时流程，或非完全稳定的模型输出，默认必须落盘并可复用。
- 持久化时至少记录 `source identity`（路径 / hash / mtime）和 `generator identity`（模型 / 版本 / 参数 / prompt / schema version）。
- 默认优先复用已有结果；只有输入变化、生成契约变化，或显式 `--force` 时才重算。
- `--incremental` / `--skip-existing` / progress file 不能只信任单一信号，至少要和真实输出文件或已写入结果交叉校验。
- 不要把“GPU 很快”或“API 还能打”当作不落盘的理由；重复计算会同时放大成本、时间和结果漂移。
- 敏感原文、密钥或不该长期保存的上下文不要无脑落盘；优先保存派生结果和最小必要元数据。

## 按任务类型的最短读取顺序

- 服务或目录级 bugfix：`CLAUDE.md` → 对应目录的 `AGENT.md` → `lesson_learned.md` 对应章节 → 相关 ADR
- chunk / embedding / ingest 调优：`CLAUDE.md` → 对应专题文档 → `lesson_learned.md` 对应章节 → 相关目录 runbook / ADR
- 纯文档治理：`CLAUDE.md` → 本文 → `docs/ADR/README.md`（若涉及架构决策）→ 相关专题文档

## 各文件优化策略

### `CLAUDE.md`

保留原则：

- 只保留高频、稳定、直接影响执行正确性的规则
- 优先写“必须怎样做”，少写背景和解释
- 每条都应该经得住“删掉它会不会明显增加出错率”这个测试

推荐结构：

1. 项目一句话说明
2. 协作约定
3. 核心目录
4. 常用命令
5. 核心约束
6. 代码约定

触发精简信号：

- 新增一条规则时，需要先看是否能并入已有条目
- 出现 3 条以上“只是例子或边角说明”的子弹点时，该下沉到 `lesson_learned.md`
- 文件开始出现“历史演进 / 提案 / 讨论”时，说明已经写串层了

### `.cursorrules`

保留原则：

- 它不是第二份 `CLAUDE.md`
- 只写最短、最不该忘、最跨会话的提醒
- 每条尽量是一句能直接执行的话
- 它不是 canonical source，只是 Cursor 的超薄提醒层

适合写入的内容：

- 默认语言
- 某个反复犯错的修正结论
- 某个稳定的文档分层约定

不适合写入的内容：

- 一整段架构说明
- 长列表代码规范
- ADR 摘要
- 只有 Cursor 才能看到、其它 agent 看不到的重要规则正文

### 根级 `AGENTS.md`

保留原则：

- 它是跨工具入口，不是第二份 `CLAUDE.md`
- 只负责把 agent 指到真正的 canonical docs
- 长期保持在 3-6 行，最好一眼扫完

适合写入的内容：

- `CLAUDE.md`
- 某个关键目录的 `AGENT.md`
- 其它目录级 `AGENT.md`
- `lesson_learned.md`
- `docs/ADR/README.md`

不适合写入的内容：

- repo 级规则正文
- 目录级 runbook 正文
- 任何和其它文件重复的大段说明

### `AGENT.md` / `AGENTS.md`

当前仓库已经有目录级这层时，继续保持“按需引入”，不要为了对称性再建一个重复全仓库规则的根 `AGENT.md` 空壳。

什么时候该加：

- 某个目录开始拥有明显不同的运行方式、测试方式、风险点
- 某个目录需要 agent 在进入时立刻知道独有约束
- 多 agent 协作或固定工作流需要局部 runbook

推荐做法：

- 优先用目录级 `AGENT.md`，不要先搞一个重复全仓库规则的根 `AGENT.md`
- 一份 `AGENT.md` 只管当前目录，不复述 repo 级规则
- 内容聚焦：入口文件、核心命令、不能碰的边界、提交流程、常见坑
- 如果未来需要兼容更多 agent，可接受同时提供 `AGENT.md` / `AGENTS.md` 之一作为入口，但正文仍应尽量指向同一套 canonical docs，而不是复制两份
- 带 `TODO` 的模板文件不算已落地规范，也不应被当作 canonical source；首次引入后应尽快补全真实入口、命令、测试和边界

推荐模板：

````md
# `<subsystem>/` Agent Guide

## 你在这里主要做什么

- 本目录的核心职责和交付边界

## 进入前先知道

- 不能破坏的局部约束
- 最关键的联动提醒

## 常用命令

```bash
uv run pytest tests/test_xxx.py
```

## 改动后必查

- `tests/test_xxx.py`
- 相关联动文件
````

### `lesson_learned.md`

保留原则：

- 只记录“未来大概率还会再次派上用场”的东西
- 重点记录非显而易见的边界，而不是代码表面事实
- 按主题组织，不按时间顺序追加

适合写入的内容：

- 某个字段为什么必须全链路贯穿
- 某个 fallback 为什么不能删
- 某个过滤逻辑的真实边界
- 某个评测或线上事故的可复用结论
- 某类高成本派生成果的 cache key / invalidation 策略

不适合写入的内容：

- “某天做了什么”式开发日志
- 已经进入 ADR 的架构摘要
- 完整 API 清单

建议拆分阈值：

- 超过 250 行：先重组章节
- 超过 350 行：考虑拆为 `lesson_learned_runtime_memory.md`、`lesson_learned_search.md` 之类的主题文件

### ADR

保留原则：

- ADR 记录的是“为什么”，不是“怎么把代码每一行都实现了”
- 一条 ADR 一个主决策；复杂决策可以在文内拆子决策
- 状态要明确：`提议`、`已采纳`、`已落地`、`已废弃`

当前建议：

- 统一使用 `docs/ADR/000-template.md`
- `docs/ADR/README.md` 只做导航，不再写整本 ADR 总结
- 旧 ADR 如果还保留提案语气，可以暂时接受，但顶部状态必须明确

## 反模式

- 在 `CLAUDE.md` 里堆实现细节，最后变成长手册
- 在 `.cursorrules` 里复制半份 `CLAUDE.md`
- 在 `lesson_learned.md` 里维护 ADR 摘要和未来提案
- 新建一个全仓库 `AGENT.md`，结果内容和 `CLAUDE.md` 高度重复
- ADR 索引页重新长成第二套 ADR 全文
- 默认重算 `embedding` / chunk / parse result，而不是先复用已有产物

## 对接入项目的默认建议

- `CLAUDE.md`：保持“短主文件”，只放高频全局规则
- `.cursorrules`：压到 3-5 条，只保留语言和极少数高价值纠错记忆
- 根级 `AGENTS.md`：允许存在，但只保留 3-6 行跨工具指针
- `AGENT.md`：保留现有目录级 `AGENT.md`；暂时不要在仓库根目录再建重复版
- `lesson_learned.md`：只保留当前有效经验，不回填 ADR 摘要
- `docs/ADR/README.md`：保持纯索引
- `docs/ADR/000-template.md`：作为唯一模板源
- 对 `embedding`、chunk、解析、抽取这类高成本结果：默认落盘并复用，只有输入或生成契约变化时才重算

## 推荐维护流程

每次想往这些文档里加内容时，按这个顺序判断：

1. 这是规则、经验还是决策？
2. 这是 repo 级、目录级，还是实现级？
3. 这是高频信息还是低频信息？
4. 这条内容会不会和现有文件重复？
5. 能不能先改已有条目，而不是新增新段落？

## 最小治理规则

如果只保留 7 条元规则，我建议是这 7 条：

1. `CLAUDE.md` 只放高频稳定规则。
2. 根级 `AGENTS.md` 只做跨工具指针，不承载正文。
3. `.cursorrules` 只放极少量持久提醒。
4. `AGENT.md` 只在目录存在独有 workflow 时才引入。
5. `lesson_learned.md` 只放当前仍有效的非显而易见经验。
6. ADR 只记录架构决策和提案，不记录日常实现碎片。
7. 高成本派生成果必须有持久化与失效策略，不能把“重跑”当默认路径。
