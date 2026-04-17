# AI 协作文档治理规范 (AI Collab Docs Standard)

一套用于规范和管理项目中 AI 协作文档（如 `CLAUDE.md`, `.cursorrules`, `AGENT.md`, `lesson_learned.md`, `docs/PROJECT_STATUS.md`, `docs/ADR/`）的通用模板、治理流程和自动化护栏。

## 为什么需要这个

随着 AI 编码助手的普及，项目里往往会堆积大量的规则文件，导致：

- `CLAUDE.md` 越来越长，AI 抓不到重点
- `.cursorrules` 和 `CLAUDE.md` 内容重复
- 架构决策（ADR）和日常踩坑经验混在一起
- 具体数字（部署实例、数据规模、端口号）把稳定规则"染色"，每次刷数据都要改规则文件
- 不同项目之间的文档结构不统一

这套规范提供的是**分层治理 + 路由流程 + 自动化护栏**，而不仅仅是模板。

## 目录结构

```
.ai-collab/
├── README.md                        # 本文件
├── scripts/
│   ├── init_ai_collab_docs.sh       # 一键初始化/检查脚本（支持 --check --install-hook）
│   ├── check.sh                     # 治理健康检查（行数/重复/TODO/状态污染）
│   └── pre-commit.sh                # pre-commit hook，改到协作文档时自动跑 check.sh
└── docs/
    ├── ai-collab-doc-governance.md            # 治理规范正文
    ├── ai-collab-doc-governance.template.md   # 治理规范（可渲染版）
    ├── CLAUDE.template.md                     # CLAUDE.md 模板
    ├── AGENT.template.md                      # 目录级 AGENT.md 模板
    ├── cursorrules.template                   # .cursorrules 模板
    ├── lesson_learned.template.md             # lesson_learned.md 模板
    ├── PROJECT_STATUS.template.md             # 状态快照模板（数据规模/端口/实例数）
    ├── ADR-000-template.md                    # 单份 ADR 模板
    └── ADR-README.template.md                 # ADR 索引模板
```

## 四类文件的 canonical source 分配

| 信息类型 | 文件 | 体积上限 |
| ---- | ---- | ---- |
| Repo 级高频规则 | `CLAUDE.md` | ≤ 150 行 |
| 跨工具入口 | `AGENTS.md` | ≤ 15 行 |
| Cursor 极简提醒 | `.cursorrules` | ≤ 10 行 |
| 目录级 runbook | 各目录 `AGENT.md` | ≤ 80 行 |
| 当前有效经验 | `lesson_learned.md` | ≤ 600 行 |
| 当前状态快照 | `docs/PROJECT_STATUS.md` | ≤ 120 行 |
| 架构决策 | `docs/ADR/*.md` | 一决策一文件 |

**硬性规则：一条信息只能有一个 canonical source，其它位置最多留一句"见 X"导航。**

详见 [治理规范](docs/ai-collab-doc-governance.md)。

## 使用指南

推荐作为 Git Submodule 引入到业务项目的 `.ai-collab/` 目录下。

### 1. 引入 Submodule

```bash
git submodule add https://github.com/your-org/ai-collab-standard.git .ai-collab
```

本地使用：`git -c protocol.file.allow=always submodule add /path/to/ai-collab-standard .ai-collab`

### 2. 一键初始化

自动探测目录结构（`backend / frontend / src / scripts` 等），生成对应文档：

```bash
bash .ai-collab/scripts/init_ai_collab_docs.sh . \
    --project-name "My Project" \
    --lang zh \
    --install-hook        # 顺便装 pre-commit hook
```

默认**安全模式**，不覆盖已有文件。想用新模板重置：加 `--force`。
只想看会改什么，不真改：加 `--dry-run`。

### 3. 填写项目特有内容

初始化生成的文件里有 TODO 占位符。先补全：

```bash
rg -n 'TODO' .
```

补完前，**不要把模板当 canonical source**。

### 4. 开启自动化护栏（强烈推荐）

```bash
# 独立安装 pre-commit hook
cp .ai-collab/scripts/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# 或一次性安装
bash .ai-collab/scripts/init_ai_collab_docs.sh . --install-hook
```

效果：任何时候 `git commit` 涉及 `CLAUDE.md / .cursorrules / lesson_learned.md / PROJECT_STATUS.md / AGENT*.md / docs/ADR/*` 改动，都会自动跑 `check.sh`，硬失败会阻断 commit。
绕过：`git commit --no-verify`（仅在明确必要时）。

### 5. 随时手动跑检查

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
- 主文件间长行重复（canonical 冲突启发式）

退出码：
- `0`：全通过
- `1`：有硬失败（会阻断 commit）
- `2`：仅软警告（不阻断）

### 6. 持续更新

```bash
git submodule update --remote                  # 拉最新模板和治理规范
bash .ai-collab/scripts/init_ai_collab_docs.sh . --force  # 若要用新模板覆盖（谨慎）
```

## 新条目路由流程（核心，反膨胀）

```
新条目进来
 ├── 是"现在跑到哪了 / 数据多大 / 哪个端口"类？── PROJECT_STATUS.md
 ├── 是"为什么选 X 而不是 Y"？─────────────── docs/ADR/
 ├── 是"踩过的坑 / 排障结论"？─────────────── lesson_learned.md 对应主题下合并
 ├── 是"稳定规则且全仓库通用"？────────────── CLAUDE.md（优先改已有条目）
 ├── 是"稳定规则但只对某目录有效"？────────── 对应目录 AGENT.md
 ├── 是"Cursor 容易忘的一句话"？────────────  .cursorrules
 └── 都能放？──────────────────────────────── 默认放更深层，浅层只留一句导航
```

完整流程和合并/消重规则见 [治理规范](docs/ai-collab-doc-governance.md)。

## 最小治理原则（10 条）

1. `CLAUDE.md` 只放高频稳定规则，≤ 150 行。
2. 根级 `AGENTS.md` 只做跨工具指针，≤ 15 行。
3. `.cursorrules` 只放极少量持久提醒，≤ 10 行，开头明确"不是 canonical source"。
4. `AGENT.md` 只在目录存在独有 workflow 时才引入。
5. `lesson_learned.md` 只放当前仍有效的非显而易见经验，≤ 600 行，超过就拆。
6. `PROJECT_STATUS.md` 只放会定期刷新的状态快照，超过 4 周没变说明写错类别。
7. ADR 只记录架构决策和提案，不记录日常实现碎片。
8. 同一条事实只能有一个 canonical source，其它位置只能写一句导航。
9. 新条目先问"能不能改已有条目"，不能才新增。
10. 高成本派生成果必须有持久化与失效策略，不能把"重跑"当默认路径。

## 维护

- 模板变更优先改 `docs/*.template.md` 和 `scripts/*.sh`；下游项目通过 `git submodule update --remote` 拉取。
- 变更治理规则请同步 `ai-collab-doc-governance.md` 和 `ai-collab-doc-governance.template.md`，两者保持内容一致。
- check.sh / pre-commit.sh 的行为阈值集中在 check.sh 顶部，修改时保持与治理规范对齐。
