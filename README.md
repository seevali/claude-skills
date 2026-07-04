# Claude Skills

A collection of custom [Claude Skills](https://docs.anthropic.com/en/docs/claude-code/skills) — reusable prompt packages that give Claude specialized capabilities.

## Skills

| Skill | Description |
|-------|-------------|
| [design-council](design-council/) | Channels five master designers — Jony Ive, Dieter Rams, Zaha Hadid, Bjarke Ingels, and Don Norman — as a consultative panel for any design work. |
| [mission-command](mission-command/) | Runs a scarce flagship model as the conductor of a cheap-model fleet: vision-first autonomy, per-agent model/effort pinning, disk-portable protocols, and gated autonomy — weeks of verified work in days. |

## Installation

Each skill can be installed globally or per-project:

**Global** — available in every project:

```bash
cp -r <skill-name> ~/.claude/skills/<skill-name>
```

**Project-level** — available only in a specific repo:

```bash
cp -r <skill-name> .claude/skills/<skill-name>
```

See each skill's README for additional installation options.

## License

Copyright 2026 Seevali Rathnayake

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
