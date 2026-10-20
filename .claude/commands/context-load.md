---
name: context-load
description: Selectively load file/dir into context, caveman-compressed
---

Load `$ARGUMENTS` (paths) into context efficiently.

Steps:
1. If arg is dir → Glob for source files. Skip: `node_modules/`, lock files, binaries, `dist/`, `build/`, `.next/`, images, `.min.*`.
2. If arg is file → Read directly.
3. For each file >200 lines: invoke `caveman-compression` skill to compress.
4. Output: file list + key signatures/exports/types + open questions. Skip boilerplate.
5. Do NOT dump raw content unless explicitly asked.

If no `$ARGUMENTS`: ask which path.

Caveman-terse output.
