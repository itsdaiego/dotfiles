/** Adds the Claude CLI models and an Auto (Jev) model that selects a model for each new task. */
import { access } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
    createAssistantMessageEventStream,
    type Api,
    type AssistantMessage,
    type AssistantMessageEventStream,
    type Model,
    type Provider,
    type SimpleStreamOptions,
    type TranscriptContext,
} from "@earendil-works/pi-ai";
import { ModelRuntime } from "@earendil-works/pi-coding-agent";
import { defineExtension } from "@earendil-works/pi-durable";
import { createJiti } from "jiti";

import {
    chooseCandidate,
    latestUserTaskKey,
    type ModelCandidate,
} from "./_jev-auto-policy.ts";

const PROVIDER = "jev";
const MODEL_ID = "auto";
const EXTENSION_NAME = "daiego-jev-auto";

type PocketHost = {
    agentDir: string;
    registerModelProvider(provider: string, config: Record<string, unknown>): () => void;
    on(
        event: "message.sent" | "run.started" | "run.ended",
        listener: (event: any) => void,
    ): () => void;
    notice(level: "info" | "warning" | "error", message: string, conversationId?: number): void;
};

type PocketWeb = {
    onDispose(dispose: () => void): void;
};

type RouterRuntime = Pick<
    ModelRuntime,
    "getAvailable" | "getAvailableOfType" | "classify" | "streamSimple"
>;

type ClaudeCliRegistration = {
    provider?: Provider;
    cleanup?: () => Promise<void>;
};

type PocketDependencies = {
    createRuntime(): Promise<RouterRuntime>;
    registerClaudeCliProvider(
        runtime: ModelRuntime,
        agentDir: string,
    ): Promise<ClaudeCliRegistration | undefined>;
};

type SessionRoute = {
    taskKey: string;
    candidate: ModelCandidate;
    model: Model<Api>;
};

function failure(model: Model<Api>, error: unknown): AssistantMessage {
    return {
        role: "assistant",
        content: [],
        api: model.api,
        provider: model.provider,
        model: model.id,
        usage: {
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            totalTokens: 0,
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
        },
        stopReason: "error",
        errorMessage: error instanceof Error ? error.message : String(error),
        timestamp: Date.now(),
    };
}

function physicalOptions(options: SimpleStreamOptions | undefined): SimpleStreamOptions | undefined {
    if (!options) {
        return undefined;
    }

    const {
        apiKey: _apiKey,
        baseUrl: _baseUrl,
        env: _env,
        headers: _headers,
        ...rest
    } = options;

    return rest;
}

function pipePhysicalStream(
    runtime: RouterRuntime,
    virtualModel: Model<Api>,
    physicalModel: Model<Api>,
    context: TranscriptContext,
    options: SimpleStreamOptions | undefined,
): AssistantMessageEventStream {
    const out = createAssistantMessageEventStream();

    void (async () => {
        try {
            const stream = runtime.streamSimple(
                physicalModel,
                context,
                physicalOptions(options),
            );

            for await (const event of stream) {
                out.push(event);
            }

            out.end(await stream.result());
        } catch (error) {
            const message = failure(virtualModel, error);

            out.push({ type: "error", reason: "error", error: message });
            out.end(message);
        }
    })();

    return out;
}

export function resolvePiAiEntryForJiti(
    resolveModule: (specifier: string) => string = import.meta.resolve,
): string {
    return fileURLToPath(
        new URL("./index.js", resolveModule("@earendil-works/pi-ai/models")),
    );
}

function pocketProviderConfig(provider: Provider): Record<string, unknown> {
    const models = () => provider.getModels().map((model) => {
        const { provider: _provider, baseUrl: _baseUrl, ...config } = model;

        return config;
    });
    const config: Record<string, unknown> = {
        name: provider.name,
        baseUrl: "http://pi-claude-cli.local",
        apiKey: "unused",
        api: provider.id,
        authHeader: false,
        streamSimple: provider.streamSimple.bind(provider),
        models: models(),
    };

    if (provider.refreshModels) {
        config.refreshModels = async (
            context: Parameters<NonNullable<Provider["refreshModels"]>>[0],
        ) => {
            await provider.refreshModels?.(context);

            return models();
        };
    }

    return config;
}

async function loadClaudeCliProvider(
    runtime: ModelRuntime,
    agentDir: string,
): Promise<ClaudeCliRegistration | undefined> {
    const entries = [
        resolve(agentDir, "git/github.com/dmmulroy/pi-claude-cli/index.ts"),
        resolve(agentDir, "../agent/git/github.com/dmmulroy/pi-claude-cli/index.ts"),
    ];
    let entry: string | undefined;

    for (const candidate of new Set(entries)) {
        try {
            await access(candidate);
            entry = candidate;
            break;
        } catch {}
    }

    if (!entry) {
        return undefined;
    }

    const handlers = new Map<string, Array<(...args: any[]) => unknown>>();
    const jiti = createJiti(import.meta.url, {
        alias: {
            "@earendil-works/pi-ai": resolvePiAiEntryForJiti(),
            "@earendil-works/pi-ai/compat": fileURLToPath(
                import.meta.resolve("@earendil-works/pi-ai/compat"),
            ),
            "@earendil-works/pi-ai/providers/all": fileURLToPath(
                import.meta.resolve("@earendil-works/pi-ai/providers/all"),
            ),
        },
    });
    const module = await jiti.import(entry) as {
        default(pi: Record<string, unknown>): void | Promise<void>;
    };
    let provider: Provider | undefined;
    const pi = {
        on(event: string, handler: (...args: any[]) => unknown) {
            handlers.set(event, [...(handlers.get(event) ?? []), handler]);
            return () => {};
        },
        registerProvider(candidate: unknown) {
            if (typeof candidate === "object" && candidate !== null) {
                provider = candidate as Provider;
                runtime.registerNativeProvider(provider as never);
            }
        },
        registerCommand() {},
    };

    await module.default(pi);

    return {
        provider,
        cleanup: async () => {
            for (const handler of handlers.get("session_shutdown") ?? []) {
                await handler({ reason: "quit" }, {});
            }
        },
    };
}

const defaultDependencies: PocketDependencies = {
    createRuntime: () => ModelRuntime.create({ allowModelNetwork: false }),
    registerClaudeCliProvider: loadClaudeCliProvider,
};

export async function createPocketJevAuto(
    host: PocketHost,
    web: PocketWeb,
    dependencies: PocketDependencies = defaultDependencies,
) {
    const runtime = await dependencies.createRuntime();
    const routes = new Map<string, SessionRoute>();
    const sessionConversations = new Map<string, number>();
    const conversationVersions = new Map<number, number>();
    const pendingRuns: number[] = [];
    const messages = host.on("message.sent", ({ conversationId }) => {
        conversationVersions.set(
            conversationId,
            (conversationVersions.get(conversationId) ?? 0) + 1,
        );
    });
    const started = host.on("run.started", ({ conversationId }) => {
        pendingRuns.push(conversationId);
    });
    const ended = host.on("run.ended", ({ conversationId }) => {
        const index = pendingRuns.indexOf(conversationId);
        if (index >= 0) {
            pendingRuns.splice(index, 1);
        }
    });
    const claude = await dependencies.registerClaudeCliProvider(
        runtime as ModelRuntime,
        host.agentDir,
    );
    const removeClaudeProvider = claude?.provider
        ? host.registerModelProvider(
            claude.provider.id,
            pocketProviderConfig(claude.provider),
        )
        : undefined;

    const conversationFor = (sessionId: string | undefined): number | undefined => {
        if (!sessionId) {
            return undefined;
        }

        const known = sessionConversations.get(sessionId);
        if (known !== undefined) {
            return known;
        }

        const conversationId = pendingRuns.shift();
        if (conversationId !== undefined) {
            sessionConversations.set(sessionId, conversationId);
        }

        return conversationId;
    };

    const streamSimple = (
        virtualModel: Model<Api>,
        context: TranscriptContext,
        options?: SimpleStreamOptions,
    ): AssistantMessageEventStream => {
        const out = createAssistantMessageEventStream();

        void (async () => {
            try {
                const sessionId = options?.sessionId;
                const conversationId = conversationFor(sessionId);
                const taskKey = conversationId === undefined
                    ? latestUserTaskKey(context.messages)
                    : `${conversationId}:${conversationVersions.get(conversationId) ?? 0}`;
                const previous = sessionId ? routes.get(sessionId) : undefined;
                const selected = previous?.taskKey === taskKey
                    ? previous
                    : await chooseCandidate(runtime, context.messages, options?.signal);
                const route: SessionRoute = previous?.taskKey === taskKey
                    ? previous
                    : { taskKey, candidate: selected.candidate, model: selected.model };

                if (!previous || previous.taskKey !== taskKey) {
                    if (sessionId) {
                        routes.set(sessionId, route);
                    }
                    host.notice(
                        "info",
                        `Jev chose ${route.candidate.label}.`,
                        conversationId,
                    );
                }

                const stream = pipePhysicalStream(
                    runtime,
                    virtualModel,
                    route.model,
                    context,
                    options,
                );
                for await (const event of stream) {
                    out.push(event);
                }
                out.end(await stream.result());
            } catch (error) {
                const message = failure(virtualModel, error);

                out.push({ type: "error", reason: "error", error: message });
                out.end(message);
            }
        })();

        return out;
    };

    const removeProvider = host.registerModelProvider(PROVIDER, {
        name: "Jev",
        baseUrl: "http://jev.local",
        apiKey: "none",
        api: "jev-auto",
        streamSimple,
        models: [
            {
                id: MODEL_ID,
                name: "Auto (Jev)",
                api: "jev-auto",
                reasoning: true,
                thinkingLevelMap: {
                    off: null,
                    minimal: null,
                    low: "low",
                    medium: "medium",
                    high: "high",
                    xhigh: "xhigh",
                    max: null,
                },
                input: ["text", "image"],
                cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
                contextWindow: 272_000,
                maxTokens: 128_000,
            },
        ],
    });

    web.onDispose(messages);
    web.onDispose(started);
    web.onDispose(ended);
    web.onDispose(removeProvider);
    if (removeClaudeProvider) {
        web.onDispose(removeClaudeProvider);
    }
    web.onDispose(() => {
        void claude?.cleanup?.();
    });

    return defineExtension({ name: EXTENSION_NAME });
}

export default function jevAuto(host: PocketHost, web: PocketWeb) {
    return createPocketJevAuto(host, web);
}
