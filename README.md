# Claude Skills

A collection of custom [Claude Skills](https://docs.anthropic.com/en/docs/claude-code/skills) — reusable prompt packages that give Claude specialized capabilities.

## Skills

| Skill | Description |
|-------|-------------|
| [design-council](design-council/) | Channels five master designers — Jony Ive, Dieter Rams, Zaha Hadid, Bjarke Ingels, and Don Norman — as a consultative panel for any design work. |
| [mission-command](mission-command/) | Runs a scarce flagship model as the conductor of a cheap-model fleet: vision-first autonomy, per-agent model/effort pinning, disk-portable protocols, and gated autonomy — weeks of verified work in days. |

## Installation

### npx skills

The [Vercel `skills` CLI](https://github.com/vercel-labs/skills) discovers this repo's layout with no setup. It also works for coding agents other than Claude Code (it writes to each agent's own skills convention).

```bash
npx skills add seevali/claude-skills
```

```bash
# Install just one skill
npx skills add seevali/claude-skills --skill design-council

# Install globally (~/.claude/skills) instead of per-project
npx skills add seevali/claude-skills -g

# List available skills without installing
npx skills add seevali/claude-skills --list
```

### Claude Code plugin

This repo is also a [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) (`.claude-plugin/marketplace.json` at the repo root, with a `.claude-plugin/plugin.json` per skill). Run inside Claude Code:

```
/plugin marketplace add seevali/claude-skills
/plugin install design-council@claude-skills
/plugin install mission-command@claude-skills
```

### Manual

Copy a skill directory into `~/.claude/skills/<skill-name>` (global) or `.claude/skills/<skill-name>` (project-level):

```bash
cp -r <skill-name> ~/.claude/skills/<skill-name>   # global
cp -r <skill-name> .claude/skills/<skill-name>     # project-level
```

See each skill's README for additional installation options.

## License

Copyright 2026 Seevali Rathnayake

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
