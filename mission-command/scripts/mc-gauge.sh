#!/usr/bin/env bash
# mc-gauge.sh — PostToolUse hook (matcher ""): writes the gauge file and tells
# the worker its true turn count. Contract: references/landing.md, hook 1.
[ "${MC_HOOKS_OFF:-}" = "1" ] && exit 0
set -u
. "$(dirname "$0")/mc-hook-lib.sh" 2>/dev/null || exit 0

main() {
  mc_read_input
  MC_DISPATCH_FILE="$(mc_dispatch)"
  [ -n "$MC_DISPATCH_FILE" ] || return 0
  if ! mc_numbers; then mc_gauge_event "error gauge: turns or cap unknown"; return 0; fi
  mc_gauge_write "$MC_T" "$MC_C" "$MC_S"
  local rf msg
  rf="$(mc_field return_file)"
  if [ "$(mc_landing)" = "return-only" ]; then
    if [ "$MC_T" -ge "$MC_S" ]; then
      msg="[mc] RESERVE: turn $MC_T of $MC_C. Only Read/Write/Edit of the return file is allowed. Fill '## Return', stop."
    elif [ "$MC_T" -ge $(( MC_S - 3 )) ]; then
      msg="[mc] turn $MC_T of $MC_C. Reserve opens at turn $MC_S: land now — fill '## Return' in $rf."
    else
      msg="[mc] turn $MC_T of $MC_C. Reserve opens at turn $MC_S."
    fi
  else
    if [ "$MC_T" -ge "$MC_S" ]; then
      msg="[mc] RESERVE: turn $MC_T of $MC_C. Only git add/commit/status/diff and the return file are allowed. Commit, fill '## Return', stop."
    elif [ "$MC_T" -ge $(( MC_S - 3 )) ]; then
      msg="[mc] turn $MC_T of $MC_C. Reserve opens at turn $MC_S: land now — commit what is on disk, then fill '## Return' in $rf."
    else
      msg="[mc] turn $MC_T of $MC_C. Reserve opens at turn $MC_S."
    fi
  fi
  jq -nc --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}' 2>/dev/null || true
}

main 2>/dev/null || true
exit 0
