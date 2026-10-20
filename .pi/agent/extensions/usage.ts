import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { hyperlink } from "@earendil-works/pi-tui";

const OPENAI_CODEX_USAGE_URL = "https://chatgpt.com/codex/settings/usage";

type Totals = {
  turns: number;
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  reasoning: number;
  total: number;
  cost: number;
};

const formatTokens = (value: number) =>
  new Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 }).format(value);

export default function usageExtension(pi: ExtensionAPI) {
  pi.registerCommand("usage", {
    description: "Show token and estimated-cost usage for the active session branch",
    handler: async (_args, ctx) => {
      const totals: Totals = {
        turns: 0,
        input: 0,
        output: 0,
        cacheRead: 0,
        cacheWrite: 0,
        reasoning: 0,
        total: 0,
        cost: 0,
      };

      for (const entry of ctx.sessionManager.getBranch()) {
        if (entry.type !== "message" || entry.message.role !== "assistant") continue;
        const usage = entry.message.usage;
        if (!usage) continue;

        totals.turns++;
        totals.input += usage.input ?? 0;
        totals.output += usage.output ?? 0;
        totals.cacheRead += usage.cacheRead ?? 0;
        totals.cacheWrite += usage.cacheWrite ?? 0;
        totals.reasoning += usage.reasoning ?? 0;
        totals.total += usage.totalTokens ?? 0;
        totals.cost += usage.cost?.total ?? 0;
      }

      const context = ctx.getContextUsage();
      const lines = [
        `Session usage — ${totals.turns} model turn${totals.turns === 1 ? "" : "s"}`,
        `Input: ${formatTokens(totals.input)}  Output: ${formatTokens(totals.output)}`,
        `Cache read: ${formatTokens(totals.cacheRead)}  Cache write: ${formatTokens(totals.cacheWrite)}`,
        `Reasoning: ${formatTokens(totals.reasoning)}  Total: ${formatTokens(totals.total)}`,
        `Estimated API cost: $${totals.cost.toFixed(4)}`,
        `OpenAI Codex subscription limits: ${hyperlink(OPENAI_CODEX_USAGE_URL, OPENAI_CODEX_USAGE_URL)}`,
      ];

      if (context?.percent != null) {
        lines.push(`Context: ${context.percent.toFixed(1)}% of ${formatTokens(context.contextWindow)}`);
      }

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });
}
