# {{PROJECT_NAME}}

{{PROJECT_ONE_LINE_SUMMARY}}

## 协作约定

- {{LANG_RULE}}
- `CLAUDE.md` 只保留高频、稳定、直接影响执行的规则；目标长度 ≤ 150 行。
- **本文件里绝对不放会刷新的数字**（数据规模、端口、实例数、版本号）；这些去 `docs/PROJECT_STATUS.md`。
- 新踩到的坑、修好的 bug、非显而易见的实现经验：进 `lesson_learned.md` 对应主题，不要塞回本文件。
- 架构决策、"为什么选 X 而不是 Y"：进 `docs/ADR/`。
- 修改本文件时优先删重、合并、压缩表达，不要无限追加条目；文件体积超过 150 行应触发精简。

## 文档索引（canonical source）

| 想找 | 看这里 |
| ---- | ---- |
| Repo 级高频规则 | 本文件 |
| 当前部署状态 / 数据规模 / 端口 | `docs/PROJECT_STATUS.md` |
| 排障经验 / 踩坑结论 / 实现边界 | `lesson_learned.md` |
| 架构决策 / 替代方案 | `docs/ADR/README.md` |
| 跨工具入口 | `AGENTS.md` |
| Cursor 极简提醒 | `.cursorrules` |
| 目录级 runbook | 各目录 `AGENT.md` |
| 治理规范 | `docs/ai-collab-doc-governance.md` |

## 核心目录

{{DIR_LIST}}

## 常用命令

```bash
# TODO: 本项目最常用的启动命令（至少一条）
# TODO: 本项目最常用的测试命令（至少一条）
# TODO: 本项目最常用的构建命令（至少一条）
```

## 稳定技术选型

> 这里写"**用了什么**"，不写"**跑了几个实例、多少张卡、多大数据量**"。实例数和数据量进 `PROJECT_STATUS.md`。

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

---

**维护提醒**：新增内容前，先对照"文档索引"确认它是否属于本文件；大多数情况下都该进 `lesson_learned.md` / `PROJECT_STATUS.md` / ADR 而不是这里。
