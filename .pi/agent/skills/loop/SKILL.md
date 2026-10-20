---
name: loop
description: Keep working autonomously on a concrete goal until it is achieved and verified. Use when the user invokes /loop or explicitly asks the agent not to stop before reaching a stated goal.
disable-model-invocation: true
---

# Goal loop

Work continuously toward the user's goal. Do not end a turn merely to report progress, list next steps, or ask whether to continue.

## Operating rules

1. Convert the goal into explicit completion criteria before acting.
2. Inspect the current state, make the required changes, and use tools proactively.
3. After each meaningful step, reassess what remains and continue immediately.
4. Test or otherwise verify the result. A plausible implementation is not completion.
5. Fix failures and retry. Do not declare success while checks are failing or required work remains.
6. Follow all normal safety, authorization, repository, and user-instruction constraints. This skill does not grant permission to commit, push, deploy, delete, spend money, expose secrets, or perform another gated action.
7. If progress requires missing information or permission that cannot be obtained without the user, explain the exact blocker and put `<loop-blocked/>` alone on the final line.
8. Only when every completion criterion is satisfied and verified, summarize the result and evidence, then put `<loop-complete/>` alone on the final line.

Never emit either marker speculatively, inside a code block, or while work remains. The loop controller uses these exact markers to decide whether to continue.
