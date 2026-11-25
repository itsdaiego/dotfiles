import type { Message } from "@earendil-works/pi-ai";

export type CandidateKey =
  | "gpt_5_6_luna"
  | "gpt_5_6_sol"
  | "gpt_6_luna"
  | "gpt_6_sol"
  | "claude_sonnet_5_5"
  | "claude_opus_5_5";

export type ModelCandidate = {
  key: CandidateKey;
  provider: string;
  id: string;
  label: string;
  criterion: string;
};

export const MODEL_CANDIDATES: readonly ModelCandidate[] = [
  {
    key: "gpt_5_6_luna",
    provider: "openai-codex",
    id: "gpt-5.6-luna",
    label: "GPT-5.6 Luna",
    criterion: "A small, routine task where speed matters most: simple edits, lookups, summaries, or commands.",
  },
  {
    key: "gpt_5_6_sol",
    provider: "openai-codex",
    id: "gpt-5.6-sol",
    label: "GPT-5.6 Sol",
    criterion: "The dependable default for ordinary coding, debugging, review, and autonomous repository work.",
  },
  {
    key: "gpt_6_luna",
    provider: "openai-codex",
    id: "gpt-6-luna",
    label: "GPT-6 Luna",
    criterion: "A moderately difficult task that benefits from GPT-6 reasoning but should stay responsive.",
  },
  {
    key: "gpt_6_sol",
    provider: "openai-codex",
    id: "gpt-6-sol",
    label: "GPT-6 Sol",
    criterion: "Hard debugging, architecture, broad multi-file changes, or long autonomous work where maximum OpenAI capability is justified.",
  },
  {
    key: "claude_sonnet_5_5",
    provider: "pi-claude-cli",
    id: "claude-sonnet-5-5",
    label: "Claude Sonnet 5.5",
    criterion: "Balanced Claude work: code review, UI or prose-heavy tasks, ambiguous requirements, and long-context synthesis.",
  },
  {
    key: "claude_opus_5_5",
    provider: "pi-claude-cli",
    id: "claude-opus-5-5",
    label: "Claude Opus 5.5",
    criterion: "Exceptionally difficult reasoning, subtle debugging, deep planning, or research where the strongest Claude model is worth the extra cost and latency.",
  },
];

const DEFAULT_CANDIDATE: CandidateKey = "gpt_5_6_sol";
const DIRECT_CANDIDATE: CandidateKey = "gpt_5_6_luna";
const MAX_CURRENT_REQUEST = 8_000;
const MAX_RECENT_CONVERSATION = 16_000;

type ChatModel = {
  provider: string;
  id: string;
};

type ClassifierModel = {
  provider: string;
  id: string;
};

type RoutingRuntime<TModel extends ChatModel = ChatModel> = {
  getAvailable(): readonly TModel[] | Promise<readonly TModel[]>;
  getAvailableOfType(
    type: "classifier",
  ): readonly ClassifierModel[] | Promise<readonly ClassifierModel[]>;
  classify(
    model: ClassifierModel,
    context: {
      state: { currentRequest: string; recentConversation: string };
      questions: {
        model: {
          type: "choice";
          instructions: string;
          criteria: Record<string, string>;
        };
      };
    },
    options?: { signal?: AbortSignal },
  ): Promise<{
    stopReason: string;
    answers: Record<string, { type: string; choice?: string }>;
  }>;
};

function textOfContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  const parts: string[] = [];
  for (const block of content) {
    if (typeof block !== "object" || block === null) continue;
    const value = block as { type?: unknown; text?: unknown };
    if (value.type === "text" && typeof value.text === "string") parts.push(value.text);
    else if (value.type === "image") parts.push("[image attached]");
  }
  return parts.join("\n");
}

export function buildRoutingContext(messages: readonly Message[]) {
  const conversational = messages.flatMap((message) => {
    if (message.role !== "user" && message.role !== "assistant") return [];
    const text = textOfContent(message.content).trim();
    return text ? [{ role: message.role, text }] : [];
  });
  const currentRequest = [...conversational]
    .reverse()
    .find((message) => message.role === "user")?.text ?? "";
  const recentConversation = conversational
    .slice(-8)
    .map((message) => `${message.role}: ${message.text}`)
    .join("\n\n")
    .slice(-MAX_RECENT_CONVERSATION);

  return {
    currentRequest: currentRequest.slice(0, MAX_CURRENT_REQUEST),
    recentConversation,
  };
}

export function latestUserTaskKey(messages: readonly Message[]): string {
  for (let index = messages.length - 1; index >= 0; index--) {
    const message = messages[index];
    if (message?.role !== "user") continue;
    return `${index}:${textOfContent(message.content).slice(0, MAX_CURRENT_REQUEST)}`;
  }
  return `none:${messages.length}`;
}

function matches(candidate: ModelCandidate, model: ChatModel): boolean {
  return candidate.provider === model.provider && candidate.id === model.id;
}

export async function availableCandidateModels<TModel extends ChatModel>(
  runtime: Pick<RoutingRuntime<TModel>, "getAvailable">,
): Promise<Array<{ candidate: ModelCandidate; model: TModel }>> {
  const models = await runtime.getAvailable();
  return MODEL_CANDIDATES.flatMap((candidate) => {
    const model = models.find((available) => matches(candidate, available));
    return model ? [{ candidate, model }] : [];
  });
}

export function fallbackCandidate<TModel extends ChatModel>(
  available: Array<{ candidate: ModelCandidate; model: TModel }>,
  preferred: CandidateKey = DEFAULT_CANDIDATE,
): { candidate: ModelCandidate; model: TModel } {
  const selected = available.find(({ candidate }) => candidate.key === preferred) ?? available[0];
  if (!selected) {
    const expected = MODEL_CANDIDATES.map(({ provider, id }) => `${provider}/${id}`).join(", ");
    throw new Error(`None of the Jev routing models is available. Expected one of: ${expected}`);
  }
  return selected;
}

export async function directCandidate<TModel extends ChatModel>(
  runtime: Pick<RoutingRuntime<TModel>, "getAvailable">,
): Promise<{ candidate: ModelCandidate; model: TModel }> {
  return fallbackCandidate(await availableCandidateModels(runtime), DIRECT_CANDIDATE);
}

function preferredJev(classifiers: readonly ClassifierModel[]): ClassifierModel | undefined {
  const preferences = [
    "typesafe/jev-latest",
    "openrouter/~typesafe/jev-latest",
    "cloudflare-workers-ai/typesafe/jev",
    "vercel-ai-gateway/typesafe-ai/jev",
    "opencode/jev-1.13",
  ];
  return [...classifiers].sort((left, right) => {
    const leftRank = preferences.indexOf(`${left.provider}/${left.id}`);
    const rightRank = preferences.indexOf(`${right.provider}/${right.id}`);
    return (leftRank < 0 ? preferences.length : leftRank) -
      (rightRank < 0 ? preferences.length : rightRank);
  }).find((model) => model.id.toLowerCase().includes("jev"));
}

export async function chooseCandidate<TModel extends ChatModel>(
  runtime: RoutingRuntime<TModel>,
  messages: readonly Message[],
  signal?: AbortSignal,
): Promise<{ candidate: ModelCandidate; model: TModel }> {
  const available = await availableCandidateModels(runtime);
  if (available.length <= 1) return fallbackCandidate(available);

  const jev = preferredJev(await runtime.getAvailableOfType("classifier"));
  if (!jev) return fallbackCandidate(available);

  const criteria = Object.fromEntries(
    available.map(({ candidate }) => [candidate.key, candidate.criterion]),
  );
  const result = await runtime.classify(
    jev,
    {
      state: buildRoutingContext(messages),
      questions: {
        model: {
          type: "choice",
          instructions:
            "Choose the best available model for the current task. Prefer the lighter model when it can complete the work reliably. Use the strongest models only when the task's difficulty or consequences justify them.",
          criteria,
        },
      },
    },
    { signal },
  );
  const answer = result.stopReason === "stop" ? result.answers.model : undefined;
  if (answer?.type !== "choice" || typeof answer.choice !== "string") {
    return fallbackCandidate(available);
  }

  return available.find(({ candidate }) => candidate.key === answer.choice) ?? fallbackCandidate(available);
}
