# `{{DIR_NAME}}/` Agent Guide

补充目录级 runbook。Repo 级规则先看 `{{ROOT_AGENTS_PATH}}`，Agent 行为约束（思考前 / 简洁优先 / 精准修改 / 目标驱动）见 `.ai-collab/docs/ai-collab-agent-behavior.md`，本文件不重复。

> Codex CLI 和 Cursor 都会在你工作于 `{{DIR_NAME}}/` 时**自动叠加**本文件的内容，
> 无需手动 @ 引用。所以本文件只放**目录独有**的规则；通用规则去 `{{ROOT_AGENTS_PATH}}`。

> **什么时候需要这个文件？**
> 只有当 `{{DIR_NAME}}/` 有**独有的 workflow / 入口 / 坑**，在根 `AGENTS.md` 里写不下、也不通用时，才保留本文件。
> 如果本文件最终内容和根 `AGENTS.md` 高度重合，**直接删掉本文件**，别维护两份。
>
> 带 `TODO` 的模板文件不算已落地规范，也不应被当作 canonical source。首次引入后应尽快补全真实入口、命令、测试和边界；如果一周内还无法填实，考虑删除本文件而不是留着空模板。

## 你在这里主要处理什么

- TODO: `{{DIR_NAME}}/` 的核心职责（一句话）
- TODO: `{{DIR_NAME}}/` 的关键入口或模块
- TODO: `{{DIR_NAME}}/` 的交付边界（什么在这里做，什么不在这里做）

## 进入前先知道

- TODO: 在 `{{DIR_NAME}}/` 最容易踩坑的局部规则（必须写出"为什么"）
- TODO: 在 `{{DIR_NAME}}/` 最关键的流程约束
- TODO: 在 `{{DIR_NAME}}/` 最关键的联动提醒

## 常用命令

```bash
# TODO: 在 {{DIR_NAME}}/ 最常用的命令（至少一条）
# TODO: 在 {{DIR_NAME}}/ 次常用的命令（至少一条）
```

## 改动后优先检查

- TODO: 改动后需要优先跑的测试文件（如 `tests/test_xxx.py`）
- TODO: 改动后需要同步检查的联动文件

## 常见联动

- TODO: 改动本目录后，极易被遗漏的外部联动点（如 "改了 DB schema 记得更新 frontend types"）
