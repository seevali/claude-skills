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

The fleet mechanics need `bash`, `jq` and `git`. Every route above produces a plugin, and there is nothing else to install. The marketplace installs `mission-command@claude-skills`. A skill folder that carries `.claude-plugin/plugin.json` under `~/.claude/skills/` or a project's `.claude/skills/`, which is what `npx skills` and the copy commands leave behind, loads as `mission-command@skills-dir` with its hooks and agents (Claude Code's skills documentation says so; `claude plugin list` shows it). Either way the plugin's `hooks/hooks.json` registers the three landing hooks, and the workers are the plugin's own agents, `mission-command:mc-worker-opus` and `mission-command:mc-worker-sonnet`. Claude Code ignores the `hooks` key in a plugin agent's frontmatter (verified 2026-11-07: a plugin worker ran with no gauge, no reserve and no stop gate), which is why the hooks live at plugin level. Plugin hooks run on every tool call of every session where the plugin is enabled and stay inert, at about 20 ms per hook call measured on WSL 2, whenever the session's first user line carries no `MC_DISPATCH=` token. A project-level skill folder loads as a plugin only after you accept the workspace trust dialog for that project, and an administrator can block skills-directory plugins in managed settings.

- **Updating.** Marketplace: `claude plugin update mission-command@claude-skills`. `npx skills`: run the install command again. Hook and agent files load at session start, so a running session needs `/reload-plugins` or a restart to pick up a new version.
- **A copy that is not a plugin** (a folder outside the two locations above, or skills-directory plugins blocked): run `scripts/mc-install-agents.sh` once. It copies the two definitions to the `agents/` folder of Claude Code's config directory (`$CLAUDE_CONFIG_DIR`, else `~/.claude`) with the hook paths filled in, and Claude Code honours frontmatter hooks on user-level agents. The workers are then `mc-worker-opus` and `mc-worker-sonnet`. The installer refuses when `claude plugin list` already shows the plugin, because a worker reached by both routes gets every hook twice; `--force` overrides. Until 1.4.0 this README sent every `npx skills` install through the installer, which produced exactly that doubling (found 2026-11-07 on the author's machine, Claude Code 2.1.319); if you followed it, delete `mc-worker-opus.md` and `mc-worker-sonnet.md` from that `agents/` folder and address the workers by their plugin-qualified names.

**Windows** — Git for Windows is required: its Git Bash runs the hooks. The PowerShell fallback is not supported by this skill, and the `shell: bash` on every hook entry in `agents/mc-worker-*.md` makes a missing Git Bash fail visibly instead of falling through to PowerShell. Git for Windows does not ship `jq`: install it with `winget install jqlang.jq`. Clone with LF line endings: the repo's `.gitattributes` handles it (a CRLF script fails to parse, and the hooks go inert); if a clone predates it, run `git add --renormalize .` in it. WSL 2 needs none of this.

**Proving it on a Windows box** — from Git Bash, at the root of the repo that holds `mission-command/`:

```bash
git config --get core.autocrlf
grep -lU $'\r' mission-command/scripts/*.sh tests/mission-command/*.sh mission-command/agents/*.md
command -v jq realpath git bash claude cygpath
bash tests/mission-command/run.sh
bash mission-command/scripts/mc-dispatch.sh --unit W-TEST --agent mission-command:mc-worker-opus --worktree "$(pwd)" --return /tmp/ret.md --out /tmp/W-TEST.dispatch.json --cap 10
bash mission-command/scripts/mc-run.sh --dry-run /tmp/W-TEST.dispatch.json mission-command:mc-worker-opus /tmp/ret.md
```

The `grep` prints nothing (no CRLF in the working tree), `command -v` prints six paths, the suite ends `failed 0`, and the dry run prints a `cd … && claude -p …` line whose paths are all in POSIX form (`/c/…`, `/tmp/…`), never `C:\…`. `claude -p --agent` finds a definition only where the harness looks (a plugin, or the config directory's `agents/`), so the worker is addressed by its plugin-qualified name; only a copy that does not load as a plugin needs `bash mission-command/scripts/mc-install-agents.sh` first, and `mc-run.sh` prints a note when neither the plugin name is used nor that copy exists. The brief argument only has to exist, so the return skeleton serves.

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
├── agents/       # Worker definitions, the plugin's agents (their frontmatter hooks serve only a copy installed outside a plugin)
├── hooks/        # hooks.json: the three landing hooks at plugin level
├── scripts/      # The three hooks, mc-dispatch.sh, mc-land.sh, mc-run.sh
└── references/
    └── landing.md  # The landing contract
```

The test harness lives outside the installed folder, at `tests/mission-command/run.sh` in the repository root, so an install carries no developer tooling.

## What it reads, writes and sends

Written for anyone reviewing the plugin before installing it, including the plugin directory's policy review.

- **Reads.** The three hooks read the JSON the harness hands them on stdin and the worker's own transcript file, at the `transcript_path` in that JSON, for two things only: the number of distinct assistant message ids (the turn count) and the `MC_DISPATCH=<path>` token in the first user line. Under a plugin install they run in every session where the plugin is enabled; in a session that is not a worker they read that first line once, cache the negative answer, and do nothing further. Nothing from the transcript is kept beyond a per-session cache of that path under `/tmp/mc-hooks`. `mc-run.sh` and `mc-dispatch.sh` read agent frontmatter (`model`, `effort`, `maxTurns`) from the definitions shipped in `agents/`, falling back to the `agents/` folder of Claude Code's config directory (`$CLAUDE_CONFIG_DIR`, else `~/.claude`) for a copy installed with `mc-install-agents.sh`. No other file under that directory is read: no credentials file, no settings, no token, no environment secret, no keychain.
- **Writes.** The dispatch, gauge and return files the conductor names; `wip:` and `land:` commits in the worker's worktree; and, only when you run `mc-install-agents.sh` yourself, two agent definitions into the config directory's `agents/` folder.
- **Sends.** Nothing. The scripts make no network calls. The one outward process is `claude -p` in `mc-run.sh`: the user's own Claude Code CLI under the user's own login, given the brief and the stripped flags and nothing else from the machine. No script ever runs `git push`.

## Background

Distilled in July 2026 from a multi-day engagement in which a time-limited frontier model orchestrated fleets of cheaper sub-agents across several personal projects. The scarcity forced the doctrine; the doctrine turned out to be better than unlimited access would have been.

## License

Copyright 2026 Seevali Rathnayake

Licensed under the Apache License, Version 2.0. See [LICENSE](../LICENSE) for details.
