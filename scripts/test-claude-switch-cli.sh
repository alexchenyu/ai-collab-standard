#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCH="$SCRIPT_DIR/wrappers/claude-codex/claude-switch"
PREP="$SCRIPT_DIR/wrappers/claude-codex/claude-session-prep.js"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CONFIG_DIR="$TMP_DIR/.claude"
PROJECT_DIR="$TMP_DIR/project"
PROJECT_STORE="$CONFIG_DIR/projects/-fixture-project"
BIN_DIR="$TMP_DIR/bin"
SESSION_ID="33333333-3333-4333-8333-333333333333"

mkdir -p "$PROJECT_DIR" "$PROJECT_STORE" "$BIN_DIR"
printf '%s\n' \
  "{\"type\":\"user\",\"cwd\":\"$PROJECT_DIR\",\"sessionId\":\"$SESSION_ID\",\"message\":{\"role\":\"user\",\"content\":\"fixture\"}}" \
  > "$PROJECT_STORE/$SESSION_ID.jsonl"

cp "$SWITCH" "$PREP" "$BIN_DIR/"

cat > "$BIN_DIR/claude-official" <<'EOF'
#!/usr/bin/env bash
printf 'official'
printf ' <%s>' "$@"
printf '\n'
EOF
cat > "$BIN_DIR/claude-kimi" <<'EOF'
#!/usr/bin/env bash
printf 'kimi'
printf ' <%s>' "$@"
printf '\n'
EOF
chmod 755 "$BIN_DIR/claude-switch" "$BIN_DIR/claude-official" "$BIN_DIR/claude-kimi"

official_output="$(
  cd "$PROJECT_DIR"
  PATH="$BIN_DIR:$PATH" CLAUDE_CONFIG_DIR="$CONFIG_DIR" CLAUDE_SWITCH_STABILITY_MS=0 \
    "$BIN_DIR/claude-switch" official --resume "$SESSION_ID" --permission-mode plan
)"
[[ "$official_output" == \
  "official <--model> <default> <--resume> <$SESSION_ID> <--permission-mode> <plan>" ]]

kimi_output="$(
  cd "$PROJECT_DIR"
  PATH="$BIN_DIR:$PATH" CLAUDE_CONFIG_DIR="$CONFIG_DIR" CLAUDE_SWITCH_STABILITY_MS=0 \
    "$BIN_DIR/claude-switch" kimi --continue
)"
[[ "$kimi_output" == "kimi <--resume> <$SESSION_ID>" ]]

if "$BIN_DIR/claude-switch" unsupported --continue; then
  echo "Expected unsupported backend to fail" >&2
  exit 1
fi

echo "PASS: claude-switch launches the selected backend with the prepared session"
