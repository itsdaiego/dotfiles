// @ts-nocheck

import { execFile } from "node:child_process";

const paneId = process.env.HERDR_PANE_ID;
const tabId = process.env.HERDR_TAB_ID;
const enabled = process.env.HERDR_ENV === "1" && !!paneId;
const renameContext =
  "The current root agent is running inside Herdr and has no task name. " +
  "Before substantive work, infer a concise task description from the user's prompt. " +
  "Convert it to a lowercase ASCII kebab-case slug with two to five useful words and " +
  "at most 32 characters. Run `herdr agent rename \"$HERDR_PANE_ID\" \"<slug>\"` " +
  "once. Herdr's bold top line combines the workspace/project name with the harness " +
  "tab label (for example, `chessan · pi`). The inferred task name belongs on the " +
  "lower description line. Do not rename an agent that already has a task name, and " +
  "do not rename subagents.";

type AgentDetails = { harness: string; needsName: boolean } | null;

function getAgentDetails(): Promise<AgentDetails> {
  if (!enabled) {
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
            agent
              ? { harness: agent.agent, needsName: !agent.name }
              : null,
          );
        } catch {
          resolve(null);
        }
      },
    );
  });
}

function setHarnessTabLabel(harness: string): Promise<void> {
  if (!tabId || !["codex", "claude", "pi"].includes(harness)) {
    return Promise.resolve();
  }

  return new Promise((resolve) => {
    execFile(
      "herdr",
      ["tab", "rename", tabId, harness],
      { timeout: 1000 },
      () => resolve(),
    );
  });
}

export default function (pi) {
  if (!enabled) {
    return;
  }

  pi.on("before_agent_start", async (event) => {
    const details = await getAgentDetails();
    if (!details) {
      return;
    }

    await setHarnessTabLabel(details.harness);

    if (!details.needsName) {
      return;
    }

    return {
      systemPrompt: `${event.systemPrompt}\n\n${renameContext}`,
    };
  });
}
