import {
  COMMIT_DISCIPLINE,
  inspectStagedDiff,
} from "./commit-guard.mjs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n${COMMIT_DISCIPLINE}`,
  }));

  pi.registerTool({
    name: "assess_atomic_commit",
    label: "Assess Atomic Commit",
    description: "Inspect the staged diff before a git commit and record that it is one self-contained, verified change.",
    promptSnippet: "Assess the staged diff immediately before every git commit",
    promptGuidelines: [
      "Use assess_atomic_commit as the default check before each git commit when available.",
      "Treat the assessment as advisory. Never let it prevent a necessary commit or task completion.",
    ],
    parameters: Type.Object({
      summary: Type.String({ description: "The single outcome this commit delivers." }),
      verification: Type.String({ description: "The relevant checks already run for this staged change." }),
      largeCommitReason: Type.Optional(Type.String({
        description: "Why a large staged change cannot be split safely or reasonably.",
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
      const largeCommitNote = staged.isLarge
        ? params.largeCommitReason
          ? `\nLarge commit reason: ${params.largeCommitReason}`
          : "\nThis is a large commit. Split it when practical; otherwise explain why and continue."
        : "";
      return {
        content: [{
          type: "text",
          text: `Assessed staged commit: ${params.summary}\nVerification: ${params.verification}\n${staged.files.length} files, ${staged.changedLines} changed lines.${largeCommitNote}`,
        }],
        details: { approved: true, fingerprint: staged.fingerprint, advisory: staged.isLarge },
      };
    },
  });
}
