# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

A collection of custom Claude Code skills — reusable prompt packages, pure Markdown, no build/lint/test tooling. Each skill lives in its own top-level directory and is installed by copying that directory into `~/.claude/skills/` (global) or `.claude/skills/` (per-project).

This repo is a git submodule of the Metis monorepo (`skills/claude-skills`), with its own remote (`seevali/claude-skills`) and independent history. Commit and push here directly; the Metis parent repo tracks the submodule pointer separately.

## Skill Anatomy

```
<skill-name>/
├── SKILL.md          # The skill itself — loaded by Claude when triggered
├── README.md         # Human-facing docs: what it does, installation, usage
├── references/       # Optional: supporting material loaded on demand
└── .claude-plugin/
    └── plugin.json   # Plugin manifest (name, description, author, license, homepage, repository, version)
```

- **SKILL.md frontmatter is the trigger mechanism.** The YAML `description` field is what Claude reads to decide whether to activate the skill — it must enumerate trigger phrases, use cases, and scope explicitly (see either existing skill for the expected density). The `name` field must match the directory name.
- **SKILL.md body is the payload.** It's written as instructions *to Claude*, not documentation *about* the skill. Keep it lean; push long supporting material into `references/`.
- Every skill also gets a `README.md` written for humans (overview, installation commands, usage), and a row in the root `README.md` skills table.
- **This repo installs via two mechanisms, both dependent on the layout above:**
  - **`npx skills` CLI** (Vercel's `skills` package): its standard search paths are the repo root and `skills/`-style folders, so it finds this repo's top-level `<skill-name>/SKILL.md` folders through the entries declared in `.claude-plugin/marketplace.json` (verified against the CLI README on 2026-10-16) — the marketplace file is load-bearing for both install paths. Do not restructure skills away from this shape.
  - **Claude Code plugin marketplace**: `.claude-plugin/marketplace.json` at repo root lists each skill as a plugin entry (`name`, `source`, `description`, `license`); each skill dir carries its own `.claude-plugin/plugin.json` with matching metadata plus a semver `version`. The version lives in `plugin.json` only, never in the marketplace entry. A single `SKILL.md` at a plugin's root (no `skills/` subdirectory needed) is a documented default location — confirmed working via `claude plugin validate` on 2026-07-05.

## Conventions

- License is Apache 2.0, copyright Seevali Rathnayake — new skills reference the root `LICENSE` (see the "License" section pattern in `mission-command/README.md`).
- Some tracked `*:Zone.Identifier` files exist (WSL artifacts from copying files in from Windows). Do not create or commit new ones; ignore the existing ones unless asked to clean them up.
- When editing a skill's SKILL.md, keep its README.md and the root README.md table in sync — descriptions drift apart otherwise.
- **Bump a plugin's `version` in its `plugin.json` whenever you change anything in that skill's folder** (patch for fixes and metadata, minor for new behaviour, major for breaking changes). Why: Claude Code compares versions to decide whether `claude plugin update <name>@claude-skills` fetches anything. A version that never moves leaves installed users stuck on old code. That happened between 2026-10-15 and 2026-10-26, when 11 commits shipped under a fixed `1.0.0`. Dropping `version` and letting the commit SHA stand in would also fix updates, but the HOL plugin scanner (hol.org, which gates the awesome-ai-plugins catalog listing) flags a missing `version` as a medium finding, and `claude plugin validate --strict` warns about it.
- **A new skill needs four things kept in sync:** its own `README.md`, a row in the root `README.md` table, a `.claude-plugin/plugin.json` inside the skill dir, and a matching entry in the root `.claude-plugin/marketplace.json` `plugins` array. Run `claude plugin validate .` (and `claude plugin validate ./<skill-name>`) after adding one.
