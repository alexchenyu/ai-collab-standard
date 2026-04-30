# {{PROJECT_NAME}} Glossary（共享语言）

> 项目内 jargon 的 canonical 词典。Agent 读任一文件遇到陌生术语先查这里，不要望文生义。
> 体积上限：**≤ 150 行**。术语只放"在 ≥ 2 份 lesson_learned / docs / 代码里复用"的；只在 1 处出现的留在原文。
> 每条格式：`**术语** — 一句话定义。锚点：xxx`。锚点指最权威的解释源（lesson 主题 / ADR / 代码模块）。

## TODO 分类

> 按本项目的实际领域切分章节，例如：检索链路 / 数据存储 / 模型 / 运维 / 评估 / 治理。
> 章节示例（按需删减）：

## 核心链路

- TODO: **核心术语 1** — 一句话定义。锚点：`docs/xxx.md` 或 `lesson_learned_xx.md` § 主题
- TODO: **核心术语 2** — 一句话定义。锚点：xxx

## 数据 / 存储

- TODO: 数据库表名 / 主键约定 / schema 名词
- TODO: 索引 / collection 命名规则

## 服务 / 模型

- TODO: 主要外部服务、模型、推理引擎名

## 治理 / 元

- **canonical source** — 一条信息的唯一权威出处。其它位置最多留一句"见 X"导航。锚点：`.ai-collab/docs/ai-collab-doc-governance.md`
- **行为约束层** — agent 行为规则（思考前 / 简洁优先 / 精准修改 / 目标驱动）。锚点：`.ai-collab/docs/ai-collab-agent-behavior.md`

---

**维护规则**：

- 加新条目前，先确认它在 ≥ 2 份文件里出现且会被复用；只在 1 处出现的留在原文。
- 锚点必须指向当前仍存在的文件 / 章节；目标文件被拆分或重命名时同步改这里。
- 体积超 150 行时按章节拆（如 `PROJECT_GLOSSARY_<topic>.md`），不要无限追加。
