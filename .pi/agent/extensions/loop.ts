import type {
	AgentBeforeSettleEvent,
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const COMPLETE_MARKER = "<loop-complete/>";
const BLOCKED_MARKER = "<loop-blocked/>";
const COMPLETE_LINE = /^<loop-complete\/>$/m;
const BLOCKED_LINE = /^<loop-blocked\/>$/m;

interface LoopState {
	active: boolean;
	goal: string;
	iteration: number;
}

function assistantText(event: AgentBeforeSettleEvent): string {
	for (let index = event.context.contextMessages.length - 1; index >= 0; index--) {
		const message = event.context.contextMessages[index];
		if (message.role !== "assistant") continue;
		return message.content
			.filter((part) => part.type === "text")
			.map((part) => part.text)
			.join("\n");
	}
	return "";
}

function continuationPrompt(state: LoopState): string {
	return [
		`Goal loop iteration ${state.iteration}. Continue working on this goal:`,
		state.goal,
		"",
		"Do not stop at a progress report. Reassess the completion criteria, inspect the actual state, take the next useful actions, and verify the result.",
		`Only put ${COMPLETE_MARKER} alone on the final line when the goal is fully achieved and verified.`,
		`If a missing user decision or permission makes further progress impossible, explain the blocker and put ${BLOCKED_MARKER} alone on the final line.`,
	].join("\n");
}

export default function loopExtension(pi: ExtensionAPI) {
	const state: LoopState = { active: false, goal: "", iteration: 0 };

	const stop = (ctx: ExtensionContext, message: string, level: "info" | "warning" = "info") => {
		state.active = false;
		state.goal = "";
		state.iteration = 0;
		ctx.ui.notify(message, level);
	};

	pi.registerCommand("loop", {
		description: "Keep working until a goal is achieved; use 'status' or 'stop' to control it",
		handler: async (args, ctx) => {
			const input = args.trim();

			if (input === "stop") {
				if (!state.active) {
					ctx.ui.notify("No goal loop is active.", "info");
					return;
				}
				stop(ctx, "Goal loop stopped.", "warning");
				return;
			}

			if (input === "status") {
				ctx.ui.notify(
					state.active
						? `Goal loop active (iteration ${state.iteration}): ${state.goal}`
						: "No goal loop is active.",
					"info",
				);
				return;
			}

			if (!input) {
				ctx.ui.notify("Usage: /loop <goal> | /loop status | /loop stop", "warning");
				return;
			}

			if (!ctx.isIdle()) {
				ctx.ui.notify("Wait for the current turn to finish, then start /loop.", "warning");
				return;
			}

			state.active = true;
			state.goal = input;
			state.iteration = 1;
			ctx.ui.notify(`Goal loop started: ${input}`, "info");
			pi.sendUserMessage(`/skill:loop ${input}`, { expandPromptTemplates: true });
		},
	});

	pi.on("agent_before_settle", async (event, ctx) => {
		if (!state.active) return;

		if (event.outcome !== "completed") {
			stop(ctx, `Goal loop stopped because the agent run ${event.outcome}.`, "warning");
			return;
		}

		const text = assistantText(event);
		if (COMPLETE_LINE.test(text)) {
			stop(ctx, "Goal loop completed.");
			return;
		}
		if (BLOCKED_LINE.test(text)) {
			stop(ctx, "Goal loop is blocked and needs your input.", "warning");
			return;
		}

		state.iteration += 1;
		return {
			entries: [
				{
					type: "custom_message",
					customType: "goal-loop-continuation",
					content: continuationPrompt(state),
					display: false,
				},
			],
			continue: true,
		};
	});

	pi.on("session_start", async () => {
		state.active = false;
		state.goal = "";
		state.iteration = 0;
	});
}
