import {
  CHANGE_LOCATION_RULE,
  describeChangeLocation,
  formatChangeLocation,
} from "./location.mjs";
import { type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n${CHANGE_LOCATION_RULE}`,
  }));

  pi.registerTool({
    name: "describe_change_location",
    label: "Describe Change Location",
    description: "Report the worktree path, branch or detached HEAD, upstream, and main-checkout status for a path.",
    promptSnippet: "Describe where changes were made before reporting them",
    promptGuidelines: [
      "Call describe_change_location for each location you changed before you report edits, commits, or pushes.",
    ],
    parameters: Type.Object({
      paths: Type.Optional(Type.Array(Type.String(), {
        description: "Paths you changed. Defaults to the current working directory.",
      })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const paths = params.paths?.length ? params.paths : [ctx.cwd];
      const locations = paths.map((path) => describeChangeLocation(path));
      return {
        content: [{ type: "text", text: locations.map(formatChangeLocation).join("\n\n") }],
        details: { locations },
      };
    },
  });
}
