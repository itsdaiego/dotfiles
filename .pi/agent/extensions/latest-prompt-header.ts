import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

/** Keep the latest submitted request in a one-line overlay at screen row zero. */
export default function latestPromptHeader(pi: ExtensionAPI) {
  let latestPrompt = "";
  let requestRender: (() => void) | undefined;
  let overlayHandle: { hide(): void; unfocus(): void } | undefined;

  function toOneLine(text: string): string {
    return text.replace(/\s+/g, " ").trim();
  }

  function restoreLatestPrompt(ctx: ExtensionContext): void {
    for (const entry of [...ctx.sessionManager.getBranch()].reverse()) {
      if (entry.type !== "message" || entry.message.role !== "user") continue;

      const { content } = entry.message;
      latestPrompt = toOneLine(
        typeof content === "string"
          ? content
          : content
              .filter((block) => block.type === "text")
              .map((block) => block.text)
              .join(" "),
      );
      return;
    }
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
    restoreLatestPrompt(ctx);
    showOverlay(ctx);
  });

  pi.on("input", (event, ctx) => {
    if (ctx.mode !== "tui") return;
    latestPrompt = toOneLine(event.text);
    requestRender?.();
  });

  pi.on("session_shutdown", () => {
    overlayHandle?.hide();
  });
}
