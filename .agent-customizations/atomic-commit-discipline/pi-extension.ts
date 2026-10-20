import {
  COMMIT_DISCIPLINE,
  commitBlockReason,
  inspectStagedDiff,
  isGitCommitCommand,
} from "./commit-guard.mjs";
import {
  isToolCallEventType,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
  let approvedFingerprint: string | undefined;

  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n${COMMIT_DISCIPLINE}`,
  }));

  pi.registerTool({
    name: "assess_atomic_commit",
    label: "Assess Atomic Commit",
    description: "Inspect the staged diff before a git commit and record that it is one self-contained, verified change.",
    promptSnippet: "Assess the staged diff immediately before every git commit",
    promptGuidelines: [
      "Use assess_atomic_commit immediately before each git commit. Do not commit when it reports a blocker.",
    ],
    parameters: Type.Object({
      summary: Type.String({ description: "The single outcome this commit delivers." }),
      verification: Type.String({ description: "The relevant checks already run for this staged change." }),
      largeCommitApprovedByUser: Type.Optional(Type.Boolean({
        description: "True only when the user explicitly approved an inseparable large commit.",
      })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const staged = inspectStagedDiff(ctx.cwd);
      if (staged.kind === "not-repository") {
        return {
          content: [{ type: "text", text: "The current directory is not a Git repository." }],
          details: { approved: false },
        };
      }
      if (staged.kind === "empty") {
        return {
          content: [{ type: "text", text: "There are no staged changes to assess." }],
          details: { approved: false },
        };
      }
      if (staged.whitespaceErrors) {
        return {
          content: [{ type: "text", text: `Blocked: staged whitespace errors:\n${staged.whitespaceErrors}` }],
          details: { approved: false },
        };
      }
      if (staged.isLarge && !params.largeCommitApprovedByUser) {
        return {
          content: [{
            type: "text",
            text: `Blocked: ${staged.files.length} files and ${staged.changedLines} changed lines. Split the commit, or obtain explicit user approval for an inseparable large commit.`,
          }],
          details: { approved: false },
        };
      }

      approvedFingerprint = staged.fingerprint;
      const approval = staged.isLarge ? " Large commit approval was recorded." : "";
      return {
        content: [{
          type: "text",
          text: `Approved staged commit: ${params.summary}\nVerification: ${params.verification}\n${staged.files.length} files, ${staged.changedLines} changed lines.${approval}`,
        }],
        details: { approved: true, fingerprint: staged.fingerprint },
      };
    },
  });

  pi.on("tool_call", (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;
    const command = event.input.command;
    if (!isGitCommitCommand(command)) return;

    const basicBlocker = commitBlockReason(ctx.cwd, command);
    if (basicBlocker) {
      return { block: true, reason: basicBlocker, terminate: true };
    }

    const staged = inspectStagedDiff(ctx.cwd, command);
    if (staged.kind !== "changes") return;
    if (approvedFingerprint !== staged.fingerprint) {
      return {
        block: true,
        reason: "Call assess_atomic_commit after staging this exact diff, then run the commit again.",
        terminate: true,
      };
    }
    approvedFingerprint = undefined;
  });
}
