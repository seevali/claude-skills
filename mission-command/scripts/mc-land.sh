#!/usr/bin/env bash
# mc-land.sh <dispatch.json> — the conductor's recovery for a worker that hit
# its cap: commit leftovers, run the gate, append '## Landing' to the return
# file, print one summary line. Never pushes, never touches the tracker.
# Idempotent: a return file that already has '## Landing' is only summarised.
set -uo pipefail

die() { printf 'mc-land: %s\n' "$*" >&2; exit 2; }
usage="usage: mc-land.sh <dispatch.json>
  Commits the worktree's leftovers as wip(<unit>) (limited to the dispatch's
  \"scope\" paths when set; dirt outside the scope is left alone), runs \"gate\"
  in the worktree, appends '## Landing' to the return file and, when the return
  file is inside the worktree, commits that as land(<unit>): landing record.
  Idempotent: when '## Landing' already exists it only prints the summary."
[ $# -eq 1 ] || die "$usage"
disp="$(realpath -m -- "$1")"
[ -f "$disp" ] || die "no dispatch file: $disp"
f() { jq -r --arg f "$1" '.[$f] // empty | if type == "array" then .[] else . end' "$disp"; }
unit="$(f unit)"; wt="$(f worktree)"; rf="$(f return_file)"; gate="$(f gate)"; cap="$(f cap)"
landing="$(f landing)"; [ -n "$landing" ] || landing=commit
scope=(); while IFS= read -r s; do [ -n "$s" ] && scope+=("$s"); done < <(f scope)
[ -n "$unit" ] && [ -n "$wt" ] && [ -n "$rf" ] || die "dispatch lacks unit, worktree or return_file"
git -C "$wt" rev-parse --git-dir >/dev/null 2>&1 || die "worktree is not a git repository: $wt"
ddir="$(dirname "$disp")"

# Already landed: print the existing summary, change nothing.
if [ -f "$rf" ] && grep -q '^## Landing' "$rf"; then
  sec="$(sed -n '/^## Landing/,$p' "$rf")"
  l_turns="$(printf '%s\n' "$sec" | sed -n 's/^- turns: \([^ ]*\) of \([^ ]*\).*/\1\/\2/p' | head -1)"
  l_left="$(printf '%s\n' "$sec" | sed -n 's/^- leftovers: //p' | head -1)"
  l_gate="$(printf '%s\n' "$sec" | sed -n 's/^- gate: exit \([^,]*\), log \(.*\)/\1 log=\2/p; s/^- gate: none$/none/p' | head -1)"
  printf '[mc-land] %s: turns=%s leftovers=%s gate=%s (already landed; nothing done)\n' "$unit" "${l_turns:-?}" "${l_left:-?}" "${l_gate:-?}"
  exit 0
fi

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

# A return file inside the worktree would leave it dirty again: commit the record.
rwt="$(realpath -m -- "$wt")"; rrf="$(realpath -m -- "$rf")"
case "$rrf" in "$rwt"/*)
  git -C "$wt" add -- "$rrf" && git -C "$wt" commit -q -m "land($unit): landing record" -- "$rrf" \
    || printf 'mc-land: could not commit the landing record in %s\n' "$wt" >&2 ;;
esac

printf '[mc-land] %s: turns=%s/%s leftovers=%s gate=%s%s\n' "$unit" "$turns" "${cap:-?}" "$leftovers" "$gate_code" "${log:+ log=$log}"
exit 0
