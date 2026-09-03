---
name: claude-codex-wrappers
description: Install and use machine-local Claude Code / Codex backend wrappers (claude-kimi, claude-deepseek, claude-glm, claude-official, codex-kimi, codex-deepseek, codex-official) via LiteLLM on Linux/macOS/Windows. Use when the user asks to run Claude Code on Kimi/DeepSeek/GLM, switch Codex profiles, install claude-kimi, or recreate ~/.local/bin wrappers.
---

# Claude Code / Codex LiteLLM wrappers

> **Canonical source: `.ai-collab/skills/claude-codex-wrappers/SKILL.md`**. Installed copy under `.cursor/skills/` is overwritten by `init_ai_collab_docs.sh`. Edit upstream; do not edit the local copy.

These commands are **machine-local**, not project git. Virtual keys stay in `~/.config/litellm/client.env` (mode 600 / ACL current user only). Never commit the key. Same `client.env` format on Linux and Windows so WSL can share it.

## Install / reinstall

Linux / macOS / Git Bash:

```bash
bash .ai-collab/scripts/install-claude-codex-wrappers.sh --key 'sk-你的-virtual-key'
bash .ai-collab/scripts/install-claude-codex-wrappers.sh          # reuse client.env
bash .ai-collab/scripts/install-claude-codex-wrappers.sh --wan
```

Windows (PowerShell 5.1+ / cmd):

```powershell
powershell -ExecutionPolicy Bypass -File .ai-collab/scripts/install-claude-codex-wrappers.ps1 -Key 'sk-你的-virtual-key'
powershell -ExecutionPolicy Bypass -File .ai-collab/scripts/install-claude-codex-wrappers.ps1
powershell -ExecutionPolicy Bypass -File .ai-collab/scripts/install-claude-codex-wrappers.ps1 -Wan
```

| | Unix installer | Windows installer |
| --- | --- | --- |
| Wrappers | `~/.local/bin/claude-kimi` (bash) | `%USERPROFILE%\.local\bin\claude-kimi.cmd` + `.ps1` |
| PATH | append `~/.bashrc` | User environment `Path` |
| Key file | `~/.config/litellm/client.env` | same path under `%USERPROFILE%` |

Installer also writes Codex `[model_providers.litellm]` + `[profiles.kimi|deepseek|openai]` in `~/.codex/config.toml` (does **not** change the top-level official default model).

Default LAN: `http://us-agent.supermicro.com:4500`. `--wan` / `-Wan` → `https://api.365ui.com`. Root URL only — no `/v1`.

Reject `LITELLM_MASTER_KEY` / `sk-supersuper*` — gateway master keys, not client virtual keys.

Windows: **open a new terminal** after install so User PATH picks up `.local\bin`. `claude-kimi` / `claude-fix-transcripts` work in cmd and PowerShell via the `.cmd` shim (`ExecutionPolicy Bypass` on that invoke only). `--all` 扫 `%USERPROFILE%\.claude\projects`。

## Commands

| Command | Backend |
| --- | --- |
| `claude-kimi` | Claude Code → `Kimi-K3` (1M max; compact at 900000 to keep request headroom) |
| `claude-deepseek` | Claude Code → `DeepSeek-V4-Flash-0731` (compact 655360) |
| `claude-glm` | Claude Code → `GLM-5.3` (served `--max-model-len=563392`) |
| `claude-official` | Claude Code → Anthropic (unsets LiteLLM env) |
| `claude-fix-transcripts` | 修复 Kimi/DeepSeek 时期会话记录，使其可被官方 API resume |
| `codex-kimi` | `codex -p kimi` |
| `codex-deepseek` | `codex -p deepseek` |
| `codex-official` | `codex -p openai` |

Claude wrappers unset `ANTHROPIC_API_KEY`, set `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`, and pin **all** `ANTHROPIC_DEFAULT_*` + `CLAUDE_CODE_SUBAGENT_MODEL` to the same model so `/status` and subagents cannot silently fall back to opus.

LiteLLM 模型 id（`Kimi-K3` / `GLM-5.3` / …）Claude Code 不认识，会按 **200k** 当成模型上限。只设 `CLAUDE_CODE_AUTO_COMPACT_WINDOW=502000` 会显示 `502k · capped to 200k by model`，实际还是 200k。必须同时设 `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 为真实窗口（Kimi：`1048576`；GLM：当前 serving `--max-model-len=563392`）。自动压缩阈值必须低于服务端硬上限，为单次工具输出、系统提示和摘要输出留余量；Kimi 使用 `900000`。见 [Correct the window for a gateway or custom model ID](https://code.claude.com/docs/en/model-config)。

## Pitfalls

- Wrapper 环境变量只在启动时注入，已打开的 Claude Code 进程不会热更新。会话已超过服务端硬上限时，`/compact` 也会因摘要请求携带超限历史而失败；先用 `Esc Esc` / `/rewind` 回退到大输出前并立即 `/compact`，然后退出并用新 wrapper resume。无法回退时只能新开会话，工作区文件不会丢。
- **中转时期的会话记录不能直接给官方 resume**：Kimi-K3 / DeepSeek 经 LiteLLM 生成的 transcript（`~/.claude/projects/<项目>/<会话>.jsonl`）里，工具调用 id 形如 `Bash:12`（含冒号，违反官方 `^[a-zA-Z0-9_-]+$` 校验），还可能夹带空 `text` 块（`"text":""`）。resume 会全量回放历史，因此用 `claude` / `claude-official` 打开这类会话会每条消息都 400：`tool_use.id: String should match pattern '^[a-zA-Z0-9_-]+$'` 或 `text content blocks must be non-empty`。规则：**谁的会话谁来 resume**；确实要用官方打开旧中转会话时，先关闭该会话，跑 `claude-fix-transcripts <会话文件.jsonl>`（或 `--all` 扫全部），再 `claude --resume`。反过来官方创建的会话（`toolu_` 开头的 id）用三个 wrapper 都能 resume。
- `~/.claude/settings.json` `"env"` overrides wrapper env. Clear `ANTHROPIC_*` there before using `claude-kimi`.
- If `/status` still shows `opus*`, delete or change the `"model"` field in `settings.json`.
- Codex wrappers unset `OPENAI_BASE_URL` / `OPENAI_API_KEY` so profile `env_key = LITELLM_API_KEY` wins.
- Need `claude` / `codex` on PATH (`npm i -g @anthropic-ai/claude-code` / `@openai/codex`).
- Git Bash on Windows: run the `.sh` installer (bash shebang scripts). Native cmd/PowerShell: run the `.ps1` installer. Same `client.env`; you can run both.
