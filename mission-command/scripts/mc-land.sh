#!/usr/bin/env bash
# mc-land.sh <dispatch.json> — the conductor's recovery for a worker that hit
# its cap: commit leftovers, run the gate, append '## Landing' to the return
# file, print one summary line. Never pushes, never touches the tracker.
set -uo pipefail

die() { printf 'mc-land: %s\n' "$*" >&2; exit 2; }
[ $# -eq 1 ] || die "usage: mc-land.sh <dispatch.json>"
disp="$(realpath -m -- "$1")"
[ -f "$disp" ] || die "no dispatch file: $disp"
f() { jq -r --arg f "$1" '.[$f] // empty | if type == "array" then .[] else . end' "$disp"; }
unit="$(f unit)"; wt="$(f worktree)"; rf="$(f return_file)"; gate="$(f gate)"; cap="$(f cap)"
landing="$(f landing)"; [ -n "$landing" ] || landing=commit
scope=(); while IFS= read -r s; do [ -n "$s" ] && scope+=("$s"); done < <(f scope)
[ -n "$unit" ] && [ -n "$wt" ] && [ -n "$rf" ] || die "dispatch lacks unit, worktree or return_file"
git -C "$wt" rev-parse --git-dir >/dev/null 2>&1 || die "worktree is not a git repository: $wt"
ddir="$(dirname "$disp")"

# Leftovers.
leftovers="clean"
if [ "$landing" = "return-only" ]; then
  leftovers="not committed (landing: return-only)"
elif [ -n "$(git -C "$wt" status --porcelain -- "${scope[@]}")" ]; then
  if git -C "$wt" add -A -- "${scope[@]}" \
     && git -C "$wt" commit -q -m "wip($unit): capped worker's leftovers, unreviewed"; then
    leftovers="$(git -C "$wt" rev-parse --short HEAD)"
  else
    leftovers="commit failed"
  fi
fi

# True turn count from the gauge file.
turns="$(sed -n '1s/.*turns=\([0-9][0-9]*\).*/\1/p' "$disp.gauge" 2>/dev/null)"
[ -n "$turns" ] || turns="unknown"

# Gate.
gate_code="none" log=""
if [ -n "$gate" ]; then
  log="$ddir/$unit.gate.log"
  ( cd "$wt" && bash -c "$gate" ) > "$log" 2>&1
  gate_code=$?
fi

{
  printf '\n## Landing\n\n'
  printf -- '- date: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- turns: %s of %s (from the gauge file)\n' "$turns" "${cap:-?}"
  printf -- '- leftovers: %s\n' "$leftovers"
  if [ -n "$gate" ]; then printf -- '- gate: exit %s, log %s\n' "$gate_code" "$log"; else printf -- '- gate: none\n'; fi
} >> "$rf"

printf '[mc-land] %s: turns=%s/%s leftovers=%s gate=%s%s\n' "$unit" "$turns" "${cap:-?}" "$leftovers" "$gate_code" "${log:+ log=$log}"
exit 0
