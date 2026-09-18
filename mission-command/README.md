# Mission Command

**Run a scarce flagship model as the conductor of a cheap-model fleet — and get weeks of verified work done in days.**

A [Claude Skill](https://docs.anthropic.com/en/docs/claude-code/skills) encoding one repeatable engagement pattern: the human hands the model a *mission* (vision + constraints + budget), the model becomes an intellectual counterpart that drives the work autonomously, and all heavy labor is routed to cheaper model tiers with the model and effort level pinned per sub-agent.

The name comes from the military doctrine of mission command (*Auftragstaktik*): state the commander's intent, delegate the how, demand disciplined initiative, and spend your scarcest asset only where errors multiply.

## What It Does

When active, the skill makes Claude:

- **Internalize your vision first** — cheap parallel readers over your docs and code, synthesized and played back, before anything is executed
- **Design to your budget** — the cheap fleet shape is the default, not something you have to ask for; resumable plans, disk-based trackers, a per-phase model/effort matrix, a pre-launch shape estimate (agents × turns × context), and a cost ledger: every fleet run's measured cost against the shared pool, with no launch that would spend more than a third of what remains
- **Cap the workers** — a worker lives at most ~40 turns / ~120K context (enforced by the harness, resumed by a fresh worker from a written note) and runs in a stripped environment: no CLAUDE.md hierarchy, no skill or plugin listings, no MCP servers, a tool allowlist, model and effort pinned — because cost grows with the square of an agent's lifetime and fixed per-turn overhead is a third of a fleet's bill
- **Spend the fleet where it counts** — deterministic gates (build, tests) before any refuter; one refute round by default, scoped to the diff; shared read-only provisioning (worktrees, built artifacts, package caches) so agents never rebuild the world; rulings that state facts and deletions rather than prose
- **Pin the fleet** — fast tier reads, mid tier implements and verifies, flagship designs and adjudicates; sub-agents never choose or inherit their tier, and zero flagship tokens go to grunt work
- **Discipline the conductor** — no shell work in the main loop, medium effort for orchestration, small context (one mission per session, low auto-compaction window, no extended-context variant), non-blocking delegation, surgical edits, no scope extras
- **Make the operation disk-portable** — protocol READMEs, trackers, and decision ledgers that let any fresh session (or an unattended headless fleet) resume from files alone
- **Keep autonomy gated** — adversarial verification as a separate role, rehearsals before irreversible operations, draft PRs with you as the merge-gate, and a strict blocked-over-guessed rule for unattended workers

## Installation

**npx skills** — installs from the [claude-skills](https://github.com/seevali/claude-skills) repo, works for Claude Code and other supported agents:

```bash
npx skills add seevali/claude-skills --skill mission-command
```

**Claude Code plugin** — this repo is a plugin marketplace; add it once, then install:

```
/plugin marketplace add seevali/claude-skills
/plugin install mission-command@claude-skills
```

**Claude Code, manual copy** — global (every project) or project-level:

```bash
cp -r mission-command ~/.claude/skills/mission-command   # global
cp -r mission-command .claude/skills/mission-command     # project-level
```

**Claude.ai** — zip the `mission-command` folder (folder at ZIP root) and upload it under Settings → Capabilities → Skills. Note: on claude.ai the *doctrine* loads, but the fleet mechanics (per-agent model pinning, headless worker loops) require Claude Code — the skill degrades to single-agent execution of the same moves.

## Usage

The skill triggers automatically on mission-style prompts. The shape that drives it:

> "Here is my vision: … My premium-model quota ends soon, so route sub-agent work to cheaper models by task complexity and save the flagship for judgment. Document every decision. You own the mission — drive it to done."

Steering afterward can be as small as a heartbeat: *"quota refilled — keep going."*

Or invoke it directly: `/mission-command`.

## File Structure

```
mission-command/
├── SKILL.md      # The protocol: cost model + six phases + non-negotiables
└── README.md     # This file
```

## Background

Distilled in July 2026 from a multi-day engagement in which a time-limited frontier model orchestrated fleets of cheaper sub-agents across several personal projects. The scarcity forced the doctrine; the doctrine turned out to be better than unlimited access would have been.

## License

Copyright 2026 Seevali Rathnayake

Licensed under the Apache License, Version 2.0. See [LICENSE](../LICENSE) for details.
