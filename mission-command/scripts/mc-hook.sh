#!/usr/bin/env bash
# mc-hook.sh <gauge|reserve|stop-gate>
# The only command an agent definition points at. It never exits non-zero and never
# prints anything but the real hook's stdout, so an edit that breaks a hook script
# (a parse error exits bash with 2, which the harness reads as a denial) can never
# lock a session out. Stdin is passed through to the real hook untouched.
[ -n "${MC_HOOKS_OFF:-}" ] && exit 0
d="${BASH_SOURCE[0]%/*}"; n="${1:-}"
case "$n" in gauge|reserve|stop-gate) ;; *) exit 0 ;; esac
t="$d/mc-$n.sh"
log="${MC_HOOK_TMP:-/tmp/mc-hooks}/errors.log"
if ! bash -n "$t" 2>/dev/null; then
  { mkdir -p "${log%/*}" && printf '%s mc-%s.sh: syntax error, hook skipped\n' "$(date -u +%FT%TZ)" "$n" >> "$log"; } 2>/dev/null
  exit 0
fi
out=$(bash "$t" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then printf '%s' "$out"; else
  { mkdir -p "${log%/*}" && printf '%s mc-%s.sh: exit %s, hook skipped\n' "$(date -u +%FT%TZ)" "$n" "$rc" >> "$log"; } 2>/dev/null
fi
exit 0
