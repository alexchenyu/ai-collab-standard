# AI 协作文档治理规范 (AI Collab Docs Standard)

一套用于规范和管理项目中 AI 协作文档（`AGENTS.md`、`CLAUDE.md`、`.cursor/rules/*.mdc`、`lesson_learned.md`、`docs/ADR/` 等）的通用模板、治理流程和自动化护栏。**遵循 2026 年跨工具事实标准**：AGENTS.md 作为 canonical（被 Codex、Cursor、GitHub Copilot、Windsurf、Amp、Devin 等原生支持），其它文件作为薄入口或工具特化补丁。

包含两个正交维度：

- **信息治理**（`docs/ai-collab-doc-governance.md`）：信息放哪、怎么不膨胀、canonical source 怎么分配。
- **行为约束**（`docs/ai-collab-agent-behavior.md`）：agent 应该怎么思考与动手 —— 思考前 / 简洁优先 / 精准修改 / 目标驱动 / 临时工作记忆 / 自我学习。受 [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) 与 [devin.cursorrules](https://github.com/grapeot/devin.cursorrules) 启发，按本仓库实战经验扩展。

## 为什么需要这个

随着 AI 编码助手的普及，项目里往往会堆积大量的规则文件，导致：

- 每个工具都有自己的规则文件（`.cursorrules` / `CLAUDE.md` / `AGENTS.md` / `.codex/...`），互相重复
- `.cursorrules` 在 Cursor Agent 模式下被静默忽略 —— 用户经常不知道
- 子目录 `AGENT.md`（单数）不被 Codex/Cursor 递归自动加载，被当作普通 Markdown 漏掉
- canonical source 散落在不同工具私有文件中，agent 切换工具就丢上下文
- 临时 scratchpad / Lessons 被写进规则文件，工具私有文件慢慢变成第二套长期记忆
- 可复用 agent 工具流程散落在规则长文里，而不是沉淀成 skills / runbook

这套规范提供的是**分层治理 + 路由流程 + 自动化护栏**，按 2026 行业标准统一架构。

## 新架构（2026 跨工具标准）

| 文件 | 角色 | 谁读它 | 体积 |
|------|------|--------|------|
| `AGENTS.md` | **canonical**（项目级规则唯一真相） | Codex / Cursor / Copilot / Windsurf / Amp / Devin | ≤ 200 行 / ≤ 8 KiB |
| `CLAUDE.md` | Claude Code 桩文件（指向 AGENTS.md） | Claude Code | ≤ 30 行 |
| `.cursor/rules/00-core.mdc` | Cursor `alwaysApply` 指针 | Cursor (Agent 模式) | ≤ 60 行 |
| `<dir>/AGENTS.md` | 子目录 runbook（递归自动加载） | Codex / Cursor 在该目录工作时 | ≤ 80 行 |
| `lesson_learned.md` | 当前有效经验 | 引用即可 | ≤ 600 行 |
| `docs/PROJECT_GLOSSARY.md` | 共享术语 | 引用即可 | ≤ 150 行 |
| `docs/PROJECT_STATUS.md` | 状态快照（数字 / 端口 / 实例） | 引用即可 | ≤ 120 行 |
| `docs/ADR/*.md` | 架构决策 | 引用即可 | 一决策一文件 |
| `.cursor/skills/` (+ `.claude/skills` symlink) | Agent skills | Cursor + Claude Code | 一 skill 一目录 |

**Codex 总预算**：所有 AGENTS.md（根 + 递归子目录）累加 ≤ 32 KiB（默认 `project_doc_max_bytes`），超出 Codex 会截断深层文件。可在 `~/.codex/config.toml` 调高。

**`.cursorrules` 已弃用**：Cursor Agent 模式静默忽略它。本仓库不再生成；旧项目用 `--migrate-legacy` 迁移。

## 目录结构

```
.ai-collab/
├── README.md                        # 本文件
├── .gitattributes                   # 强制 LF（跨 Windows / Mac / Linux）
├── scripts/
│   ├── bootstrap.sh                 # 一行 curl | bash 入口（Linux / Mac）
│   ├── bootstrap.ps1                # Windows PowerShell 入口
│   ├── init_ai_collab_docs.sh       # 初始化 / 检查 / 迁移
│   ├── check.sh                     # 治理健康检查
│   ├── check_ai_collab_docs.py      # Python 轻量 pre-commit gate
│   ├── install_hooks.sh             # 装 Python pre-commit hook
│   ├── pre-commit.sh                # Bash pre-commit hook（跑 check.sh）
│   └── split_lesson.sh              # 自动拆分 lesson_learned.md
├── skills/
│   └── task-scratchpad/             # Devin-style 本地短期工作记忆 skill
└── docs/
    ├── ai-collab-doc-governance.md           # 治理规范（canonical）
    ├── ai-collab-doc-governance.template.md  # 治理规范（可分发模板）
    ├── ai-collab-agent-behavior.md           # Agent 行为约束（canonical）
    ├── AGENTS.template.md                    # 根 AGENTS.md 模板（canonical）
    ├── CLAUDE.template.md                    # Claude Code 桩模板
    ├── cursor-rule-core.mdc.template         # Cursor alwaysApply 模板
    ├── AGENTS-subdir.template.md             # 子目录 AGENTS.md 模板
    ├── lesson_learned.template.md            # lesson_learned.md 模板
    ├── PROJECT_STATUS.template.md            # 状态快照模板
    ├── PROJECT_GLOSSARY.template.md          # 共享语言模板
    ├── ADR-000-template.md                   # 单份 ADR 模板
    └── ADR-README.template.md                # ADR 索引模板
```

## 跨平台 / 跨工具兼容性

- **OS**：Linux / macOS / Windows（Git Bash / WSL / 原生 PowerShell）。
  - macOS 默认 bash 3.2 不支持 `declare -A`；脚本顶部有版本守卫，提示 `brew install bash`。
  - Windows 默认 `ln -s` 不可用；`init_ai_collab_docs.sh` 自动 fallback 到 `cp -R` 并提示。
  - `.gitattributes` 强制所有文本文件 LF，避免 autocrlf 破坏 shell 脚本。
- **AI 工具**：
  - **Codex CLI**：原生读 `AGENTS.md`（递归 + 全局 `~/.codex/AGENTS.md`，32 KiB 总预算）。
  - **Cursor**：原生读 `AGENTS.md` + `.cursor/rules/*.mdc`（`.cursorrules` legacy）。
  - **Claude Code**：读 `CLAUDE.md`；本架构让 CLAUDE.md 主动指向 AGENTS.md，避免双套真相。
  - **GitHub Copilot / Windsurf / Amp / Devin**：原生读 AGENTS.md。

## 使用指南

推荐作为 Git Submodule 引入到业务项目的 `.ai-collab/` 目录下。

> **生产项目导入前先 pin 一个 reviewed commit。** `bootstrap.sh` / `git submodule add`
> 会拿到当时的上游 HEAD，但真正的可复现边界是父仓库提交里的 submodule gitlink。
> 如果上游文档或脚本需要本地修正，先 fork，再把 `.ai-collab` 指向 fork 和已审核的 commit。
>
> ```bash
> git submodule add https://github.com/alexchenyu/ai-collab-standard.git .ai-collab
> git -C .ai-collab checkout <reviewed-commit-sha>
> # 如需 fork：
> git submodule set-url .ai-collab git@github.com:<org>/ai-collab-standard.git
> git add .gitmodules .ai-collab
> git commit -m "chore: pin ai-collab standard"
> ```

> **新 contributor clone 已配置好的项目时**：git 不会自动跑任何脚本（安全设计）。
> 必须在**父仓库根目录**手动一次性执行下面的命令 —— **不是在 `.ai-collab/` 子目录里跑**（之后都是增量）。
>
> 自检：跑命令前先 `ls .ai-collab/scripts/install_hooks.sh`，能列出文件说明你在正确的目录。
>
> **Linux / macOS / Git for Windows bash**：
>
> ```bash
> git pull                                       # 1. 拉父仓库（带上 submodule pointer 更新）
> git submodule update --init --recursive        # 2. 同步子模块到父记录的 SHA
> bash .ai-collab/scripts/install_hooks.sh .     # 3. 装 pre-commit hook（一次性，幂等）
> bash .ai-collab/scripts/check.sh               # 4. 健康检查，应输出"全部通过"
> ```
>
> 注意：**不要进 `.ai-collab/` 里跑 `git pull`**。submodule 默认是 detached HEAD，`git pull` 会报 "not currently on a branch"。要升级 submodule，在父仓库根目录跑 `git submodule update --remote --merge .ai-collab`。
>
> **Windows PowerShell**（推荐先装 Git for Windows，自带 bash）：
>
> ```powershell
> git pull
> git submodule update --init --recursive
> bash .ai-collab/scripts/install_hooks.sh .   # 调用 Git for Windows 自带的 bash
> bash .ai-collab/scripts/check.sh
> ```
>
> 前置依赖：`git` + `bash`（Linux/macOS 自带；Windows 装 Git for Windows）+ `python3` 或 `uv`（pre-commit 运行时需要）。
>
> 推荐把这一段写进**业务项目根目录的 `AGENTS.md` 顶部**（本仓库的 `AGENTS.template.md` 已带这段，用 `bootstrap.sh` / `bootstrap.ps1` 新建项目时自动继承）。

### 1. 一行安装 / 更新

**Linux / macOS / Git Bash**：

```bash
curl -fsSL https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.sh | bash
```

**Windows PowerShell**：

```powershell
iwr -useb https://raw.githubusercontent.com/alexchenyu/ai-collab-standard/main/scripts/bootstrap.ps1 | iex
```

bootstrap 会自动：

- 如果当前目录还不是 git repo，先 `git init`
- 新项目：添加 `.ai-collab` submodule
- 老项目：更新 `.ai-collab` 到远端默认分支（自动探测 `main` / `master`）
- 生成 / 更新协作文档入口（AGENTS.md / CLAUDE.md / .cursor/rules/00-core.mdc / 子目录 AGENTS.md）
- 安装内置 skills（含 `task-scratchpad`）和 `.claude/skills` symlink
- 安装 pre-commit hook
- 跑 `check.sh`

常用参数：

```bash
# 英文项目
curl -fsSL .../bootstrap.sh | bash -s -- --lang en

# 显式指定项目名和子目录 runbook
curl -fsSL .../bootstrap.sh | bash -s -- --project-name "My Project" --agent-dir backend --agent-dir frontend

# 启用 Codex skills（.codex/skills -> ../.cursor/skills）
curl -fsSL .../bootstrap.sh | bash -s -- --codex
```

### 2. 从旧版本迁移

如果你的项目已经用 `.ai-collab` 但还是旧架构（CLAUDE.md canonical / 子目录 AGENT.md / `.cursorrules`），运行：

```bash
bash .ai-collab/scripts/init_ai_collab_docs.sh . --migrate-legacy --force
```

`--migrate-legacy` 会：
- 把 `.cursorrules` 重命名为 `.cursorrules.legacy.bak`（你需手动按类型迁到 `AGENTS.md` / `lesson_learned.md` / skills / `.cursor/rules/*.mdc`）
- 把所有子目录 `AGENT.md` 重命名为 `AGENTS.md`
- 检测过长 CLAUDE.md 并提示把内容迁到 AGENTS.md

详细迁移步骤见 [`MIGRATION.md`](./MIGRATION.md)。

### 3. 手动初始化

```bash
git submodule add https://github.com/alexchenyu/ai-collab-standard.git .ai-collab
bash .ai-collab/scripts/init_ai_collab_docs.sh . \
    --project-name "My Project" \
    --lang zh \
    --install-hook
```

默认**安全模式**，不覆盖已有文件。想用新模板重置：加 `--force`。
只想看会改什么，不真改：加 `--dry-run`。

### 4. 填写项目特有内容

```bash
rg -n 'TODO' .
```

补完前，**不要把模板当 canonical source**。

### 5. 持续更新

```bash
curl -fsSL .../bootstrap.sh | bash

# 或手动：
git -C .ai-collab fetch origin
default_branch="$(git -C .ai-collab symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')"
git -C .ai-collab checkout "origin/${default_branch:-main}"
bash .ai-collab/scripts/init_ai_collab_docs.sh . --force  # 用新模板覆盖（谨慎）
```

### 6. 健康检查

```bash
bash .ai-collab/scripts/check.sh
```

包含 14 类检查：行数 / TODO 残留 / 状态污染 / lesson 主题长度 / 子目录 AGENTS.md 迁移 / Cursor MDC alwaysApply / 旧 `.cursorrules` 残留 / Codex 32 KiB 预算 / CLAUDE.md 桩文件 / 行为约束指针 / 共享语言锚点 / Skills 符号链接 / Codex skills opt-in / 本地 scratchpad / 跨文件重复。

退出码：`0` 全过 / `1` 硬失败（pre-commit 阻断）/ `2` 仅软警告。

## Codex 高级用法

- **个人全局**：`~/.codex/AGENTS.md` 写跨项目偏好（≤ 2-3 KB）。
- **临时调试**：项目同级 `AGENTS.override.md` —— 替换语义（不是叠加）。
- **预算调整**：`~/.codex/config.toml`：

```toml
project_doc_max_bytes = 65536    # 升到 64 KiB
project_doc_fallback_filenames = ["CLAUDE.md", "CONTRIBUTING.md"]
```

加 `CLAUDE.md` 到 fallback 后，Codex 也会读 Claude 桩文件（一般不需要，因为本架构 CLAUDE.md 只是指针）。

## 新条目路由流程（核心，反膨胀）

```
新条目进来
 ├── "当前任务计划 / 进度 / 临时假设"？──── 本地 scratchpad（不进 git）
 ├── "现在跑到哪了 / 数据多大 / 哪个端口"？─ docs/PROJECT_STATUS.md
 ├── "为什么选 X 而不是 Y"？──────────────── docs/ADR/
 ├── "踩过的坑 / 排障结论"？──────────────── lesson_learned.md 对应主题
 ├── "被用户纠正后的可复用经验"？─────────── lesson_learned.md（不进任何规则文件）
 ├── "可复用 agent 工具 / 多步工作流"？──── .cursor/skills/<name>/SKILL.md
 ├── "稳定规则且全仓库通用"？──────────────── AGENTS.md（canonical，优先改已有条目）
 ├── "稳定规则但只对某目录有效"？─────────── 对应目录 AGENTS.md（递归加载）
 ├── "Claude Code 才会用到的特殊配置"？──── CLAUDE.md
 ├── "Cursor 极薄提醒（≤2K token）"？──── .cursor/rules/00-core.mdc 或新增 .mdc
 └── 都能放？──────────────────────────────── 默认放更深层，浅层只留一句导航
```

## 维护

- 模板变更优先改 `docs/*.template.md` 和 `scripts/*.sh`；下游项目通过 `bootstrap.sh` 重跑或 `git submodule update --remote` 拉取。
- 治理规则改动同步 `ai-collab-doc-governance.md` 和 `.template.md` 两份。
- check.sh / pre-commit.sh / check_ai_collab_docs.py 的阈值集中在文件顶部，修改时保持与本 README 表格一致。
