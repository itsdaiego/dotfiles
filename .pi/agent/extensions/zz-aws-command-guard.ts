import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const AWS_BLOCK_REASON =
  "AWS CLI commands are disabled by the global command guard. Give the command to the user instead."
const DELETE_BLOCK_REASON =
  "Recursive forced deletion requires explicit user confirmation in an interactive Pi session."

// Match conservatively so quoting, paths, and shell composition do not bypass the guard.
function containsAwsCommand(command: string): boolean {
  return /\baws\b/i.test(command)
}

function containsRecursiveForcedDelete(command: string): boolean {
  for (const match of command.matchAll(/\brm\b([^;&|\n]*)/gi)) {
    const args = match[1]
    const recursive = /(?:^|\s)(?:--recursive|-[a-z]*r[a-z]*)(?=\s|$)/i.test(args)
    const forced = /(?:^|\s)(?:--force|-[a-z]*f[a-z]*)(?=\s|$)/i.test(args)
    if (recursive && forced) return true
  }
  return false
}

function blockedUserBashResult(reason: string) {
  return {
    result: {
      output: reason,
      exitCode: 126,
      cancelled: false,
      truncated: false,
    },
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return

    const command = event.input.command as string
    if (containsAwsCommand(command)) {
      if (ctx.hasUI) ctx.ui.notify(AWS_BLOCK_REASON, "warning")
      return { block: true, reason: AWS_BLOCK_REASON, terminate: true }
    }

    if (!containsRecursiveForcedDelete(command)) return
    if (!ctx.hasUI) return { block: true, reason: DELETE_BLOCK_REASON, terminate: true }

    const allowed = await ctx.ui.confirm(
      "Allow recursive forced deletion?",
      `The command can delete entire folders without recovery:\n\n${command}`,
    )
    if (!allowed) return { block: true, reason: "User denied recursive forced deletion." }
  })

  pi.on("user_bash", async (event, ctx) => {
    if (containsAwsCommand(event.command)) return blockedUserBashResult(AWS_BLOCK_REASON)
    if (!containsRecursiveForcedDelete(event.command)) return
    if (!ctx.hasUI) return blockedUserBashResult(DELETE_BLOCK_REASON)

    const allowed = await ctx.ui.confirm(
      "Allow recursive forced deletion?",
      `The command can delete entire folders without recovery:\n\n${event.command}`,
    )
    if (!allowed) return blockedUserBashResult("User denied recursive forced deletion.")
  })
}
