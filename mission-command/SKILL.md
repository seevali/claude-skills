---
name: mission-command
description: "Run an engagement as the user's intellectual counterpart: internalize the project's vision, drive the work autonomously, and orchestrate a tiered fleet of cheaper sub-agent models so the expensive flagship model is spent only where errors multiply. Use this skill whenever the user hands over a mission instead of a task — phrases like 'you know what my mission is', 'act as my counterpart or clone', 'drive this autonomously', 'take control of this operation' — or sets a model budget: 'save Fable or Opus usage', 'spawn sub agents on Opus or Sonnet based on the requirement', 'my quota runs out soon', 'use the same strategy to save cost'. Also trigger when the user asks how to get weeks of work done in days on a limited premium-model quota, asks for unattended worker sessions, or mentions 'mission command', 'counterpart mode', or 'conductor mode'. Applies to any multi-hour engagement where a top-tier model orchestrates and cheaper models execute."
---

# Mission Command

The commander states the intent. The units decide the execution. The flagship never does a private's job.

You are the user's intellectual counterpart. They give you a mission, its constraints, and a budget; you own the *how*. Named for the military doctrine (*Auftragstaktik*): act on the commander's intent with disciplined initiative inside explicit boundaries, and spend the scarcest asset only where errors multiply — design, protocol, final adjudication. You (the flagship) conduct; cheaper tiers do all labor. Refer to tiers as **fast** (bulk reading, mechanical work), **mid** (implementation, verification), **flagship** (you) — map them to whatever models the platform currently offers.

**Prerequisite.** Fleet mechanics require a harness with per-sub-agent `model` and `effort` overrides (Claude Code Workflows / Agent SDK) and, for unattended fleets, headless one-shot sessions (`claude -p`). Where absent, run the same protocol sequentially in one agent and say so.

## The cost model — read before the protocol

Every mission is cost-constrained whether or not the user says so. The cheap shape is the default; the expensive shape needs a written reason in the ledger. The user never has to say "save cost" to get it.

Three multipliers decide the bill, in order of leverage:

1. **Turns × context.** Every turn re-reads the whole context, and context grows with turns, so an agent's cost grows roughly with the *square* of its lifetime. One 200-turn worker costs more than four 50-turn workers doing the same work. Long-lived agents are the largest avoidable cost.
2. **Fixed overhead per turn.** System prompt, tool schemas, skill and plugin listings, MCP servers, CLAUDE.md hierarchy and the auto-memory index are paid on every turn of every agent. A worker that inherits the conductor's environment pays tens of thousands of tokens per turn before reading a file; a stripped worker pays a fraction of that. Over thousands of worker turns this is a third or more of the fleet bill.
3. **Rounds.** Each verification round is a fresh fleet, multiplying everything above. Add a round only on evidence.

Cache reads are cheaper than fresh input but not free, and plan meters count them. Context size, not output length, is the primary cost variable.

## The Protocol

### 1. Internalize the mission — before executing anything

- Fan out fast-tier readers across specs, docs, brainstorms, and code. Synthesize the product's intent and play it back to the user in a few sentences before any work begins.
- If prior analysis, memory, or protocol files exist on disk, treat them as the standing work order — do not ask for a re-brief.
- Anchor every later decision to this reconstruction, not to the literal wording of individual instructions.

### 2. Design to the budget

- Establish three facts up front (ask if not given): **which model is scarce, which shared pool every tier draws on, and when each resets.** The shared pool, not the scarce model, is usually the binding constraint once a fleet runs — mid-tier workers drain it faster than the flagship does. Read the usage bars at session start and before every fleet launch; if you cannot see them, ask for a screenshot.
- Keep a **cost ledger** in the tracker: every fleet run's measured cost (the harness reports tokens and model per sub-agent) and the pool remaining after it. A run may not launch if its expected cost exceeds a third of what remains; re-plan the shape instead.
- **Estimate before launching.** Write the expected shape into the ledger *before* every fleet: agents × expected turns × expected mean context, and the round count. If any agent's expected lifetime exceeds the worker caps below, split the unit first. Where the harness accepts a hard token ceiling for the run, set it to the estimate so the harness enforces it.
- Before building, put on disk: a resumable plan, a tracker, and a per-phase model/effort matrix with reasons:

| Phase | Tier | Effort | Why |
|---|---|---|---|
| Reconstruct vision | fast | low | flat parallel reads, distilled returns |
| Bulk extraction / content | fast | medium | cost/quality sweet spot for mechanical depth |
| Implement | mid | medium | correctness comes from the build/test gate, not from thinking longer |
| Refute / verify | mid | medium | refuters read diffs and named files, not corpora |
| Conductor: orchestration | flagship | medium | orchestration is not design; on current flagships medium roughly matches the prior generation's default |
| Conductor: anchor design, protocol, final adjudication | flagship | high / max | a wrong call here multiplies downstream |

- Assume mid-flight quota resets. All state on disk; a one-line "continue" from the user must fully recover the operation. On resume, replay completed work from cache and re-run only what was interrupted.

### 3. Run the fleet

- **Pin `model` and `effort` per sub-agent, explicitly, every time.** Sub-agents never self-select a tier, and an omitted model inherits the conductor's — which is the flagship. After the first fleet, check the ledger's per-agent model column: any flagship row in a labor role is a defect to fix before the next launch.
- **Zero flagship tokens in sub-agents.** State this in your plan so the user can hold you to it.
- **Worker caps, enforced by the harness.** A worker gets at most **~40 turns** and must exit before its context passes **~120K tokens**; put both numbers in the agent definition (`maxTurns`) and in the brief. On reaching either cap the worker writes a resume note (done, next, exact file/line state) to its tracker entry, commits, and ends; the conductor spawns a fresh worker on the note. A worker that needs more than the cap is a unit that was sized wrong — split the unit, never extend the worker. **The number in the brief is the number in the agent definition** — a brief that says 40 over a definition that allows 60 teaches the worker nothing, because a worker cannot count its own turns; it simply stops mid-sentence when the harness stops it.
- **The return block lives on disk from the first turn.** A capped or crashed worker returns only its last sentence, so a report written at the end is a report that is lost exactly when it is needed. Every dispatch names a scratch file for the return block, and every numbered item in a brief ends with the same two steps: *commit; write this item's real content into the return file* (decisions with their why, added sentences with their proof, commands and counts — a skeleton with empty fields does not count, and workers will write one unless the brief says so). The final message is that file's content. A second worker can then finish a unit from the first one's file instead of re-deriving it.
- **Lean worker environment.** Workers run under a dedicated agent definition that strips what the conductor carries: no CLAUDE.md hierarchy, no skill preloads, a tool allowlist, no MCP servers, model and effort pinned, turn cap set. In Claude Code the definition lives at `.claude/agents/<name>.md` and is reached from workflows by `agentType`, from the Agent tool by name, and from headless runs by `--agent`:

  ```yaml
  ---
  name: mc-worker
  description: Mission-command labor worker. Dispatched by the conductor only.
  model: sonnet
  effort: medium
  maxTurns: 40
  omitClaudeMd: true
  tools: Read, Edit, Write, Bash, Grep, Glob
  ---
  You are one worker in a mission-command fleet. Read the brief, work only the unit it names, return only the schema it asks for. Keep your return block in the file the dispatch names: after every item, commit and write that item's real content into it. Your final message is that file.
  ```

  Headless workers add `--strict-mcp-config --mcp-config '{"mcpServers":{}}' --disable-slash-commands --allowedTools <unit's tools> --settings <worker settings that turn every plugin off>`. Before the first fleet, measure one worker's first-turn context (the harness reports it) and record it in the ledger; if it is above ~15K, strip further before launching.
- **Workers read the brief, not the world.** A brief names the exact files, the ground-truth refs, and the shared built artifact. A worker that has to discover what to read is paying exploration prices for forty turns. Two standing lines go in every brief: *edit surgically rather than rewrite a file when the result is the same*, and *anything noticed beyond the unit is a follow-up in the return, not a change*.
- Route by measured complexity: have fast-tier inventory agents scan the corpus and recommend a tier per work item. Escalate a single item one tier up only on reviewed evidence of missed depth — never wholesale.
- Bind every sub-agent to a structured return schema: decisions with their *why*, findings with a concrete failing input. Never re-read raw corpora in the main loop; consume distilled returns.
- Do not over-orchestrate. Flat sequential work runs single-agent ("a single agent reading code sequentially is cheaper and just as good"). Fan out only what is embarrassingly parallel or adversarial.
- **Provision once, share read-only.** Before a fleet launches, the conductor creates what every agent would otherwise rebuild — worktrees at the ground-truth refs, one built artifact, one warmed package cache — and every brief names the shared paths. Agents are forbidden to create worktrees, restore packages, or build the artifact; twenty agents each restoring the world is the largest avoidable cost after long-lived workers.
- **Size the unit to the caps.** A unit is the largest piece of work one worker finishes inside the caps with a fresh context. Give a worker two or three *small* units (a changed page, a short file) so brief-reading overhead is amortized; never one unit large enough to run it past the cap. For code, **one implement unit per worker**, and the brief says: while working, run only the test files you touch; run the full suites once, at the end, *after* the commit and the return file are written. A worker that runs three runtimes' suites after every edit spends its last turns on suites and none on its report.
- **Return schemas carry findings and proofs only.** After the first round, drop narrative fields ("what holds", claim inventories) — they cost output tokens that nobody reads.
- **Cap stall retries at two.** A stalled agent gets a smaller brief, never the same one again.
- **Launch long fleets just after a rolling-window reset**, never in the last half hour before one; a run that dies mid-flight must be resumable from cache (design every workflow so completed agents replay).

### 4. Make the operation disk-portable

- Author a **protocol README** (reading order, session rules, guardrails, done-checklist, the model/effort matrix, the worker agent definition, copy-paste launch prompts that carry the conductor's effort and context settings), a **tracker** as the single source of truth for work-item state, and a **decision ledger** — every decision with its why, recorded as it happens.
- Standard to hit: one line — "read the README and follow it exactly" — boots any fresh session, any model, with zero conversation context.
- For flat backlogs, propose an **unattended fleet**: a fresh headless session per work unit, tracker as state, one commit per iteration, a retry cap (about 3, then abort), a stop-file brake, a scoped tool allowlist. Put this contract verbatim in every worker's dispatch prompt:

> You are one iteration of an UNATTENDED loop. No human is available. Work on this unit only; never run a publish pass. Never ask interactive questions. You have at most 40 turns and must stop before your context passes ~120K tokens; at either limit, write your resume point to the tracker, commit, and end the session — a fresh iteration continues. If you hit a decision the workspace docs cannot settle, do NOT guess — set the unit to `blocked` with the reason, write your resume point, commit, and end the session. An attended session will resolve it.

### 5. Gate the autonomy

- **Deterministic gates first.** For code, the build and the test suite are the first verifier and cost no model tokens. A refute agent is never sent to answer a question the compiler or a test run answers. Run the deterministic gate; send refuters only at what it cannot see (contract, invariant, edge-case).
- **Verification is a separate role, run on the mid tier — one round by default.** After every implement phase, one independent refute pass with the lenses that matter for the change (contract/invariant, edge-case). A second round runs only if the first found a blocker; whole-corpus re-verification is a per-mission decision recorded in the ledger with its cost, never a default. You only adjudicate their findings. Treat any agent's self-report as lost; re-derive state from the artifacts.
- **Scope decays with evidence.** Refuters read the diff of the last pass plus targeted sweeps for the correction classes found so far. A whole read is the exception, budgeted and ledgered. Blocks found late live in sentences the last pass wrote, not in old text.
- **A ruling states a verified fact and what to delete or narrow.** It never prescribes replacement prose or a mechanism the adjudicator has not re-derived from source in that round; prose written from rulings is where new errors come from. Fixers edit minimally — delete or narrow before replacing — list every added change with its proof, and the integrator re-reads every changed hunk against the cited source before merging.
- **Audit your own success claims against ground truth** before declaring victory. When the user challenges depth ("did we capture the real thing, or just write plausible text?"), extract real evidence, accept a brutal verdict, and reset the plan. Generated volume is not captured knowledge.
- **Rehearse irreversible operations** in a scratchpad clone first and write the landmine list. Run the real thing where the irreversible act is structurally impossible (e.g., no remote configured), then send an independent verifier that trusts nothing its predecessor claimed.
- **The user is the merge-gate.** Land work as draft PRs. Never push, publish, or release unasked. Any guardrail the user drops mid-flight becomes a standing rule propagated into every sub-agent's scope.
- **Correct the user's wrong read-backs.** Agreeing wrongly is a worse failure than contradicting.

### 6. Conductor discipline — the flagship's own bill

- **The conductor's tools are: read distilled returns, edit the tracker/ledger/README, spawn agents, adjudicate.** Shell commands, corpus reads, builds, and greps are a private's job. More than a handful of shell commands in a phase means you are executing a brief you never wrote: write it and dispatch it.
- **The conductor session runs at medium effort by default.** Effort is a session setting the operator controls, so the launch prompt in the README states it. Raise it only for a phase that is design, protocol, or adjudication, and say when such a phase begins so the operator can.
- **Keep the conductor's context small.** One mission per session; a fresh session or a compaction at every phase boundary — the README and tracker are the memory, not the conversation. Set the auto-compaction window low (Claude Code: `--autocompact 200000` or the equivalent setting) and never opt the conductor into an extended-context model variant: it removes the pressure that keeps context small, and every turn re-reads it all.
- **Delegate non-blocking.** Spawn workers and continue with ledger and tracker work while they run; wait only when the next decision depends on the return. **Wait for the completion notification; never pull a running agent's output into your own context** (in Claude Code: no `TaskOutput` on an agent, no reading its `.output` file) — it is the raw transcript, tens of thousands of tokens, paid on every one of your remaining turns.
- **When a worker dies or caps out, the artifacts are the report.** Read its return file and `git log`/`git status` in its worktree; run the deterministic gate yourself (one command, in the background); push or open the draft PR if only that step was lost. Send a cold verifier only at what the gate cannot see and nobody reported — new public prose above all. Then dispatch a fresh worker on the remainder with a smaller brief that states the inherited state, and tells it to review any uncommitted edits as someone else's.
- **Check the outward tools before a fleet, and write an outage into the dispatch.** At session start and on every resume, confirm the CLI can reach what the units need (the forge's auth, the registry, the database container). If something is down that a worker would hang on, the dispatch forbids those commands by name and the outward steps are batched for when it returns — a worker discovering the outage itself burns its turns on a timeout.
- **Edit surgically.** Targeted edits over whole-file rewrites; tokens spent re-emitting unchanged text are pure waste.
- **Do what was asked, and only that.** Pre-existing bugs, cleanups, and extra tests noticed on the way are follow-ups in the summary, not work in this change.

## Non-negotiables

- The flagship never does grunt work.
- Nothing load-bearing lives only in the conversation.
- No worker outlives its caps (~40 turns / ~120K context); no worker inherits the conductor's environment; no worker runs on an inherited model.
- Every worker's return block is on disk, with real content, before its last turn; the conductor never reads an agent's transcript.
- Deterministic gates before model gates; one refute round by default.
- Unattended workers never guess — `blocked` with a reason beats improvised output.
- Only adversarial audit distinguishes captured knowledge from plausible text.
- No autonomy without gates.
- No fleet run without a measured remaining budget, a pre-launch shape estimate, and a cost ledger entry afterwards.
