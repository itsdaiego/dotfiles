import assert from "node:assert/strict";
import test from "node:test";

import registerJevAuto, {
  MODEL_CANDIDATES,
  buildRoutingContext,
} from "../jev-auto.ts";

function model(provider: string, id: string) {
  return { provider, id, reasoning: true, input: ["text", "image"] };
}

function createHarness(options?: {
  available?: Array<ReturnType<typeof model>>;
  classifierChoice?: string;
  classifierAvailable?: boolean;
}) {
  const available = options?.available ?? MODEL_CANDIDATES.map((candidate) => model(candidate.provider, candidate.id));
  const classifier = { provider: "typesafe", id: "jev-latest", input: ["text"] };
  const classifyCalls: unknown[] = [];
  const statuses: Array<{ id: string; text: string | undefined }> = [];
  let definition: any;

  const pi = {
    registerVirtualModel(value: unknown) {
      definition = value;
    },
    on() {
      return () => {};
    },
  };
  const ctx = {
    ui: {
      setStatus(id: string, text: string | undefined) {
        statuses.push({ id, text });
      },
    },
    modelRegistry: {
      getAvailable: () => available,
      getAvailableOfType: async () => options?.classifierAvailable === false ? [] : [classifier],
      classify: async (_model: unknown, request: unknown) => {
        classifyCalls.push(request);
        return {
          stopReason: "stop",
          answers: {
            model: {
              type: "choice",
              choice: options?.classifierChoice ?? "gpt_5_6_sol",
              probabilities: {},
              confidence: 1,
            },
          },
        };
      },
    },
  };

  registerJevAuto(pi as never);
  return { definition, ctx, classifyCalls, statuses };
}

test("registers one selectable virtual model with the six requested physical models", () => {
  const { definition } = createHarness();

  assert.equal(definition.provider, "jev");
  assert.equal(definition.id, "auto");
  assert.equal(definition.name, "Auto (Jev)");
  assert.deepEqual(
    MODEL_CANDIDATES.map(({ provider, id }) => `${provider}/${id}`),
    [
      "openai-codex/gpt-5.6-luna",
      "openai-codex/gpt-5.6-sol",
      "openai-codex/gpt-6-luna",
      "openai-codex/gpt-6-sol",
      "pi-claude-cli/claude-sonnet-5-5",
      "pi-claude-cli/claude-opus-5-5",
    ],
  );
});

test("asks Jev to select an available model for each new user task", async () => {
  const { definition, ctx, classifyCalls, statuses } = createHarness({ classifierChoice: "claude_opus_5_5" });
  const request = {
    reason: "user",
    thinkingLevel: "high",
    messages: [
      { role: "user", content: "Trace a subtle race across the worker system." },
    ],
  };

  const route = await definition.route(request, ctx);

  assert.equal(route.model.provider, "pi-claude-cli");
  assert.equal(route.model.id, "claude-opus-5-5");
  assert.equal(route.thinkingLevel, "high");
  assert.equal(classifyCalls.length, 1);
  assert.deepEqual(statuses, [{ id: "jev-route", text: "Jev → Claude Opus 5.5" }]);
});

test("keeps continuations on the model that started the turn", async () => {
  const { definition, ctx, classifyCalls } = createHarness();
  const previous = { model: model("openai-codex", "gpt-6-sol"), thinkingLevel: "xhigh" };

  const route = await definition.route(
    { reason: "continuation", thinkingLevel: "high", previous, messages: [] },
    ctx,
  );

  assert.equal(route.model, previous.model);
  assert.equal(route.thinkingLevel, "xhigh");
  assert.equal(classifyCalls.length, 0);
});

test("falls back to GPT-5.6 Sol when Jev is unavailable", async () => {
  const { definition, ctx, classifyCalls } = createHarness({ classifierAvailable: false });

  const route = await definition.route(
    {
      reason: "user",
      thinkingLevel: "medium",
      messages: [{ role: "user", content: "Rename this variable." }],
    },
    ctx,
  );

  assert.equal(route.model.provider, "openai-codex");
  assert.equal(route.model.id, "gpt-5.6-sol");
  assert.equal(classifyCalls.length, 0);
});

test("builds compact classifier context from the latest request and nearby conversation", () => {
  const context = buildRoutingContext([
    { role: "user", content: "Start with the parser." },
    { role: "assistant", content: [{ type: "text", text: "I found the entry point." }] },
    { role: "toolResult", toolName: "read", content: [{ type: "text", text: "large output" }] },
    { role: "user", content: [{ type: "text", text: "Now fix the concurrency bug." }, { type: "image" }] },
  ] as never);

  assert.equal(context.currentRequest, "Now fix the concurrency bug.\n[image attached]");
  assert.match(context.recentConversation, /user: Start with the parser\./);
  assert.match(context.recentConversation, /assistant: I found the entry point\./);
  assert.doesNotMatch(context.recentConversation, /large output/);
});
