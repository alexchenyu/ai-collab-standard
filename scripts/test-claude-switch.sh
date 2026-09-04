#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREP="$SCRIPT_DIR/wrappers/claude-codex/claude-session-prep.js"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CONFIG_DIR="$TMP_DIR/.claude"
PROJECT_DIR="$TMP_DIR/work/project"
OTHER_DIR="$TMP_DIR/work/other"
PROJECT_STORE="$CONFIG_DIR/projects/-fixture-project"
OTHER_STORE="$CONFIG_DIR/projects/-fixture-other"
SESSION_ID="11111111-1111-4111-8111-111111111111"
OTHER_SESSION_ID="22222222-2222-4222-8222-222222222222"

mkdir -p "$PROJECT_DIR" "$OTHER_DIR" "$PROJECT_STORE" "$OTHER_STORE"

node - "$PROJECT_STORE/$SESSION_ID.jsonl" "$PROJECT_DIR" <<'NODE'
const fs = require("fs");
const [file, cwd] = process.argv.slice(2);
const image = "A".repeat(100001);
const rows = [
  {
    type: "assistant",
    cwd,
    sessionId: "11111111-1111-4111-8111-111111111111",
    message: {
      role: "assistant",
      content: [
        { type: "text", text: "" },
        {
          type: "tool_use",
          id: "Read:12",
          name: "Read",
          input: { file_path: "plot.png" },
          provider_specific_fields: null,
        },
      ],
    },
  },
  {
    type: "user",
    cwd,
    sessionId: "11111111-1111-4111-8111-111111111111",
    message: {
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: "Read:12",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: "image/png", data: image },
            },
          ],
        },
      ],
    },
    toolUseResult: {
      file: { base64: image, type: "image/png", originalSize: 75001 },
    },
  },
];
fs.writeFileSync(file, rows.map((row) => JSON.stringify(row)).join("\n") + "\n");
NODE

node - "$OTHER_STORE/$OTHER_SESSION_ID.jsonl" "$OTHER_DIR" <<'NODE'
const fs = require("fs");
const [file, cwd] = process.argv.slice(2);
fs.writeFileSync(
  file,
  JSON.stringify({
    type: "user",
    cwd,
    sessionId: "22222222-2222-4222-8222-222222222222",
    message: { role: "user", content: "other project" },
  }) + "\n",
);
NODE

selected="$(
  CLAUDE_CONFIG_DIR="$CONFIG_DIR" CLAUDE_SWITCH_STABILITY_MS=0 \
    node "$PREP" --backend official --continue --cwd "$PROJECT_DIR"
)"
[[ "$selected" == "$SESSION_ID" ]]

node - "$PROJECT_STORE/$SESSION_ID.jsonl" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const rows = fs.readFileSync(file, "utf8").trim().split("\n").map(JSON.parse);
const toolUse = rows[0].message.content[1];
const toolResult = rows[1].message.content[0];
if (!/^[a-zA-Z0-9_-]+$/.test(toolUse.id)) process.exit(1);
if (toolResult.tool_use_id !== toolUse.id) process.exit(1);
if ("provider_specific_fields" in toolUse) process.exit(1);
if (rows[0].message.content[0].text !== " ") process.exit(1);
if (toolResult.content[0].type !== "text") process.exit(1);
if (!toolResult.content[0].text.includes("Large image omitted")) process.exit(1);
if (rows[1].toolUseResult.file.base64 !== "") process.exit(1);
NODE

shopt -s nullglob
backups=("$PROJECT_STORE/$SESSION_ID.jsonl.switchbak-"*)
shopt -u nullglob
[[ "${#backups[@]}" == "1" ]]

selected="$(
  CLAUDE_CONFIG_DIR="$CONFIG_DIR" CLAUDE_SWITCH_STABILITY_MS=0 \
    node "$PREP" --backend kimi --resume "$OTHER_SESSION_ID" --cwd "$PROJECT_DIR"
)"
[[ "$selected" == "$OTHER_SESSION_ID" ]]

if CLAUDE_CONFIG_DIR="$CONFIG_DIR" CLAUDE_SWITCH_STABILITY_MS=0 \
  node "$PREP" --backend official --resume missing-session --cwd "$PROJECT_DIR"; then
  echo "Expected missing session lookup to fail" >&2
  exit 1
fi

echo "PASS: claude-switch prepares explicit and current-project sessions safely"
