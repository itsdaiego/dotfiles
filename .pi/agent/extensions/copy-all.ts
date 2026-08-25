import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type ClipboardCommand = { command: string; args: string[] };

function clipboardCommands(): ClipboardCommand[] {
  const commands: ClipboardCommand[] = [];
  if (process.env.WAYLAND_DISPLAY) commands.push({ command: "wl-copy", args: [] });
  if (process.env.DISPLAY) {
    commands.push({ command: "xclip", args: ["-selection", "clipboard"] });
    commands.push({ command: "xsel", args: ["--clipboard", "--input"] });
  }
  return commands;
}

function copy(command: ClipboardCommand, text: string): Promise<void> {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command.command, command.args, { stdio: ["pipe", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk: Buffer) => {
      stderr = (stderr + chunk.toString()).slice(-2_000);
    });
    child.once("error", reject);
    child.once("close", (code) => {
      if (code === 0) resolvePromise();
      else reject(new Error(stderr.trim() || `${command.command} exited with code ${code}`));
    });
    child.stdin.end(text);
  });
}

async function copyToClipboard(text: string): Promise<string> {
  const errors: string[] = [];
  for (const command of clipboardCommands()) {
    try {
      await copy(command, text);
      return command.command;
    } catch (error) {
      errors.push(`${command.command}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  throw new Error(errors.length ? errors.join("; ") : "No Wayland or X11 clipboard command is available");
}

/** Return only visible message text; omit thinking, tool calls, images, and metadata. */
function messageText(content: unknown): string {
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";
  return content
    .flatMap((block) => {
      if (!block || typeof block !== "object") return [];
      const value = block as { type?: unknown; text?: unknown };
      return value.type === "text" && typeof value.text === "string" ? [value.text.trim()] : [];
    })
    .filter(Boolean)
    .join("\n\n");
}

export default function copyAllExtension(pi: ExtensionAPI) {
  pi.registerCommand("copy-all", {
    description: "Copy the current conversation's user prompts and assistant responses as clean Markdown",
    handler: async (_args, ctx) => {
      const sections: string[] = [];

      // The active branch is the conversation visible in the current Pi session.
      for (const entry of ctx.sessionManager.getBranch()) {
        if (entry.type !== "message") continue;
        const message = entry.message;
        if (message.role !== "user" && message.role !== "assistant") continue;

        const text = messageText(message.content);
        if (!text) continue;
        sections.push(`## ${message.role === "user" ? "User" : "Assistant"}\n\n${text}`);
      }

      if (sections.length === 0) {
        ctx.ui.notify("No user/assistant conversation text is available to copy.", "warning");
        return;
      }

      try {
        const command = await copyToClipboard(`# Conversation\n\n${sections.join("\n\n")}`);
        ctx.ui.notify(`Copied ${sections.length} prompts/responses via ${command}.`, "info");
      } catch (error) {
        ctx.ui.notify(`Could not copy the conversation: ${error instanceof Error ? error.message : String(error)}`, "error");
      }
    },
  });
}
