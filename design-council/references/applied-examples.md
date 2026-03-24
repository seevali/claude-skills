# Applied Examples — The Design Council in Practice

Real decisions from seevali.dev and seevali.me showing how the five lenses shaped actual design outcomes.

---

## Example 1: Two Sites, One Person

**The decision:** How do you design two websites for the same person that feel distinct but connected?

| Lens | seevali.dev (professional) | seevali.me (personal) |
|------|---------------------------|----------------------|
| **Ive (Material)** | Material = code. Dark terminal void (#0f0f23). JetBrains Mono as identity font. The site is *made of* the same stuff the work is made of. | Material = light. Warm canvas (#FAF8F5). Newsreader serif as voice. The site is *made of* paper, photographs, natural texture. |
| **Rams (Economy)** | Rich system (5 signal types, lenses, ambient line) but each element functional. | Even less design. No pills, no signal types, no lenses. Restraint *is* the personality. |
| **Hadid (Space)** | Cathedral → stream. Dramatic entrance, then vertical flow with choreographed reveals. | Garden path. Gentle opening, rooms you enter (not zones you scroll through). |
| **Ingels (Delight)** | Feed count on hover. Ambient line that shifts color. "Last signal: 2 days ago" at 0.4 opacity. | Photo captions like Polaroid backs. "This isn't that site." The closing as a shrug. |
| **Norman (Affordance)** | Signal pills teach the type system. Lighthouse effect concentrates attention. Cards lift = clickable. | "Read →" appears only on hover. Lightbox opens on photo click without instruction. Discovered, not declared. |

**The tension resolved:** Rams says seevali.me should have *even less* than seevali.dev. Ingels says it needs personality. Resolution: the absence of system *is* the personality. No categories = deliberate. Updated slowly = on purpose.

---

## Example 2: The Cathedral Entrance (seevali.dev)

**The decision:** How should the homepage open?

- **Hadid:** Full viewport. 100vh. You don't scroll into the site — you *enter* it. The background text "SOFTWARE ARCHITECT" at 0.025 opacity creates spatial depth without competing with content.
- **Ive:** The pinned signal card is centered, max-width 640px. Generous negative space around it. The card's border is transparent by default — it only appears on hover, as if the card is *emerging* from the void.
- **Rams:** Three elements only: label ("— pinned —"), signal pill, title + excerpt. No bio, no photo, no tagline. The content *is* the introduction.
- **Ingels:** The scroll hint ("scroll" + chevron) uses a breathe animation at 0.2-0.5 opacity and fades after 80px scroll. It's functional (tells you to scroll) AND atmospheric (breathing suggests life).
- **Norman:** The pinned card is an `<a>` link. On hover: 4px lift, border appears, title shifts to accent blue, "Read this post →" fades in. Every visual cue maps to the same message: *this is clickable, click it.*

---

## Example 3: The Garden Opening (seevali.me)

**The counterpoint decision:** How should a *personal* site open?

- **Hadid:** Still full viewport. Still a threshold. But the atmosphere is completely different — no parallax, no background text. The opening is *still*, not kinetic. You're entering a room, not a cathedral.
- **Ive:** Profile photo at 88px with `grayscale(0.15)` default → full color on hover. The subtle desaturation creates a film-print quality. The material is *photographic*, not digital.
- **Rams:** Name, place, one line. That's it. No social links in the opening. No call to action. The breathing room communicates patience.
- **Ingels:** The tagline: "Software architect by trade. Observer of small things by habit." — the second line is the delight. It reframes the whole site.
- **Norman:** The scroll hint says "explore" (not "scroll") with a vertical line (not a chevron). Language and form both signal: this isn't urgent. Wander.

---

## Example 4: The Lighthouse Effect

**The decision:** How should signal type colors work in the stream?

- **Ive:** Every signal pill renders at 0.5 opacity by default. On card hover, the pill goes to 1.0. One bright point at a time — concentrated color, not evenly distributed. This is how light works in physical space: you notice what's illuminated.
- **Rams:** The dimmed state means color isn't shouting for attention when you're not focused on it. The system is quiet until you ask it to speak.
- **Norman:** The brightness change on hover reinforces "you are here" — it's a wayfinding cue, not just decoration.
- **Resolution of Ive vs Rams:** Ive wants the colors to be beautiful. Rams wants them to be quiet. The lighthouse effect achieves both — beautiful when active, quiet when not.

---

## Example 5: Lenses vs Categories

**The decision:** How should content filtering work on seevali.dev?

- **Ingels:** "Lenses" not "categories." A lens is a perspective you choose to look through — it doesn't define the content, it reveals a facet. A signal can belong to multiple lenses. This is a playful reframing of a standard filter UI.
- **Norman:** Clicking a lens collapses non-matching cards (max-height: 0, opacity: 0). The URL updates to `#lens=name` (shareable). Clear button appears when active. Status text: "Showing X of Y signals." Every state is communicated.
- **Hadid:** When a lens activates, the page scrolls to `#lensStatus` and the sidebar locks visible for 1200ms — the space reorganizes around your choice, like walls moving in response to your presence.
- **Rams:** Only three lenses. Not five, not seven. Three perspectives is enough to be useful without being overwhelming.

---

## Example 6: Film Grain vs Ambient Line

**The decision:** What's the texture layer for each site?

- **seevali.dev — Ambient line:** A 2px fixed bar at page top that changes color based on which signal type is in view. This is Ingels (dual-purpose: decorative + wayfinding) and Norman (maps color to content type, teachable).
- **seevali.me — Film grain:** A CSS-only SVG noise filter at 0.025 opacity, fixed position, pointer-events none. This is Ive (material = analog photograph) and Rams (so subtle most people won't consciously notice it — but they'll *feel* it).
- **The contrast:** Digital artifact (shifting colors, responding to scroll position) vs analog artifact (static noise, unchanging). The texture layer tells you which world you're in before you read a word.

---

## Example 7: Typography as Identity

**The decision:** Font choices across both sites.

| Role | seevali.dev | seevali.me | Why (Council reasoning) |
|------|------------|------------|------------------------|
| Display | Inter 600 | Newsreader 400 | **Ive:** Weight carries authority (.dev). Serif carries voice (.me). |
| Body | Inter 400 | DM Sans 400 | **Rams:** Inter is invisible (workhorse). DM Sans is slightly warmer (personality through subtlety). |
| Mono/Meta | JetBrains Mono | IBM Plex Mono | **Ingels:** JetBrains = developer identity (the tool itself). Plex = quieter, thinner, recedes into margins. |
| Rule | Three steps only | Three steps only | **Rams:** Headline, title, body. Nothing between. Intermediate sizes are indecision made visible. |

---

## Example 8: Hover States as Material Behavior

**The decision:** How should cards respond to hover?

| Card type | Hover behavior | Council reasoning |
|-----------|---------------|-------------------|
| WRITE card (seevali.dev) | Lift 2px + shadow | **Ive:** The card is a physical object that lifts off the surface. Material = rigid, elevated. |
| Photo cell (seevali.me) | Scale 0.985 (inward press) | **Ive:** The photo is being pressed like a physical print. Material = film, paper. Opposite direction from .dev — intentional. |
| Standalone thought | Pill brightens only | **Norman:** Not clickable → no lift, no border change. The *absence* of affordance communicates "this is content, not a link." |
| Expandable thought | Border shifts to accent blue + bg wash | **Norman:** Clickable → visual change signals interactivity. But gentler than a card lift — it's a thought, not a destination. |

---

## Example 9: Closing Statements

Two endings, two emotional registers:

- **seevali.dev:** "Software Architect. The work speaks." — opacity 0 → 0.5, 60vh height. **Hadid** (arrival at a destination). **Ingels** (the declaration as personality). **Ive** (0.5 opacity, not 1.0 — confidence doesn't need to shout).
- **seevali.me:** "Mostly I just notice things. Sometimes I write them down." — opacity 0 → 0.4, 40vh height. **Hadid** (exhale, not arrival). **Ingels** (the shrug as personality). **Rams** (even lower contrast than .dev — the site ends by nearly disappearing).

---

## Using These Examples

When applying the Design Council to new work, use these examples as calibration:

1. **Identify the material first** (Ive) — what is this thing *made of*?
2. **Establish the spatial flow** (Hadid) — how does someone move through it?
3. **Subtract** (Rams) — what can you remove?
4. **Add one moment of delight** (Ingels) — where's the discovery?
5. **Verify affordance** (Norman) — does every element teach its function?

The order matters. Structure before surface. Surface before personality. Personality before polish.
