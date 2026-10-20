import { execFile as execFileCallback } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const execFile = promisify(execFileCallback);
const BUTLER_PROJECT = "butlerinc/butler";
const RISK_WORKTREE =
	process.env.WALLE_RISK_WORKTREE ?? "/Users/daiego/Documents/code-stuff/eve/butler-walle-risk";
const RISK_PREVIEW_POLICY_REF =
	process.env.WALLE_RISK_PREVIEW_POLICY_REF ?? "origin/empran/risk-tier-gate";
const MAX_TOTAL_DIFF_CHARS = 120_000;

type MergeRequest = {
	iid: number;
	sourceBranch: string;
	targetBranch: string;
	sha: string;
	title: string;
};

async function run(command: string, args: string[], cwd?: string): Promise<string> {
	const { stdout } = await execFile(command, args, {
		cwd,
		encoding: "utf8",
		maxBuffer: 2_000_000,
	});
	return stdout;
}

function commandError(error: unknown): string {
	if (error instanceof Error) {
		return error.message;
	}
	return String(error);
}

function mergeRequestIids(text: string): number[] {
	const iids = new Set<number>();
	const trimmed = text.trim();
	if (/^!?\d+$/.test(trimmed)) {
		iids.add(Number(trimmed.replace("!", "")));
	}

	for (const match of text.matchAll(/(?:merge_requests\/|(?:^|[\s,])!|\bMR[-\s]?)(\d+)\b/gi)) {
		iids.add(Number(match[1]));
	}
	return [...iids];
}

function messageText(entry: unknown): string {
	if (typeof entry !== "object" || entry === null || !("type" in entry) || entry.type !== "message") {
		return "";
	}
	if (!("message" in entry) || typeof entry.message !== "object" || entry.message === null) {
		return "";
	}
	const content = "content" in entry.message ? entry.message.content : undefined;
	if (typeof content === "string") {
		return content;
	}
	if (!Array.isArray(content)) {
		return "";
	}
	return content
		.filter((part): part is { type: "text"; text: string } =>
			typeof part === "object" && part !== null && part.type === "text" && typeof part.text === "string",
		)
		.map((part) => part.text)
		.join("\n");
}

function inferMergeRequestIids(ctx: ExtensionCommandContext): number[] {
	const branch = ctx.sessionManager.getBranch();
	for (let index = branch.length - 1; index >= 0; index--) {
		const iids = mergeRequestIids(messageText(branch[index]));
		if (iids.length > 0) {
			return iids;
		}
	}
	return [];
}

function resolveMergeRequestIids(args: string, ctx: ExtensionCommandContext): number[] {
	const explicitIids = mergeRequestIids(args);
	return explicitIids.length > 0 ? explicitIids : inferMergeRequestIids(ctx);
}

function readString(value: unknown, key: string): string {
	if (typeof value !== "object" || value === null || !(key in value)) {
		throw new Error(`GitLab did not return ${key}.`);
	}
	const candidate = value[key as keyof typeof value];
	if (typeof candidate !== "string") {
		throw new Error(`GitLab returned an invalid ${key}.`);
	}
	return candidate;
}

function readNumber(value: unknown, key: string): number {
	if (typeof value !== "object" || value === null || !(key in value)) {
		throw new Error(`GitLab did not return ${key}.`);
	}
	const candidate = value[key as keyof typeof value];
	if (typeof candidate !== "number" || !Number.isInteger(candidate)) {
		throw new Error(`GitLab returned an invalid ${key}.`);
	}
	return candidate;
}

async function getMergeRequest(iid: number): Promise<MergeRequest> {
	const raw = await run("glab", ["mr", "view", String(iid), "-R", BUTLER_PROJECT, "-F", "json"]);
	const parsed: unknown = JSON.parse(raw);
	const responseIid = readNumber(parsed, "iid");
	return {
		iid: responseIid,
		sourceBranch: readString(parsed, "source_branch"),
		targetBranch: readString(parsed, "target_branch"),
		sha: readString(parsed, "sha"),
		title: readString(parsed, "title"),
	};
}

async function refHasPolicy(ref: string): Promise<boolean> {
	try {
		await run("git", ["cat-file", "-e", `${ref}:.gitlab/risk-tiers.toml`], RISK_WORKTREE);
		return true;
	} catch {
		return false;
	}
}

async function riskReport(mr: MergeRequest): Promise<string> {
	const sourceRef = `refs/walle-review-risk/mr-${mr.iid}`;
	const targetRef = `origin/${mr.targetBranch}`;
	const reporter = path.join(
		RISK_WORKTREE,
		".claude/skills/walle-review-risk/scripts/report.py",
	);

	await run("git", ["fetch", "origin", mr.targetBranch], RISK_WORKTREE);
	await run("git", ["fetch", "origin", `${mr.sourceBranch}:${sourceRef}`], RISK_WORKTREE);

	const command = [
		reporter,
		"--target",
		targetRef,
		"--head",
		sourceRef,
	];
	const environment = { ...process.env, PYTHONPATH: path.join(RISK_WORKTREE, "src/document_extractor") };
	const executeReport = async (args: string[]): Promise<string> => {
		const { stdout } = await execFile("python3", args, {
			cwd: RISK_WORKTREE,
			encoding: "utf8",
			maxBuffer: 2_000_000,
			env: environment,
		});
		return stdout;
	};

	if (await refHasPolicy(targetRef)) {
		return `Wall-E-equivalent risk result\n\n${await executeReport(command)}`;
	}
	if (!(await refHasPolicy(RISK_PREVIEW_POLICY_REF))) {
		return `Wall-E-equivalent result: unlabelled. ${targetRef} has no risk policy, and the local preview policy is unavailable.`;
	}
	return [
		`Wall-E-equivalent result: unlabelled. ${targetRef} has no risk policy.`,
		"",
		`Local preview using ${RISK_PREVIEW_POLICY_REF}:`,
		await executeReport([...command, "--policy-ref", RISK_PREVIEW_POLICY_REF]),
	].join("\n");
}

function truncate(text: string, maxChars: number): string {
	if (text.length <= maxChars) {
		return text;
	}
	return `${text.slice(0, maxChars)}\n\n[Diff truncated by the local Pi extension.]`;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("walle-review-risk", {
		description: "Classify Butler GitLab MRs with Wall-E's local risk policy; infers recent MRs when omitted",
		handler: async (args, ctx) => {
		if (!ctx.isIdle()) {
			ctx.ui.notify("Wait for the current response before running a risk report.", "warning");
			return;
		}
		const iids = resolveMergeRequestIids(args, ctx);
		if (iids.length === 0) {
			ctx.ui.notify("Could not infer an MR. Provide a GitLab MR URL or !IID.", "warning");
			return;
		}
		try {
			const mrs = await Promise.all(iids.map(getMergeRequest));
			const reports: string[] = [];
			for (const mr of mrs) {
				reports.push(`!${mr.iid}, ${mr.title}:\n\n${await riskReport(mr)}`);
			}
			pi.sendUserMessage(
				`Local deterministic Wall-E risk report for ${mrs.map((mr) => `!${mr.iid}`).join(", ")}:\n\n${reports.join("\n\n---\n\n")}\n\nExplain each result concisely. Do not post to Slack or GitLab, change labels, or publish anything.`,
			);
		} catch (error) {
			ctx.ui.notify(`Could not classify the MR: ${commandError(error)}`, "error");
		}
		},
	});

	pi.registerCommand("read-mr", {
		description: "Read Butler GitLab MRs and request concise, read-only digests; infers recent MRs when omitted",
		handler: async (args, ctx) => {
		if (!ctx.isIdle()) {
			ctx.ui.notify("Wait for the current response before reading an MR.", "warning");
			return;
		}
		const iids = resolveMergeRequestIids(args, ctx);
		if (iids.length === 0) {
			ctx.ui.notify("Could not infer an MR. Provide a GitLab MR URL or !IID.", "warning");
			return;
		}
		try {
			const diffCharsPerMr = Math.max(1, Math.floor(MAX_TOTAL_DIFF_CHARS / iids.length));
			const documents = await Promise.all(
				iids.map(async (iid) => {
					const [metadata, diff] = await Promise.all([
						run("glab", ["mr", "view", String(iid), "-R", BUTLER_PROJECT, "-F", "json"]),
						run("glab", ["mr", "diff", String(iid), "-R", BUTLER_PROJECT]),
					]);
					return `## !${iid}\n\nMetadata:\n${metadata}\n\nDiff:\n${truncate(diff, diffCharsPerMr)}`;
				}),
			);
			pi.sendUserMessage(
				`Read these GitLab MRs. Produce a separate concise, read-only human digest for each. Do not review them, post comments, approve them, or edit them. For each, state the TL;DR, key behavior changes, risks, files to inspect, and any description-to-diff gaps.\n\n${documents.join("\n\n---\n\n")}`,
			);
		} catch (error) {
			ctx.ui.notify(`Could not read the MR: ${commandError(error)}`, "error");
		}
		},
	});

	pi.registerCommand("read-issue", {
		description: "Explain a Slack thread, Linear issue, or other work discussion in simple, read-only terms",
		handler: async (args, ctx) => {
			if (!ctx.isIdle()) {
				ctx.ui.notify("Wait for the current response before reading an issue or discussion.", "warning");
				return;
			}
			if (!args.trim()) {
				ctx.ui.notify("Provide a Slack permalink, Linear issue, GitHub issue, or pasted discussion.", "warning");
				return;
			}
			pi.sendUserMessage(
				`Read this work discussion or issue and explain it in simple, concise terms. Follow only links that affect the current status, decision, owner, next step, blocker, or risk. State confirmed information separately from proposals and unanswered questions. Do not post, react, comment, edit, assign, change status, or create follow-up work.\n\n${args.trim()}`,
			);
		},
	});
}
