# Pi 自定义模型配置

本文说明如何把 OpenAI-compatible 网关模型接入 Pi，并以 Kimi、GLM 和 Grok
为例配置模型选择、thinking、上下文窗口和工具调用。

配置只写入用户目录：

- `~/.pi/agent/models.json`：provider、模型和兼容参数
- `~/.pi/agent/settings.json`：默认模型、默认 thinking 和 Ctrl+P 模型范围
- 独立 env 文件：API key 的唯一存储位置

不要把真实 API key 写入 `models.json`、项目文档或 Git。

## 1. 准备凭据文件

LiteLLM 和 Grok 分开保存，权限设为 `0600`：

```bash
install -d -m 700 "$HOME/.config/ai-gateways"
touch "$HOME/.config/ai-gateways/litellm.env"
touch "$HOME/.config/ai-gateways/grok.env"
chmod 600 "$HOME/.config/ai-gateways/"*.env
```

`~/.config/ai-gateways/litellm.env`：

```bash
export LITELLM_BASE_URL="https://gateway.example.com/v1"
export LITELLM_API_KEY="replace-with-client-key"
```

`~/.config/ai-gateways/grok.env`：

```bash
export GROK_BASE_URL="https://api.x.ai/v1"
export GROK_API_KEY="replace-with-api-key"
```

`models.json` 的 `apiKey` 支持以 `!` 开头的 shell command。Pi 在请求时执行命令并
读取 stdout，因此可以复用 env 文件而不复制 key。`baseUrl` 不支持同样的动态解析，
必须在 `models.json` 中写实际 URL。

## 2. 配置模型

创建 `~/.pi/agent/models.json`：

```json
{
  "providers": {
    "litellm": {
      "baseUrl": "https://gateway.example.com/v1",
      "api": "openai-completions",
      "apiKey": "!bash -lc 'set -a; source \"$HOME/.config/ai-gateways/litellm.env\"; printf %s \"$LITELLM_API_KEY\"'",
      "authHeader": true,
      "compat": {
        "supportsDeveloperRole": false,
        "supportsUsageInStreaming": true,
        "maxTokensField": "max_tokens"
      },
      "models": [
        {
          "id": "Kimi-K3",
          "name": "Kimi K3 (LiteLLM)",
          "reasoning": true,
          "thinkingLevelMap": {
            "off": null,
            "minimal": null,
            "low": "low",
            "medium": null,
            "high": "high",
            "xhigh": null,
            "max": "max"
          },
          "input": ["text"],
          "contextWindow": 1048576,
          "maxTokens": 16000,
          "cost": {
            "input": 0,
            "output": 0,
            "cacheRead": 0,
            "cacheWrite": 0
          },
          "compat": {
            "deferredToolsMode": "kimi"
          }
        },
        {
          "id": "GLM-5.3",
          "name": "GLM 5.3 (LiteLLM)",
          "reasoning": true,
          "thinkingLevelMap": {
            "off": "off",
            "minimal": null,
            "low": "low",
            "medium": null,
            "high": "high",
            "xhigh": null,
            "max": "max"
          },
          "input": ["text"],
          "contextWindow": 563392,
          "maxTokens": 16000,
          "cost": {
            "input": 0,
            "output": 0,
            "cacheRead": 0,
            "cacheWrite": 0
          },
          "compat": {
            "thinkingFormat": "zai"
          }
        }
      ]
    },
    "xai": {
      "baseUrl": "https://api.x.ai/v1",
      "apiKey": "!bash -lc 'set -a; source \"$HOME/.config/ai-gateways/grok.env\"; printf %s \"$GROK_API_KEY\"'",
      "modelOverrides": {
        "grok-4.6": {
          "contextWindow": 500000,
          "maxTokens": 16000
        }
      }
    }
  }
}
```

注意：

- `id` 必须与网关 `/v1/models` 返回值完全一致。
- Kimi 的 `deferredToolsMode: "kimi"` 保留其 deferred tool serialization。
- GLM 的 `thinkingFormat: "zai"` 使用 Z.AI thinking payload。
- Grok 使用 Pi 内置 `xai` provider，只覆盖凭据和 token 上限；其图片、thinking
  和 API 兼容元数据仍由 Pi catalog 提供。
- 示例中的 context 和 output 上限必须与实际 serving contract 一致，不能只按模型
  理论窗口填写。

## 3. 配置默认模型

合并以下字段到 `~/.pi/agent/settings.json`：

```json
{
  "defaultProvider": "litellm",
  "defaultModel": "Kimi-K3",
  "modelThinkingLevels": {
    "litellm/Kimi-K3": "max",
    "litellm/GLM-5.3": "max",
    "xai/grok-4.6": "xhigh"
  },
  "enabledModels": [
    "litellm/Kimi-K3",
    "litellm/GLM-5.3",
    "xai/grok-4.6"
  ]
}
```

`enabledModels` 限制 Ctrl+P 循环范围，但不删除其它 provider。也可以在 `/model`
中选择模型并按 Ctrl+S 保存启动默认值。

## 4. 验证

先检查 JSON 和模型发现：

```bash
jq -e . "$HOME/.pi/agent/models.json" >/dev/null
jq -e . "$HOME/.pi/agent/settings.json" >/dev/null
pi --list-models
```

验证每个模型的基本响应：

```bash
pi --no-session --no-tools -p \
  --provider litellm --model Kimi-K3 --thinking max \
  "Reply with exactly: pong"

pi --no-session --no-tools -p \
  --provider litellm --model GLM-5.3 --thinking max \
  "Reply with exactly: pong"

pi --no-session --no-tools -p \
  --provider xai --model grok-4.6 --thinking xhigh \
  "Reply with exactly: pong"
```

基本响应成功不代表 agent tool loop 正常。进入包含 `README.md` 的仓库，再验证一次工具调用：

```bash
pi --no-session -p --tools read \
  --provider litellm --model Kimi-K3 --thinking max \
  "Use the read tool on README.md, then reply with only its first heading."
```

把 provider 和 model 替换为 GLM、Grok 后各跑一次。成功标准是 Pi 先执行 `read`，
再根据工具结果回答，而不是直接猜测文件内容。

## 5. 常见问题

### `No models available`

确认凭据文件存在、变量非空，并检查模型是否能被 Pi 发现：

```bash
bash -lc 'source "$HOME/.config/ai-gateways/litellm.env"; test -n "$LITELLM_API_KEY"'
pi --list-models litellm
```

自定义 provider 即使加载成功，没有可解析的 `apiKey` 时也不会成为可用模型。

### 网关返回 404

多数 OpenAI-compatible provider 的 `baseUrl` 需要以 `/v1` 结尾。不要把
`/chat/completions` 写进 `baseUrl`，Pi 会自行拼接具体 endpoint。

### 网关返回 401

检查 `apiKey` command 的 stdout 是否只有 key，不能带日志或换行说明。LiteLLM
应使用受限 client/virtual key，不要使用 gateway master key。

### 模型能聊天但不会正确调用工具

- Kimi：确认配置了 `deferredToolsMode: "kimi"`，推理服务也启用了对应 tool parser。
- GLM：确认使用 `thinkingFormat: "zai"`，并验证 streaming tool-call delta。
- 所有模型：用 `--tools read` 做真实 tool loop 测试，不要只测 `pong`。

### 修改后当前会话没有变化

打开 `/model` 会重新加载 `models.json`。默认模型或默认 thinking 改动建议重启 Pi；
也可以在对应 picker 中按 Ctrl+S 保存。

## 参考

- [Pi custom models](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md)
- [Pi providers and credential resolution](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/providers.md)
