import assert from "node:assert/strict";
import test from "node:test";

import { buildRexAgentTitle, findInitialTaskPrompt } from "../lib/rex-agent-title.ts";

test("uses the latest request instead of the generic Pi workspace title", () => {
  assert.equal(
    buildRexAgentTitle('[Image 1]  it just says "pi"   how am i supposed to know which agent is which', "daiego"),
    'π - it just says "pi" how am i supposed to know which agent is which',
  );
});

test("keeps titles short enough for the Rex picker", () => {
  assert.equal(
    buildRexAgentTitle("make rex show a useful task name for every open agent in the quick switcher", "daiego", 48),
    "π - make rex show a useful task name for every…",
  );
});

test("keeps the first task prompt when later requests are vague", () => {
  assert.equal(
    findInitialTaskPrompt(["match Rex fonts to Kitty", "don't see it"]),
    "match Rex fonts to Kitty",
  );
});

test("falls back to the workspace before the first request", () => {
  assert.equal(buildRexAgentTitle("", "daiego"), "π - daiego");
});
