#!/usr/bin/env bash
# mc-stop-gate.sh — Stop hook (SubagentStop in-session): refuses a stop while
# work is uncommitted or '## Return' is unfilled. Blocks once; on the stop that
# follows (stop_hook_active) it re-checks and never blocks again.
# Contract: references/landing.md, hook 3.
[ "${MC_HOOKS_OFF:-}" = "1" ] && exit 0
set -u
{ . "$(dirname "$0")/mc-hook-lib.sh"; } 2>/dev/null || exit 0

# '## Return' is filled: >= 3 content lines (non-blank, not a heading) before
# the next '#'/'##' heading, none a placeholder. A placeholder is wholly <…>,
# contains _fill_, or starts with TBD/TODO after optional brackets, dashes or
# whitespace, in any case, as a whole word (TODO: is one, Todoist is not).
HEAD12_RE='^#{1,2}[[:space:]]'
PH_RE='^[][(){}[:space:]-]*(tbd|todo)([^a-z0-9_]|$)'
return_filled() {
  local f="$1" line in=0 n=0 t lc
  [ -f "$f" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in" = 0 ]; then
      [[ "$line" =~ ^\#\#[[:space:]]+Return[[:space:]]*$ ]] && in=1
      continue
    fi
    [[ "$line" =~ $HEAD12_RE ]] && break
    t="${line#"${line%%[![:space:]]*}"}"; t="${t%"${t##*[![:space:]]}"}"
    [ -n "$t" ] || continue
    [[ "$t" == \#* ]] && continue
    [[ "${t#[-*] }" =~ ^\<.*\>$ ]] && return 1
    [[ "$t" == *_fill_* ]] && return 1
    lc="$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')"
    [[ "$lc" =~ $PH_RE ]] && return 1
    n=$(( n + 1 ))
  done < "$f"
  [ "$n" -ge 3 ]
}

main() {
  mc_require_jq || return 0
  mc_read_input
  MC_DISPATCH_FILE="$(mc_dispatch)"
  [ -n "$MC_DISPATCH_FILE" ] || return 0
  mc_require_fields stop-gate || return 0
  local wt rf problems="" n st scope=()
  wt="$(mc_field worktree)"; rf="$(mc_field return_file)"
  if [ "$(mc_landing)" = "commit" ]; then
    while IFS= read -r st; do [ -n "$st" ] && scope+=("$st"); done < <(mc_field scope)
    if st="$(git -C "$wt" status --porcelain -- "${scope[@]}" 2>/dev/null)"; then
      n="$(printf '%s' "$st" | grep -c . || true)"
      [ "${n:-0}" -gt 0 ] && problems="dirty worktree: $n paths"
    else
      mc_gauge_event "error stop-gate: git status failed in $wt"
    fi
  fi
  if ! return_filled "$rf"; then
    problems="${problems:+$problems; }'## Return' is empty or placeholder"
  fi
  [ -n "$problems" ] || return 0
  # The harness sets stop_hook_active on the stop that follows a block: this is
  # the one re-check, and it never blocks.
  if [ "$(mc_in '.stop_hook_active')" = "true" ]; then
    mc_gauge_event "stop-gate released, still unlanded ($problems)"
    return 0
  fi
  mc_gauge_event "stop-gate blocked ($problems)"
  jq -nc --arg r "[mc] Not landed: $problems. Commit everything on disk and fill '## Return' in $rf, then stop." '{decision:"block",reason:$r}' 2>/dev/null || true
}

main 2>/dev/null || true
exit 0
