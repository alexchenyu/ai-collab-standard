# AI 协作文档治理规范 (AI Collab Docs Standard)

一套用于规范和管理项目中 AI 协作文档（如 `CLAUDE.md`, `.cursorrules`, `AGENT.md`, `lesson_learned.md`, `docs/PROJECT_STATUS.md`, `docs/ADR/`）的通用模板、治理流程和自动化护栏。

包含两个正交维度：

- **信息治理**（`docs/ai-collab-doc-governance.md`）：信息放哪、怎么不膨胀、canonical source 怎么分配。
- **行为约束**（`docs/ai-collab-agent-behavior.md`）：agent 应该怎么思考与动手 —— 思考前 / 简洁优先 / 精准修改 / 目标驱动 / 临时工作记忆 / 自我学习。受 [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) 与 [devin.cursorrules](https://github.com/grapeot/devin.cursorrules) 启发，按本仓库实战经验扩展。

## 为什么需要这个

随着 AI 编码助手的普及，项目里往往会堆积大量的规则文件，导致：

- `CLAUDE.md` 越来越长，AI 抓不到重点
- `.cursorrules` 和 `CLAUDE.md` 内容重复
- 架构决策（ADR）和日常踩坑经验混在一起
- 具体数字（部署实例、数据规模、端口号）把稳定规则"染色"，每次刷数据都要改规则文件
- 临时 scratchpad / Lessons 被写进 `.cursorrules`，工具私有文件慢慢变成第二套长期记忆
- 可复用 agent 工具流程散落在规则长文里，而不是沉淀成 skills / runbook
- 不同项目之间的文档结构不统一

这套规范提供的是**分层治理 + 路由流程 + 自动化护栏**，而不仅仅是模板。

## 目录结构

```
.ai-collab/
├── README.md                        # 本文件
├── scripts/
│   ├── bootstrap.sh                  # 一行安装/更新入口（curl | bash）
│   ├── init_ai_collab_docs.sh       # 一键初始化/检查脚本（支持 --check --install-hook）
│   ├── check.sh                     # 治理健康检查（行数/重复/TODO/状态污染）
│   └── pre-commit.sh                # pre-commit hook，改到协作文档时自动跑 check.sh
├── skills/
│   └── task-scratchpad/             # Devin-style 本地短期工作记忆 skill
└── docs/
    ├── ai-collab-doc-governance.md            # 治理规范正文（信息维度）
    ├── ai-collab-doc-governance.template.md   # 治理规范（可渲染版）
    ├── ai-collab-agent-behavior.md            # Agent 行为约束（行为维度，canonical）
    ├── CLAUDE.template.md                     # CLAUDE.md 模板
    ├── AGENT.template.md                      # 目录级 AGENT.md 模板
    ├── cursorrules.template                   # .cursorrules 模板
    ├── lesson_learned.template.md             # lesson_learned.md 模板
    ├── PROJECT_STATUS.template.md             # 状态快照模板（数据规模/端口/实例数）
    ├── PROJECT_GLOSSARY.template.md           # 共享语言模板（项目术语词典）
    ├── ADR-000-template.md                    # 单份 ADR 模板
    └── ADR-README.template.md                 # ADR 索引模板
```

## canonical source 分配

| 信息类型 | 文件 | 体积上限 |
| ---- | ---- | ---- |
| Repo 级高频规则 | `CLAUDE.md` | ≤ 150 行 |
| **Agent 行为约束** | `.ai-collab/docs/ai-collab-agent-behavior.md` | ≤ 250 行 |
| **项目术语词典（共享语言）** | `docs/PROJECT_GLOSSARY.md` | ≤ 150 行 |
| 跨工具入口 | `AGENTS.md` | ≤ 15 行 |
| Cursor 极简提醒 | `.cursorrules` | ≤ 10 行 |
| 目录级 runbook | 各目录 `AGENT.md` | ≤ 80 行 |
| 当前有效经验 | `lesson_learned.md` | ≤ 600 行 |
| 当前状态快照 | `docs/PROJECT_STATUS.md` | ≤ 120 行 |
| 架构决策 | `docs/ADR/*.md` | 一决策一文件 |
| 临时任务工作记忆 | `.agent-scratchpad.local.md` / `.ai-collab/runtime/scratchpad.local.md` | 不进 git |
| 可复用 agent 能力 | `.cursor/skills/` + `.claude/skills` symlink；`.ai-collab/skills/` 提供内置能力 | 一个 skill 一个目录 |

**硬性规则：一条信息只能有一个 canonical source，其它位置最多留一句"见 X"导航。**

详见 [信息治理规范](docs/ai-collab-doc-governance.md) 与 [Agent 行为约束](docs/ai-collab-agent-behavior.md)。

## 使用指南

推荐作为 Git Submodule 引入到业务项目的 `.ai-collab/` 目录下。

### 1. 一行安装 / 更新（推荐）

在项目根目录运行：

```bash
curl -fsSL https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.sh | bash
```

这条命令会自动：

- 如果当前目录还不是 git repo，先 `git init`
- 新项目：添加 `.ai-collab` submodule
- 老项目：更新 `.ai-collab` 到远端默认分支（自动探测 `main` / `master`）
- 生成 / 更新协作文档入口
- 安装内置 skills（含 `task-scratchpad`）
- 安装 pre-commit hook
- 跑 `check.sh`

常用参数：

```bash
# 英文项目
curl -fsSL https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.sh | bash -s -- --lang en

# 显式指定项目名和目录级 runbook
curl -fsSL https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.sh | bash -s -- --project-name "My Project" --agent-dir backend --agent-dir frontend

# 启用 Codex skills
curl -fsSL https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.sh | bash -s -- --codex

# Windows PowerShell（无 bash / WSL 时）
iwr -useb https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.ps1 | iex
```

### 2. 手动引入 Submodule

```bash
git submodule add https://github.com/alexchenyu/ai-collab-standard.git .ai-collab
```

本地使用：`git -c protocol.file.allow=always submodule add /path/to/ai-collab-standard .ai-collab`

### 3. 一键初始化

自动探测目录结构（`backend / frontend / src / scripts` 等），生成对应文档：

```bash
bash .ai-collab/scripts/init_ai_collab_docs.sh . \
    --project-name "My Project" \
    --lang zh \
    --install-hook        # 顺便装 pre-commit hook
```

默认**安全模式**，不覆盖已有文件。想用新模板重置：加 `--force`。
只想看会改什么，不真改：加 `--dry-run`。

**额外行为**：init 脚本会把 `.ai-collab/skills/` 下的内置 skills 安装到目标项目 `.cursor/skills/`，默认包含 `task-scratchpad`，用于 Devin-style 本地短期工作记忆。随后脚本会创建 `.claude/skills` symlink 指向 `.cursor/skills`，让 Cursor 和 Claude Code 共用同一份 skills；若 `.gitignore` 把整个 `.claude/` ignore 了，会改写为 `.claude/* + !.claude/skills` 让 symlink 入版本控制。

Codex skills 兼容默认不开启，避免 Cursor 重复扫描多个 skills 路径。需要 Codex 也发现同一份 skills 时显式加：

```bash
bash .ai-collab/scripts/init_ai_collab_docs.sh . --enable-codex-skills
```

这会创建 `.codex/skills -> ../.cursor/skills`；`AGENTS.md` 仍作为 Codex 的薄入口，指向 canonical docs。

如果任务需要持久短期计划，使用 `task-scratchpad` skill 管理 `.agent-scratchpad.local.md`。任务结束后只把长期结论归档到 `lesson_learned.md` / ADR / `PROJECT_STATUS.md`，并清空或删除 scratchpad。

### 4. 填写项目特有内容

初始化生成的文件里有 TODO 占位符。先补全：

```bash
rg -n 'TODO' .
```

补完前，**不要把模板当 canonical source**。

### 5. 开启自动化护栏（强烈推荐）

```bash
# 独立安装 pre-commit hook
cp .ai-collab/scripts/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# 或一次性安装
bash .ai-collab/scripts/init_ai_collab_docs.sh . --install-hook
```

效果：任何时候 `git commit` 涉及 `CLAUDE.md / .cursorrules / lesson_learned.md / PROJECT_STATUS.md / AGENT*.md / docs/ADR/*` 改动，都会自动跑 `check.sh`，硬失败会阻断 commit。
绕过：`git commit --no-verify`（仅在明确必要时）。

### 6. 随时手动跑检查

```bash
bash .ai-collab/scripts/check.sh
# 或
bash .ai-collab/scripts/init_ai_collab_docs.sh --check
```

check.sh 会报告：

- 四大主文件行数 vs 上限
- `CLAUDE.md / .cursorrules` 是否混入状态快照数字
- 各文件 TODO 残留
- `lesson_learned.md` 单主题长度
- 本地 scratchpad 是否被 `.gitignore` 忽略
- `.ai-collab/skills/` 内置 skills 是否已安装到 `.cursor/skills/`
- Codex skills 是否在 opt-in 后正确指向 `.cursor/skills`
- 主文件间长行重复（canonical 冲突启发式）

退出码：
- `0`：全通过
- `1`：有硬失败（会阻断 commit）
- `2`：仅软警告（不阻断）

### 7. 持续更新

```bash
curl -fsSL https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.sh | bash

# 或手动更新（探测远端默认分支）：
git -C .ai-collab fetch origin
default_branch="$(git -C .ai-collab symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')"
git -C .ai-collab checkout "origin/${default_branch:-main}"
bash .ai-collab/scripts/init_ai_collab_docs.sh . --force  # 若要用新模板覆盖（谨慎）
```

## 新条目路由流程（核心，反膨胀）

```
新条目进来
 ├── 是"当前任务计划 / 进度 / 临时假设"？── 本地 scratchpad（不进 git）
 ├── 是"现在跑到哪了 / 数据多大 / 哪个端口"类？── PROJECT_STATUS.md
 ├── 是"为什么选 X 而不是 Y"？─────────────── docs/ADR/
 ├── 是"踩过的坑 / 排障结论"？─────────────── lesson_learned.md 对应主题下合并
 ├── 是"被用户纠正后的可复用经验"？────────── lesson_learned.md，不进 .cursorrules
 ├── 是"可复用 agent 工具 / 多步工作流"？──── 主动创建 / 更新 .cursor/skills/；目录特有则进 AGENT.md
 ├── 是"稳定规则且全仓库通用"？────────────── CLAUDE.md（优先改已有条目）
 ├── 是"稳定规则但只对某目录有效"？────────── 对应目录 AGENT.md
 ├── 是"Cursor 容易忘的一句话"？────────────  .cursorrules
 └── 都能放？──────────────────────────────── 默认放更深层，浅层只留一句导航
```

完整流程和合并/消重规则见 [治理规范](docs/ai-collab-doc-governance.md)。

## 最小治理原则（12 条）

1. `CLAUDE.md` 只放高频稳定规则，≤ 150 行。
2. 根级 `AGENTS.md` 只做跨工具指针，≤ 15 行。
3. `.cursorrules` 只放极少量持久提醒，≤ 10 行，开头明确"不是 canonical source"。
4. `AGENT.md` 只在目录存在独有 workflow 时才引入。
5. `lesson_learned.md` 只放当前仍有效的非显而易见经验，≤ 600 行，超过就拆。
6. `PROJECT_STATUS.md` 只放会定期刷新的状态快照，超过 4 周没变说明写错类别。
7. ADR 只记录架构决策和提案，不记录日常实现碎片。
8. 同一条事实只能有一个 canonical source，其它位置只能写一句导航。
9. 新条目先问"能不能改已有条目"，不能才新增。
10. Scratchpad 只做本地短期工作记忆，不进 git，不当 canonical source。
11. 发现适合 skill 化的可复用 agent 工具能力时，主动创建 / 更新 skill，不塞进 `.cursorrules`。
12. 高成本派生成果必须有持久化与失效策略，不能把"重跑"当默认路径。

## 维护

- 模板变更优先改 `docs/*.template.md` 和 `scripts/*.sh`；下游项目通过 `git submodule update --remote` 拉取。
- 变更治理规则请同步 `ai-collab-doc-governance.md` 和 `ai-collab-doc-governance.template.md`，两者保持内容一致。
- check.sh / pre-commit.sh 的行为阈值集中在 check.sh 顶部，修改时保持与治理规范对齐。
