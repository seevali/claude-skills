# Ratification Docket

**Rule on every open decision from one page, in plain language, without reading the documents that proposed them.**

A [Claude Skill](https://docs.anthropic.com/en/docs/claude-code/skills) for the moment an operation has produced a decision
record, a report and a tracker full of Proposed items and operator gates, and the owner has to ratify, amend or reject them.
Instead of a walkthrough written in the documents' own vocabulary, Claude builds an interactive ballot page: one card per real
decision, each with the question in plain words, what each option gets and costs, a recommendation, and the default if skipped.
Answers save to the page. Claude reads them back, writes a dated decision record, and updates every Status line, tracker and
ledger the rulings touch.

## What It Does

When active, the skill makes Claude:

- **Collect** every Proposed item, gate and question across the documents, with its default, and check ground truth first
- **Verify the supersession map** — where a later document changes, retimes, reinforces or contradicts an earlier one — with
  adversarial refuters and a completeness critic before the owner sees a single flag
- **Collapse** dozens of document items into fifteen to twenty-five plain-language decisions, with sub-questions wherever the
  documents silently disagree, and pin the few that cannot be skipped
- **Build and publish** the ballot as an artifact page (from the bundled template) that saves answers server-side
- **Read the answers back and apply them**: a dated decision record with every ruling's why, the owner's departures from the
  recommendations named, and every source document's Status lines, trackers and ledgers updated

## Installation

**npx skills** — installs from the [claude-skills](https://github.com/seevali/claude-skills) repo:

```bash
npx skills add seevali/claude-skills --skill ratification-docket
```

**Claude Code plugin** — this repo is a plugin marketplace; add it once, then install:

```
/plugin marketplace add seevali/claude-skills
/plugin install ratification-docket@claude-skills
```

**Claude Code, manual copy** — global (every project) or project-level:

```bash
cp -r ratification-docket ~/.claude/skills/ratification-docket   # global
cp -r ratification-docket .claude/skills/ratification-docket     # project-level
```

## Usage

Point Claude at the documents and say what you want to do with them:

> Read `docs/decisions/<record>.md` and `docs/<op>/report.md`. Walk me through every Proposed decision so I can ratify,
> amend or reject each one — I don't want to read the documents.

Claude publishes the ballot link. Answer on the page; skipped cards take their stated default. Then:

> Answered. Check.

Claude reads the answers from the page, writes the decision record, and updates the trackers.

The page requires the artifact `db` capability to save answers; without it the page keeps answers on the device and shows a
copy-out block instead.

## Files

- `SKILL.md` — the protocol Claude follows
- `references/docket-template.html` — the ballot page template (option cards, sub-question chips, pinned must-answer rail,
  answer block, page-store persistence with device fallback); replace the data blocks and the masthead text

## License

Copyright 2026 Seevali Rathnayake. Licensed under the Apache License, Version 2.0 — see the repository's
[LICENSE](../LICENSE).
