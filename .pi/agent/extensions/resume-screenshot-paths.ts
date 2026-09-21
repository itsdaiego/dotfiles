import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { SessionManager, type SessionInfo } from "@earendil-works/pi-coding-agent";
import { Input, Key, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Scope = "current" | "all";

type ReferenceState = { imageNumber: number };

/** Replace Pi's verbose attachment and skill references without changing other text. */
export function replaceReferences(text: string, state: ReferenceState = { imageNumber: 0 }): string {
  return text
    .replace(
      /(?:\/private)?\/var\/folders\/[\w.-]+(?:\/[\w.-]+)*\/pi-clipboard-[^\s"'`]+?\.(?:png|jpe?g|gif|webp)/gi,
      () => `[Image ${++state.imageNumber}]`,
    )
    .replace(/<skills?:\s*([^>\s]+)[^>]*>/gi, (_tag, reference: string) => {
      const withoutSkillFile = reference.replace(/[\\/]SKILL\.md$/i, "");
      const name = withoutSkillFile.split(/[\\/]/).filter(Boolean).pop() || reference;
      return `[Skill ${name}]`;
    });
}

/** A resume row is one line, so collapse whitespace after replacing references. */
function summarizeReferences(text: string): string {
  return replaceReferences(text).replace(/\s{2,}/g, " ").trim();
}

function formatAge(date: Date): string {
  const minutes = Math.floor((Date.now() - date.getTime()) / 60_000);
  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d`;
  if (days < 30) return `${Math.floor(days / 7)}w`;
  if (days < 365) return `${Math.floor(days / 30)}mo`;
  return `${Math.floor(days / 365)}y`;
}

class CleanResumePicker {
  private sessions: SessionInfo[];
  private readonly currentSessions: SessionInfo[];
  private filtered: SessionInfo[] = [];
  private selected = 0;
  private readonly search = new Input();
  private showOriginalPaths = false;
  private scope: Scope = "current";
  private allSessions?: SessionInfo[];
  private loadingAll = false;
  private error?: string;
  private cachedWidth?: number;
  private cachedLines?: string[];
  public focused = false;

  constructor(
    currentSessions: SessionInfo[],
    private readonly loadAll: () => Promise<SessionInfo[]>,
    private readonly onDone: (sessionPath: string | null) => void,
    private readonly requestRender: () => void,
    private readonly theme: {
      fg(color: "text" | "accent" | "muted" | "dim" | "warning" | "error", text: string): string;
      bg(color: "selectedBg", text: string): string;
      bold(text: string): string;
    },
  ) {
    this.sessions = currentSessions;
    this.currentSessions = currentSessions;
    this.search.onSubmit = () => this.chooseSelected();
    this.applyFilter();
  }

  private displayText(session: SessionInfo): string {
    const raw = (session.name ?? session.firstMessage).replace(/[\x00-\x1f\x7f]/g, " ").trim();
    if (this.showOriginalPaths) return raw;
    return summarizeReferences(raw) || "(image-only prompt)";
  }

  private applyFilter(): void {
    const query = this.search.getValue().trim().toLowerCase();
    this.filtered = !query
      ? this.sessions
      : this.sessions.filter((session) =>
          `${session.name ?? ""} ${session.firstMessage} ${session.allMessagesText} ${session.cwd}`
            .toLowerCase()
            .includes(query),
        );
    this.selected = Math.min(this.selected, Math.max(0, this.filtered.length - 1));
    this.invalidate();
  }

  private chooseSelected(): void {
    const session = this.filtered[this.selected];
    if (session) this.onDone(session.path);
  }

  private async toggleScope(): Promise<void> {
    if (this.scope === "all") {
      this.scope = "current";
      this.sessions = this.currentSessions;
      this.applyFilter();
      this.requestRender();
      return;
    }

    this.scope = "all";
    if (this.allSessions) {
      this.sessions = this.allSessions;
      this.applyFilter();
      this.requestRender();
      return;
    }

    this.loadingAll = true;
    this.invalidate();
    this.requestRender();
    try {
      this.allSessions = await this.loadAll();
      this.sessions = this.allSessions;
    } catch (error) {
      this.error = error instanceof Error ? error.message : String(error);
      this.scope = "current";
      this.sessions = this.currentSessions;
    } finally {
      this.loadingAll = false;
      this.applyFilter();
      this.requestRender();
    }
  }

  handleInput(data: string): void {
    if (matchesKey(data, Key.escape)) {
      this.onDone(null);
      return;
    }
    if (matchesKey(data, Key.tab)) {
      void this.toggleScope();
      return;
    }
    // R deliberately takes precedence over search input: it restores the full original row.
    if (data === "r" || data === "R") {
      this.showOriginalPaths = !this.showOriginalPaths;
      this.invalidate();
      this.requestRender();
      return;
    }
    if (matchesKey(data, Key.up)) {
      this.selected = Math.max(0, this.selected - 1);
    } else if (matchesKey(data, Key.down)) {
      this.selected = Math.min(this.filtered.length - 1, this.selected + 1);
    } else if (matchesKey(data, Key.pageUp)) {
      this.selected = Math.max(0, this.selected - 10);
    } else if (matchesKey(data, Key.pageDown)) {
      this.selected = Math.min(this.filtered.length - 1, this.selected + 10);
    } else if (matchesKey(data, Key.enter)) {
      this.chooseSelected();
      return;
    } else {
      this.search.handleInput(data);
      this.applyFilter();
    }
    this.invalidate();
    this.requestRender();
  }

  render(width: number): string[] {
    if (this.cachedWidth === width && this.cachedLines) return this.cachedLines;

    this.search.focused = this.focused;
    const scope = this.scope === "current" ? "Current folder" : "All folders";
    const pathMode = this.showOriginalPaths ? "full references" : "compact references";
    const lines = [
      this.theme.bold("Resume Session"),
      this.theme.fg("muted", `Tab ${scope.toLowerCase()} · R ${pathMode} · ↑↓ select · Enter resume · Esc cancel`),
      "",
      ...this.search.render(width),
      "",
    ];

    if (this.loadingAll) {
      lines.push(this.theme.fg("muted", "  Loading all sessions…"));
    } else if (this.error) {
      lines.push(this.theme.fg("error", `  Could not load all sessions: ${this.error}`));
    } else if (this.filtered.length === 0) {
      lines.push(this.theme.fg("muted", `  No sessions in ${scope.toLowerCase()} match this search.`));
    } else {
      const start = Math.max(0, Math.min(this.selected - 5, this.filtered.length - 10));
      const end = Math.min(start + 10, this.filtered.length);
      for (let index = start; index < end; index++) {
        const session = this.filtered[index]!;
        const selected = index === this.selected;
        const right = `${session.messageCount} ${formatAge(session.modified)}`;
        const prefix = selected ? "› " : "  ";
        const available = Math.max(10, width - visibleWidth(prefix) - visibleWidth(right) - 1);
        let message = truncateToWidth(this.displayText(session), available, "…");
        if (selected) message = this.theme.bold(this.theme.fg("accent", message));
        else if (session.name) message = this.theme.fg("warning", message);
        const gap = Math.max(1, width - visibleWidth(prefix + message) - visibleWidth(right));
        let row = `${prefix}${message}${" ".repeat(gap)}${this.theme.fg("dim", right)}`;
        if (selected) row = this.theme.bg("selectedBg", row);
        lines.push(truncateToWidth(row, width));
      }
      if (start > 0 || end < this.filtered.length) {
        lines.push(this.theme.fg("muted", `  (${this.selected + 1}/${this.filtered.length})`));
      }
    }

    this.cachedWidth = width;
    this.cachedLines = lines.map((line) => truncateToWidth(line, width));
    return this.cachedLines;
  }

  invalidate(): void {
    this.cachedWidth = undefined;
    this.cachedLines = undefined;
  }
}

export default function resumeScreenshotPaths(pi: ExtensionAPI): void {
  let opening = false;
  let installTimer: ReturnType<typeof setTimeout> | undefined;

  async function showCleanResume(ctx: ExtensionCommandContext): Promise<void> {
    if (opening || ctx.mode !== "tui") return;
    opening = true;
    try {
      const currentSessions = await SessionManager.list(ctx.cwd);
      const sessionPath = await ctx.ui.custom<string | null>((tui, theme, _keybindings, done) => {
        const picker = new CleanResumePicker(
          currentSessions,
          () => SessionManager.listAll(),
          done,
          () => tui.requestRender(),
          theme,
        );
        return picker;
      });
      if (sessionPath) await ctx.switchSession(sessionPath);
    } finally {
      opening = false;
    }
  }

  // This is display-only: session text and model context retain the real paths.
  pi.registerMarkdownTransformer((markdown, { messageType }) =>
    messageType === "user" ? replaceReferences(markdown) : markdown,
  );

  pi.registerCommand("resume-clean", {
    description: "Resume with [Image N] and [Skill name] references; press R to reveal originals",
    handler: async (_args, ctx) => showCleanResume(ctx),
  });

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    // Pi handles /resume before extension commands. Wrap the active editor so the
    // normal /resume spelling opens this picker without replacing other editor mods.
    installTimer = setTimeout(() => {
      installTimer = undefined;
      const previous = ctx.ui.getEditorComponent();
      if (!previous) return;

      ctx.ui.setEditorComponent((tui, theme, keybindings) => {
        const editor = previous(tui, theme, keybindings);
        const render = editor.render.bind(editor);
        // Keep the real editor value (and thus pasted-image behavior), but display
        // complete references as compact labels whenever they fit on one visual row.
        editor.render = (width: number): string[] => {
          const state: ReferenceState = { imageNumber: 0 };
          return render(width).map((line: string) => replaceReferences(line, state));
        };
        // interactive-mode wires onSubmit *after* this factory returns, so patch it
        // in a microtask after Pi has installed its normal submit callback.
        queueMicrotask(() => {
          const submit = editor.onSubmit;
          editor.onSubmit = (text: string) => {
            if (text.trim() === "/resume") {
              editor.setText("");
              // Re-enter through the extension command so its handler receives a
              // command context (only that context can switch sessions).
              if (ctx.isIdle()) {
                pi.sendUserMessage("/resume-clean", { expandPromptTemplates: true });
              } else {
                pi.sendUserMessage("/resume-clean", {
                  deliverAs: "steer",
                  expandPromptTemplates: true,
                });
              }
              return;
            }
            submit?.(text);
          };
        });
        return editor;
      });
    }, 0);
  });

  pi.on("session_shutdown", () => {
    if (installTimer) clearTimeout(installTimer);
    installTimer = undefined;
  });
}
