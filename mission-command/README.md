# Mission Command

**Run a scarce flagship model as the conductor of a cheap-model fleet — and get weeks of verified work done in days.**

A [Claude Skill](https://docs.anthropic.com/en/docs/claude-code/skills) encoding one repeatable engagement pattern: the human hands the model a *mission* (vision + constraints + budget), the model becomes an intellectual counterpart that drives the work autonomously, and all heavy labor is routed to cheaper model tiers with the model and effort level pinned per sub-agent.

The name comes from the military doctrine of mission command (*Auftragstaktik*): state the commander's intent, delegate the how, demand disciplined initiative, and spend your scarcest asset only where errors multiply.

## What It Does

When active, the skill makes Claude:

- **Internalize your vision first** — cheap parallel readers over your docs and code, synthesized and played back, before anything is executed
- **Design to your budget** — the cheap fleet shape is the default, not something you have to ask for; resumable plans, disk-based trackers, a per-phase model/effort matrix, a pre-launch shape estimate (agents × turns × context), and a cost ledger: every fleet run's measured cost against the shared pool, with no launch that would spend more than a third of what remains
- **Land the workers** — a worker's turn cap lives only in its agent definition; three hooks shipped with the skill give it a turn gauge on every tool result, a reserve in which only commit and the return file are allowed, and a stop gate that refuses an unlanded exit; when one caps anyway, `mc-land.sh` commits the leftovers and runs the gate, so the flagship never finishes a worker's last lines. Workers run stripped: no CLAUDE.md hierarchy, no skill or plugin listings, no MCP servers, a tool allowlist, model and effort pinned
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

**Not on the Claude plugin directory, by decision.** Submitted 2026-10-16 and withdrawn 2026-11-07. The directory's policy check (2026-11-07, v1.2.0) refuses three things from any plugin not published by an Anthropic-Verified organization, with no way to apply for that status: hooks of type `command`, files that are not Markdown, text, JSON, YAML or images, and agent frontmatter keys outside its allow-list. The landing mechanics are exactly those three things (the three hooks, the `scripts/*.sh` files, and keys such as `maxTurns` and `hooks` in `agents/*.md`), so the plugin cannot be listed there without losing what makes it work. Do not resubmit unless that policy changes; the marketplace and `npx skills` routes above carry no such limit.

**Claude Code, manual copy** — global (every project) or project-level:

```bash
cp -r mission-command ~/.claude/skills/mission-command   # global
cp -r mission-command .claude/skills/mission-command     # project-level
```

The fleet mechanics need `bash`, `jq` and `git`. Worker definitions: the shipped definitions reference `${CLAUDE_PLUGIN_ROOT}` and work as-is under a plugin install; for a skills-folder install or headless runs, run `scripts/mc-install-agents.sh` once, which copies them to the `agents/` folder of Claude Code's config directory (`$CLAUDE_CONFIG_DIR`, else `~/.claude`) with the path filled in. Claude Code runs a project agent's frontmatter hooks only after you accept the workspace trust dialog once for that folder.

**Windows** — Git for Windows is required: its Git Bash runs the hooks. The PowerShell fallback is not supported by this skill, and the `shell: bash` on every hook entry in `agents/mc-worker-*.md` makes a missing Git Bash fail visibly instead of falling through to PowerShell. Git for Windows does not ship `jq`: install it with `winget install jqlang.jq`. Clone with LF line endings: the repo's `.gitattributes` handles it (a CRLF script fails to parse, and the hooks go inert); if a clone predates it, run `git add --renormalize .` in it. WSL 2 needs none of this.

**Proving it on a Windows box** — from Git Bash, at the root of the repo that holds `mission-command/`:

```bash
git config --get core.autocrlf
grep -lU $'\r' mission-command/scripts/*.sh tests/mission-command/*.sh mission-command/agents/*.md
command -v jq realpath git bash claude cygpath
bash tests/mission-command/run.sh
bash mission-command/scripts/mc-dispatch.sh --unit W-TEST --agent mc-worker-opus --worktree "$(pwd)" --return /tmp/ret.md --out /tmp/W-TEST.dispatch.json --cap 10
bash mission-command/scripts/mc-run.sh --dry-run /tmp/W-TEST.dispatch.json mc-worker-opus /tmp/ret.md
```

The `grep` prints nothing (no CRLF in the working tree), `command -v` prints six paths, the suite ends `failed 0`, and the dry run prints a `cd … && claude -p …` line whose paths are all in POSIX form (`/c/…`, `/tmp/…`), never `C:\…`. `claude -p --agent` finds a definition only where the harness looks (the plugin, or the config directory's `agents/`), so under a skills-folder install run `bash mission-command/scripts/mc-install-agents.sh` first; `mc-run.sh` prints a note when that copy is missing. The brief argument only has to exist, so the return skeleton serves.

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
├── README.md     # This file
├── agents/       # Worker definitions with landing hooks
├── scripts/      # The three hooks, mc-dispatch.sh, mc-land.sh, mc-run.sh
└── references/
    └── landing.md  # The landing contract
```

The test harness lives outside the installed folder, at `tests/mission-command/run.sh` in the repository root, so an install carries no developer tooling.

## What it reads, writes and sends

Written for anyone reviewing the plugin before installing it, including the plugin directory's policy review.

- **Reads.** The three hooks read the JSON the harness hands them on stdin and the worker's own transcript file, at the `transcript_path` in that JSON, for two things only: the number of distinct assistant message ids (the turn count) and the `MC_DISPATCH=<path>` token in the first user line. Nothing from the transcript is kept beyond a per-worker cache of that path under `/tmp/mc-hooks`. `mc-run.sh` and `mc-dispatch.sh` read agent frontmatter (`model`, `effort`, `maxTurns`) from the definitions shipped in `agents/`, falling back to the `agents/` folder of Claude Code's config directory (`$CLAUDE_CONFIG_DIR`, else `~/.claude`) for a skills-folder install. No other file under that directory is read: no credentials file, no settings, no token, no environment secret, no keychain.
- **Writes.** The dispatch, gauge and return files the conductor names; `wip:` and `land:` commits in the worker's worktree; and, only when you run `mc-install-agents.sh` yourself, two agent definitions into the config directory's `agents/` folder.
- **Sends.** Nothing. The scripts make no network calls. The one outward process is `claude -p` in `mc-run.sh`: the user's own Claude Code CLI under the user's own login, given the brief and the stripped flags and nothing else from the machine. No script ever runs `git push`.

## Background

Distilled in July 2026 from a multi-day engagement in which a time-limited frontier model orchestrated fleets of cheaper sub-agents across several personal projects. The scarcity forced the doctrine; the doctrine turned out to be better than unlimited access would have been.

## License

Copyright 2026 Seevali Rathnayake

Licensed under the Apache License, Version 2.0. See [LICENSE](../LICENSE) for details.
