function shellSegments(command: string): string[][] {
  const segments: string[][] = []
  let tokens: string[] = []
  let token = ""
  let quote: "'" | '"' | null = null

  const endToken = () => {
    if (token.length > 0) tokens.push(token)
    token = ""
  }
  const endSegment = () => {
    endToken()
    if (tokens.length > 0) segments.push(tokens)
    tokens = []
  }

  for (let index = 0; index < command.length; index++) {
    const character = command[index]
    if (quote) {
      if (character === quote) quote = null
      else if (character === "\\" && quote === '"' && index + 1 < command.length) token += command[++index]
      else token += character
      continue
    }
    if (character === "'" || character === '"') {
      quote = character
    } else if (character === "\\" && index + 1 < command.length) {
      token += command[++index]
    } else if (";&|\n()".includes(character)) {
      endSegment()
    } else if (/\s/.test(character)) {
      endToken()
    } else {
      token += character
    }
  }
  endSegment()
  return segments
}

function basename(value: string): string {
  return value.split("/").at(-1) ?? value
}

function segmentRunsDocumentExtractorTypecheck(tokens: string[], contextMatches: boolean, depth: number): boolean {
  if (depth > 3) return false

  const shellIndex = tokens.findIndex((token) => ["bash", "dash", "sh", "zsh"].includes(basename(token)))
  if (shellIndex >= 0) {
    const shellArgs = tokens.slice(shellIndex + 1)
    const commandIndex = shellArgs.findIndex((argument) => /^-[A-Za-z]*c[A-Za-z]*$/.test(argument))
    const script = commandIndex >= 0 ? shellArgs[commandIndex + 1] : undefined
    if (script && isBlockedDocumentExtractorTypecheck(script, contextMatches ? "/src/document_extractor" : "", depth + 1)) {
      return true
    }
  }

  let index = 0
  while (index < tokens.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[index])) index++
  const executable = basename(tokens[index] ?? "")
  const args = tokens.slice(index + 1)

  if (executable === "typeCheck.sh") return contextMatches
  return (
    contextMatches &&
    executable === "uv" &&
    args[0] === "run" &&
    basename(args[1] ?? "") === "pyright" &&
    args.some((argument) => argument === "--threads" || argument.startsWith("--threads="))
  )
}

export function isBlockedDocumentExtractorTypecheck(command: string, cwd = "", depth = 0): boolean {
  const contextMatches =
    cwd.includes("/src/document_extractor") ||
    command.includes("src/document_extractor") ||
    command.includes("document_extractor/typeCheck.sh")
  return shellSegments(command).some((segment) =>
    segmentRunsDocumentExtractorTypecheck(segment, contextMatches, depth),
  )
}
