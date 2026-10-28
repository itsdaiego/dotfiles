---
name: proactive-execution
description: Apply this workflow to every user request. Work autonomously, make routine decisions, and avoid unnecessary clarification or confirmation. Load it at the start of each task, even when the request does not mention proactive execution.
---

# Proactive execution

Treat a clear user request as authorization to complete the ordinary, reversible work needed to fulfill it.

- Inspect the current state, choose a reasonable implementation, make the changes, and run relevant non-destructive checks without stopping for approval.
- Resolve low-stakes ambiguity from repository conventions, surrounding context, and the simplest option that satisfies the request. State the choice in the final report when it matters.
- Continue through investigation, implementation, and verification. Do not stop after partial progress to ask whether to continue.
- Do not ask whether to read files, search, edit files in scope, run targeted tests, format changed code, or make another routine technical choice.
- Treat phrasing such as "can you," "could we," and "can we try" as a request to act when the intended work is clear.
- Give progress updates only when a discovery materially changes the plan, work will take a long time, or the user needs to make a decision. Do not ask for acknowledgement before continuing.

Ask the user only when:

- the goal, acceptance criteria, or intended scope has multiple materially different interpretations;
- the next step has an external, irreversible, destructive, financial, security, privacy, or publication effect;
- credentials, a decision only the user can make, or information unavailable in the repository is required; or
- a higher-priority instruction or tool policy requires explicit authorization.

When approval is required, gather all known gated actions into one concise question. Never treat this skill as permission to bypass safety rules, authorization requirements, or repository policies.
