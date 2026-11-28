import { spawn } from "node:child_process";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const PROBE_TIMEOUT_MS = 15_000;
const CODEX_REQUEST_ID = 2;
const CLAUDE_REQUEST_ID = "pi-slash-usage";

const CLAUDE_SUBSCRIPTION_OVERRIDE_ENV_VARS = [
  "ANTHROPIC_API_KEY",
  "ANTHROPIC_AUTH_TOKEN",
  "ANTHROPIC_BASE_URL",
  "ANTHROPIC_FOUNDRY_API_KEY",
  "ANTHROPIC_FOUNDRY_AUTH_TOKEN",
  "ANTHROPIC_AWS_API_KEY",
  "CLAUDE_CODE_USE_BEDROCK",
  "CLAUDE_CODE_USE_MANTLE",
  "CLAUDE_CODE_USE_VERTEX",
  "CLAUDE_CODE_USE_FOUNDRY",
  "CLAUDE_CODE_USE_ANTHROPIC_AWS",
] as const;

type UnknownRecord = Record<string, unknown>;

type ModelIdentity = {
  provider?: string;
  id?: string;
};

export type UsageProvider = {
  kind: "claude" | "openai";
  provider: string;
  model: string;
};

export type UsageWindow = {
  label: string;
  remainingPercent: number;
};

export type ProviderUsage = {
  provider: string;
  early: UsageWindow;
  weekly: UsageWindow;
};

function record(value: unknown): UnknownRecord | undefined {
  return typeof value === "object" && value !== null ? value as UnknownRecord : undefined;
}

function text(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function number(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function classifyProvider(provider: string, model: string): UsageProvider["kind"] | undefined {
  const identity = `${provider} ${model}`.toLowerCase();
  if (identity.includes("claude") || identity.includes("anthropic")) return "claude";
  if (
    identity.includes("openai") ||
    identity.includes("codex") ||
    /\b(?:gpt|o[134])[-_.]/.test(identity)
  ) return "openai";
  return undefined;
}

export function detectUsageProvider(
  activeModel: ModelIdentity | undefined,
  branch: readonly unknown[],
): UsageProvider | undefined {
  const activeProvider = text(activeModel?.provider);
  const activeModelId = text(activeModel?.id);
  if (activeProvider && activeModelId) {
    const activeKind = classifyProvider(activeProvider, activeModelId);
    if (activeKind) return { kind: activeKind, provider: activeProvider, model: activeModelId };
  }

  for (let index = branch.length - 1; index >= 0; index--) {
    const entry = record(branch[index]);
    if (entry?.type !== "message") continue;
    const message = record(entry.message);
    if (message?.role !== "assistant") continue;
    const provider = text(message.provider);
    const model = text(message.model);
    if (!provider || !model) continue;
    const kind = classifyProvider(provider, model);
    if (kind) return { kind, provider, model };
  }

  return undefined;
}

function durationLabel(minutes: number, weekly: boolean): string {
  if (weekly && minutes === 7 * 24 * 60) return "Weekly";
  if (minutes % 60 === 0) return `${minutes / 60}-hour`;
  return `${minutes}-minute`;
}

function codexWindow(value: unknown, weekly: boolean): UsageWindow {
  const window = record(value);
  const usedPercent = number(window?.usedPercent);
  const minutes = number(window?.windowDurationMins);
  if (usedPercent === undefined || minutes === undefined) {
    throw new Error("Codex did not return both usage windows.");
  }
  return {
    label: durationLabel(minutes, weekly),
    remainingPercent: Math.max(0, 100 - usedPercent),
  };
}

export function parseCodexRateLimitsResponse(value: unknown): ProviderUsage {
  const envelope = record(value);
  if (envelope?.id !== CODEX_REQUEST_ID) throw new Error("Codex returned an unexpected response.");
  const error = record(envelope.error);
  if (error) throw new Error(text(error.message) ?? "Codex could not read account usage.");
  const limits = record(record(envelope.result)?.rateLimits);
  if (!limits) throw new Error("Codex account usage is unavailable.");

  return {
    provider: "OpenAI Codex",
    early: codexWindow(limits.primary, false),
    weekly: codexWindow(limits.secondary, true),
  };
}

function claudeWindow(value: unknown, label: string): UsageWindow {
  const window = record(value);
  const usedPercent = number(window?.utilization);
  if (usedPercent === undefined) throw new Error(`Claude did not return the ${label.toLowerCase()} usage window.`);
  return {
    label,
    remainingPercent: Math.max(0, 100 - usedPercent),
  };
}

export function parseClaudeUsageResponse(value: unknown, model = ""): ProviderUsage {
  const envelope = record(value);
  const response = record(envelope?.response);
  if (envelope?.type !== "control_response" || response?.request_id !== CLAUDE_REQUEST_ID) {
    throw new Error("Claude returned an unexpected response.");
  }
  if (response.subtype !== "success") throw new Error("Claude could not read account usage.");

  const payload = record(response.response);
  if (payload?.rate_limits_available !== true) {
    throw new Error("Claude subscription usage limits are unavailable. Sign in to Claude Code with a subscription account.");
  }
  const limits = record(payload.rate_limits);
  if (!limits) throw new Error("Claude subscription usage limits are unavailable.");

  const modelWeekly = model.toLowerCase().includes("opus")
    ? limits.seven_day_opus
    : model.toLowerCase().includes("sonnet")
      ? limits.seven_day_sonnet
      : undefined;
  const weekly = limits.seven_day ?? modelWeekly;

  return {
    provider: "Claude",
    early: claudeWindow(limits.five_hour, "5-hour"),
    weekly: claudeWindow(weekly, "Weekly"),
  };
}

type ProbeOptions = {
  command: string;
  args: string[];
  env?: NodeJS.ProcessEnv;
  requests: unknown[];
  matches: (value: unknown) => boolean;
};

function runIsolatedProbe(options: ProbeOptions): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const detached = process.platform !== "win32";
    const child = spawn(options.command, options.args, {
      env: options.env,
      detached,
      stdio: ["pipe", "pipe", "ignore"],
    });
    let output = "";
    let settled = false;

    const stop = () => {
      if (child.pid && detached) {
        try {
          process.kill(-child.pid, "SIGKILL");
          return;
        } catch {
          // The process may already have exited.
        }
      }
      child.kill("SIGKILL");
    };
    const finish = (error: Error | undefined, value?: unknown) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      stop();
      if (error) reject(error);
      else resolve(value);
    };
    const readLines = () => {
      let newline = output.indexOf("\n");
      while (newline >= 0) {
        const line = output.slice(0, newline).trim();
        output = output.slice(newline + 1);
        if (line) {
          try {
            const value = JSON.parse(line) as unknown;
            if (options.matches(value)) {
              finish(undefined, value);
              return;
            }
          } catch {
            // Provider CLIs may write non-protocol status lines; ignore them.
          }
        }
        newline = output.indexOf("\n");
      }
    };
    const timer = setTimeout(
      () => finish(new Error(`${options.command} timed out while reading account usage.`)),
      PROBE_TIMEOUT_MS,
    );

    child.once("error", () => finish(new Error(`Could not start ${options.command}.`)));
    child.once("exit", () => finish(new Error(`${options.command} exited before returning account usage.`)));
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      output += chunk;
      readLines();
    });

    for (const request of options.requests) child.stdin.write(`${JSON.stringify(request)}\n`);
  });
}

async function readCodexUsage(): Promise<ProviderUsage> {
  const response = await runIsolatedProbe({
    command: process.env.PI_CODEX_COMMAND?.trim() || "codex",
    args: ["app-server", "--stdio"],
    requests: [
      {
        id: 1,
        method: "initialize",
        params: { clientInfo: { name: "pi-slash-usage", title: "Pi slash usage", version: "1.0.0" } },
      },
      { id: CODEX_REQUEST_ID, method: "account/rateLimits/read", params: null },
    ],
    matches: (value) => record(value)?.id === CODEX_REQUEST_ID,
  });
  return parseCodexRateLimitsResponse(response);
}

function claudeEnvironment(): NodeJS.ProcessEnv {
  const env = { ...process.env };
  for (const name of CLAUDE_SUBSCRIPTION_OVERRIDE_ENV_VARS) delete env[name];
  const configDirectory = process.env.PI_CLAUDE_CLI_CONFIG_DIR?.trim();
  if (configDirectory) env.CLAUDE_CONFIG_DIR = configDirectory;
  env.CLAUDE_CODE_DISABLE_CLAUDE_MDS = "1";
  env.CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
  env.ENABLE_CLAUDEAI_MCP_SERVERS = "false";
  env.DISABLE_AUTOUPDATER = "1";
  return env;
}

async function readClaudeUsage(model: string): Promise<ProviderUsage> {
  const response = await runIsolatedProbe({
    command: process.env.PI_CLAUDE_CLI_COMMAND?.trim() || "claude",
    args: [
      "-p",
      "--input-format", "stream-json",
      "--output-format", "stream-json",
      "--verbose",
      "--strict-mcp-config",
      "--setting-sources", "",
      "--disable-slash-commands",
      "--no-chrome",
      "--tools", "",
      "--no-session-persistence",
    ],
    env: claudeEnvironment(),
    requests: [
      {
        type: "control_request",
        request_id: "pi-slash-usage-init",
        request: { subtype: "initialize" },
      },
      {
        type: "control_request",
        request_id: CLAUDE_REQUEST_ID,
        request: { subtype: "get_usage", skip_behaviors: true },
      },
    ],
    matches: (value) => record(record(value)?.response)?.request_id === CLAUDE_REQUEST_ID,
  });
  return parseClaudeUsageResponse(response, model);
}

function formatPercent(value: number): string {
  return `${new Intl.NumberFormat("en", { maximumFractionDigits: 1 }).format(value)}%`;
}

export function formatUsageReport(usage: ProviderUsage): string {
  return [
    `Current window: ${formatPercent(usage.early.remainingPercent)} left`,
    `Week: ${formatPercent(usage.weekly.remainingPercent)} left`,
  ].join("\n");
}

async function handleUsage(ctx: ExtensionCommandContext): Promise<void> {
  await ctx.waitForIdle();
  const active = detectUsageProvider(ctx.model, ctx.sessionManager.getBranch());
  if (!active) {
    const identity = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no active model";
    ctx.ui.notify(`Slash usage supports Claude and OpenAI. Could not resolve either provider from ${identity}.`, "warning");
    return;
  }

  ctx.ui.setStatus("slash-usage", `Checking ${active.kind === "claude" ? "Claude" : "OpenAI"} usage…`);
  try {
    const usage = active.kind === "claude"
      ? await readClaudeUsage(active.model)
      : await readCodexUsage();
    ctx.ui.notify(formatUsageReport(usage), "info");
  } catch (error) {
    const message = error instanceof Error ? error.message : "Could not read provider usage.";
    ctx.ui.notify(message, "error");
  } finally {
    ctx.ui.setStatus("slash-usage", undefined);
  }
}

export default function slashUsageExtension(pi: ExtensionAPI) {
  pi.registerCommand("usage", {
    description: "Show active Claude or OpenAI short-window and weekly limits",
    handler: async (_args, ctx) => handleUsage(ctx),
  });
}
