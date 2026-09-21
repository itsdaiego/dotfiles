import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type VimMode = "insert" | "normal" | "visual" | "visual-line";

type VimEditor = {
  getMode(): VimMode;
  handleInput(data: string): void;
};

const JJ_TIMEOUT_MS = 300;

function isVimEditor(editor: unknown): editor is VimEditor {
  return (
    typeof editor === "object" &&
    editor !== null &&
    "getMode" in editor &&
    typeof editor.getMode === "function" &&
    "handleInput" in editor &&
    typeof editor.handleInput === "function"
  );
}

export default function (pi: ExtensionAPI) {
  let installTimer: ReturnType<typeof setTimeout> | undefined;
  let stop: (() => void) | undefined;

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    // pi-vim registers its editor in its session_start handler. Run after that handler.
    installTimer = setTimeout(() => {
      installTimer = undefined;
      const previous = ctx.ui.getEditorComponent();
      if (!previous) {
        ctx.ui.notify("vim-jj requires pi-vim to load first.", "warning");
        return;
      }

      ctx.ui.setEditorComponent((tui, theme, keybindings) => {
        const editor = previous(tui, theme, keybindings);
        if (!isVimEditor(editor)) {
          ctx.ui.notify("vim-jj could not find the pi-vim editor.", "warning");
          return editor;
        }

        const originalHandleInput = editor.handleInput.bind(editor);
        let pendingJTimer: ReturnType<typeof setTimeout> | undefined;

        const flushPendingJ = () => {
          if (!pendingJTimer) return;
          clearTimeout(pendingJTimer);
          pendingJTimer = undefined;
          originalHandleInput("j");
        };

        editor.handleInput = (data: string) => {
          if (pendingJTimer) {
            if (data === "j" && editor.getMode() === "insert") {
              clearTimeout(pendingJTimer);
              pendingJTimer = undefined;
              originalHandleInput("\x1b");
              return;
            }
            flushPendingJ();
          }

          if (data === "j" && editor.getMode() === "insert") {
            pendingJTimer = setTimeout(() => {
              pendingJTimer = undefined;
              originalHandleInput("j");
              tui.requestRender();
            }, JJ_TIMEOUT_MS);
            return;
          }

          originalHandleInput(data);
        };

        stop = () => {
          if (pendingJTimer) clearTimeout(pendingJTimer);
          pendingJTimer = undefined;
        };
        return editor;
      });
      ctx.ui.notify("vim-jj enabled: press jj within 300 ms to enter NORMAL mode.", "info");
    }, 0);
  });

  pi.on("session_shutdown", () => {
    if (installTimer) clearTimeout(installTimer);
    installTimer = undefined;
    stop?.();
    stop = undefined;
  });
}
