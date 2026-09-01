---
name: kimi-code-setup
description: Install Kimi Code CLI and point it at self-hosted K3 (OpenAI-compatible /v1/chat/completions). Use when the user asks to install kimi, configure ~/.kimi-code/config.toml, run kimi-k3, or connect Kimi Code to local vLLM/SGLang without /login.
---

# Kimi Code → 自托管 K3

> **Canonical source: `.ai-collab/skills/kimi-code-setup/SKILL.md`**. Installed copy under `.cursor/skills/` is overwritten by `init_ai_collab_docs.sh`. Edit upstream; do not edit the local copy.

Kimi Code **不绑云端 `/login`**。自托管 K3 只要吐 OpenAI 兼容的 `/v1/chat/completions` 就能接。官方也把 Kimi Code 当 K3 的首选 agent。

别跟 `kimi web` 搞混：那个是 Kimi Code 自己的本地 UI/API，不是模型推理。

本机命令，不进项目 git。`api_key` 写在 `~/.kimi-code/config.toml`（mode 600）。

## Install

```bash
bash .ai-collab/scripts/install-kimi-code.sh
bash .ai-collab/scripts/install-kimi-code.sh --base-url http://127.0.0.1:8000/v1 --model Kimi-K3
bash .ai-collab/scripts/install-kimi-code.sh --litellm          # 复用 ~/.config/litellm/client.env
bash .ai-collab/scripts/install-kimi-code.sh --skip-install     # 只写配置
```

CLI 走官方 `https://code.kimi.com/kimi-code/install.sh`（落到 `~/.kimi-code/bin/kimi`）。已装则跳过，`--upgrade` 才重装。Windows 官方入口是 `install.ps1`；config.toml 字段一样。

## 写进去的配置

`~/.kimi-code/config.toml`：

```toml
default_model = "local-k3"

[providers.local-k3]
type = "kimi"
base_url = "http://127.0.0.1:8000/v1"
api_key = "dummy"

[models.local-k3]
provider = "local-k3"
model = "Kimi-K3"
max_context_size = 1048576
capabilities = ["thinking", "always_thinking", "tool_use"]
support_efforts = ["low", "high", "max"]
default_effort = "max"
```

`model` 必须等于 vLLM/SGLang 的 `--served-model-name`。`api_key` 必填，本地没鉴权就写假的。TUI 里 `/model` 选 `local-k3`，或靠 `default_model`。也可用 `/provider` 交互加自定义 OpenAI 兼容端点。

`~/.local/bin/kimi-k3` → `kimi -m local-k3`。

## type

| 端点 | type |
| --- | --- |
| 长得像 Moonshot（thinking / tool 字段齐），自托管 K3 | `kimi`（优先） |
| 纯通用 Chat Completions | `openai` |

## 临时试（不写盘）

`KIMI_MODEL_NAME` 一设就在内存里合成 provider。普通 `export KIMI_API_KEY=...` **不会被读**。

```bash
export KIMI_MODEL_NAME="Kimi-K3"
export KIMI_MODEL_API_KEY="dummy"
export KIMI_MODEL_PROVIDER_TYPE="kimi"
export KIMI_MODEL_BASE_URL="http://127.0.0.1:8000/v1"
export KIMI_MODEL_MAX_CONTEXT_SIZE="1048576"
export KIMI_MODEL_CAPABILITIES="thinking,tool_use"
kimi
```

## 推理侧别配错

Moonshot 认的引擎：vLLM、SGLang、TokenSpeed。必须开 **kimi_k3 tool parser + reasoning parser**，否则 Kimi Code 的 tool loop 会烂。

K3 默认 `tool_use.id` 是单轮计数。旧 vLLM 会让 Kimi Code 配对失败；用已修 conversation-level 唯一 ID 的版本（vLLM #50420 那条线）。

硬件：2.8T MoE，官方量级是 64+ 加速卡。量化/蒸馏另说。

## 和云端 K3 的差

Harness 一样，权重对了、parser 对了，能力接近。差在：serving 质量、tool-id、context 实际能塞多少、没有云端那套 video / managed 周边。WebSearch/Fetch 仍走 Kimi 云服务，除非再改 `[services.moonshot_*]`。

## 校验

```bash
kimi --version
kimi doctor
kimi-k3 -p 'reply with pong only'
```
