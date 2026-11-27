import assert from "node:assert/strict";
import test from "node:test";

import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";

import { createPocketJevAuto, resolvePiAiEntryForJiti } from "./jev-auto.ts";

function model(provider: string, id: string) {
  return {
    provider,
    id,
    api: provider,
    name: id,
    reasoning: true,
    input: ["text", "image"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 272_000,
    maxTokens: 128_000,
  };
}

test("resolves the real pi-ai entry when Pocket redirects the bare package", () => {
  const resolved: string[] = [];
  const entry = resolvePiAiEntryForJiti((specifier) => {
    resolved.push(specifier);
    if (specifier === "@earendil-works/pi-ai/models") {
      return "file:///opt/pi-ai/dist/models.js";
    }
    if (specifier === "@earendil-works/pi-ai") {
      return "file:///opt/pi-pocket/extension-pi-ai-compat.ts";
    }
    throw new Error(`Unexpected specifier: ${specifier}`);
  });

  assert.equal(entry, "/opt/pi-ai/dist/index.js");
  assert.deepEqual(resolved, ["@earendil-works/pi-ai/models"]);
});

function completedStream(chosen: ReturnType<typeof model>) {
  const stream = createAssistantMessageEventStream();
  const message = {
    role: "assistant" as const,
    content: [{ type: "text" as const, text: "done" }],
    api: chosen.api,
    provider: chosen.provider,
    model: chosen.id,
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "stop" as const,
    timestamp: Date.now(),
  };
  stream.push({ type: "done", reason: "stop", message });
  stream.end(message);
  return stream;
}

test("registers Auto (Jev), routes a task, and tells the matching Pocket session", async () => {
  const providerConfigs = new Map<string, any>();
  let messageSent: ((event: any) => void) | undefined;
  let runStarted: ((event: any) => void) | undefined;
  let classifyCalls = 0;
  const notices: Array<{ message: string; conversationId?: number }> = [];
  const disposers: Array<() => void> = [];
  const chosen = model("pi-claude-cli", "claude-sonnet-5-5");
  const runtime = {
    getAvailable: async () => [
      model("openai-codex", "gpt-5.6-sol"),
      model("openai-codex", "gpt-6-sol"),
      chosen,
    ],
    getAvailableOfType: async () => [{ provider: "typesafe", id: "jev-latest" }],
    classify: async () => {
      classifyCalls++;
      return {
        stopReason: "stop",
        answers: {
          model: {
            type: "choice",
            choice: classifyCalls === 1 ? "claude_sonnet_5_5" : "gpt_6_sol",
            probabilities: {},
            confidence: 1,
          },
        },
      };
    },
    streamSimple: (physical: ReturnType<typeof model>) => completedStream(physical),
  };
  const host = {
    agentDir: "/tmp/pi-agent",
    registerModelProvider(provider: string, config: unknown) {
      providerConfigs.set(provider, config);
      return () => providerConfigs.delete(provider);
    },
    on(event: string, listener: (value: unknown) => void) {
      if (event === "message.sent") messageSent = listener;
      if (event === "run.started") runStarted = listener;
      return () => {};
    },
    notice(_level: string, message: string, conversationId?: number) {
      notices.push({ message, conversationId });
    },
  };
  const web = {
    onDispose(dispose: () => void) {
      disposers.push(dispose);
    },
  };

  const extension = await createPocketJevAuto(host as never, web as never, {
    createRuntime: async () => runtime as never,
    registerClaudeCliProvider: async () => ({
      provider: {
        id: "pi-claude-cli",
        name: "pi-claude-cli",
        baseUrl: "pi-claude-cli",
        getModels: () => [chosen],
        streamSimple: runtime.streamSimple,
      },
    }),
  });

  const providerConfig = providerConfigs.get("jev");
  const claudeConfig = providerConfigs.get("pi-claude-cli");

  assert.equal(extension.name, "daiego-jev-auto");
  assert.equal(providerConfig.name, "Jev");
  assert.equal(providerConfig.models[0].id, "auto");
  assert.equal(claudeConfig.name, "pi-claude-cli");
  assert.equal(claudeConfig.apiKey, "unused");
  assert.equal(claudeConfig.authHeader, false);
  assert.equal(claudeConfig.models[0].id, "claude-sonnet-5-5");
  assert.equal(claudeConfig.models[0].provider, undefined);

  runStarted?.({ conversationId: 42, session: 42 });
  const stream = providerConfig.streamSimple(
    model("jev", "auto"),
    { messages: [{ role: "user", content: [{ type: "text", text: "Review this UI flow." }] }] },
    { sessionId: "session-42", reasoning: "high" },
  );
  const result = await stream.result();

  assert.equal(result.provider, "pi-claude-cli");
  assert.equal(result.model, "claude-sonnet-5-5");
  assert.deepEqual(notices, [
    { message: "Jev chose Claude Sonnet 5.5.", conversationId: 42 },
  ]);

  const continuation = providerConfig.streamSimple(
    model("jev", "auto"),
    {
      messages: [
        { role: "system", content: "tools changed" },
        { role: "user", content: "Review this UI flow." },
        { role: "toolResult", toolName: "read", content: "output" },
      ],
    },
    { sessionId: "session-42", reasoning: "high" },
  );
  assert.equal((await continuation.result()).model, "claude-sonnet-5-5");
  assert.equal(classifyCalls, 1);
  assert.equal(notices.length, 1);

  messageSent?.({ conversationId: 42 });
  const nextTask = providerConfig.streamSimple(
    model("jev", "auto"),
    { messages: [{ role: "user", content: "Now redesign the routing layer." }] },
    { sessionId: "session-42", reasoning: "high" },
  );
  assert.equal((await nextTask.result()).model, "gpt-6-sol");
  assert.equal(classifyCalls, 2);
  assert.deepEqual(notices.at(-1), {
    message: "Jev chose GPT-6 Sol.",
    conversationId: 42,
  });
  assert.ok(disposers.length >= 3);
});
