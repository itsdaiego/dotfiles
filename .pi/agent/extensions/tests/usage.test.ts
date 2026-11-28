import assert from "node:assert/strict";
import test from "node:test";

import {
  detectUsageProvider,
  parseClaudeUsageResponse,
  formatUsageReport,
  parseCodexRateLimitsResponse,
} from "../usage.ts";

test("uses the provider from the latest physical-model response behind a virtual model", () => {
  const provider = detectUsageProvider(
    { provider: "jev", id: "auto" },
    [
      { type: "message", message: { role: "assistant", provider: "pi-claude-cli", model: "claude-opus-5-5" } },
      { type: "message", message: { role: "user", content: "What is my usage?" } },
      { type: "message", message: { role: "assistant", provider: "openai-codex", model: "gpt-5.6-sol" } },
    ],
  );

  assert.deepEqual(provider, { kind: "openai", provider: "openai-codex", model: "gpt-5.6-sol" });
});

test("detects Claude directly from the active model", () => {
  assert.deepEqual(detectUsageProvider({ provider: "pi-claude-cli", id: "claude-sonnet-5-5" }, []), {
    kind: "claude",
    provider: "pi-claude-cli",
    model: "claude-sonnet-5-5",
  });
});

test("prefers a physical active model over a stale assistant response", () => {
  assert.deepEqual(
    detectUsageProvider(
      { provider: "pi-claude-cli", id: "claude-sonnet-5-5" },
      [{ type: "message", message: { role: "assistant", provider: "openai-codex", model: "gpt-5.6-sol" } }],
    ),
    { kind: "claude", provider: "pi-claude-cli", model: "claude-sonnet-5-5" },
  );
});

test("parses Codex five-hour and weekly limits", () => {
  const usage = parseCodexRateLimitsResponse({
    id: 2,
    result: {
      rateLimits: {
        primary: { usedPercent: 76, windowDurationMins: 300, resetsAt: 1_795_825_711 },
        secondary: { usedPercent: 18, windowDurationMins: 10_080, resetsAt: 1_796_402_457 },
      },
    },
  });

  assert.deepEqual(usage, {
    provider: "OpenAI Codex",
    early: { label: "5-hour", remainingPercent: 24 },
    weekly: { label: "Weekly", remainingPercent: 82 },
  });
});

test("parses Claude five-hour and weekly limits", () => {
  const usage = parseClaudeUsageResponse({
    type: "control_response",
    response: {
      request_id: "pi-slash-usage",
      subtype: "success",
      response: {
        rate_limits_available: true,
        rate_limits: {
          five_hour: { utilization: 42.5, resets_at: "2026-11-28T04:00:00Z" },
          seven_day: { utilization: 11, resets_at: "2026-12-04T00:00:00Z" },
        },
      },
    },
  });

  assert.deepEqual(usage, {
    provider: "Claude",
    early: { label: "5-hour", remainingPercent: 57.5 },
    weekly: { label: "Weekly", remainingPercent: 89 },
  });
});

test("formats only the current-window and weekly percentages left", () => {
  const report = formatUsageReport({
    provider: "OpenAI Codex",
    early: { label: "5-hour", remainingPercent: 24 },
    weekly: { label: "Weekly", remainingPercent: 82 },
  });

  assert.match(report, /^Current window: 24% left\nWeek: 82% left$/);
});

test("rejects Claude usage when subscription limits are unavailable", () => {
  assert.throws(
    () =>
      parseClaudeUsageResponse({
        type: "control_response",
        response: {
          request_id: "pi-slash-usage",
          subtype: "success",
          response: { rate_limits_available: false, rate_limits: null },
        },
      }),
    /subscription usage limits are unavailable/i,
  );
});
