#!/usr/bin/env bash
# mc-stop-gate.sh — Stop hook (SubagentStop in-session): refuses a stop while
# work is uncommitted or '## Return' is unfilled; releases after two blocks.
# Contract: references/landing.md, hook 3.
[ "${MC_HOOKS_OFF:-}" = "1" ] && exit 0
set -u
. "$(dirname "$0")/mc-hook-lib.sh" 2>/dev/null || exit 0

# '## Return' is filled: >= 3 non-blank lines before the next '## ' heading,
# none of them a placeholder.
return_filled() {
  local f="$1" line in=0 n=0 t
  [ -f "$f" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in" = 0 ]; then
      [[ "$line" =~ ^\#\#[[:space:]]+Return[[:space:]]*$ ]] && in=1
      continue
    fi
    [[ "$line" =~ ^\#\#[[:space:]] ]] && break
    t="${line#"${line%%[![:space:]]*}"}"; t="${t%"${t##*[![:space:]]}"}"
    [ -n "$t" ] || continue
    t="${t#[-*] }"
    [[ "$t" =~ ^\<.*\>$ ]] && return 1
    [[ "$t" == *_fill_* ]] && return 1
    [[ "$t" =~ (^|:[[:space:]]*)(TBD|TODO)\.?$ ]] && return 1
    n=$(( n + 1 ))
  done < "$f"
  [ "$n" -ge 3 ]
}

main() {
  mc_read_input
  [ "$(mc_in '.stop_hook_active')" = "true" ] && return 0
  MC_DISPATCH_FILE="$(mc_dispatch)"
  [ -n "$MC_DISPATCH_FILE" ] || return 0
  local wt rf key cnt problems="" n st scope=()
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
  key="$(mc_key)"; cnt=0
  [ -f "$MC_TMP/$key.blocks" ] && cnt="$(cat "$MC_TMP/$key.blocks" 2>/dev/null || echo 0)"
  case "$cnt" in ''|*[!0-9]*) cnt=0 ;; esac
  if [ "$cnt" -ge 2 ]; then
    mc_gauge_event "stop-gate released after 2 blocks ($problems)"
    return 0
  fi
  cnt=$(( cnt + 1 ))
  mkdir -p "$MC_TMP" 2>/dev/null; printf '%s' "$cnt" > "$MC_TMP/$key.blocks" 2>/dev/null
  mc_gauge_event "stop-gate block $cnt ($problems)"
  jq -nc --arg r "[mc] Not landed: $problems. Commit everything on disk and fill '## Return' in $rf, then stop." '{decision:"block",reason:$r}' 2>/dev/null || true
}

main 2>/dev/null || true
exit 0
