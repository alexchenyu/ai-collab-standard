#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/wrappers/claude-codex/claude-kimi-image-guard.js"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

small_image="$TMP_DIR/small.png"
large_image="$TMP_DIR/large.png"
large_text="$TMP_DIR/large.txt"

dd if=/dev/zero of="$small_image" bs=100000 count=1 status=none
dd if=/dev/zero of="$large_image" bs=100001 count=1 status=none
dd if=/dev/zero of="$large_text" bs=100001 count=1 status=none

run_guard() {
  local file_path="$1"
  printf '{"hook_event_name":"PreToolUse","tool_name":"Read","cwd":"%s","tool_input":{"file_path":"%s"}}' \
    "$TMP_DIR" "$file_path" | node "$GUARD"
}

[[ -z "$(run_guard "$small_image")" ]]
[[ -z "$(run_guard "$large_text")" ]]

decision="$(run_guard "$large_image")"
node -e '
const result = JSON.parse(process.argv[1]);
const output = result.hookSpecificOutput;
if (output.hookEventName !== "PreToolUse") process.exit(1);
if (output.permissionDecision !== "deny") process.exit(1);
if (!output.permissionDecisionReason.includes("100001 bytes")) process.exit(1);
' "$decision"

echo "PASS: Kimi image guard blocks only oversized image reads"
