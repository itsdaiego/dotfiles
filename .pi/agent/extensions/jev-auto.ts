import type {
  ExtensionAPI,
  ExtensionContext,
  ModelRoute,
  ModelRouteRequest,
} from "@earendil-works/pi-coding-agent";

import {
  MODEL_CANDIDATES,
  buildRoutingContext,
  chooseCandidate,
  directCandidate,
} from "../../../pi-durable/extensions/_jev-auto-policy.ts";

export { MODEL_CANDIDATES, buildRoutingContext };

const STATUS_ID = "jev-route";

type JevRequest = ModelRouteRequest<never>;

function routeTo(
  request: JevRequest,
  model: ModelRoute["model"],
  thinkingLevel = request.thinkingLevel,
): ModelRoute {
  return { model, thinkingLevel };
}

function displayChoice(ctx: ExtensionContext, label: string): void {
  ctx.ui?.setStatus(STATUS_ID, `Jev → ${label}`);
}

function labelFor(provider: string, id: string): string {
  return MODEL_CANDIDATES.find((candidate) => candidate.provider === provider && candidate.id === id)?.label ?? id;
}

export default function registerJevAuto(pi: ExtensionAPI) {
  pi.registerVirtualModel({
    provider: "jev",
    id: "auto",
    name: "Auto (Jev)",
    thinkingLevels: ["low", "medium", "high", "xhigh"],
    contextWindow: 272_000,
    maxTokens: 128_000,
    input: ["text", "image"],
    async route(request, ctx) {
      const sticky = request.reason === "retry" ? request.failed : request.previous;
      if (request.reason !== "user" && sticky) {
        displayChoice(ctx, labelFor(sticky.model.provider, sticky.model.id));
        return routeTo(request, sticky.model, sticky.thinkingLevel ?? request.thinkingLevel);
      }

      const selected = request.reason === "direct"
        ? await directCandidate(ctx.modelRegistry)
        : await chooseCandidate(ctx.modelRegistry, request.messages, request.signal);
      displayChoice(ctx, selected.candidate.label);
      return routeTo(request, selected.model);
    },
  });

  pi.on("model_select", (event, ctx) => {
    if (event.model.provider !== "jev" || event.model.id !== "auto") {
      ctx.ui.setStatus(STATUS_ID, undefined);
    }
  });

  pi.on("session_shutdown", (_event, ctx) => {
    ctx.ui.setStatus(STATUS_ID, undefined);
  });
}
