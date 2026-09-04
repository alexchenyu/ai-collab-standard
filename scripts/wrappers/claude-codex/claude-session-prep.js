"use strict";

const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const VALID_TOOL_ID = /^[a-zA-Z0-9_-]+$/;
const LARGE_IMAGE_BASE64_CHARS = 100000;
const IMAGE_PLACEHOLDER =
  "[Large image omitted during backend switch; the original image remains on disk.]";

function fail(message) {
  console.error(`claude-switch: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const options = {
    backend: "",
    cwd: process.cwd(),
    mode: "continue",
    sessionId: "",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--backend") {
      options.backend = argv[++index] || "";
    } else if (arg === "--cwd") {
      options.cwd = path.resolve(argv[++index] || "");
    } else if (arg === "--continue") {
      options.mode = "continue";
      options.sessionId = "";
    } else if (arg === "--resume") {
      options.mode = "resume";
      options.sessionId = argv[++index] || "";
    } else {
      fail(`unknown argument: ${arg}`);
    }
  }

  if (!["kimi", "official"].includes(options.backend)) {
    fail("--backend must be official or kimi");
  }
  if (options.mode === "resume" && !options.sessionId) {
    fail("--resume requires a session ID");
  }
  return options;
}

function sessionFiles(configDir) {
  const projectsDir = path.join(configDir, "projects");
  if (!fs.existsSync(projectsDir)) return [];

  const files = [];
  for (const project of fs.readdirSync(projectsDir, { withFileTypes: true })) {
    if (!project.isDirectory()) continue;
    const projectDir = path.join(projectsDir, project.name);
    for (const entry of fs.readdirSync(projectDir, { withFileTypes: true })) {
      if (entry.isFile() && entry.name.endsWith(".jsonl")) {
        files.push(path.join(projectDir, entry.name));
      }
    }
  }
  return files;
}

function parseTranscript(file) {
  const text = fs.readFileSync(file, "utf8");
  const trailingNewline = text.endsWith("\n");
  const lines = text.split("\n");
  if (trailingNewline) lines.pop();
  const records = lines.map((line, index) => {
    try {
      return JSON.parse(line);
    } catch (error) {
      throw new Error(`${file}:${index + 1}: invalid JSON: ${error.message}`);
    }
  });
  return { records, trailingNewline };
}

function relatedPath(left, right) {
  const relative = path.relative(left, right);
  return (
    relative === "" ||
    (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative))
  );
}

function transcriptMatchesCwd(file, cwd) {
  const { records } = parseTranscript(file);
  return records.some((record) => {
    const recordedCwd = record.cwd;
    return (
      typeof recordedCwd === "string" &&
      (relatedPath(cwd, recordedCwd) || relatedPath(recordedCwd, cwd))
    );
  });
}

function findSession(options, configDir) {
  const files = sessionFiles(configDir);
  if (options.mode === "resume") {
    const matches = files.filter(
      (file) => path.basename(file, ".jsonl") === options.sessionId,
    );
    if (matches.length === 0) fail(`session not found: ${options.sessionId}`);
    if (matches.length > 1) fail(`session ID is ambiguous: ${options.sessionId}`);
    return matches[0];
  }

  const matches = files
    .filter((file) => transcriptMatchesCwd(file, options.cwd))
    .map((file) => ({ file, mtimeMs: fs.statSync(file).mtimeMs }))
    .sort((left, right) => right.mtimeMs - left.mtimeMs);
  if (matches.length === 0) {
    fail(`no session found for current project: ${options.cwd}`);
  }
  return matches[0].file;
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function assertStable(file) {
  const milliseconds = Number(process.env.CLAUDE_SWITCH_STABILITY_MS ?? "2000");
  if (!Number.isFinite(milliseconds) || milliseconds < 0) {
    fail("CLAUDE_SWITCH_STABILITY_MS must be a non-negative number");
  }
  if (milliseconds === 0) return;

  const before = fs.statSync(file);
  await delay(milliseconds);
  const after = fs.statSync(file);
  if (before.size !== after.size || before.mtimeMs !== after.mtimeMs) {
    fail("session is still being written; exit Claude Code and retry");
  }
}

function safeToolId(toolId) {
  if (VALID_TOOL_ID.test(toolId)) return toolId;
  const digest = crypto.createHash("sha256").update(toolId).digest("hex").slice(0, 20);
  return `toolu_switch_${digest}`;
}

function collectToolIds(value, idMap) {
  if (Array.isArray(value)) {
    value.forEach((child) => collectToolIds(child, idMap));
    return;
  }
  if (!value || typeof value !== "object") return;

  if (value.type === "tool_use" && typeof value.id === "string") {
    idMap.set(value.id, safeToolId(value.id));
  }
  Object.values(value).forEach((child) => collectToolIds(child, idMap));
}

function sanitizeValue(value, idMap, stats) {
  if (Array.isArray(value)) {
    return value.map((child) => sanitizeValue(child, idMap, stats));
  }
  if (!value || typeof value !== "object") return value;

  if (
    value.type === "image" &&
    value.source?.type === "base64" &&
    typeof value.source.data === "string" &&
    value.source.data.length > LARGE_IMAGE_BASE64_CHARS
  ) {
    stats.images += 1;
    return { type: "text", text: IMAGE_PLACEHOLDER };
  }

  const sanitized = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === "provider_specific_fields") {
      stats.providerFields += 1;
      continue;
    }
    sanitized[key] = sanitizeValue(child, idMap, stats);
  }

  if (sanitized.type === "tool_use" && typeof sanitized.id === "string") {
    const replacement = idMap.get(sanitized.id) || safeToolId(sanitized.id);
    if (replacement !== sanitized.id) stats.toolIds += 1;
    sanitized.id = replacement;
  }
  if (sanitized.type === "tool_result" && typeof sanitized.tool_use_id === "string") {
    const replacement =
      idMap.get(sanitized.tool_use_id) || safeToolId(sanitized.tool_use_id);
    if (replacement !== sanitized.tool_use_id) stats.toolIds += 1;
    sanitized.tool_use_id = replacement;
  }
  if (sanitized.type === "text" && sanitized.text === "") {
    sanitized.text = " ";
    stats.emptyBlocks += 1;
  }
  if (
    ["assistant", "user"].includes(sanitized.role) &&
    (sanitized.content === "" ||
      (Array.isArray(sanitized.content) && sanitized.content.length === 0))
  ) {
    sanitized.content = [{ type: "text", text: " " }];
    stats.emptyBlocks += 1;
  }
  if (
    sanitized.file &&
    typeof sanitized.file === "object" &&
    typeof sanitized.file.base64 === "string" &&
    sanitized.file.base64.length > LARGE_IMAGE_BASE64_CHARS
  ) {
    sanitized.file.base64 = "";
    sanitized.file.omittedFromTranscript = true;
    stats.imageMetadata += 1;
  }
  return sanitized;
}

function timestamp() {
  return new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

function writeRepair(file, transcript, records, stats, backend) {
  const changed =
    stats.toolIds > 0 ||
    stats.emptyBlocks > 0 ||
    stats.images > 0 ||
    stats.imageMetadata > 0 ||
    stats.providerFields > 0;
  if (!changed) {
    console.error(`claude-switch: session already portable for ${backend}`);
    return;
  }

  const backup = `${file}.switchbak-${timestamp()}`;
  const temp = `${file}.switch-${process.pid}.tmp`;
  fs.copyFileSync(file, backup, fs.constants.COPYFILE_EXCL);
  const mode = fs.statSync(file).mode;
  const body =
    records.map((record) => JSON.stringify(record)).join("\n") +
    (transcript.trailingNewline ? "\n" : "");
  try {
    fs.writeFileSync(temp, body, { encoding: "utf8", mode });
    parseTranscript(temp);
    fs.renameSync(temp, file);
  } catch (error) {
    if (fs.existsSync(temp)) fs.unlinkSync(temp);
    throw error;
  }

  console.error(
    `claude-switch: prepared ${path.basename(file, ".jsonl")} for ${backend}; ` +
      `tool_ids=${stats.toolIds}, empty_blocks=${stats.emptyBlocks}, ` +
      `images=${stats.images}, provider_fields=${stats.providerFields}, backup=${backup}`,
  );
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const configDir =
    process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude");
  const file = findSession(options, configDir);
  await assertStable(file);

  const transcript = parseTranscript(file);
  const idMap = new Map();
  transcript.records.forEach((record) => collectToolIds(record, idMap));
  const stats = {
    toolIds: 0,
    emptyBlocks: 0,
    images: 0,
    imageMetadata: 0,
    providerFields: 0,
  };
  const records = transcript.records.map((record) =>
    sanitizeValue(record, idMap, stats),
  );
  writeRepair(file, transcript, records, stats, options.backend);
  process.stdout.write(path.basename(file, ".jsonl"));
}

main().catch((error) => fail(error.message));
