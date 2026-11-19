// @ts-nocheck

import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const paneId = process.env.HERDR_PANE_ID;
const tabId = process.env.HERDR_TAB_ID;
const herdrEnabled = process.env.HERDR_ENV === "1" && !!paneId;
const rexSession = process.env.REX_SESSION;
const rexBlock = process.env.REX_BLOCK;
const rexEnabled = !!rexSession && !!rexBlock;
const renameContext =
  "The current root agent is running inside Herdr and has no task name. " +
  "Before substantive work, infer a concise task description from the user's prompt. " +
  "Convert it to a lowercase ASCII kebab-case slug with two to five useful words and " +
  "at most 32 characters. Run `herdr agent rename \"$HERDR_PANE_ID\" \"<slug>\"` " +
  "once. Herdr's bold top line combines the workspace/project name with the harness " +
  "tab label (for example, `chessan · pi`). The inferred task name belongs on the " +
  "lower description line. Do not rename an agent that already has a task name, and " +
  "do not rename subagents.";
const rexRenameContext =
  "The current root agent is running in Rex pane " +
  `${rexBlock} inside session ${rexSession}. Before substantive work, infer a concise ` +
  "task description from the user's prompt. Convert it to a lowercase ASCII kebab-case " +
  "slug with two to four useful words and at most 32 characters. Run `\"$REX_BIN_DIR/rex\" " +
  "block rename -s \"$REX_SESSION\" \"$REX_BLOCK\" \"<slug>\"` once. Keep an existing " +
  "pane label only when it already describes the same work. Rename the pane again when " +
  "the topic changes. Do not rename the containing Rex session or another pane.";

type AgentDetails = { needsName: boolean } | null;

export function rexBlockNameLockPath(blockId = rexBlock): string {
  if (!blockId) {
    return "";
  }

  const stateHome = process.env.XDG_STATE_HOME || join(homedir(), ".local", "state");
  return join(
    stateHome,
    "rex",
    "block-name-locks",
    blockId.replace(/^block:/, ""),
  );
}

function isRexBlockNameLocked(): boolean {
  const lockPath = rexBlockNameLockPath();
  return lockPath !== "" && existsSync(lockPath);
}

function getAgentDetails(): Promise<AgentDetails> {
  if (!herdrEnabled) {
    return Promise.resolve(null);
  }

  return new Promise((resolve) => {
    execFile(
      "herdr",
      ["agent", "get", paneId!],
      { timeout: 1000 },
      (error, stdout) => {
        if (error) {
          resolve(null);
          return;
        }

        try {
          const payload = JSON.parse(stdout);
          const agent = payload?.result?.agent;
          resolve(
            agent ? { needsName: !agent.name } : null,
          );
        } catch {
          resolve(null);
        }
      },
    );
  });
}

function setHarnessTabLabel(): Promise<void> {
  if (!tabId) {
    return Promise.resolve();
  }

  return new Promise((resolve) => {
    execFile(
      "herdr",
      ["tab", "rename", tabId, "pi"],
      { timeout: 1000 },
      () => resolve(),
    );
  });
}

export default function (pi) {
  if (!herdrEnabled && !rexEnabled) {
    return;
  }

  pi.on("before_agent_start", async (event) => {
    const contexts: string[] = [];

    if (herdrEnabled) {
      await setHarnessTabLabel();

      const details = await getAgentDetails();
      if (details?.needsName) {
        contexts.push(renameContext);
      }
    }

    if (rexEnabled && !isRexBlockNameLocked()) {
      contexts.push(rexRenameContext);
    }

    if (contexts.length === 0) {
      return;
    }

    return {
      systemPrompt: `${event.systemPrompt}\n\n${contexts.join("\n\n")}`,
    };
  });
}
