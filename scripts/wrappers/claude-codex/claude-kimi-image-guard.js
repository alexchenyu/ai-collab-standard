"use strict";

const fs = require("fs");
const path = require("path");

const MAX_IMAGE_BYTES = 100000;
const IMAGE_EXTENSIONS = new Set([".gif", ".jpeg", ".jpg", ".png", ".webp"]);

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  input += chunk;
});
process.stdin.on("end", () => {
  try {
    const payload = JSON.parse(input);
    if (payload.tool_name !== "Read") return;

    const requestedPath = payload.tool_input?.file_path;
    if (typeof requestedPath !== "string") return;
    if (!IMAGE_EXTENSIONS.has(path.extname(requestedPath).toLowerCase())) return;

    const resolvedPath = path.resolve(payload.cwd || process.cwd(), requestedPath);
    const size = fs.statSync(resolvedPath).size;
    if (size <= MAX_IMAGE_BYTES) return;

    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason:
            `Kimi image guard: ${requestedPath} is ${size} bytes; the safe limit is ` +
            `${MAX_IMAGE_BYTES} bytes because this gateway counts image base64 against the ` +
            "text context. Create a preview at or below the limit, or use a vision model. " +
            "Do not Read the original image.",
        },
      }),
    );
  } catch {
    // Fail open. Read itself will report malformed input or inaccessible files.
  }
});
