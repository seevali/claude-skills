# Design Council

A Claude Skill that channels the design philosophies of five master designers as a consultative panel for any design work.

**Five minds. Five lenses. One design decision.**

## The Five Lenses

| Lens | Designer | Core Question |
|------|----------|---------------|
| **Material Truth** | Jony Ive | What is this thing made of, and does the design honor that material? |
| **Honest Restraint** | Dieter Rams | Is every element here earning its place, or am I decorating? |
| **Movement Through Space** | Zaha Hadid | How does someone move through this, and what do they feel at each threshold? |
| **Playful Function** | Bjarke Ingels | Where's the delight? What's the ski slope on the power plant? |
| **Human-Centered Affordance** | Don Norman | Does this design teach someone how to use it without being told? |

## What It Does

When you're making any design decision — UI, brand, presentations, documents, architecture — this skill gives Claude a structured framework to evaluate your work through five distinct axes of quality. Each designer surfaces a different dimension that the others might miss.

The skill works for:
- Web and app interfaces
- Typography and color palette choices
- Slide decks and presentations
- Brand identity systems
- Print and poster design
- Physical spaces and products
- Even code architecture (APIs, developer experience)

## Installation

### Claude Code (terminal)

**Global** — available in every project:

```bash
mkdir -p ~/.claude/skills/
cp -r design-council ~/.claude/skills/design-council
```

**Project-level** — available only in a specific repo:

```bash
mkdir -p .claude/skills/
cp -r design-council .claude/skills/design-council
```

### Claude.ai (web/desktop)

1. Download or clone this repo
2. ZIP the `design-council/` folder (the folder must be the root of the ZIP)
3. Go to **Settings → Customize → Skills**
4. Upload the ZIP

### Claude Code Plugin

```
/plugin add /path/to/design-council
```

## Usage

The skill auto-triggers when Claude detects design-related work. You can also invoke it explicitly:

```
/design-council
```

**Examples of prompts that trigger it:**

- "Review this homepage layout"
- "Help me choose a color palette for a dashboard"
- "What typography should I use for a personal blog?"
- "Critique this card component design"
- "I'm designing a presentation — what should I consider?"
- "Apply the Dieter Rams lens to this UI"

## How the Council Works

### For Design Decisions

Run the choice through all five lenses in sequence:

1. **Ive:** What material is this? Does the design honor it?
2. **Rams:** Is every element earning its place?
3. **Hadid:** How does someone move through this space?
4. **Ingels:** Where's the delight? What dual purpose can this serve?
5. **Norman:** Does this teach itself? What happens when someone gets confused?

### For Design Critique

Score each lens independently (1–5):

- **Ive:** Material authenticity
- **Rams:** Economy
- **Hadid:** Flow
- **Ingels:** Delight
- **Norman:** Clarity

### Tension Is the Feature

The designers disagree — that's the point:

- **Rams vs Ingels:** Remove vs add delight → Resolution: delight that's *also* functional
- **Ive vs Norman:** Beauty vs usability → Resolution: beauty *through* usability
- **Hadid vs Rams:** Drama vs quiet → Resolution: dramatic structure, quiet surface

## File Structure

```
design-council/
├── SKILL.md                          # Core skill — five lenses, patterns, usage guide
├── references/
│   └── applied-examples.md           # Nine worked examples from real projects
├── LICENSE                           # Apache 2.0
└── README.md                         # This file
```

## Signature Patterns

Quick reference for patterns the council produces:

| Pattern | Origin | When to Use |
|---------|--------|-------------|
| Three-step typography | Ive + Rams | Always — kill intermediate font sizes |
| Cathedral entrance | Hadid | Full-viewport opening sections |
| Lighthouse effect | Ive | Dim by default, bright on focus |
| Dual-purpose element | Ingels | Functional elements that also carry personality |
| Discovered interaction | Norman | Hover reveals, progressive disclosure |
| Whitespace differential | Rams | Spacious between sections, dense within |
| Breaking the grid | Hadid | One element per layout that violates the pattern |
| Material palette | Ive | Color = material (void, paper, canvas, terminal) |
| Constraint as creativity | Ingels | Turn limitations into design features |
| Affordance mapping | Norman | Every visual cue maps to a real behavior |

## Background

This skill was developed for [seevali.dev](https://seevali.dev) and seevali.me — two sites for the same person with deliberately opposite design languages (dark cathedral vs warm garden path). The five-lens framework shaped every decision across both projects, from hover state direction (lift vs press) to closing statement tone (declaration vs shrug).

The `references/applied-examples.md` file contains nine worked examples showing how the council produced real design outcomes.

## License

Copyright 2026 Seevali Rathnayake

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
