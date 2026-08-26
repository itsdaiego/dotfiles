import { copyFile, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

async function patch(path, apply) {
  const source = await readFile(path, "utf8");
  const next = apply(source);
  if (next !== source) await writeFile(path, next, "utf8");
}

const modules = resolve(import.meta.dirname, "node_modules");

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
