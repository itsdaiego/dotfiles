#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
}

function parseArgs(argv) {
  const args = { stdout: false };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--stdout") args.stdout = true;
    else if (arg === "--codex" || arg === "--claude" || arg === "--input") {
      const value = argv[index + 1];
      if (!value) throw new Error(`${arg} needs a value`);
      args[arg.slice(2)] = value;
      index += 1;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

function textFromContent(value) {
  if (typeof value === "string") return value.trim();
  if (!Array.isArray(value)) return "";
  return value
    .flatMap((block) => {
      if (!block || typeof block !== "object") return [];
      if (block.type === "tool_result" || block.type === "tool_use") return [];
      return typeof block.text === "string" ? [block.text.trim()] : [];
    })
    .filter(Boolean)
    .join("\n\n");
}

function walk(directory, matches) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) walk(path, matches);
    else if (entry.isFile() && entry.name.endsWith(".jsonl")) matches.push(path);
  }
}

function findSession(root, sessionId) {
  const matches = [];
  if (existsSync(root)) walk(root, matches);
  return matches.find((path) => basename(path).includes(sessionId));
}

function readJsonLines(path) {
  return readFileSync(path, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line, index) => {
      try {
        return JSON.parse(line);
      } catch {
        throw new Error(`Could not parse JSON on line ${index + 1} of ${path}`);
      }
    });
}

function exportCodex(lines) {
  const messages = [];
  for (const record of lines) {
    if (record.type === "session_meta") {
      const text = record.payload?.base_instructions?.text?.trim();
      if (text) messages.push({ role: "System", text });
      continue;
    }
    if (record.type !== "response_item" || record.payload?.type !== "message") continue;
    const role = record.payload.role;
    if (role !== "developer" && role !== "system" && role !== "user") continue;
    const text = textFromContent(record.payload.content);
    if (text) messages.push({ role: role[0].toUpperCase() + role.slice(1), text });
  }
  return messages;
}

function attachmentText(record) {
  const content = record.attachment?.content;
  if (typeof content === "string" && content.trim()) return content.trim();
  if (!Array.isArray(record.rendered)) return "";
  return record.rendered
    .flatMap((item) => (typeof item?.content === "string" ? [item.content.trim()] : []))
    .filter(Boolean)
    .join("\n\n");
}

function exportClaude(lines) {
  const messages = [];
  for (const record of lines) {
    if (record.type === "attachment" && (record.renderedRole === "system" || record.renderedRole === "user")) {
      const text = attachmentText(record);
      if (text) messages.push({ role: record.renderedRole === "system" ? "System" : "User", text });
      continue;
    }
    if (record.type !== "user" || record.message?.role !== "user") continue;
    const text = textFromContent(record.message.content);
    if (text) messages.push({ role: "User", text });
  }
  return messages;
}

function copyToClipboard(text) {
  const candidates = process.platform === "darwin"
    ? [["pbcopy", []]]
    : process.env.WAYLAND_DISPLAY
      ? [["wl-copy", []]]
      : [["xclip", ["-selection", "clipboard"]], ["xsel", ["--clipboard", "--input"]]];
  const errors = [];
  for (const [command, args] of candidates) {
    const result = spawnSync(command, args, { input: text, encoding: "utf8" });
    if (!result.error && result.status === 0) return command;
    errors.push(`${command}: ${result.error?.message || result.stderr?.trim() || `exit ${result.status}`}`);
  }
  throw new Error(`Could not copy to the clipboard (${errors.join("; ")})`);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const explicitKind = args.codex ? "codex" : args.claude ? "claude" : null;
  const codexSessionId = explicitKind === "codex" ? args.codex : process.env.CODEX_SESSION_ID;
  const claudeSessionId = explicitKind === "claude" ? args.claude : process.env.CLAUDE_SESSION_ID;
  if (!explicitKind && codexSessionId && claudeSessionId) throw new Error("Both Codex and Claude session IDs are set; pass --codex or --claude.");
  const kind = explicitKind || (codexSessionId ? "codex" : claudeSessionId ? "claude" : null);
  const sessionId = kind === "codex" ? codexSessionId : claudeSessionId;
  if (!kind || !sessionId) throw new Error("Run this from Codex or Claude Code, or pass --codex <session-id> or --claude <session-id>.");

  const root = kind === "codex" ? join(homedir(), ".codex", "sessions") : join(homedir(), ".claude", "projects");
  const input = args.input || findSession(root, sessionId);
  if (!input || !existsSync(input)) throw new Error(`Could not find the ${kind} session record for ${sessionId}.`);
  if (!statSync(input).isFile()) throw new Error(`Session record is not a file: ${input}`);

  const messages = kind === "codex" ? exportCodex(readJsonLines(input)) : exportClaude(readJsonLines(input));
  if (!messages.length) throw new Error(`No system, developer, or user messages found in ${input}.`);
  const output = [
    "# Conversation inputs",
    "",
    `Source: ${kind === "codex" ? "Codex" : "Claude Code"} session \`${sessionId}\``,
    "",
    ...messages.flatMap(({ role, text }) => [`## ${role}`, "", text, ""]),
  ].join("\n").trimEnd() + "\n";

  if (args.stdout) process.stdout.write(output);
  else {
    const command = copyToClipboard(output);
    process.stdout.write(`Copied ${messages.length} system, developer, and user messages from ${kind} session ${sessionId} via ${command}.\n`);
  }
}

try {
  main();
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
