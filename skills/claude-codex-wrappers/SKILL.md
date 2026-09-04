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
| `claude-kimi` | Claude Code → `Kimi-K3` (1M max; compact at 900000; block image `Read` above 100KB) |
| `claude-deepseek` | Claude Code → `DeepSeek-V4-Flash-0731` (compact 655360) |
| `claude-glm` | Claude Code → `GLM-5.3` (served `--max-model-len=563392`) |
| `claude-official` | Claude Code → Anthropic (unsets LiteLLM env) |
| `claude-switch` | Safely switch one session between `official` and `kimi` |
| `claude-fix-transcripts` | 修复 Kimi/DeepSeek 时期会话记录，使其可被官方 API resume |
| `codex-kimi` | `codex -p kimi` |
| `codex-deepseek` | `codex -p deepseek` |
| `codex-official` | `codex -p openai` |

Claude wrappers unset `ANTHROPIC_API_KEY`, set `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`, and pin **all** `ANTHROPIC_DEFAULT_*` + `CLAUDE_CODE_SUBAGENT_MODEL` to the same model so `/status` and subagents cannot silently fall back to opus.

LiteLLM 模型 id（`Kimi-K3` / `GLM-5.3` / …）Claude Code 不认识，会按 **200k** 当成模型上限。只设 `CLAUDE_CODE_AUTO_COMPACT_WINDOW=900000` 会显示 `900k · capped to 200k by model`，实际还是 200k。必须同时设 `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 为真实窗口（Kimi：`1048576`；GLM：当前 serving `--max-model-len=563392`）。Kimi 保留 `900000` 自动压缩阈值；wrapper 通过 session-only `--settings` 注入 `PreToolUse` hook，阻止大于 100KB 的图片 `Read`，避免 image base64 单次增加约 400K tokens。见 [Correct the window for a gateway or custom model ID](https://code.claude.com/docs/en/model-config)。

## Switch backends on one session

先退出当前 Claude Code，然后在项目根目录运行：

```bash
claude-switch official --continue
claude-switch kimi --continue
claude-switch official --resume <session-id>
```

`claude-switch` 只选择当前项目最新 session（或显式 ID），确认 transcript 短时间内没有继续写入，按需创建 `.switchbak-<timestamp>` 备份，统一修复非法 tool IDs / 空文本块 / `provider_specific_fields`，并清除大于 100K base64 字符的历史图片。任何准备步骤失败都不会启动目标后端。切到 official 时显式使用 `--model default`，避免尝试恢复 `Kimi-K3` model id。

## Pitfalls

- Wrapper 环境变量只在启动时注入，已打开的 Claude Code 进程不会热更新。会话已超过服务端硬上限时，`/compact` 也会因摘要请求携带超限历史而失败；先用 `Esc Esc` / `/rewind` 回退到大输出前并立即 `/compact`，然后退出并用新 wrapper resume。无法回退时只能新开会话，工作区文件不会丢。
- Kimi/LiteLLM 链路读取 PNG 时可能把图片 base64 计入文本 token：约 600KB PNG 曾让下一次请求增加约 400K tokens。`claude-kimi` 默认拒绝读取大于 100KB 的 GIF/JPEG/PNG/WebP；先生成不超过 100KB 的预览，或交给正确支持 image content block 的 vision 模型。该 hook 只通过 wrapper 的 `--settings` 作用于当前 Kimi 会话，不修改 `~/.claude/settings.json`，也不影响官方 Claude。
- **不要直接用 `claude` resume Kimi session**：Kimi/LiteLLM transcript 的 `Bash:12` 一类 tool ID 不符合官方校验，还可能有空 `text` 块。优先用 `claude-switch official --continue` 自动修复并启动；手工恢复时先关闭会话，运行 `claude-fix-transcripts <session.jsonl>`，再 `claude --resume`。官方创建的 `toolu_` ID 可被 Kimi 接受。
- `~/.claude/settings.json` `"env"` overrides wrapper env. Clear `ANTHROPIC_*` there before using `claude-kimi`.
- If `/status` still shows `opus*`, delete or change the `"model"` field in `settings.json`.
- Codex wrappers unset `OPENAI_BASE_URL` / `OPENAI_API_KEY` so profile `env_key = LITELLM_API_KEY` wins.
- Need `claude` / `codex` / `node` on PATH (`npm i -g @anthropic-ai/claude-code` / `@openai/codex`); `node` executes the Kimi image guard.
- Git Bash on Windows: run the `.sh` installer (bash shebang scripts). Native cmd/PowerShell: run the `.ps1` installer. Same `client.env`; you can run both.
