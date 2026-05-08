# {{PROJECT_NAME}} — Claude Code Notes

> **本文件不是 canonical source。** 项目级规则的唯一真相在同目录 [`AGENTS.md`](./AGENTS.md)。
> Claude Code 会自动加载 CLAUDE.md，但你应该把 AGENTS.md 也读进上下文（它是跨工具
> 标准，Codex/Cursor/Copilot 等都靠它）。本文件只放 Claude Code 专属补充。

## 必读

1. **先读 `AGENTS.md`**：项目协作规则、技术选型、目录、命令、约束都在那。
2. **再读 `.ai-collab/docs/ai-collab-agent-behavior.md`**：行为约束（思考前 / 简洁优先 / 精准修改 / 目标驱动 / scratchpad / skill 化）。
3. **遇到陌生术语先查 `docs/PROJECT_GLOSSARY.md`**，再查 `lesson_learned.md` 对应主题。

## Claude Code 专属（如果有）

> 写在这里的内容只对 Claude Code 生效（Codex/Cursor 看 AGENTS.md）。一般保持空。
> 例如：调用 `/agents` 子代理时的特殊参数、Anthropic skills 兼容设置等。

- TODO: 留空或写 Claude Code 专属补充

## 不要在本文件做的事

- ❌ 重复 AGENTS.md 内容（违反单一真相源原则）
- ❌ 写跨工具规则（应该在 AGENTS.md）
- ❌ 写当前状态数字（应该在 `docs/PROJECT_STATUS.md`）
- ❌ 写架构决策（应该在 `docs/ADR/`）
