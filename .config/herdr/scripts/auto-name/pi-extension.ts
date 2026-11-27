// @ts-nocheck

import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const paneId = process.env.HERDR_PANE_ID;
const tabId = process.env.HERDR_TAB_ID;
const herdrEnabled = process.env.HERDR_ENV === "1" && !!paneId;
const rexSession = process.env.REX_SESSION;
const rexBlock = process.env.REX_BLOCK;
const rexEnabled = !!rexSession && !!rexBlock;
const namingContext =
  "The current interactive Pi session has no meaningful name. Before substantive work, " +
  "infer a concise task description from the user's prompt. Convert it to a lowercase " +
  "ASCII kebab-case slug with two to five useful words and at most 32 characters, then " +
  "call `set_agent_session_name` with that slug. Name the underlying task rather than " +
  "copying the prompt, a file path, or an attachment name. Do not name subagents.";

export function normalizeSessionName(value: string): string {
  const normalized = value
    .normalize("NFKD")
    .replace(/[^\x00-\x7F]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

  if (normalized.length <= 32) {
    return normalized;
  }

  const shortened = normalized.slice(0, 32).replace(/-+$/g, "");
  const lastDash = shortened.lastIndexOf("-");
  return lastDash >= 8 ? shortened.slice(0, lastDash) : shortened;
}

export function rexBlockNameLockPath(blockId = rexBlock): string {
  if (!blockId) {
    return "";
  }

  const stateHome = process.env.XDG_STATE_HOME || join(homedir(), ".local", "state");
  return join(stateHome, "rex", "block-name-locks", blockId.replace(/^block:/, ""));
}

function isRexBlockNameLocked(): boolean {
  const lockPath = rexBlockNameLockPath();
  return lockPath !== "" && existsSync(lockPath);
}

export default function (pi) {
  async function setHarnessTabLabel(): Promise<void> {
    if (!tabId) {
      return;
    }

    await pi.exec("herdr", ["tab", "rename", tabId, "pi"], { timeout: 1000 });
  }

  async function syncExternalNames(name: string): Promise<void> {
    const operations: Promise<unknown>[] = [];

    if (herdrEnabled) {
      operations.push(
        pi.exec("herdr", ["agent", "rename", paneId, name], { timeout: 1000 }),
      );
    }

    if (rexEnabled && !isRexBlockNameLocked()) {
      const rex = process.env.REX_BIN_DIR ? join(process.env.REX_BIN_DIR, "rex") : "rex";
      operations.push(
        pi.exec(
          rex,
          ["block", "rename", "-s", rexSession, rexBlock, name],
          { timeout: 1000 },
        ),
      );
    }

    await Promise.allSettled(operations);
  }

  pi.registerTool({
    name: "set_agent_session_name",
    label: "Name session",
    description:
      "Set a concise semantic name for the current interactive Pi session and mirror it to its terminal harness.",
    promptSnippet: "Name the current interactive Pi session from its task",
    parameters: {
      type: "object",
      properties: {
        name: {
          type: "string",
          description: "A concise task name, preferably two to five lowercase kebab-case words.",
        },
      },
      required: ["name"],
      additionalProperties: false,
    },
    async execute(_toolCallId, params) {
      const name = normalizeSessionName(params.name);
      if (!name) {
        throw new Error("Session name must contain at least one ASCII letter or number.");
      }

      pi.setSessionName(name);
      await syncExternalNames(name);

      return {
        content: [{ type: "text", text: `Named the current Pi session ${name}.` }],
        details: { name },
      };
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") {
      return;
    }

    if (herdrEnabled) {
      await setHarnessTabLabel();
    }

    const name = pi.getSessionName();
    if (name) {
      await syncExternalNames(name);
    }
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (ctx.mode !== "tui") {
      return;
    }

    if (herdrEnabled) {
      await setHarnessTabLabel();
    }

    if (pi.getSessionName()) {
      return;
    }

    return {
      systemPrompt: `${event.systemPrompt}\n\n${namingContext}`,
    };
  });
}
