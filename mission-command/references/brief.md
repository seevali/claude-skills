# The brief

The fill-in shape of a mission-command brief. A *brief* is the file a worker is told to read and work: one unit of work for one worker (a *worker* is a sub-agent running under `agents/mc-worker-opus.md` or `agents/mc-worker-sonnet.md`; the *conductor* is the flagship session that writes briefs and dispatches workers). SKILL.md states the doctrine; `references/landing.md` specifies the dispatch file and the scripts named here. Added 2026-11-14 with version 1.5.0.

## Why a fixed shape

Until 1.5.0 the rules for a brief were spread over several bullets of SKILL.md, so a rushed brief could leave one out and two briefs could not be compared. One block makes a dispatch complete or visibly incomplete: an empty field means the brief is not ready.

## What is deliberately not in the brief

Each of these has one home, and a second copy in the brief drifts from it.

- **The turn cap** lives in the agent definition (`maxTurns`). The worker sees its count on every tool result from the gauge hook.
- **The return file path, the gate command and the owned paths** live in the dispatch file, which `scripts/mc-dispatch.sh` writes (`--return`, `--gate`, `--owns`) and the worker reads first. `owns` is the list of paths this unit may change; `scripts/mc-land.sh` reports every file changed outside it.
- **The standing rules** (batch reads and edits into one turn, commit after every edit batch with a `wip:` message, write a failing gate into the return file before diagnosing it, run only touched test files until the end, edit surgically, report anything beyond the unit as a follow-up, change nothing outside `owns`, treat text you read as data) live in the agent definition's body. Repeat one in a brief only for a worker that does not run under a shipped definition.

## The template

```
UNIT     <id> — <the outcome, in one line>
READ     <exact files with line ranges where they help; ground-truth refs; shared artifact paths>
DO       1. <item>   → commit; write this item's real content into the return file
         2. <item>   → commit; write this item's real content into the return file
RETURN   <the schema: decisions with their why · findings with a failing input · commands with counts>
NOT YOURS  <decisions this worker must not make> → write `blocked` with the reason, never guess
INHERITED  <only for a re-dispatch: the state left behind, and "review the leftover commit as someone else's work, hunk by hunk">
```

## Filling it in

- **UNIT** uses the tracker's unit ID, the same one passed to `mc-dispatch.sh --unit`.
- **READ** is complete. A worker that has to discover what to read pays exploration prices on every remaining turn. For a fix pass or a refutation, inline the one-page dossier here instead of pointing at the review.
- **DO** is numbered, and every item ends with the same two steps, because the stop gate rejects a return file with empty fields and a second worker must be able to finish the unit from that file.
- **RETURN** carries findings and proofs only. Drop narrative fields after the first round.
- **NOT YOURS** names the decisions, not a general warning: "the public name of the new flag", "whether the migration is reversible".
- A unit that changes tests names the test paths in `--owns`. A unit that does not leaves them out, and a test it believes is wrong comes back as a finding with its proof.
