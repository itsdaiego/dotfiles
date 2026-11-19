import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { buildRexAgentTitle, findInitialTaskPrompt } from "./lib/rex-agent-title.ts";
import { replaceReferences } from "./resume-screenshot-paths.ts";

/** Keep the latest submitted request in a one-line overlay at screen row zero. */
export default function latestPromptHeader(pi: ExtensionAPI) {
  let latestPrompt = "";
  let taskPrompt = "";
  let requestRender: (() => void) | undefined;
  let overlayHandle: { hide(): void; unfocus(): void } | undefined;

  function toOneLine(text: string): string {
    return replaceReferences(text).replace(/\s+/g, " ").trim();
  }

  function updateTerminalTitle(ctx: ExtensionContext): void {
    ctx.ui.setTitle(buildRexAgentTitle(taskPrompt, path.basename(ctx.cwd)));
  }

  function restorePrompts(ctx: ExtensionContext): void {
    const prompts: string[] = [];
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "message" || entry.message.role !== "user") continue;

      const { content } = entry.message;
      prompts.push(
        toOneLine(
          typeof content === "string"
            ? content
            : content
                .filter((block) => block.type === "text")
                .map((block) => block.text)
                .join(" "),
        ),
      );
    }

    latestPrompt = prompts.at(-1) ?? "";
    taskPrompt = findInitialTaskPrompt(prompts);
  }

  function showOverlay(ctx: ExtensionContext): void {
    // A regular TUI uses terminal scrollback, where no extension can pin a line
    // to the visible viewport. `tuiMode: "fullscreen"` gives this overlay an
    // application-owned viewport, so row 0 remains the physical top row.
    ctx.ui.setHeader(undefined);

    void ctx.ui
      .custom<void>(
        (tui, theme, _keybindings, _done) => {
          requestRender = () => tui.requestRender();
          return {
            render(width: number): string[] {
              if (!latestPrompt || width < 1) return [];
              const text = theme.fg("muted", "Latest request: ") + theme.fg("text", latestPrompt);
              return [theme.bg("customMessageBg", truncateToWidth(text, width))];
            },
            invalidate() {},
          };
        },
        {
          overlay: true,
          overlayOptions: {
            row: 0,
            col: 0,
            width: "100%",
            maxHeight: 1,
            margin: 0,
          },
          onHandle: (handle) => {
            overlayHandle = handle;
            handle.unfocus();
          },
        },
      )
      .finally(() => {
        requestRender = undefined;
        overlayHandle = undefined;
      });
  }

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    restorePrompts(ctx);
    updateTerminalTitle(ctx);
    showOverlay(ctx);
  });

  pi.on("input", (event, ctx) => {
    if (ctx.mode !== "tui") return;
    latestPrompt = toOneLine(event.text);
    taskPrompt ||= findInitialTaskPrompt([latestPrompt]);
    updateTerminalTitle(ctx);
    requestRender?.();
  });

  pi.on("session_shutdown", () => {
    overlayHandle?.hide();
  });
}
