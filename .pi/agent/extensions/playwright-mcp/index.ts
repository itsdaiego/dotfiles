import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const extensionDirectory = dirname(fileURLToPath(import.meta.url));
const serverEntrypoint = join(extensionDirectory, "node_modules", "@playwright", "mcp", "cli.js");
const UNSAFE_MCP_TOOLS = new Set(["browser_run_code_unsafe"]);

let client: Client | undefined;
let transport: StdioClientTransport | undefined;
let connecting: Promise<void> | undefined;
let reconnectTimer: ReturnType<typeof setTimeout> | undefined;
let sessionActive = false;
const registeredToolNames = new Set<string>();
const RECONNECT_DELAYS_MS = [1_000, 3_000, 10_000];

async function disconnect(): Promise<void> {
  const activeTransport = transport;
  client = undefined;
  transport = undefined;
  await activeTransport?.close().catch(() => undefined);
}

function scheduleReconnect(pi: ExtensionAPI, cwd: string, attempt = 0): void {
  if (!sessionActive || reconnectTimer !== undefined || attempt >= RECONNECT_DELAYS_MS.length) return;

  reconnectTimer = setTimeout(async () => {
    reconnectTimer = undefined;
    if (!sessionActive) return;

    try {
      await connect(pi, cwd);
    } catch {
      scheduleReconnect(pi, cwd, attempt + 1);
    }
  }, RECONNECT_DELAYS_MS[attempt]);
}

function resultText(result: CallToolResult): string {
  const content = result.content.map((item) => {
    if (item.type === "text") return item.text;
    if (item.type === "image") return "[Playwright returned an image; use browser_snapshot for actionable page state.]";
    if (item.type === "resource") return JSON.stringify(item.resource);
    return JSON.stringify(item);
  });
  if (result.structuredContent !== undefined) {
    content.push(JSON.stringify(result.structuredContent));
  }
  return content.join("\n");
}

async function connect(pi: ExtensionAPI, cwd: string): Promise<void> {
  if (client !== undefined) return;
  if (connecting !== undefined) return connecting;

  connecting = (async () => {
    const nextTransport = new StdioClientTransport({
      // Pi is bundled as a Bun executable, so process.execPath is Pi itself
      // rather than Node. @playwright/mcp must run under Node; using Pi here
      // leaves the MCP initialize request unanswered until it times out.
      command: process.env.PLAYWRIGHT_MCP_NODE ?? "node",
      args: [
        serverEntrypoint,
        "--headless",
        "--browser",
        "chromium",
        "--isolated",
        "--image-responses",
        "omit",
        "--caps",
        "testing",
        "--output-dir",
        join(cwd, ".playwright-mcp"),
      ],
      cwd,
      stderr: "pipe",
    });
    const nextClient = new Client({ name: "pi-playwright-mcp", version: "1.0.0" });

    try {
      await nextClient.connect(nextTransport);
      const { tools } = await nextClient.listTools();

      const enabledTools: string[] = [];

    for (const tool of tools) {
      if (UNSAFE_MCP_TOOLS.has(tool.name)) continue;
      const name = `playwright_${tool.name}`;
      if (registeredToolNames.has(name)) continue;
      registeredToolNames.add(name);
      enabledTools.push(name);

      pi.registerTool({
        name,
        label: `Playwright: ${tool.annotations?.title ?? tool.name}`,
        description: tool.description ?? `Run Playwright MCP tool ${tool.name}.`,
        parameters: Type.Unsafe(tool.inputSchema),
        async execute(_toolCallId, params, signal) {
          // A previous browser crash or timeout clears the connection. Recreate
          // it before the next call instead of leaving the extension unusable.
          await connect(pi, cwd);
          const activeClient = client;
          if (activeClient === undefined) throw new Error("Playwright MCP is not connected");

          let result: Awaited<ReturnType<Client["callTool"]>>;
          try {
            result = await activeClient.callTool(
              { name: tool.name, arguments: params as Record<string, unknown> },
              undefined,
              { signal },
            );
          } catch (error) {
            if (client === activeClient) await disconnect();
            scheduleReconnect(pi, cwd);
            throw error;
          }

          const typedResult = result as CallToolResult;
          const text = resultText(typedResult);
          if (typedResult.isError) throw new Error(text);
          return {
            content: [{ type: "text", text }],
            details: { mcpTool: tool.name, structuredContent: typedResult.structuredContent },
          };
        },
      });
    }

      pi.setActiveTools([...new Set([...pi.getActiveTools(), ...enabledTools])]);
      client = nextClient;
      transport = nextTransport;
    } catch (error) {
      // `transport` is assigned only after initialization succeeds. Close this
      // local transport on startup failure so a timed-out MCP never leaks.
      await nextTransport.close().catch(() => undefined);
      throw error;
    }
  })();

  try {
    await connecting;
  } finally {
    connecting = undefined;
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    sessionActive = true;
    try {
      await connect(pi, ctx.cwd);
      ctx.ui.notify("Playwright MCP connected", "info");
    } catch (error) {
      ctx.ui.notify(`Playwright MCP unavailable: ${String(error)}`, "error");
      // Recover transient Chromium/MCP startup failures without requiring a
      // Pi restart. Failed transports are closed by connect() above.
      scheduleReconnect(pi, ctx.cwd);
    }
  });

  pi.on("session_shutdown", async () => {
    sessionActive = false;
    if (reconnectTimer !== undefined) clearTimeout(reconnectTimer);
    reconnectTimer = undefined;
    await disconnect();
  });
}
