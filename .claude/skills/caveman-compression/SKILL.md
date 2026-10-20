---
name: caveman-compression
description: Losslessly compress and decompress text using Caveman Compression — a scheme that strips predictable grammar/connectives/articles while preserving every fact, number, and logical step. Use when the user asks to compress/shorten prose, trim prompt tokens, or decompress text that looks like short telegraphic sentences. Based on the spec at github.com/wilpel/caveman-compression.
---

# Caveman Compression

Lossless semantic compression for LLM contexts. Strips linguistic overhead (grammar, connectives, articles, intensifiers) while preserving facts, numbers, constraints, and the full logical chain.

**Core principle:** Remove only what an LLM can deterministically reconstruct. Keep every fact a reader cannot predict.

## When to invoke

- User asks to "compress", "cavemanize", "shrink", or "shorten tokens for" a block of text.
- User pastes compressed caveman-style text and asks to decompress, expand, or restore.
- User asks to trim a system prompt or long context to save tokens without losing meaning.

Do **not** invoke for: code compression, lossy summarization, TL;DRs, or rewriting for style.

## Compression rules

Apply all nine rules:

1. **Sentence atomicity** — one fact, action, constraint, or step per sentence. No compound sentences.
2. **Word count** — target 2–5 words per sentence. 6–7 allowed only to preserve a constraint or technical term.
3. **Connective elimination** — remove `because, since, however, although, therefore, thus, hence, in order to`. Express cause→effect by sentence order. Keep `if` only when multiple interleaved conditionals would otherwise become ambiguous.
4. **Active voice, present tense** — `Function calculates value.` not `The value is calculated by the function.` Keep past/future only when temporal distinction is load-bearing (`Was O(n). Now O(log n).`).
5. **Preserve specifics** — keep exact numbers and quantities. Never replace `50 million` with `many`, `three` with `several`.
6. **Drop intensifiers only** — remove `very, extremely, quite, rather, really, somewhat`. Keep meaningful descriptors (`critical`, `optional`, `same`, `quickly`).
7. **Omit articles** — drop `a, an, the` when context is unambiguous. Keep when omission conflates generic and specific reference.
8. **Pronouns** — keep `it, we, he, she` when unambiguous. Replace with the noun when the referent is unclear.
9. **Logical completeness** — every inference step must be explicit. A reader must be able to reconstruct the full reasoning chain.

## Anti-patterns to reject

- **Telegraphic ambiguity** — `Function error return null` (word order loses relation). Expand to two sentences.
- **Over-compression** — skipping intermediate reasoning (`Try fix.`) violates rule 9.
- **Information addition** — never add facts the original did not contain.

## Workflow

1. **Extract facts** from the source. List every number, constraint, action, and logical step.
2. **Rewrite** each fact as a 2–5 word atomic sentence in active/present voice.
3. **Sequence** sentences so cause→effect is conveyed by order (replacing removed connectives).
4. **Self-validate** before returning:
   - Fact set of compressed == fact set of original.
   - No logical gap a reader would have to guess across.
   - Token reduction ≥ 30% (typical 15–58%).
5. Report the compressed text and the approximate % token reduction.

## Decompression

Given caveman-compressed text, expand to natural prose:

- Re-insert articles, connectives, and auxiliary verbs.
- Fuse adjacent atomic sentences into compound sentences where cause/effect, sequence, or contrast is implicit in the ordering.
- Preserve all facts and numbers exactly; do **not** add information not present in the compressed form.
- Restore natural tense/voice for the context (narrative past, instructional imperative, etc.).

## Worked examples

**Source (61 tokens)**
> Binary search works by repeatedly dividing the search space in half. First, compare the target value to the middle element. If they match, return the position. If target is less, search the left half. If target is greater, search the right half.

**Compressed (49 tokens, −20%)**
> Binary search divides search space in half. Compare target to middle element. Match found. Return position. Target less than middle. Search left half. Target greater than middle. Search right half.

---

**Source (66 tokens)**
> When debugging the null pointer exception, start by checking the stack trace to identify where the error occurred. Then examine the code at that line to see which variable is null. Add a null check before the dereference to prevent the error from happening again.

**Compressed (54 tokens, −18%)**
> Debugging null pointer exception. Check stack trace. Find error location. Examine code at error line. Identify null variable. Variable needs value check. Add null check before dereference. Prevents error next time.

## Reference

Full specification: https://github.com/wilpel/caveman-compression/blob/main/SPEC.md
