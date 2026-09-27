# mc-hook-lib.sh — shared functions for the mission-command landing hooks.
# Sourced, never executed. Contract: references/landing.md.
# Every function tolerates missing input/files and yields empty output instead
# of failing; callers treat empty as "unknown" and stay inert.

MC_IN="${MC_IN:-}"
MC_TMP="${MC_HOOK_TMP:-/tmp/mc-hooks}"
MC_DISPATCH_FILE="${MC_DISPATCH_FILE:-}"

# The one path normaliser: every path that is compared or joined goes through it.
# Git Bash (cygpath present): C:\x\y and C:/x/y become /c/x/y first; then
# realpath -m. Empty in, empty out; the input unchanged if realpath fails.
# cygpath is looked up only for a path in Windows form (drive letter or a
# backslash): a POSIX path needs no conversion, and a PATH scan that misses
# costs ~100 ms per call under WSL, whose PATH carries the /mnt/c directories.
mc_norm_path() {
  local p="${1:-}"
  [ -n "$p" ] || return 0
  case "$p" in [A-Za-z]:*|*\\*)
    if command -v cygpath >/dev/null 2>&1; then p="$(cygpath -u "$p" 2>/dev/null || printf '%s' "$p")"; fi ;;
  esac
  realpath -m -- "$p" 2>/dev/null || printf '%s' "$p"
}

# jq present, else one line to $MC_TMP/errors.log (no dispatch can be read
# without jq, so the gauge file is out of reach) and return 1: the hook goes inert.
mc_require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  { mkdir -p "$MC_TMP" && printf '%s %s: jq missing, hook inert\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${0##*/}" >> "$MC_TMP/errors.log"; } 2>/dev/null
  return 1
}

# The dispatch fields every guarding hook needs. Returns 1 and logs
# `event: error` when one is missing (an unreadable dispatch reads as empty),
# once per worker key: $MC_TMP/<key>.errlogged marks it logged.
mc_require_fields() {
  local f miss="" key m=""
  for f in worktree return_file; do [ -n "$(mc_field "$f")" ] || miss="$miss $f"; done
  [ -z "$miss" ] && return 0
  key="$(mc_key)"
  if [ -n "$key" ]; then m="$MC_TMP/$key.errlogged"; [ -e "$m" ] && return 1; fi
  mc_gauge_event "error $1: dispatch missing or unreadable:$miss"
  [ -n "$m" ] && { mkdir -p "$MC_TMP" && : > "$m"; } 2>/dev/null
  return 1
}

# stdin into $MC_IN, once.
mc_read_input() {
  if [ -z "${MC_IN_READ:-}" ]; then
    MC_IN="$(cat 2>/dev/null || true)"
    MC_IN_READ=1
  fi
}

# jq over the hook input; empty on any failure.
mc_in() {
  printf '%s' "$MC_IN" | jq -r "$1 // empty" 2>/dev/null || true
}

# agent_id when present, else session_id. Sanitised for use as a file name.
mc_key() {
  local k
  k="$(mc_in '.agent_id')"
  [ -n "$k" ] || k="$(mc_in '.session_id')"
  printf '%s' "$k" | tr -c 'A-Za-z0-9._-' '_'
}

# The worker's own transcript: in-session (agent_id present) it lives under
# <transcript without .jsonl>/subagents/agent-<agent_id>.jsonl.
mc_transcript() {
  local tp aid
  tp="$(mc_in '.transcript_path')"
  [ -n "$tp" ] || return 0
  aid="$(mc_in '.agent_id')"
  if [ -n "$aid" ]; then
    printf '%s' "${tp%.jsonl}/subagents/agent-${aid}.jsonl"
  else
    printf '%s' "$tp"
  fi
}

# Dispatch file path from the first user line carrying MC_DISPATCH=<path>.
# Cached per key (a negative result is cached as an empty file). Sets and
# prints $MC_DISPATCH_FILE; empty when unknown or the file does not exist.
mc_dispatch() {
  local key cache tr p=""
  if [ -n "$MC_DISPATCH_FILE" ]; then printf '%s' "$MC_DISPATCH_FILE"; return 0; fi
  key="$(mc_key)"
  cache=""
  if [ -n "$key" ]; then
    cache="$MC_TMP/$key.dispatch"
    if [ -f "$cache" ]; then
      p="$(cat "$cache" 2>/dev/null || true)"
      if [ -n "$p" ] && [ -f "$p" ]; then MC_DISPATCH_FILE="$p"; printf '%s' "$p"; fi
      return 0
    fi
  fi
  tr="$(mc_transcript)"
  [ -n "$tr" ] && [ -f "$tr" ] || return 0
  p="$(jq -rRn '
      first(inputs | fromjson? | select(type == "object" and .type == "user")
        | .message.content
        | if type == "string" then .
          elif type == "array" then (map(select(type == "object" and .type == "text") | .text // "") | join("\n"))
          else "" end
        | select(test("MC_DISPATCH="))
        | capture("MC_DISPATCH=(?<p>[^\\s\"'"'"'`]+)").p)
    ' "$tr" 2>/dev/null || true)"
  if [ -n "$cache" ]; then
    mkdir -p "$MC_TMP" 2>/dev/null && printf '%s' "$p" > "$cache" 2>/dev/null || true
  fi
  if [ -n "$p" ] && [ -f "$p" ]; then MC_DISPATCH_FILE="$p"; printf '%s' "$p"; fi
  return 0
}

# Model calls completed so far: distinct message.id on type=="assistant"
# lines, one jq pass. Lines that do not parse (a half-written last line) are
# skipped. The transcript lags the current turn by one message (its own line
# is written after its tools finish), so this raw count is one less than the
# turn the model is actually in; use mc_turns for that.
mc_assistant_ids() {
  local tr
  tr="$(mc_transcript)"
  [ -n "$tr" ] && [ -f "$tr" ] || return 0
  jq -rRn '[inputs | fromjson? | select(type == "object" and .type == "assistant") | .message.id // empty] | unique | length' "$tr" 2>/dev/null || true
}

# The turn the model is in right now: distinct assistant ids + 1 (the lag
# fact in references/landing.md). This is the number every hook reasons
# about and the number written to the gauge file's turns= field.
mc_turns() {
  local n
  n="$(mc_assistant_ids)"
  case "$n" in ''|*[!0-9]*) return 0 ;; esac
  printf '%s' $(( n + 1 ))
}

# A dispatch field as text (arrays one element per line); empty when absent.
mc_field() {
  local d
  d="$(mc_dispatch)"
  [ -n "$d" ] && [ -f "$d" ] || return 0
  jq -r --arg f "$1" '.[$f] // empty | if type == "array" then .[] else . end' "$d" 2>/dev/null || true
}

# Rewrite the gauge line; keep any event: lines already below it.
# Usage: mc_gauge_write TURNS CAP RESERVE_AT
mc_gauge_write() {
  local d g tmp
  d="$(mc_dispatch)"
  [ -n "$d" ] || return 0
  g="$d.gauge"
  tmp="$g.$$.tmp"
  {
    printf 'turns=%s cap=%s reserve_at=%s updated=%s\n' "$1" "$2" "$3" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    [ -f "$g" ] && grep '^event:' "$g" 2>/dev/null || true
  } > "$tmp" 2>/dev/null && mv -f "$tmp" "$g" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  return 0
}

# Append "event: <text>" to the gauge file.
mc_gauge_event() {
  local d
  d="$(mc_dispatch)"
  [ -n "$d" ] || return 0
  printf 'event: %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$d.gauge" 2>/dev/null || true
  return 0
}

# Common arithmetic: sets MC_T MC_C MC_R MC_S. Returns 1 when unknown.
mc_numbers() {
  MC_T="$(mc_turns)"; MC_C="$(mc_field cap)"; MC_R="$(mc_field reserve)"
  [ -n "$MC_R" ] || MC_R=6
  case "$MC_T$MC_C$MC_R" in *[!0-9]*|'') return 1 ;; esac
  [ -n "$MC_T" ] && [ -n "$MC_C" ] || return 1
  MC_S=$(( MC_C - MC_R + 1 ))
  return 0
}

# "commit" (default) or "return-only".
mc_landing() {
  local l
  l="$(mc_field landing)"
  [ "$l" = "return-only" ] && printf 'return-only' || printf 'commit'
}
