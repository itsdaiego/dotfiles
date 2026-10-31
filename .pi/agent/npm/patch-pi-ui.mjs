import { copyFile, readdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

async function patch(path, apply) {
  const source = await readFile(path, "utf8");
  const next = apply(source);
  if (next !== source) await writeFile(path, next, "utf8");
}

const modules = resolve(import.meta.dirname, "node_modules");

// Pi's overlay close path can leave the panel focused in fullscreen mode. When
// the last overlay closes, explicitly restore the normal editor and its focus.
async function patchOverlayFocus() {
  const codingAgent = resolve(modules, "@earendil-works/pi-coding-agent");
  const interactiveMode = resolve(codingAgent, "dist/modes/interactive/interactive-mode.js");
  const sourceNeedle = "if (isOverlay)\n                    this.ui.hideOverlay();\n                else\n                    restoreEditor();";
  const sourceReplacement = "if (isOverlay) {\n                    this.ui.hideOverlay();\n                    if (!this.ui.hasOverlay())\n                        restoreEditor();\n                }\n                else\n                    restoreEditor();";
  await patch(interactiveMode, (source) => {
    if (source.includes(sourceReplacement)) return source;
    if (!source.includes(sourceNeedle)) {
      throw new Error("Unsupported pi coding-agent interactive-mode.js: overlay close path not found");
    }
    return source.replace(sourceNeedle, sourceReplacement);
  });

  const chunks = resolve(codingAgent, "dist/bundle/chunks");
  for (const file of await readdir(chunks)) {
    if (!file.endsWith(".js")) continue;
    await patch(resolve(chunks, file), (source) =>
      source.replace(
        "isOverlay?this.ui.hideOverlay():restoreEditor3()",
        "isOverlay?(this.ui.hideOverlay(),this.ui.hasOverlay()||restoreEditor3()):restoreEditor3()",
      ),
    );
  }
}

await patchOverlayFocus();

// The MCP panel must release its overlay focus before closing. Without this,
// fullscreen Pi can render the editor yet drop every subsequent keypress.
await patch(resolve(modules, "pi-mcp-adapter/commands.ts"), (source) => {
  if (source.includes("overlayHandle?.unfocus();")) return source;
  return source
    .replace(
      "            done(undefined);\n            resolve();\n          })().catch((error) => {",
      "            overlayHandle?.unfocus();\n            done(undefined);\n            resolve();\n          })().catch((error) => {",
    )
    .replace(
      "            done(undefined);\n            resolve();\n          });\n        }, { noticeLines, keybindings, theme });",
      "            overlayHandle?.unfocus();\n            done(undefined);\n            resolve();\n          });\n        }, { noticeLines, keybindings, theme });",
    )
    .replace(
      "        return createMcpPanel(config, cache, provenanceMap, callbacks, tui, () => {\n          done(undefined);",
      "        return createMcpPanel(config, cache, provenanceMap, callbacks, tui, () => {\n          overlayHandle?.unfocus();\n          done(undefined);",
    );
});

await patch(
  resolve(modules, "@earendil-works/pi-tui/dist/layout.js"),
  (source) => {
    if (source.includes("const column = box.rect.x;")) return source;
    const needle = "const column = box.rect.x + box.rect.width - 1;";
    if (!source.includes(needle)) {
      throw new Error("Unsupported pi-tui layout.js: scrollbar column not found");
    }
    return source.replace(needle, "const column = box.rect.x;");
  },
);

await patch(resolve(modules, "pi-vim/index.ts"), (source) => {
  const method = /private getDesiredCursorShapeSequence\(\): CursorShapeSequence \{[\s\S]*?\n  \}/;
  if (!method.test(source)) {
    throw new Error("Unsupported pi-vim index.ts: cursor-shape method not found");
  }
  let next = source.replace(
    method,
    `private getDesiredCursorShapeSequence(): CursorShapeSequence {
    // Keep the thick block cursor in every pi-vim mode. The footer identifies
    // INSERT, NORMAL, VISUAL, and EX.
    return BLOCK_CURSOR_SHAPE;
  }`,
  );
  if (!next.includes("BLOCK_CURSOR_SHAPE")) {
    throw new Error("Unable to apply pi-vim block cursor patch");
  }
  if (!/\bBLOCK_CURSOR_SHAPE,/.test(next)) {
    next = next.replace(
      "  type CursorShapeSequence,\n",
      "  type CursorShapeSequence,\n  BLOCK_CURSOR_SHAPE,\n",
    );
  }
  next = next.replace("  INSERT_CURSOR_SHAPE,\n", "");
  return next;
});

// edb-diff-files only supplied diffs inside Git repos and registered its
// cleanup command before its main command. Keep our maintained override so
// `/diff-files` is first, works outside Git, and supports `o` → Neovim.
await copyFile(
	resolve(import.meta.dirname, "overrides/edb-diff-files/index.ts"),
	resolve(modules, "@agnishc/edb-diff-files/src/index.ts"),
);
