import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SOURCE_LOCATION_INSTRUCTIONS = `
## Repository code source headers

When you include a fenced block that quotes or paraphrases content from the current repository, add a source header immediately before the fence.

Use this exact format:

**Source:** \`path/from/repository/root.ext:START-END\`

Use a single line number instead of a range for a one-line excerpt. Resolve line numbers against the current working tree of the checked-out branch. Verify the path and line numbers with the available file tools before you answer. Never guess a location. If one fence contains content from multiple files or non-contiguous ranges, split it into separate fenced blocks with separate source headers.

Apply this rule to source code, configuration, logs, queries, schemas, markup, diffs, and plain-text excerpts from repository files. Do not add a source header to original examples, proposed code that does not exist in the repository, or shell commands that you provide for the user to run.
`;

export default function sourceLocationHeaders(pi: ExtensionAPI) {
  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n${SOURCE_LOCATION_INSTRUCTIONS}`,
  }));
}
