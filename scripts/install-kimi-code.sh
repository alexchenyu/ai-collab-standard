#!/usr/bin/env bash
# install-kimi-code.sh
# 下载/安装 Kimi Code CLI，并写入自托管 K3 的持久配置：
#   ~/.kimi-code/config.toml   [providers.local-k3] + [models.local-k3]
#   ~/.local/bin/kimi-k3       → kimi -m local-k3
#
# 不绑云端 /login。Kimi Code 只要端点吐 OpenAI 兼容 /v1/chat/completions 就能接。
# 别跟 `kimi web` 搞混：那个是 Kimi Code 自己的本地 UI/API，不是模型推理。
#
# 用法：
#   ./install-kimi-code.sh
#   ./install-kimi-code.sh --base-url http://127.0.0.1:8000/v1 --model Kimi-K3
#   ./install-kimi-code.sh --litellm            # 复用 ~/.config/litellm/client.env
#   ./install-kimi-code.sh --litellm --wan
#   ./install-kimi-code.sh --skip-install       # 只写配置
#   ./install-kimi-code.sh --upgrade            # 重跑官方 install.sh
set -euo pipefail

DEFAULT_BASE_URL="http://127.0.0.1:8000/v1"
LAN_LITELLM="http://us-agent.supermicro.com:4500"
WAN_LITELLM="https://api.365ui.com"
CLIENT_ENV="${LITELLM_CLIENT_ENV:-$HOME/.config/litellm/client.env}"
KIMI_HOME="${KIMI_CODE_HOME:-$HOME/.kimi-code}"
CONFIG_TOML="${KIMI_HOME}/config.toml"
BIN_DIR="${HOME}/.local/bin"
OFFICIAL_INSTALL_URL="https://code.kimi.com/kimi-code/install.sh"

ALIAS="local-k3"
PROVIDER_TYPE="kimi"
BASE_URL="$DEFAULT_BASE_URL"
BASE_URL_SET=0
KEY="dummy"
KEY_SET=0
MODEL="Kimi-K3"
CONTEXT_SIZE="1048576"
SET_DEFAULT=1
SKIP_INSTALL=0
UPGRADE=0
USE_LITELLM=0
USE_WAN=0
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./install-kimi-code.sh [options]

Options:
  --base-url URL     OpenAI 兼容根（必须含 /v1）。默认 http://127.0.0.1:8000/v1
  --key KEY          api_key。本地没鉴权就写假的。默认 dummy
  --model NAME       必须等于 vLLM/SGLang --served-model-name。默认 Kimi-K3
  --alias NAME       provider/model 段名。默认 local-k3
  --type kimi|openai 端点像 Moonshot（thinking/tool 齐）用 kimi；纯 Chat Completions 用 openai
  --context N        max_context_size。默认 1048576
  --litellm          复用 ~/.config/litellm/client.env（base = $LITELLM_BASE_URL/v1）
  --wan              和 --litellm 一起：https://api.365ui.com
  --no-default       不改 default_model（TUI 里 /model 选手动选）
  --skip-install     不下载 Kimi Code，只写 config + wrapper
  --upgrade          即使已安装也重跑官方 install.sh
  --force            覆盖已有同名 provider/model 段
  -h, --help         显示帮助

持久配置在 ~/.kimi-code/config.toml。export KIMI_API_KEY=... 不会被读；
临时试才用 KIMI_MODEL_* 那一组（本脚本不写环境变量）。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) BASE_URL="${2:-}"; BASE_URL_SET=1; shift 2 ;;
    --key) KEY="${2:-}"; KEY_SET=1; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --alias) ALIAS="${2:-}"; shift 2 ;;
    --type) PROVIDER_TYPE="${2:-}"; shift 2 ;;
    --context) CONTEXT_SIZE="${2:-}"; shift 2 ;;
    --litellm) USE_LITELLM=1; shift ;;
    --wan) USE_WAN=1; shift ;;
    --no-default) SET_DEFAULT=0; shift ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    --upgrade) UPGRADE=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! "$ALIAS" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]; then
  echo "ERROR: --alias 只能是 [A-Za-z][A-Za-z0-9_-]*，当前: $ALIAS" >&2
  exit 1
fi
if [[ "$PROVIDER_TYPE" != "kimi" && "$PROVIDER_TYPE" != "openai" ]]; then
  echo "ERROR: --type 只能是 kimi 或 openai" >&2
  exit 1
fi
if [[ ! "$CONTEXT_SIZE" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --context 必须是正整数" >&2
  exit 1
fi
if [[ -z "$MODEL" ]]; then
  echo "ERROR: --model 不能为空（必须等于 --served-model-name）" >&2
  exit 1
fi

if [[ "$USE_WAN" == 1 && "$USE_LITELLM" != 1 && "$BASE_URL_SET" != 1 ]]; then
  USE_LITELLM=1
fi

if [[ "$USE_LITELLM" == 1 ]]; then
  existing_key=""
  existing_base=""
  if [[ -f "$CLIENT_ENV" ]]; then
    existing_key="$(unset LITELLM_API_KEY LITELLM_BASE_URL; set -a; # shellcheck disable=SC1090
      source "$CLIENT_ENV"; printf '%s' "${LITELLM_API_KEY:-}")"
    existing_base="$(unset LITELLM_API_KEY LITELLM_BASE_URL; set -a; # shellcheck disable=SC1090
      source "$CLIENT_ENV"; printf '%s' "${LITELLM_BASE_URL:-}")"
  fi
  if [[ "$KEY_SET" != 1 ]]; then
    KEY="$existing_key"
  fi
  if [[ "$BASE_URL_SET" != 1 ]]; then
    if [[ "$USE_WAN" == 1 ]]; then
      BASE_URL="${WAN_LITELLM}/v1"
    elif [[ -n "$existing_base" ]]; then
      BASE_URL="${existing_base%/}/v1"
    else
      BASE_URL="${LAN_LITELLM}/v1"
    fi
  fi
  if [[ -z "$KEY" ]]; then
    echo "ERROR: --litellm 需要 virtual key。用法：" >&2
    echo "  $0 --litellm --key 'sk-你的-LiteLLM-virtual-key'" >&2
    echo "或先跑 install-claude-codex-wrappers.sh --key '...'" >&2
    exit 1
  fi
  if [[ "$KEY" == *"MASTER"* ]] || [[ "$KEY" == sk-supersuper* ]]; then
    echo "ERROR: 这看起来像 LITELLM_MASTER_KEY，不要拿去跑 Kimi Code" >&2
    exit 1
  fi
fi

if [[ -z "$KEY" ]]; then
  echo "ERROR: --key 不能为空。本地没鉴权写 dummy" >&2
  exit 1
fi
if [[ -z "$BASE_URL" ]]; then
  echo "ERROR: --base-url 不能为空" >&2
  exit 1
fi
BASE_URL="${BASE_URL%/}"
if [[ "$BASE_URL" != */v1 ]]; then
  echo "INFO: Kimi Code 要 /v1，已补上：${BASE_URL} → ${BASE_URL}/v1"
  BASE_URL="${BASE_URL}/v1"
fi

kimi_bin() {
  if [[ -x "${KIMI_HOME}/bin/kimi" ]]; then
    printf '%s' "${KIMI_HOME}/bin/kimi"
    return 0
  fi
  if command -v kimi >/dev/null 2>&1; then
    command -v kimi
    return 0
  fi
  return 1
}

install_kimi_cli() {
  local tmp
  tmp="$(mktemp)"
  echo "下载官方安装脚本：$OFFICIAL_INSTALL_URL"
  if ! curl -fsSL -A 'Mozilla/5.0' -o "$tmp" "$OFFICIAL_INSTALL_URL"; then
    rm -f "$tmp"
    echo "ERROR: 官方 install.sh 下载失败。可手动：" >&2
    echo "  curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash" >&2
    echo "  或 npm install -g @moonshot-ai/kimi-code   # 需要 Node >= 22.19" >&2
    exit 1
  fi
  bash "$tmp"
  rm -f "$tmp"
}

if [[ "$SKIP_INSTALL" == 1 ]]; then
  echo "跳过 Kimi Code 下载（--skip-install）"
elif [[ "$UPGRADE" == 1 ]]; then
  echo "升级 Kimi Code（官方 install.sh）"
  install_kimi_cli
elif kimi_bin >/dev/null; then
  echo "已安装：$(kimi_bin)  ($("$(kimi_bin)" --version 2>/dev/null || echo '?'))"
else
  echo "未找到 kimi，开始官方安装"
  install_kimi_cli
fi

KIMI="$(kimi_bin || true)"
if [[ -z "$KIMI" ]]; then
  echo "ERROR: 安装后仍找不到 kimi。看 ${KIMI_HOME}/bin/kimi，或 source ~/.bashrc" >&2
  exit 1
fi

if [[ -f "$CONFIG_TOML" && "$FORCE" != 1 ]]; then
  if grep -qF "[providers.${ALIAS}]" "$CONFIG_TOML" || grep -qF "[models.${ALIAS}]" "$CONFIG_TOML"; then
    echo "INFO: 已有 [${ALIAS}] 段，将覆盖（同名 upsert）。不想动就换 --alias"
  fi
fi

mkdir -p "$KIMI_HOME"
if [[ ! -f "$CONFIG_TOML" ]]; then
  umask 077
  cat > "$CONFIG_TOML" <<'EOF'
# ~/.kimi-code/config.toml
# Runtime settings for Kimi Code.
EOF
fi

python3 - "$CONFIG_TOML" "$ALIAS" "$PROVIDER_TYPE" "$BASE_URL" "$KEY" "$MODEL" "$CONTEXT_SIZE" "$SET_DEFAULT" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
alias, ptype, base_url, api_key, model, context, set_default = sys.argv[2:9]


def toml_str(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def upsert_section(text: str, header: str, body: str) -> str:
    name = header[1:-1]
    pattern = re.compile(
        rf"(?ms)^\[{re.escape(name)}\][^\n]*\n(?:(?!^\[).*\n?)*"
    )
    block = body.rstrip() + "\n"
    if pattern.search(text):
        return pattern.sub(lambda _m: block + "\n", text, count=1)
    if text and not text.endswith("\n"):
        text += "\n"
    return text + "\n" + block + "\n"


def upsert_default_model(text: str, alias: str) -> str:
    line = f"default_model = {toml_str(alias)}"
    if re.search(r"(?m)^default_model\s*=", text):
        return re.sub(r"(?m)^default_model\s*=\s*.*$", line, text, count=1)
    if text.startswith("#"):
        lines = text.splitlines(True)
        i = 0
        while i < len(lines) and (lines[i].startswith("#") or lines[i].strip() == ""):
            i += 1
        return "".join(lines[:i]) + line + "\n" + "".join(lines[i:])
    return line + "\n" + text


provider_body = (
    f"[providers.{alias}]\n"
    f"type = {toml_str(ptype)}\n"
    f"base_url = {toml_str(base_url)}\n"
    f"api_key = {toml_str(api_key)}\n"
)
model_body = (
    f"[models.{alias}]\n"
    f"provider = {toml_str(alias)}\n"
    f"model = {toml_str(model)}\n"
    f"max_context_size = {context}\n"
    f'capabilities = ["thinking", "always_thinking", "tool_use"]\n'
    f'support_efforts = ["low", "high", "max"]\n'
    f'default_effort = "max"\n'
)

text = path.read_text()
text = upsert_section(text, f"[providers.{alias}]", provider_body)
text = upsert_section(text, f"[models.{alias}]", model_body)
if set_default == "1":
    text = upsert_default_model(text, alias)
path.write_text(text)
PY

chmod 600 "$CONFIG_TOML"
echo "已写入 $CONFIG_TOML  （provider/model: $ALIAS → $MODEL @ $BASE_URL）"

mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/kimi-k3" <<EOF
#!/usr/bin/env bash
# kimi-k3 — Kimi Code → 自托管 K3（alias: ${ALIAS}）
set -euo pipefail
export PATH="\${KIMI_CODE_HOME:-\$HOME/.kimi-code}/bin:\$HOME/.local/bin:\$PATH"
exec kimi -m ${ALIAS} "\$@"
EOF
chmod 755 "$BIN_DIR/kimi-k3"
echo "已安装 wrapper：$BIN_DIR/kimi-k3"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
KIMI_PATH_LINE="export PATH=\"${KIMI_HOME}/bin:\$PATH\""
if [[ -f "$HOME/.bashrc" ]]; then
  if grep -Fq '$HOME/.local/bin' "$HOME/.bashrc" || grep -Fq "${HOME}/.local/bin" "$HOME/.bashrc"; then
    echo "~/.bashrc 已包含 ~/.local/bin"
  else
    echo "$PATH_LINE" >> "$HOME/.bashrc"
    echo "已把 ~/.local/bin 写入 ~/.bashrc"
  fi
  if grep -Fq "${KIMI_HOME}/bin" "$HOME/.bashrc"; then
    echo "~/.bashrc 已包含 ${KIMI_HOME}/bin"
  else
    printf '\n# kimi-code\n%s\n' "$KIMI_PATH_LINE" >> "$HOME/.bashrc"
    echo "已把 ${KIMI_HOME}/bin 写入 ~/.bashrc"
  fi
fi

if "$KIMI" doctor config "$CONFIG_TOML"; then
  echo "kimi doctor：config.toml OK"
else
  echo "WARN: kimi doctor 未通过，检查 $CONFIG_TOML" >&2
fi

if command -v curl >/dev/null 2>&1; then
  probe="${BASE_URL}/models"
  if curl -fsS -o /dev/null -m 3 -H "Authorization: Bearer ${KEY}" "$probe"; then
    echo "推理端点可达：$probe"
  else
    echo "WARN: 现在 ping 不到 $probe 。model 必须等于 serving 的 --served-model-name。" >&2
    echo "      引擎用 vLLM / SGLang / TokenSpeed，并开 kimi_k3 tool parser + reasoning parser。" >&2
  fi
fi

echo
echo "已就绪："
echo "  $( "$KIMI" --version 2>/dev/null || echo kimi )  @ $KIMI"
echo "  default_model:  $( [[ "$SET_DEFAULT" == 1 ]] && echo "$ALIAS" || echo '(未改，TUI 里 /model 选)' )"
echo "  type:           $PROVIDER_TYPE"
echo "  model:          $MODEL"
echo "  base_url:       $BASE_URL"
echo "  config:         $CONFIG_TOML"
echo
echo "启动：kimi    或    kimi-k3"
echo "换模型：TUI 里 /model 选 $ALIAS；临时试不用写盘："
echo "  export KIMI_MODEL_NAME=\"$MODEL\""
echo "  export KIMI_MODEL_API_KEY=\"dummy\""
echo "  export KIMI_MODEL_PROVIDER_TYPE=\"$PROVIDER_TYPE\""
echo "  export KIMI_MODEL_BASE_URL=\"$BASE_URL\""
echo "  export KIMI_MODEL_MAX_CONTEXT_SIZE=\"$CONTEXT_SIZE\""
echo "  export KIMI_MODEL_CAPABILITIES=\"thinking,tool_use\""
echo "  kimi"
echo
echo "注意：export KIMI_API_KEY=... 不会被读。WebSearch/Fetch 仍走 Kimi 云，除非改 [services.moonshot_*]。"
echo "      kimi web 是本地 UI，不是推理。别跟这个端点搞混。"
