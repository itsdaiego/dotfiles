/**
 * Blocks the document extractor typecheck that starts eight Pyright workers and can exhaust system memory.
 */
import { defineExtension, hook, section, ToolTask } from "@earendil-works/pi-durable"

import { isBlockedDocumentExtractorTypecheck } from "./_document-extractor-typecheck-guard.ts"

const BLOCK_REASON =
  "Blocked: document_extractor/typeCheck.sh starts eight Pyright workers and exhausted system memory. Skip this check and report that it was not run."

export default function createDocumentExtractorTypecheckGuard(host: {
  cwdOf?: (conversationId: number) => string
}) {
  return defineExtension({
    name: "daiego-document-extractor-typecheck-guard",
    sections: [
      section(
        "document_extractor_typecheck_guard",
        () =>
          "Do not run src/document_extractor/typeCheck.sh or threaded Pyright in document_extractor. It is blocked because its workers can exhaust system memory. Skip it and report that it was not run.",
      ),
    ],
    hooks: [
      hook(ToolTask, {
        beforeTool: (call, api) => {
          if (call.name !== "bash") return undefined
          const command = (call.arguments as { command?: unknown }).command
          if (typeof command !== "string") return undefined
          const cwd = host.cwdOf?.(api.conversationId) ?? ""
          return isBlockedDocumentExtractorTypecheck(command, cwd)
            ? { block: BLOCK_REASON }
            : undefined
        },
      }),
    ],
  })
}
