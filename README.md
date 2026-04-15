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

## 如何在项目中接入

推荐将本仓库作为 Git Submodule 引入到你的业务项目中：

```bash
# 1. 在你的项目根目录下添加 submodule
git submodule add https://github.com/your-org/ai-collab-standard.git .ai-collab

# 2. 运行初始化脚本
bash .ai-collab/scripts/init_ai_collab_docs.sh . \
    --project-name "My Project" \
    --agent-dir backend \
    --agent-dir frontend
```

默认不会覆盖已有文件；需要覆盖时加 `--force`。
使用 `--help` 查看所有可用选项（如 `--lang`、`--dry-run` 等）。

## 核心治理原则

详细的文档分层逻辑请阅读 [AI 协作文档分层治理](docs/ai-collab-doc-governance.md)。

简而言之：
1. `CLAUDE.md` 只放高频稳定规则。
2. 根级 `AGENTS.md` 只做跨工具指针，不承载正文。
3. `.cursorrules` 只放极少量持久提醒。
4. `AGENT.md` 只在目录存在独有 workflow 时才引入。
5. `lesson_learned.md` 只放当前仍有效的非显而易见经验。
6. ADR 只记录架构决策和提案，不记录日常实现碎片。
