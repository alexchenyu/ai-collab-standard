---
name: claude-codex-wrappers
description: Install and use machine-local Claude Code / Codex backend wrappers (claude-kimi, claude-deepseek, claude-official, codex-kimi, codex-deepseek, codex-official) via LiteLLM on Linux/macOS/Windows. Use when the user asks to run Claude Code on Kimi/DeepSeek, switch Codex profiles, install claude-kimi, or recreate ~/.local/bin wrappers.
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

Windows: **open a new terminal** after install so User PATH picks up `.local\bin`. `claude-kimi` works in cmd and PowerShell via the `.cmd` shim (`ExecutionPolicy Bypass` on that invoke only).

## Commands

| Command | Backend |
| --- | --- |
| `claude-kimi` | Claude Code → `Kimi-K3` (compact window 502000) |
| `claude-deepseek` | Claude Code → `DeepSeek-V4-Flash-0731` (compact window 655360) |
| `claude-official` | Claude Code → Anthropic (unsets LiteLLM env) |
| `claude-fix-transcripts` | 修复 Kimi/DeepSeek 时期会话记录，使其可被官方 API resume |
| `codex-kimi` | `codex -p kimi` |
| `codex-deepseek` | `codex -p deepseek` |
| `codex-official` | `codex -p openai` |

Claude wrappers unset `ANTHROPIC_API_KEY`, set `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`, and pin **all** `ANTHROPIC_DEFAULT_*` + `CLAUDE_CODE_SUBAGENT_MODEL` to the same model so `/status` and subagents cannot silently fall back to opus.

## Pitfalls

- **中转时期的会话记录不能直接给官方 resume**：Kimi-K3 / DeepSeek 经 LiteLLM 生成的 transcript（`~/.claude/projects/<项目>/<会话>.jsonl`）里，工具调用 id 形如 `Bash:12`（含冒号，违反官方 `^[a-zA-Z0-9_-]+$` 校验），还可能夹带空 `text` 块（`"text":""`）。resume 会全量回放历史，因此用 `claude` / `claude-official` 打开这类会话会每条消息都 400：`tool_use.id: String should match pattern '^[a-zA-Z0-9_-]+$'` 或 `text content blocks must be non-empty`。规则：**谁的会话谁来 resume**；确实要用官方打开旧中转会话时，先关闭该会话，跑 `claude-fix-transcripts <会话文件.jsonl>`（或 `--all` 扫全部），再 `claude --resume`。反过来官方创建的会话（`toolu_` 开头的 id）用三个 wrapper 都能 resume。
- `~/.claude/settings.json` `"env"` overrides wrapper env. Clear `ANTHROPIC_*` there before using `claude-kimi`.
- If `/status` still shows `opus*`, delete or change the `"model"` field in `settings.json`.
- Codex wrappers unset `OPENAI_BASE_URL` / `OPENAI_API_KEY` so profile `env_key = LITELLM_API_KEY` wins.
- Need `claude` / `codex` on PATH (`npm i -g @anthropic-ai/claude-code` / `@openai/codex`).
- Git Bash on Windows: run the `.sh` installer (bash shebang scripts). Native cmd/PowerShell: run the `.ps1` installer. Same `client.env`; you can run both.
