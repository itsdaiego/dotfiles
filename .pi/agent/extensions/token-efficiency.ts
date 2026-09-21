import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import {
  compact,
  isToolCallEventType,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";

const rtkPath = `${process.env.HOME ?? ""}/.local/bin/rtk`;
const rtk = existsSync(rtkPath) ? rtkPath : "rtk";

const CAVEMAN_COMPACTION = [
  "Apply lossless Caveman Compression to every prose field in this checkpoint.",
  "Preserve every fact, number, name, path, constraint, exception, decision, and logical step exactly.",
  "Use short atomic active-voice sentences. Remove only predictable grammar, articles, connectives, and filler.",
  "Keep the required headings, checklist markers, file paths, function names, error messages, and XML file lists unchanged.",
].join(" ");

function rewriteWithRtk(command: string): string | undefined {
  const result = spawnSync(rtk, ["rewrite", command], {
    encoding: "utf8",
    timeout: 2_000,
    windowsHide: true,
  });
  if (result.error) return undefined;

  const rewritten = result.stdout.trim();
  return rewritten && rewritten !== command ? rewritten : undefined;
}

export default function (pi: ExtensionAPI) {
  // Enforce RTK's supported command proxies before Pi executes LLM bash calls.
  pi.on("tool_call", (event) => {
    if (!isToolCallEventType("bash", event)) return;
    if (event.input.command.includes("rtk ")) return;

    const rewritten = rewriteWithRtk(event.input.command);
    if (rewritten) event.input.command = rewritten;
  });

  // Replace Pi's normal compaction with the same compactor plus Caveman's
  // lossless-compression instructions. This applies to manual and automatic compaction.
  pi.on("session_before_compact", async (event, ctx) => {
    const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
    if (!auth.ok) return;

    const instructions = [CAVEMAN_COMPACTION, event.customInstructions]
      .filter(Boolean)
      .join("\n\n");
    const result = await compact(
      event.preparation,
      ctx.model,
      auth.apiKey,
      auth.headers,
      instructions,
      event.signal,
      ctx.thinkingLevel,
      undefined,
      auth.env,
    );

    return { compaction: result };
  });
}
