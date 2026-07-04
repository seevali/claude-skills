# Mission Command

**Run a scarce flagship model as the conductor of a cheap-model fleet — and get weeks of verified work done in days.**

A [Claude Skill](https://docs.anthropic.com/en/docs/claude-code/skills) encoding one repeatable engagement pattern: the human hands the model a *mission* (vision + constraints + budget), the model becomes an intellectual counterpart that drives the work autonomously, and all heavy labor is routed to cheaper model tiers with the model and effort level pinned per sub-agent.

The name comes from the military doctrine of mission command (*Auftragstaktik*): state the commander's intent, delegate the how, demand disciplined initiative, and spend your scarcest asset only where errors multiply.

## What It Does

When active, the skill makes Claude:

- **Internalize your vision first** — cheap parallel readers over your docs and code, synthesized and played back, before anything is executed
- **Design to your budget** — resumable plans, disk-based trackers, and a per-phase model/effort matrix written into the workspace
- **Pin the fleet** — fast tier reads, mid tier implements and verifies, flagship designs and adjudicates; sub-agents never choose their own tier, and zero flagship tokens go to grunt work
- **Make the operation disk-portable** — protocol READMEs, trackers, and decision ledgers that let any fresh session (or an unattended headless fleet) resume from files alone
- **Keep autonomy gated** — adversarial verification as a separate role, rehearsals before irreversible operations, draft PRs with you as the merge-gate, and a strict blocked-over-guessed rule for unattended workers

## Installation

**Claude Code, global** — available in every project:

```bash
cp -r mission-command ~/.claude/skills/mission-command
```

**Claude Code, project-level:**

```bash
cp -r mission-command .claude/skills/mission-command
```

**Claude Code plugin:**

```bash
/plugin add <this-repo>
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
├── SKILL.md      # The protocol: five phases + non-negotiables
└── README.md     # This file
```

## Background

Distilled in July 2026 from a multi-day engagement in which a time-limited frontier model orchestrated fleets of cheaper sub-agents across several personal projects. The scarcity forced the doctrine; the doctrine turned out to be better than unlimited access would have been.

## License

Copyright 2026 Seevali Rathnayake

Licensed under the Apache License, Version 2.0. See [LICENSE](../LICENSE) for details.
