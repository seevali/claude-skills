# The landing contract

How a mission-command worker lands before its turn cap instead of crashing into it. This file is the specification that `scripts/`, `agents/` and `tests/` implement; SKILL.md states the doctrine, this file states the mechanics. Written 2026-09-27 against Claude Code 2.1.283.

## Why a contract

A worker is a Claude Code sub-agent with `maxTurns` set. The harness stops it at the cap with **no final message**: the parent gets `error_max_turns` (headless) or a result marked *partial* (in-session), and the worker's Stop hook does not fire. Nothing in the harness tells a running agent how many turns it has used. So the worker cannot land on its own; the hooks below give it a gauge, a reserve in which only landing actions are allowed, and a gate that refuses a stop with work still on disk.

## Facts the contract rests on (observed 2026-09-27)

- **A turn is one model call.** One assistant message that issues three parallel tool calls is one turn. `--max-turns 3` ran exactly three assistant messages, then cut. Parallel tool calls are therefore the cheapest way to do more per turn.
- The harness's reported `num_turns` counts user-side messages (prompt plus tool results) and is not the number to gauge against; the model-call count is the count of **distinct `message.id` values on `type: "assistant"` lines** of the transcript.
- Frontmatter `hooks:` in an agent definition fire for that agent both in-session (Agent tool) and headless (`claude -p --agent`). `PostToolUse` `additionalContext` is visible to the model. A frontmatter `Stop` hook fires as `Stop` headless and as `SubagentStop` in-session.
- Hook input carries `session_id`, `transcript_path`, `cwd`, `agent_type`, `hook_event_name`, `tool_name`, `tool_input` and, only in-session, `agent_id`. No turn count, no token count.
- Transcript location. Headless: `transcript_path` is the worker's own transcript. In-session: the worker's transcript is `${transcript_path%.jsonl}/subagents/agent-${agent_id}.jsonl`.
- **The transcript lags the current turn by one message.** When PreToolUse, PostToolUse or Stop fires during turn N, the transcript holds the assistant lines of turns 1..N−1 only; the current turn's line is written after its tools finish. So the turn the model is in is `distinct assistant ids + 1`, in every hook. (Live probe 2026-09-27: the first tool result read "turn 0 of 10", and a nine-turn worker's last gauge reading was 7.) A turn with no tool call (text only) produces no gauge line, so consecutive gauge readings may skip a number.
- Headless `--max-turns` overrides the definition's `maxTurns`; headless does not honor the definition's `effort` (a definition saying `low` ran at `high`), so the launcher passes `--effort`. Headless does honor the definition's `model`.
- A headless run starts in the worktree, so it finds only **global** agent definitions (`~/.claude/agents/<name>.md`) and plugin-scoped ones; a definition in a project's `.claude/agents/` is invisible to it. Worker definitions used headless live in `~/.claude/agents/`.
- In-session, a worker's `cwd` is the conductor's cwd, not its worktree. The dispatch file therefore names the worktree explicitly, and the hooks find the dispatch file through the prompt, not through `cwd`.

## Files

### The dispatch file

Written by the conductor before launch, one per worker, anywhere on disk (by convention in the operation's `returns/` folder as `<unit>.dispatch.json`). The hooks read it on every call, so it stays small.

```json
{
  "unit": "W-12",
  "worktree": "/abs/path/to/worktree",
  "return_file": "/abs/path/to/returns/W-12.md",
  "tracker": "/abs/path/to/TRACKER.md",
  "cap": 40,
  "reserve": 6,
  "gate": "pnpm --dir /abs/path/to/worktree typecheck && pnpm --dir /abs/path/to/worktree test",
  "permission_mode": "bypassPermissions"
}
```

- `cap` is copied from the agent definition's `maxTurns` by `mc-dispatch.sh`; the definition is the number's only home. A headless launch passes the same number as `--max-turns`.
- `reserve` is the number of turns at the end in which only landing actions are allowed. Default 6.
- `gate` is the deterministic gate `mc-land.sh` runs; empty string means none.
- `tracker` is optional; when present it is a second file the worker may write in the reserve.
- `landing` is `"commit"` (default) or `"return-only"`. A read-only unit (inventory, review, a dossier) lands with the return file alone: the reserve then allows only the return file and tracker, and the stop gate checks only the return file.
- `scope` is an optional array of paths, relative to `worktree`, that the stop gate's dirty check is limited to (`git status --porcelain -- <scope...>`). Default: the whole worktree. Use it when the worktree is a shared checkout with unrelated dirt.

### The prompt header

The first line of every worker's prompt is:

```
MC_DISPATCH=/abs/path/to/W-12.dispatch.json
```

The hooks discover the dispatch file by reading the first `user` line of the worker's transcript and extracting that token. A worker whose prompt has no `MC_DISPATCH=` line runs with the hooks inert (exit 0, no output); the definitions therefore stay usable for ad-hoc dispatches.

### The return file

The worker's report, at `return_file`. The worker creates it on its first turn and keeps it real as it goes. Required shape:

```
# Return: W-12

## Return
<decisions with their why, changes with their proof, commands and counts — real content>

## Landing
<appended by mc-land.sh only; absent when the worker landed itself>
```

The stop gate considers `## Return` filled when at least three non-blank lines follow the heading and none of them is a placeholder (`<...>`, `TBD`, `TODO`, `_fill_`).

### The gauge file

`<dispatch file>.gauge`, maintained by the gauge hook. Overwritten on every tool call with one line:

```
turns=17 cap=40 reserve_at=35 updated=2026-09-27T10:11:12Z
```

Only that first line is rewritten on each call. Any hook event worth recording (a stop-gate block, a release, an internal error) is appended below it, prefixed `event:`, and survives later rewrites. The conductor and `mc-land.sh` read this file for the true turn count; they never trust the worker's own report of it.

### Hook scratch

`${MC_HOOK_TMP:-/tmp/mc-hooks}/<key>.*` where `<key>` is `agent_id` when present else `session_id`. Used for the cached dispatch path and the stop-gate block counter. Safe to delete at any time.

## The hooks

All three are shell scripts under `scripts/`, read hook JSON on stdin, need only `bash`, `jq`, `git`, and must finish in well under 100 ms on an 800 KB transcript. On any internal error they exit 0 with no output and append `event: error <what>` to the gauge file if the dispatch is known; a hook must never fail a tool call by accident. `MC_HOOKS_OFF=1` in the environment makes all three inert.

Shared library `scripts/mc-hook-lib.sh` (sourced) provides: `mc_read_input` (stdin into `$MC_IN`), `mc_key`, `mc_transcript` (per the facts above), `mc_dispatch` (cached discovery), `mc_turns` (distinct assistant message ids in the transcript), `mc_field <name>` (dispatch field), `mc_gauge_write`, `mc_gauge_event`.

### 1. Gauge (`mc-gauge.sh`, PostToolUse, matcher `""`)

Let `T` = the turn the model is in (`distinct assistant ids in the transcript + 1`, per the lag fact above), `C` = cap, `R` = reserve, `S` = `C − R + 1` (first reserve turn). Writes the gauge file, then emits (for a `return-only` unit the same bands, with "commit what is on disk" and the git clause dropped, since no git is allowed):

- `T < S − 3`: `[mc] turn T of C. Reserve opens at turn S.`
- `S − 3 ≤ T < S`: `[mc] turn T of C. Reserve opens at turn S: land now — commit what is on disk, then fill '## Return' in <return_file>.`
- `T ≥ S`: `[mc] RESERVE: turn T of C. Only git add/commit/status/diff and the return file are allowed. Commit, fill '## Return', stop.`

as `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"..."}}`.

### 2. Reserve (`mc-reserve.sh`, PreToolUse, matcher `""`)

When `T ≥ S`, allow only the landing set and deny everything else:

- `Bash`: strip heredoc bodies, then split the command on `&&`, `||`, `;`, `|` and newlines outside quotes; every segment must match `^\s*git(\s+-C\s+\S+)?\s+(add|commit|status|diff|log|rev-parse|show)\b`, and a `-C <dir>` must resolve to `worktree` (any other directory is denied). Command substitution (`$(...)`, backticks) inside a segment is denied, with one exception: `$(cat <<'EOF' … EOF)` (any quoted or unquoted heredoc tag, `cat` only) as a `git commit` message, which is the standard commit idiom and must pass. For a `return-only` unit every `Bash` call is denied. The denial reason names the allowed forms so a worker does not spend reserve turns guessing: `git add …`, `git commit -m "…"`, `git commit -F - <<'EOF'`, `git commit -m "$(cat <<'EOF' … EOF)"`.
- `Read`, `Write`, `Edit`: `tool_input.file_path` resolves (realpath, or plain string compare when the file does not exist yet) to `return_file` or `tracker`.

Denial output: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"[mc] Reserve: turn T of C. Only landing actions are allowed: git add/commit/status/diff, and Read/Write/Edit of <return_file>. Commit what is on disk, fill '## Return', then stop."}}` (return-only: without the git clauses). Before `S`, or with no dispatch, the hook exits 0 silently.

`T` here is the same `distinct assistant ids + 1` as in the gauge; the live probe of 2026-09-27 showed the lag applies to PreToolUse as well.

### 3. Stop gate (`mc-stop-gate.sh`, Stop, matcher none)

With a dispatch known, check two things: `git -C <worktree> status --porcelain` is empty (untracked files count as dirty), and `## Return` is filled per the return-file rule. If either fails, output `{"decision":"block","reason":"[mc] Not landed: <dirty worktree: N paths | '## Return' is empty or placeholder>. Commit everything on disk and fill '## Return' in <return_file>, then stop."}`. Blocks are counted per key; after two blocks the gate releases (exit 0) and appends `event: stop-gate released after 2 blocks` to the gauge file so the conductor sees it. The gate never blocks when `stop_hook_active` is true.

## Conductor scripts

### `mc-dispatch.sh`

```
mc-dispatch.sh --unit W-12 --agent mc-worker-opus --worktree DIR --return FILE [--tracker FILE] [--gate "CMD"] [--reserve 6] [--cap N] [--landing commit|return-only] [--scope PATH ...] [--permission-mode MODE] --out FILE
```

Reads `maxTurns:` from `<cwd>/.claude/agents/<agent>.md`, else `~/.claude/agents/<agent>.md`; `--cap` overrides; exits 2 when no cap can be found. Writes the dispatch JSON to `--out`, creates the return file with the required skeleton if absent, and prints the prompt header line `MC_DISPATCH=<out>` so the conductor pastes it.

### `mc-land.sh <dispatch.json>`

The conductor's one-command recovery when a worker capped anyway. In the worktree: if dirty, `git add -A && git commit -q -m "wip(<unit>): capped worker's leftovers, unreviewed"`; read `turns` from the gauge file; if `gate` is non-empty, run it in the worktree with output to `<dispatch dir>/<unit>.gate.log`; append a `## Landing` section to the return file (date, turns, leftover commit hash or `clean`, gate exit code and log path); print one summary line. Never pushes, never touches the tracker.

### `mc-run.sh <dispatch.json> <agent> <brief-file>`

Headless launcher for unattended fleets. Reads `cap` and `permission_mode` from the dispatch and `model`/`effort` from the agent definition, which must exist at `~/.claude/agents/<agent>.md` (a headless run starts in the worktree and cannot see a project's `.claude/agents/`; the script exits 2 with that message when the definition is only there). `--dry-run` prints the command instead of running it. It then runs from the worktree:

```
claude -p "MC_DISPATCH=<dispatch>
Read the brief at <brief-file> and work it." \
  --agent <agent> --max-turns <cap> --effort <effort> \
  --output-format json --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
  --disable-slash-commands --permission-mode <mode> < /dev/null
```

Output JSON goes to `<dispatch dir>/<unit>.run.json`; the script prints `subtype`, `num_turns` and the gauge line, and exits non-zero on `error_max_turns` so a loop can call `mc-land.sh`.

## Agent definitions

`agents/mc-worker-opus.md` and `agents/mc-worker-sonnet.md` carry the three hooks. Hook commands are absolute paths under `$HOME/.claude/skills/mission-command/scripts/`; a per-project install edits the path. Project-level frontmatter hooks run only after the workspace trust dialog is accepted once for that folder.

## Tests

`tests/run.sh` builds a temporary git repository as the worktree, a synthetic transcript with a chosen number of distinct assistant message ids, and a dispatch file, then feeds hook JSON on stdin and asserts on stdout, the gauge file and exit codes. It must cover: gauge text at each of the three bands; reserve allow/deny for each landing action and for a compound `git add -A && git commit`, a denied `pnpm test`, a denied `Edit` of a source file, an allowed `Write` of the return file; stop gate blocking on dirty, blocking on placeholder return, passing when clean and filled, releasing after two blocks; hooks inert without `MC_DISPATCH`; `mc-land.sh` committing leftovers and appending `## Landing`; `mc-dispatch.sh` reading `maxTurns` from a definition. It runs with `bash tests/run.sh` and prints one line per case and a final count.
