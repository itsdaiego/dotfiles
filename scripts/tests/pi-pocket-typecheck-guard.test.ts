import assert from "node:assert/strict"
import test from "node:test"

import { isBlockedDocumentExtractorTypecheck } from "../../pi-durable/extensions/_document-extractor-typecheck-guard.ts"

test("blocks document extractor typecheck commands in Pi Pocket", () => {
  assert.equal(
    isBlockedDocumentExtractorTypecheck(
      'cd /private/tmp/worktrees/butler/task && cd src/document_extractor && PATH="$PWD/.venv/bin:$PATH" ./typeCheck.sh',
      "/Users/daiego",
    ),
    true,
  )
  assert.equal(
    isBlockedDocumentExtractorTypecheck(
      "uv run pyright --threads 8",
      "/private/tmp/worktrees/butler/task/src/document_extractor",
    ),
    true,
  )
})

test("allows unrelated commands and similarly named scripts", () => {
  assert.equal(
    isBlockedDocumentExtractorTypecheck("./typeCheck.sh", "/tmp/another-project"),
    false,
  )
  assert.equal(
    isBlockedDocumentExtractorTypecheck(
      "rg 'typeCheck.sh' src/document_extractor",
      "/private/tmp/worktrees/butler/task",
    ),
    false,
  )
})
