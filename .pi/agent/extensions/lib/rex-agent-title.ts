const ATTACHMENT_PREFIX = /^(?:\[(?:Image|Attachment)\s+\d+\]\s*)+/i;

function normalizeTask(text: string): string {
  return text.replace(/\s+/g, " ").trim().replace(ATTACHMENT_PREFIX, "").trim();
}

export function findInitialTaskPrompt(prompts: string[]): string {
  for (const prompt of prompts) {
    const normalized = normalizeTask(prompt);
    if (normalized) return normalized;
  }
  return "";
}

export function buildRexAgentTitle(text: string, workspace: string, maxLength = 72): string {
  const prefix = "π - ";
  const task = normalizeTask(text);
  const fallback = normalizeTask(workspace) || "pi";
  const content = task || fallback;
  const fullTitle = `${prefix}${content}`;

  if ([...fullTitle].length <= maxLength) {
    return fullTitle;
  }

  const available = Math.max(1, maxLength - [...prefix].length - 1);
  const characters = [...content];
  const rawShortened = characters.slice(0, available).join("");
  let shortened = rawShortened.trimEnd();
  const cutsInsideWord =
    characters.length > available &&
    /\S/.test(characters[available - 1] ?? "") &&
    /\S/.test(characters[available] ?? "");
  if (cutsInsideWord) {
    shortened = shortened.replace(/\s+\S*$/, "") || shortened;
  }

  return `${prefix}${shortened}…`;
}
