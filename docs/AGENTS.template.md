# {{PROJECT_NAME}}

{{PROJECT_ONE_LINE_SUMMARY}}

> **此文件是项目协作的 canonical source**，被 Codex CLI、Cursor、GitHub Copilot、
> Windsurf、Amp、Devin 等 AI agent 工具自动读取（见 [agents.md](https://agents.md/)
> 跨工具标准）。Claude Code 通过同目录 `CLAUDE.md` 桩文件指向本文件。
> 修改本文件 = 修改全 agent 的项目级 instructions。

## 协作约定

- {{LANG_RULE}}
- **写代码前先想 4 件事**：假设是否明确？是否最简方案？改动是否最小？成功标准是否可验证？详见 `.ai-collab/docs/ai-collab-agent-behavior.md`。
- 本文件目标长度 ≤ 200 行 / ≤ 8 KiB；Codex 总预算 32 KiB（含递归子目录 AGENTS.md），别一个文件吃完。
- **本文件里绝对不放会刷新的数字**（数据规模、端口、实例数、版本号）；这些去 `docs/PROJECT_STATUS.md`。
- 新踩到的坑 / 修好的 bug / 非显而易见的实现经验：进 `lesson_learned.md` 对应主题，不要塞回本文件。
- 架构决策、"为什么选 X 而不是 Y"：进 `docs/ADR/`。

## 文档索引（canonical sources）

| 想找 | 看这里 |
| ---- | ---- |
| Repo 级高频规则（本文件） | `AGENTS.md` |
| Agent 行为约束（思考 / 简洁 / 精准 / 目标 / scratchpad / skill 化） | `.ai-collab/docs/ai-collab-agent-behavior.md` |
| 项目术语词典（共享语言） | `docs/PROJECT_GLOSSARY.md` |
| 当前部署状态 / 数据规模 / 端口 | `docs/PROJECT_STATUS.md` |
| 排障经验 / 踩坑结论 / 实现边界 | `lesson_learned.md` |
| 架构决策 / 替代方案 | `docs/ADR/README.md` |
| Claude Code 专属补充 | `CLAUDE.md`（薄 stub，本文件优先） |
| Cursor 总是注入的规则 | `.cursor/rules/00-core.mdc`（指针 + alwaysApply） |
| 目录级 runbook | 各子目录 `AGENTS.md` |
| Agent skills（含 `task-scratchpad`） | `.cursor/skills/` |
| 文档治理规范 | `.ai-collab/docs/ai-collab-doc-governance.md` |

## 核心目录

{{DIR_LIST}}

## 常用命令

```bash
# TODO: 本项目最常用的启动命令（至少一条）
# TODO: 本项目最常用的测试命令（至少一条）
# TODO: 本项目最常用的构建命令（至少一条）
```

## 稳定技术选型

> 这里写"**用了什么**"，不写"**跑了几个实例 / 多少卡 / 多大数据量**"。实例数和数据量进 `PROJECT_STATUS.md`。

- TODO: 语言 / 运行时 / 主要框架
- TODO: 核心存储（DB / 向量库 / 缓存）
- TODO: 主要外部服务或关键依赖

## 核心约束

> 写了这些约束就意味着"违反它就是 bug"。每条都应经得住"删掉它会不会明显增加出错率"测试。

- TODO: 绝不能破坏的系统不变量
- TODO: 最关键的数据契约
- TODO: 最关键的安全或治理边界
- TODO: 最关键的读写流程约束
- TODO: 最关键的性能或稳定性约束

## 代码约定

- TODO: 最重要的代码规范（命名 / 结构 / 静态检查）
- TODO: 最重要的日志或错误处理规范
- TODO: 最重要的测试规范
- TODO: 最重要的配置或依赖规范

## 跨工具约定（Codex / Cursor / Claude Code 都遵守）

- **AGENTS.md 是 canonical**；CLAUDE.md / `.cursor/rules/00-core.mdc` 都只是 thin pointer。
- **子目录 runbook 用 `AGENTS.md`**（复数），Codex 和 Cursor 会从 git root 递归向下读取。
- 个人级覆盖：在 `~/.codex/AGENTS.md` 写全局偏好；项目里临时调试用同级 `AGENTS.override.md`（替换语义，不是叠加）。
- Codex 总预算 `project_doc_max_bytes`（默认 32 KiB），可在 `~/.codex/config.toml` 调高。
- 想让 Codex 同时读 CLAUDE.md（不只是把 CLAUDE.md 当桩），在 `~/.codex/config.toml` 里加 `project_doc_fallback_filenames = ["CLAUDE.md"]`。

---

**维护提醒**：新增内容前，先对照"文档索引"确认它是否属于本文件；大多数情况下都该进 `lesson_learned.md` / `PROJECT_STATUS.md` / ADR 而不是这里。
