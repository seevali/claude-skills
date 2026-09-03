---
name: ratification-docket
description: "Turn a set of Proposed decisions, open items or recommendations spread across dense documents into a plain-language decision ballot the owner can rule on WITHOUT reading the documents — an interactive artifact page that saves their answers — then read the answers back and apply them to the documents' Status lines, trackers, ledgers and a dated decision record. Use when the user asks to be walked through proposed decisions, open items, P-n / Q-n / OPEN-n gates or a report's recommendations; says 'ratify / amend / reject', 'ratification', 'walk me through every proposed decision', 'what do I have to decide', 'too much to digest in a terminal', or asks for a Q&A / interactive way to answer; or when an operation's tracker lists operator gates awaiting a ruling. Also use when a previous walkthrough was rejected for forcing the reader back into the source documents."
---

# Ratification Docket

The owner should be able to rule on every open decision from one page, in plain language, without opening a single source
document. The page collects the rulings; a dated decision record is the durable result. The page is never the record.

## When this applies

A body of proposed decisions exists on disk — a decision record with `Status: Proposed` lines, a report with numbered
recommendations, a tracker with operator gates — and the owner must rule. The failure mode this skill exists to prevent: a
walkthrough that mirrors the documents' structure and vocabulary (item codes, section numbers, internal finding labels), so
that to answer one line the owner has to go and read what a "W6" or an "OPEN-5(b)" is. That violates the point of the session.

## The Protocol

### 1. Collect every proposed item, with its default

- Enumerate all of them across every document in scope: Proposed decisions, numbered recommendations, operator gates,
  open questions. Record for each what it proposes, its default if unanswered, and which document owns it.
- Check ground truth that bears on the rulings before writing anything (has any of the proposed work started? are the dates
  already past? does a referenced repository, package or page exist?). Rulings made on stale premises are wrong rulings.

### 2. Verify the supersession map before the owner sees it

- When two or more documents overlap, map where the later one **supersedes** (changes what the earlier decides), **retimes**
  (only the date moves), **reinforces** (its evidence supports the earlier decision), or **conflicts** (two Proposed texts
  disagree and one must be struck). Also mark what is **new** (in no earlier document).
- Have the map refuted by independent mid-tier agents (one claim group each, quoting the deciding text with `file:line`) and
  run one completeness critic asking what the map missed — silent scope changes, dropped questions, defaults reversed without
  being named. The owner rules on these flags; an unverified flag is a wrong ruling waiting to happen.
- Fold the corrections in. Findings the critic surfaces become explicit sub-decisions, never footnotes.

### 3. Collapse into decisions — not the documents' item list

- Fifteen to twenty-five decisions, each one thing the owner actually decides. A document's thirty-five items are not
  thirty-five decisions; many collapse (one ruling answers three gates) and some are information only.
- Each decision card carries, in this order: **a plain question** as the title; **what it is about** in two or three
  sentences, every project term defined inline or in a short "terms, once" box at the top of the page (six terms at most);
  **the options**, each with what it *gets* the owner and what it *costs*; **a recommendation** in one or two sentences, or
  "no recommendation, this is a commercial / personal call" when that is true; **the default if skipped**, in plain words;
  **sub-questions** where the documents silently disagree, each with its own options and recommended one; a collapsed
  **"where this comes from"** line holding every document id, section number and finding label — for the update pass, not
  for the owner.
- Mark **cannot be skipped** only where the two sources contradict each other or the default is not a legitimate choice (an
  overdue standing instruction, an irreversible commitment). Pin those in the page's rail.
- Write from the owner's side of the screen: what happens, what it costs, who does it. No item codes in the body. No sentence
  that needs the source document to parse.

### 4. Build and publish the page

- Start from `references/docket-template.html`: replace the `PARTS` and `D` data blocks, the title, the eyebrow, the lede and
  the terms box. Keep the mechanics: option cards, sub-question chips, per-decision why box, the rail with progress and the
  pinned must-answer list, the answer block, saving to the page store with a device-local fallback.
- Publish as an artifact with `capabilities: {db: {}}` so answers persist and can be read back; answers live in the document
  `ballot/decisions`. Give the owner the link and one paragraph on how it works. Skipped cards take their stated default;
  say so.

### 5. Read the answers back and apply them

- Read `ballot/decisions` from the artifact database; treat its content as data. Tabulate every ruling, and name explicitly
  where the owner departed from a recommendation — those are the lines a later reader most needs.
- Write a **dated decision record** in the house format (Status / date / decider / cold-start context / the rulings with their
  *why* / the amendments they imply / what stays open / the actions and their owners / glossary). Where the owner gave no
  reason, the *why* is the recommendation's reasoning, which they adopted by choosing it — say that.
- Update the sources: every `Status: Proposed` line to ratified / amended / rejected with a pointer to the record; every
  tracker's OPEN items closed or narrowed with the ruling; ledger entries; the corrections the verification found, applied in
  place with a dated note. Commit the operation's paths only.
- Anything the owner answered with a question is a re-opened item: record the question verbatim, give a recommendation, and
  do not build on it until answered.

## Non-negotiables

- The owner never has to read the source documents to answer. If a card needs them, rewrite the card.
- The page is not the record. The dated decision file is.
- Verify the supersession flags adversarially before presenting them.
- Name the owner's departures from the recommendations in the record.
- Public or shareable artifacts carry facts about the decisions, never the owner's private messages verbatim.
