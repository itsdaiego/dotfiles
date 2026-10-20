import { auditLocalBranches, BRANCH_CLEANUP_RULE, formatAudit } from "./branches.mjs";
import { isToolCallEventType, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const DESTRUCTIVE_GIT = [
  /\bgit\b[^;&|\n]*\bbranch\b[^;&|\n]*\s(-d|-D|--delete)\b/,
  /\bgit\b[^;&|\n]*\bworktree\s+(remove|prune)\b/,
  /\bgit\b[^;&|\n]*\bpush\b[^;&|\n]*(\s--delete\b|\s-d\b|\s:[^\s]+)/,
];

function isDestructiveGitCommand(command: string): boolean {
  return DESTRUCTIVE_GIT.some((pattern) => pattern.test(command));
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n${BRANCH_CLEANUP_RULE}`,
  }));

  pi.registerTool({
    name: "audit_local_branches",
    label: "Audit Local Branches",
    description:
      "Classify local branches and worktrees as delete candidates, review items, or active. Detects merged, squash-merged, upstream-gone, and backup branches, and stale worktrees. Changes no branch or worktree.",
    promptSnippet: "Audit local branches and worktrees after a merge or at the end of branch work",
    promptGuidelines: [
      "Call audit_local_branches after an MR or PR merges, and after you finish work on a branch.",
      "Show the delete candidates and their commands to the user. Run only the commands the user confirms.",
    ],
    parameters: Type.Object({
      path: Type.Optional(Type.String({ description: "A path in the repository. Defaults to the current working directory." })),
      fetch: Type.Optional(Type.Boolean({ description: "Fetch and prune origin first. Defaults to true." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const audit = auditLocalBranches(params.path ?? ctx.cwd, { fetch: params.fetch ?? true });
      return {
        content: [{ type: "text", text: formatAudit(audit) }],
        details: { audit },
      };
    },
  });

  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;
    const command = event.input.command;
    if (!isDestructiveGitCommand(command)) return;
    if (!ctx.hasUI) {
      return { block: true, reason: "Deleting branches or worktrees requires user confirmation in an interactive Pi session.", terminate: true };
    }
    const allowed = await ctx.ui.confirm(
      "Delete local branches or worktrees?",
      `This command deletes Git branches or worktrees:\n\n${command}`,
    );
    if (!allowed) return { block: true, reason: "User denied the branch or worktree deletion." };
  });
}
