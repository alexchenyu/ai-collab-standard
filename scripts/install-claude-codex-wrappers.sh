#!/usr/bin/env bash
# install-claude-codex-wrappers.sh
# 一键安装本机 Claude Code / Codex 切换命令：
#   claude-kimi / claude-deepseek / claude-official
#   codex-deepseek / codex-kimi / codex-official
#   claude-fix-transcripts（修复 Kimi/DeepSeek 中转时期的会话记录，使其可被官方 resume）
#
# 会写入 ~/.config/litellm/client.env（客户端 virtual key，不是仓库 .env，
# 也不是 LITELLM_MASTER_KEY），安装 ~/.local/bin 下的 wrapper，并给
# ~/.codex/config.toml 追加 LiteLLM profiles（不改顶层官方默认模型）。
#
# 用法：
#   ./install-claude-codex-wrappers.sh --key 'sk-你的-virtual-key'
# Windows（cmd / PowerShell）：
#   powershell -ExecutionPolicy Bypass -File .ai-collab/scripts/install-claude-codex-wrappers.ps1 -Key 'sk-...'
#   ./install-claude-codex-wrappers.sh --key 'sk-...' --wan
#   ./install-claude-codex-wrappers.sh --key 'sk-...' --base-url https://api.365ui.com
#   ./install-claude-codex-wrappers.sh          # 复用已有 client.env
set -euo pipefail

LAN_BASE_URL="http://us-agent.supermicro.com:4500"
WAN_BASE_URL="https://api.365ui.com"
CLIENT_ENV="${LITELLM_CLIENT_ENV:-$HOME/.config/litellm/client.env}"
BIN_DIR="${HOME}/.local/bin"
CODEX_TOML="${HOME}/.codex/config.toml"
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"

KEY=""
BASE_URL="$LAN_BASE_URL"
BASE_URL_SET=0
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  ./install-claude-codex-wrappers.sh --key 'sk-...' [--wan|--base-url URL] [--force]

Options:
  --key KEY         LiteLLM virtual key（Claude Code / Codex 客户端 key）
  --wan             使用 https://api.365ui.com
  --base-url URL    自定义 LiteLLM 根地址（不要带 /v1）
  --force           覆盖已有 ~/.config/litellm/client.env
  -h, --help        显示帮助

不传 --key 时，复用已有 client.env。不要把仓库 .env 里的 LITELLM_MASTER_KEY
或测试用 LITELLM_API_KEY 当成这个 key。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) KEY="${2:-}"; shift 2 ;;
    --wan) BASE_URL="$WAN_BASE_URL"; BASE_URL_SET=1; shift ;;
    --base-url) BASE_URL="${2:-}"; BASE_URL_SET=1; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$BASE_URL" ]]; then
  echo "ERROR: --base-url 不能为空" >&2
  exit 1
fi
BASE_URL="${BASE_URL%/}"
if [[ "$BASE_URL" == */v1 ]]; then
  echo "ERROR: LiteLLM 根地址不要带 /v1：Claude Code 用根路径，Codex 由脚本自动加 /v1" >&2
  exit 1
fi

existing_key=""
existing_base=""
if [[ -f "$CLIENT_ENV" ]]; then
  existing_key="$(unset LITELLM_API_KEY LITELLM_BASE_URL; set -a; # shellcheck disable=SC1090
    source "$CLIENT_ENV"; printf '%s' "${LITELLM_API_KEY:-}")"
  existing_base="$(unset LITELLM_API_KEY LITELLM_BASE_URL; set -a; # shellcheck disable=SC1090
    source "$CLIENT_ENV"; printf '%s' "${LITELLM_BASE_URL:-}")"
fi

if [[ -z "$KEY" ]]; then
  KEY="$existing_key"
fi
if [[ "$BASE_URL_SET" != 1 && -n "$existing_base" ]]; then
  BASE_URL="$existing_base"
fi
if [[ -z "$KEY" ]]; then
  echo "ERROR: 需要 virtual key。用法：" >&2
  echo "  $0 --key 'sk-你的-LiteLLM-virtual-key'" >&2
  echo "或先 ./add-user.sh <user> --models Kimi-K3,DeepSeek-V4-Flash-0731" >&2
  exit 1
fi
if [[ "$KEY" == *"MASTER"* ]] || [[ "$KEY" == sk-supersuper* ]]; then
  echo "ERROR: 这看起来像 LITELLM_MASTER_KEY，不要拿去跑 Claude Code / Codex" >&2
  exit 1
fi

write_client_env() {
  mkdir -p "$(dirname "$CLIENT_ENV")"
  local old_umask
  old_umask="$(umask)"
  umask 077
  {
    echo "# Claude Code / Codex 客户端 virtual key，不是 LITELLM_MASTER_KEY"
    printf 'export LITELLM_BASE_URL=%q\n' "$BASE_URL"
    printf 'export LITELLM_API_KEY=%q\n' "$KEY"
  } > "$CLIENT_ENV"
  umask "$old_umask"
  chmod 600 "$CLIENT_ENV"
}

if [[ -f "$CLIENT_ENV" && "$FORCE" != 1 ]]; then
  if [[ "$KEY" == "$existing_key" && "$BASE_URL" == "${existing_base:-$BASE_URL}" ]]; then
    echo "client.env 已存在，保持不变：$CLIENT_ENV"
  else
    echo "更新 client.env：$CLIENT_ENV"
    write_client_env
  fi
else
  echo "写入 client.env：$CLIENT_ENV"
  write_client_env
fi

install_wrapper() {
  local path="$1"
  cat > "$path"
  chmod 755 "$path"
}

mkdir -p "$BIN_DIR"

install_wrapper "$BIN_DIR/claude-kimi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CLIENT_ENV="${LITELLM_CLIENT_ENV:-$HOME/.config/litellm/client.env}"
if [[ -f "$CLIENT_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$CLIENT_ENV"
  set +a
fi
: "${LITELLM_API_KEY:?请先在 ~/.config/litellm/client.env 写入 LITELLM_API_KEY}"

exec env \
  -u ANTHROPIC_API_KEY \
  ANTHROPIC_BASE_URL="${LITELLM_BASE_URL:-http://us-agent.supermicro.com:4500}" \
  ANTHROPIC_AUTH_TOKEN="$LITELLM_API_KEY" \
  ANTHROPIC_MODEL="Kimi-K3" \
  ANTHROPIC_SMALL_FAST_MODEL="Kimi-K3" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="Kimi-K3" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="Kimi-K3" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="Kimi-K3" \
  ANTHROPIC_DEFAULT_FABLE_MODEL="Kimi-K3" \
  CLAUDE_CODE_SUBAGENT_MODEL="Kimi-K3" \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW="502000" \
  CLAUDE_CODE_EFFORT_LEVEL="max" \
  claude "$@"
EOF

install_wrapper "$BIN_DIR/claude-deepseek" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CLIENT_ENV="${LITELLM_CLIENT_ENV:-$HOME/.config/litellm/client.env}"
if [[ -f "$CLIENT_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$CLIENT_ENV"
  set +a
fi
: "${LITELLM_API_KEY:?请先在 ~/.config/litellm/client.env 写入 LITELLM_API_KEY}"

exec env \
  -u ANTHROPIC_API_KEY \
  ANTHROPIC_BASE_URL="${LITELLM_BASE_URL:-http://us-agent.supermicro.com:4500}" \
  ANTHROPIC_AUTH_TOKEN="$LITELLM_API_KEY" \
  ANTHROPIC_MODEL="DeepSeek-V4-Flash-0731" \
  ANTHROPIC_SMALL_FAST_MODEL="DeepSeek-V4-Flash-0731" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="DeepSeek-V4-Flash-0731" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="DeepSeek-V4-Flash-0731" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="DeepSeek-V4-Flash-0731" \
  ANTHROPIC_DEFAULT_FABLE_MODEL="DeepSeek-V4-Flash-0731" \
  CLAUDE_CODE_SUBAGENT_MODEL="DeepSeek-V4-Flash-0731" \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW="655360" \
  CLAUDE_CODE_EFFORT_LEVEL="max" \
  claude "$@"
EOF

install_wrapper "$BIN_DIR/claude-official" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec env \
  -u ANTHROPIC_BASE_URL \
  -u ANTHROPIC_AUTH_TOKEN \
  -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_MODEL \
  -u ANTHROPIC_SMALL_FAST_MODEL \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL \
  -u ANTHROPIC_DEFAULT_SONNET_MODEL \
  -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u ANTHROPIC_DEFAULT_FABLE_MODEL \
  -u CLAUDE_CODE_SUBAGENT_MODEL \
  -u CLAUDE_CODE_AUTO_COMPACT_WINDOW \
  -u CLAUDE_CODE_EFFORT_LEVEL \
  claude "$@"
EOF

install_wrapper "$BIN_DIR/claude-fix-transcripts" <<'EOF'
#!/usr/bin/env bash
# claude-fix-transcripts
# 修复 Kimi-K3 / DeepSeek（经 LiteLLM 中转）时期 Claude Code 会话记录（.jsonl）
# 里的非 Anthropic 官方格式残留，使这些会话可以被 claude / claude-official
# 正常 resume。
#
# 已知三类问题（resume 时全量回放历史，触发官方 API 400）：
#   1. 工具调用 id 形如 "Bash:12"（含冒号），违反 ^[a-zA-Z0-9_-]+$
#      报错：tool_use.id: String should match pattern '^[a-zA-Z0-9_-]+$'
#   2. 空文本块 "text":""（API 要求 text 非空）
#      报错：text content blocks must be non-empty
#   3. user/assistant 消息空内容 "content":[] / "content":""
#
# 用法：
#   claude-fix-transcripts <session.jsonl> [更多文件...]
#   claude-fix-transcripts --all     # 扫描 ~/.claude/projects 下全部 .jsonl
#
# 注意：先关闭对应的 Claude Code 会话再修（运行中的会话仍按内存里的旧数据
# 工作，且继续按旧格式写入）。2 分钟内有写入的文件会被视为活跃会话而跳过。
# 原文件备份为 <file>.fixbak。修复后重新 claude --resume 选择该会话即可。
set -u

usage() {
  sed -n '2,20p' "$0"
}

fix_one() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "skip（不存在）: $f"
    return 0
  fi
  local now mtime
  now=$(date +%s)
  mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
  if (( now - mtime < 120 )); then
    echo "skip（2 分钟内有写入，疑似活跃会话，先关闭再修）: $f"
    return 0
  fi
  if ! grep -qE '"(tool_use_)?id":"[A-Za-z][A-Za-z0-9_]*:[0-9]+"|"text":""' "$f"; then
    echo "ok（无需修复）: $f"
    return 0
  fi
  sed -E -i.fixbak \
    -e 's/("id":"|"tool_use_id":")([A-Za-z][A-Za-z0-9_]*):([0-9]+")/\1\2_\3/g' \
    -e 's/"text":""/"text":" "/g' \
    -e '/"role":"(user|assistant)"/s/"content":\[\]/"content":[{"type":"text","text":" "}]/g' \
    -e '/"role":"(user|assistant)"/s/"content":""/"content":" "/g' \
    "$f"
  if command -v jq >/dev/null 2>&1 && ! jq -e . "$f" >/dev/null 2>&1; then
    echo "ERROR: 修复后 JSONL 校验失败，备份在 $f.fixbak，请手动恢复" >&2
    return 1
  fi
  echo "fixed: $f（备份: $f.fixbak）"
  return 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

rc=0
if [[ "${1:-}" == "--all" ]]; then
  while IFS= read -r f; do
    fix_one "$f" || rc=1
  done < <(find "$HOME/.claude/projects" -name '*.jsonl' -type f 2>/dev/null)
  exit "$rc"
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

for f in "$@"; do
  fix_one "$f" || rc=1
done
echo "提示：修复后请退出并重开会话（claude --resume 选择该会话）。"
exit "$rc"
EOF

install_wrapper "$BIN_DIR/codex-deepseek" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CLIENT_ENV="${LITELLM_CLIENT_ENV:-$HOME/.config/litellm/client.env}"
if [[ -f "$CLIENT_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$CLIENT_ENV"
  set +a
fi
: "${LITELLM_API_KEY:?请先在 ~/.config/litellm/client.env 写入 LITELLM_API_KEY}"

exec env \
  -u OPENAI_BASE_URL \
  -u OPENAI_API_KEY \
  LITELLM_API_KEY="$LITELLM_API_KEY" \
  codex -p deepseek "$@"
EOF

install_wrapper "$BIN_DIR/codex-kimi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CLIENT_ENV="${LITELLM_CLIENT_ENV:-$HOME/.config/litellm/client.env}"
if [[ -f "$CLIENT_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$CLIENT_ENV"
  set +a
fi
: "${LITELLM_API_KEY:?请先在 ~/.config/litellm/client.env 写入 LITELLM_API_KEY}"

exec env \
  -u OPENAI_BASE_URL \
  -u OPENAI_API_KEY \
  LITELLM_API_KEY="$LITELLM_API_KEY" \
  codex -p kimi "$@"
EOF

install_wrapper "$BIN_DIR/codex-official" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec env \
  -u OPENAI_BASE_URL \
  -u LITELLM_API_KEY \
  codex -p openai "$@"
EOF

mkdir -p "$(dirname "$CODEX_TOML")"
touch "$CODEX_TOML"
CODEX_BASE_URL="${BASE_URL}/v1"
OFFICIAL_MODEL="gpt-5.1-codex-max"
if grep -qE '^model = "' "$CODEX_TOML"; then
  OFFICIAL_MODEL="$(sed -n 's/^model = "\([^"]*\)".*/\1/p' "$CODEX_TOML" | head -n1)"
fi

if grep -q '^\[model_providers.litellm\]' "$CODEX_TOML"; then
  python3 - "$CODEX_TOML" "$CODEX_BASE_URL" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
base = sys.argv[2]
text = path.read_text()
out = []
in_litellm = False
for line in text.splitlines(True):
    if line.startswith("[") and line.strip() == "[model_providers.litellm]":
        in_litellm = True
        out.append(line)
        continue
    if in_litellm and line.startswith("["):
        in_litellm = False
    if in_litellm and line.startswith("base_url"):
        out.append(f'base_url = "{base}"\n')
        continue
    out.append(line)
path.write_text("".join(out))
PY
  echo "已更新 Codex LiteLLM base_url"
else
  cat >> "$CODEX_TOML" <<EOF

[model_providers.litellm]
name = "LiteLLM"
base_url = "${CODEX_BASE_URL}"
env_key = "LITELLM_API_KEY"
wire_api = "responses"
request_max_retries = 4
stream_max_retries = 10
stream_idle_timeout_ms = 3600000
EOF
  echo "已追加 [model_providers.litellm]"
fi

append_profile() {
  local name="$1"
  local body="$2"
  if grep -q "^\[profiles.${name}\]" "$CODEX_TOML"; then
    echo "Codex profile 已存在：${name}"
    return
  fi
  printf '\n%s\n' "$body" >> "$CODEX_TOML"
  echo "已追加 [profiles.${name}]"
}

append_profile deepseek "$(cat <<'EOF'
[profiles.deepseek]
model = "DeepSeek-V4-Flash-0731"
model_provider = "litellm"
EOF
)"
append_profile kimi "$(cat <<'EOF'
[profiles.kimi]
model = "Kimi-K3"
model_provider = "litellm"
EOF
)"
append_profile openai "$(cat <<EOF
[profiles.openai]
model = "${OFFICIAL_MODEL}"
model_provider = "openai"
EOF
)"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if [[ -f "$HOME/.bashrc" ]] && grep -Fq '$HOME/.local/bin' "$HOME/.bashrc"; then
  echo "~/.bashrc 已包含 ~/.local/bin"
else
  echo "$PATH_LINE" >> "$HOME/.bashrc"
  echo "已把 ~/.local/bin 写入 ~/.bashrc"
fi

echo
echo "已安装命令："
echo "  claude-kimi          # Claude Code + Kimi K3"
echo "  claude-deepseek      # Claude Code + DeepSeek V4 Flash"
echo "  claude-official      # Anthropic 官方"
echo "  claude-fix-transcripts  # 修复 Kimi/DeepSeek 旧会话记录（供官方 resume）"
echo "  codex-deepseek       # Codex + DeepSeek V4 Flash"
echo "  codex-kimi           # Codex + Kimi K3"
echo "  codex-official       # OpenAI 官方"
echo
echo "client.env: $CLIENT_ENV"
echo "LiteLLM:    $BASE_URL"
echo "新开一个终端后直接跑 claude-kimi 或 codex-deepseek。"

if ! command -v claude >/dev/null 2>&1; then
  echo "WARN: 未找到 claude。先安装：npm install -g @anthropic-ai/claude-code" >&2
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "WARN: 未找到 codex。先安装：npm install -g @openai/codex" >&2
fi
if [[ -f "$CLAUDE_SETTINGS" ]] && grep -q '"env"' "$CLAUDE_SETTINGS"; then
  echo "WARN: ~/.claude/settings.json 含 env 字段，会覆盖 wrapper 环境变量。跑 claude-kimi 前清掉 ANTHROPIC_*。" >&2
fi
if [[ -f "$CLAUDE_SETTINGS" ]] && grep -Eq '"model"[[:space:]]*:[[:space:]]*"opus' "$CLAUDE_SETTINGS"; then
  echo "WARN: ~/.claude/settings.json 的 model 仍是 opus*。claude-kimi 若 /status 还显示 opus，改成 Kimi-K3 或删掉该字段。" >&2
fi
