---
name: design-council
description: "Channel the design philosophies of five master designers — Jony Ive, Dieter Rams, Zaha Hadid, Bjarke Ingels, and Don Norman — as a consultative panel for any design work. Use this skill whenever the user is making design decisions, evaluating aesthetics, designing interfaces, planning spatial layouts, creating visual systems, building websites, choosing typography or color palettes, designing presentations, crafting brand identity, or doing any creative work where design quality matters. Also trigger when the user mentions any of the five designers by name, references 'design council', 'design panel', 'design review', or asks for design critique, feedback, or philosophy. This skill applies to digital UI, physical products, architectural spaces, print design, slide decks, posters, and any artifact where form and function intersect."
---

# The Design Council

Five minds. Five lenses. One design decision.

This skill provides a consultative design framework drawn from the philosophies of five of the most influential designers across product, architecture, and human experience. Use them not as personas to roleplay, but as **thinking tools** — each one surfaces a different dimension of quality that the others might miss.

## The Five Lenses

Each designer represents a distinct axis of design evaluation. When approaching any design task, consider the work through each lens in sequence.

### 1. Jony Ive — Material Truth

**Core question:** *"What is this thing actually made of, and does the design honor that material?"*

**Philosophy:** Every medium has an essence. A digital interface is made of light and pixels — not paper, not plastic. A presentation is made of projected space and time. Design should reveal the nature of its material, not disguise it.

**Design moves:**
- **Reduction to essence.** Remove everything that doesn't serve the object's purpose. Not minimalism as aesthetic — minimalism as honesty. If a button doesn't need a border, the border is a lie.
- **Tactile quality in the intangible.** Even flat UI has texture. A hover state that feels like pressing into a surface (scale 0.985) vs lifting off it (translateY -4px) creates fundamentally different emotional responses.
- **Radius as personality.** Sharp corners = precision, authority. Generous radius = approachability, softness. 2px radius = film print, physical artifact. The radius *is* the tone.
- **Material palette.** Choose colors the way you'd choose materials for a building. --bg-primary isn't just "dark blue" — it's void, terminal, the inside of a machine. --bg-canvas isn't just "off-white" — it's paper, warmth, something you'd hold.
- **Finish.** The difference between good and extraordinary is in the finish — the anti-aliasing, the letter-spacing, the 0.3s vs 0.4s transition. Ive spent months on the radius of the original iPhone's corners.

**When to invoke:** Typography choices, color palette decisions, hover/interaction states, component border-radius, spacing rhythm, material metaphors (dark mode = void vs dark mode = night).

---

### 2. Dieter Rams — Honest Restraint

**Core question:** *"Is every element here earning its place, or am I decorating?"*

**Philosophy:** Good design is as little design as possible. But this is not laziness — it's discipline. Every element present must be functional, honest, and long-lasting. Decoration that serves no function is noise.

**Ten Principles (applied to digital/visual design):**

| Principle | Digital Translation |
|-----------|-------------------|
| Innovative | Does this approach solve the problem in a way that wasn't possible before? |
| Useful | Does every element serve the user's task? |
| Aesthetic | Is it beautiful *because* it's well-made, not despite it? |
| Understandable | Can a first-time visitor orient themselves in 3 seconds? |
| Unobtrusive | Does the design stay out of the content's way? |
| Honest | No fake shadows, no skeuomorphic lies, no pretending to be what you're not. |
| Long-lasting | Will this look dated in 6 months? (If trend-driven, it will.) |
| Thorough | Is every state designed? Loading, empty, error, overflow, edge case? |
| Environmentally friendly | Performance-conscious. No 4MB hero images. No layout shift. |
| As little design as possible | **Back to purity.** Can you remove one more thing? |

**Design moves:**
- **The subtraction test.** For every element, ask: what breaks if I remove this? If nothing breaks — remove it.
- **Three-step typography.** Headline, title, body. Nothing between. Intermediate sizes are indecision made visible.
- **Systematic color.** Don't pick colors — build a system. Foreground/background/accent/muted. Signal colors only where they carry meaning.
- **Whitespace as content.** 120px between sections isn't empty — it's a breath. Dense within, spacious between. The rhythm itself communicates hierarchy.

**When to invoke:** Evaluating whether a design has too many elements, auditing typography scales, questioning whether animations serve function or vanity, removing decorative elements, simplifying navigation.

---

### 3. Zaha Hadid — Movement Through Space

**Core question:** *"How does someone move through this, and what do they feel at each threshold?"*

**Philosophy:** Architecture isn't about objects — it's about the experience of moving through space. A building's quality is in its transitions: the compression before a grand reveal, the curve that draws your eye forward, the moment you cross from one material world into another.

**Design moves:**
- **The cathedral entrance.** The first viewport is a threshold, not a billboard. Full-height openings create a moment of arrival. The user isn't scrolling — they're *entering*.
- **Scroll choreography.** Staggered reveals (70-90ms delay per element), parallax at fractional speeds (0.3x), count-up animations on scroll-into-view — these create the feeling of *movement through space*, not *reading a page*.
- **Zones as rooms.** Each section has its own light, its own material, its own atmosphere. A dark terminal room (seevali.dev) vs a warm paper room (seevali.me). The transition between rooms is as important as the rooms themselves.
- **Breaking the grid.** A panoramic photo that spans full width. A tall cell that breaks the square pattern. An element that bleeds past its container. Controlled pattern-breaking creates visual drama.
- **The curve.** Not every surface needs to be rectangular. border-radius, clip-path, SVG shapes — used sparingly, curves draw the eye and create flow where rigid grids create stops.

**When to invoke:** Page-level layout and flow, section transitions, scroll behavior design, responsive breakpoints (how the space reshapes), hero sections, full-bleed elements, navigation that guides movement.

---

### 4. Bjarke Ingels — Playful Function

**Core question:** *"Where's the delight? What's the ski slope on the power plant?"*

**Philosophy:** The best architecture serves two purposes at once. A waste-to-energy plant AND a ski slope. A residential building AND a figure-eight you can bike up. Function doesn't exclude play — the constraint *creates* the play. Every limitation is a design opportunity in disguise.

**Design moves:**
- **Dual-purpose elements.** A feed count that only appears on hover — it's ambient information AND a discovery moment. An "about" section that's a personal note, not a bio — it's content AND personality. A signal type pill that dims to 0.5 opacity and brightens on hover — it's categorization AND the "lighthouse effect."
- **Constraint as creativity.** "Only three font sizes" isn't a limitation — it's a design decision that creates discipline. "No categories on seevali.me" isn't missing features — it's the personality.
- **The easter egg.** Small discoveries that reward attention. A caption that appears like writing on the back of a photo. A "last signal: 2 days ago" timestamp at 0.4 opacity that most visitors will never notice — but those who do will feel closer to the author.
- **Playful naming.** "Cathedral" not "hero section." "Rooms" not "sections." "Lenses" not "categories." The language shapes the experience before a single pixel is rendered.
- **The closing as destination.** Don't end with a whimper (generic footer) or a shout (newsletter popup). End with *arrival*. "Software Architect. The work speaks." is a destination. "Mostly I just notice things." is an exhale. Both are designed endings.

**When to invoke:** Adding personality to functional elements, naming sections/features, designing empty states, crafting microcopy, finding opportunities for delight within constraints, making utilitarian interfaces feel human.

---

### 5. Don Norman — Human-Centered Affordance

**Core question:** *"Does this design teach someone how to use it without being told?"*

**Philosophy:** Good design is invisible in use. The door handle that tells you to push or pull. The button that looks pressable. The link that looks clickable. Every interface element should communicate its function through its form — not through labels, tooltips, or instructions.

**Design moves:**
- **Visible affordance.** A card with a border and hover lift *looks* clickable without a "Click here" label. A left border on a thought card *looks* like a pull-quote without explanation. A gradient fade at the bottom of a text card *signals* "there's more" without saying it.
- **Discovered interaction.** The "Read →" hint that only appears on hover — you don't announce it, you reward curiosity. The lightbox that opens on photo click — no icon needed if the cursor changes. Interactions should feel *discovered*, not *declared*.
- **Consistent mapping.** If blue means "accent" everywhere, don't use it for "danger" anywhere. If hover-lift means "clickable," every lifted element must be clickable. Consistency is the foundation of learnability.
- **Error prevention over error handling.** In design terms: don't create confusing choices. If a thought isn't expandable, don't give it a hover state that suggests it is. If a number card isn't linked, don't make it lift on hover.
- **Emotional design.** Beyond usability: how does using this *feel*? The film grain on seevali.me isn't functional — it's emotional. The parallax on seevali.dev doesn't convey information — it creates atmosphere. These aren't decoration (Rams would object) — they're emotional affordances.

**When to invoke:** Hover state design, click target clarity, navigation patterns, form design, error states, onboarding flows, any moment where a user might be confused about what to do next, accessibility decisions.

---

## How to Use the Council

### For Design Decisions

When facing a design choice, run it through the five lenses in sequence:

```
1. IVE:    What material is this? Does the design honor it?
2. RAMS:   Is every element earning its place?
3. HADID:  How does someone move through this space?
4. INGELS: Where's the delight? What dual purpose can this serve?
5. NORMAN: Does this teach itself? What happens when someone gets confused?
```

Not every lens will have something to say about every decision. That's fine — the value is in the ones that surface something you'd otherwise miss.

### For Design Critique

When reviewing existing work, score each lens independently:

- **Ive:** Material authenticity (1-5) — Does it feel like what it's made of?
- **Rams:** Economy (1-5) — Could anything be removed without loss?
- **Hadid:** Flow (1-5) — Does movement through it feel choreographed?
- **Ingels:** Delight (1-5) — Is there a moment that surprises or rewards?
- **Norman:** Clarity (1-5) — Could someone use this without instructions?

### For New Projects

Start with Hadid (spatial flow and zones), then Ive (material and palette), then Rams (subtraction), then Norman (affordance), then Ingels (delight). This order builds structure first, then refines, then adds personality.

### Tension Is Good

The designers *disagree* with each other — that's the point:
- **Rams vs Ingels:** Rams wants to remove; Ingels wants to add delight. The resolution: delight that's *also* functional.
- **Ive vs Norman:** Ive pursues beauty; Norman pursues usability. The resolution: beauty *through* usability.
- **Hadid vs Rams:** Hadid wants drama; Rams wants quiet. The resolution: dramatic structure, quiet surface.

When two lenses conflict, name the tension explicitly. The best designs live in the resolution.

---

## Quick Reference: Signature Patterns

| Pattern | Origin | When to Use |
|---------|--------|-------------|
| Three-step typography | Ive + Rams | Always. Kill intermediate font sizes. |
| Cathedral entrance | Hadid | Full-viewport opening sections |
| Lighthouse effect | Ive | Concentrated color (dim by default, bright on focus) |
| Dual-purpose element | Ingels | Any functional element that could also carry personality |
| Discovered interaction | Norman | Hover reveals, progressive disclosure |
| Whitespace differential | Rams | 120px between sections, dense within cards |
| Breaking the grid | Hadid | One element per layout that violates the pattern |
| Material palette | Ive | Color = material (void, paper, canvas, terminal) |
| Constraint as creativity | Ingels | Turn limitations into design features |
| Affordance mapping | Norman | Every visual cue must map to a real behavior |

---

## Applying Across Domains

This framework is not limited to web design. Apply it to:

- **Presentations:** Ive (material: projected light), Hadid (flow between slides), Rams (one idea per slide), Ingels (the memorable slide), Norman (can the audience follow without narration?)
- **Documents:** Rams (typography hierarchy), Ive (margin and spacing rhythm), Norman (scannable structure), Ingels (the pull-quote that earns a screenshot)
- **Brand identity:** Ive (what material is the brand made of?), Rams (logo subtraction test), Hadid (how does someone move through the brand touchpoints?), Ingels (the brand's sense of humor), Norman (instant recognition)
- **Physical spaces:** All five in their native element
- **Code architecture:** Rams (is this function earning its place?), Norman (does the API teach itself?), Ingels (is there elegance in the constraint?), Hadid (how does a developer navigate this codebase?)

---

## Reference

For deeper context on how these five lenses were applied to specific projects, read `references/applied-examples.md`. It contains worked examples from seevali.dev and seevali.me showing how the council shaped real design decisions.
