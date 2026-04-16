# AI 协作文档治理规范 (AI Collab Docs Standard)

这是一套用于规范和管理项目中 AI 协作文档（如 `CLAUDE.md`, `.cursorrules`, `AGENT.md` 等）的通用模板和脚本。

## 为什么需要这个？

随着 AI 编码助手的普及，项目里往往会堆积大量的规则文件，导致：
- `CLAUDE.md` 越来越长，AI 抓不到重点
- `.cursorrules` 和 `CLAUDE.md` 内容重复
- 架构决策（ADR）和日常踩坑经验混在一起
- 不同项目之间的文档结构不统一

这套规范提供了一套**分层治理**方案，并附带一键初始化脚本。

## 目录结构

- `scripts/init_ai_collab_docs.sh`: 一键初始化/更新脚本
- `docs/`: 存放所有模板文件和治理说明文档

## 使用指南

推荐将本仓库作为 Git Submodule 引入到你的业务项目中，作为该项目的 `.ai-collab` 目录。

### 第一步：引入 Submodule

在你的项目根目录下执行：

```bash
git submodule add https://github.com/your-org/ai-collab-standard.git .ai-collab
```
*(如果只在本地使用，可以使用本地路径：`git -c protocol.file.allow=always submodule add /path/to/ai-collab-standard .ai-collab`)*

### 第二步：一键初始化文档骨架

调用仓库内的初始化脚本，它会自动探测你的目录结构（如 `backend`, `frontend`, `src` 等），并生成对应的文档：

```bash
bash .ai-collab/scripts/init_ai_collab_docs.sh . \
    --project-name "My Project" \
    --lang zh
```

> **提示**：脚本默认是**安全模式**，不会覆盖你项目中已有的同名文件。如果想强制覆盖（比如想用最新的模板重置框架），可以加上 `--force` 参数。

### 第三步：填写项目特有内容

脚本跑完后，你的项目里会多出 `CLAUDE.md`、`.cursorrules`、`lesson_learned.md`、`docs/ADR/` 等文件。
这些模板里预留了许多 `TODO` 占位符。运行以下命令查找并补全它们：

```bash
rg -n 'TODO' .
```

### 第四步：日常更新与维护

当 `ai-collab-standard` 仓库（即本仓库）更新了新的模板或治理规范时，你可以在业务项目中一键拉取最新规范：

```bash
# 更新 submodule 到最新版本
git submodule update --remote

# （可选）如果治理规范文档（如 ai-collab-doc-governance.md）有重大更新，
# 可以通过拷贝或带 --force 重新跑一遍脚本来同步最新架构思想。
```

## 核心治理原则

详细的文档分层逻辑请阅读 [AI 协作文档分层治理](docs/ai-collab-doc-governance.md)。

简而言之：
1. `CLAUDE.md` 只放高频稳定规则。
2. 根级 `AGENTS.md` 只做跨工具指针，不承载正文。
3. `.cursorrules` 只放极少量持久提醒。
4. `AGENT.md` 只在目录存在独有 workflow 时才引入。
5. `lesson_learned.md` 只放当前仍有效的非显而易见经验。
6. ADR 只记录架构决策和提案，不记录日常实现碎片。
