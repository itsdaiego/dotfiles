import assert from "node:assert/strict"
import { test } from "node:test"
import registerAwsCommandGuard, {
  classifyAwsCommand,
} from "../../.pi/agent/extensions/zz-aws-command-guard.ts"

test("ignores commands that only mention aws in arguments", () => {
  assert.equal(
    classifyAwsCommand(`rg -n "Only read-only AWS CLI commands" ~/.pi | head -50`),
    "none",
  )
  assert.equal(
    classifyAwsCommand("git worktree add -b topic/aws-guard ../dotfiles-aws-guard master"),
    "none",
  )
})

test("runs chained and piped read-only aws commands without asking", () => {
  assert.equal(
    classifyAwsCommand(`aws s3 cp "s3://bucket/a.ogg" "/tmp/a.ogg" && aws s3 cp "s3://bucket/b.ogg" "/tmp/b.ogg"`),
    "read",
  )
  assert.equal(classifyAwsCommand("AWS_PROFILE=eve aws logs describe-log-groups --output json | jq ."), "read")
  assert.equal(classifyAwsCommand("rtk aws sts get-caller-identity"), "read")
})

test("asks before a write hidden anywhere in a compound command", () => {
  assert.equal(classifyAwsCommand("aws s3 ls s3://bucket && aws s3 rm s3://bucket/key"), "ask")
  assert.equal(classifyAwsCommand("aws s3 cp /tmp/a.ogg s3://bucket/a.ogg"), "ask")
  assert.equal(classifyAwsCommand(`bash -c "aws ec2 terminate-instances --instance-ids i-1"`), "ask")
  assert.equal(classifyAwsCommand("cat ids.txt | xargs aws s3 rm"), "ask")
})

test("asks when command substitution can hide an aws call", () => {
  assert.equal(classifyAwsCommand("echo $(aws s3 rb s3://bucket)"), "ask")
})

test("prompts before an aws write and honors the answer", async () => {
  const handlers = new Map<string, Array<(event: unknown, context: unknown) => Promise<unknown>>>()
  registerAwsCommandGuard({
    on(event: string, handler: (event: unknown, context: unknown) => Promise<unknown>) {
      handlers.set(event, [...(handlers.get(event) ?? []), handler])
    },
  } as never)

  const toolCallHandler = handlers.get("tool_call")?.[0]
  assert.ok(toolCallHandler)

  let prompts = 0
  const event = { toolName: "bash", input: { command: "aws s3 rm s3://bucket/key" } }
  const allowed = await toolCallHandler(event, {
    hasUI: true,
    ui: {
      async confirm() {
        prompts++
        return true
      },
    },
  })
  assert.equal(allowed, undefined)
  assert.equal(prompts, 1)

  const denied = await toolCallHandler(event, {
    hasUI: true,
    ui: { async confirm() { return false } },
  })
  assert.deepEqual(denied, {
    block: true,
    reason: "User denied this AWS command. Do not retry it through another command, script, or tool.",
  })
})
