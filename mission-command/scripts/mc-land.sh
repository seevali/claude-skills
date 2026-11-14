#!/usr/bin/env bash
# mc-land.sh <dispatch.json> — the conductor's one command after every worker
# returns, capped or not: commit leftovers, list files changed outside the
# unit's "owns", run the gate, append '## Landing' to the return file, append
# one outcome row to <dispatch dir>/outcomes.tsv, print one summary line.
# Never pushes, never touches the tracker.
# Idempotent: a return file that already has '## Landing' is only summarised.
set -uo pipefail

die() { printf 'mc-land: %s\n' "$*" >&2; exit 2; }
# mc_norm_path (one path normaliser, cygpath-aware) comes from the hook library.
. "$(dirname "$0")/mc-hook-lib.sh" || { printf '%s: cannot source mc-hook-lib.sh\n' "${0##*/}" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || die "jq is required and missing: install it (Windows: winget install jqlang.jq; Debian/Ubuntu: apt install jq; macOS: brew install jq)"
usage="usage: mc-land.sh <dispatch.json>
  Commits the worktree's leftovers as wip(<unit>) (limited to the dispatch's
  \"scope\" paths when set; dirt outside the scope is left alone), runs \"gate\"
  in the worktree, appends '## Landing' to the return file and, when the return
  file is inside the worktree, commits that as land(<unit>): landing record.
  With \"owns\" and \"base\" in the dispatch it lists every file changed since
  base that is outside owns. Appends one row to <dispatch dir>/outcomes.tsv.
  Idempotent: when '## Landing' already exists it only prints the summary."
[ $# -eq 1 ] || die "$usage"
disp="$(mc_norm_path "$1")"
[ -f "$disp" ] || die "no dispatch file: $disp"
f() { jq -r --arg f "$1" '.[$f] // empty | if type == "array" then .[] else . end' "$disp"; }
unit="$(f unit)"; wt="$(mc_norm_path "$(f worktree)")"; rf="$(mc_norm_path "$(f return_file)")"; gate="$(f gate)"; cap="$(f cap)"
landing="$(f landing)"; [ -n "$landing" ] || landing=commit
agent="$(f agent)"; base="$(f base)"; tracker="$(mc_norm_path "$(f tracker)")"
scope=(); while IFS= read -r s; do [ -n "$s" ] && scope+=("$s"); done < <(f scope)
owns=(); while IFS= read -r s; do [ -n "$s" ] && owns+=("$s"); done < <(f owns)
[ -n "$unit" ] && [ -n "$wt" ] && [ -n "$rf" ] || die "dispatch lacks unit, worktree or return_file"
git -C "$wt" rev-parse --git-dir >/dev/null 2>&1 || die "worktree is not a git repository: $wt"
ddir="$(dirname "$disp")"

# Already landed: print the existing summary, change nothing.
if [ -f "$rf" ] && grep -q '^## Landing' "$rf"; then
  sec="$(sed -n '/^## Landing/,$p' "$rf")"
  l_turns="$(printf '%s\n' "$sec" | sed -n 's/^- turns: \([^ ]*\) of \([^ ]*\).*/\1\/\2/p' | head -1)"
  l_left="$(printf '%s\n' "$sec" | sed -n 's/^- leftovers: //p' | head -1)"
  l_gate="$(printf '%s\n' "$sec" | sed -n 's/^- gate: exit \([^,]*\), log \(.*\)/\1 log=\2/p; s/^- gate: none$/none/p' | head -1)"
  l_out="$(printf '%s\n' "$sec" | sed -n 's/^- outside owns: \([^ ]*\).*/\1/p' | head -1)"
  case "$l_out" in not) l_out=unchecked ;; none) l_out=0 ;; esac
  printf '[mc-land] %s: turns=%s leftovers=%s gate=%s outside=%s (already landed; nothing done)\n' "$unit" "${l_turns:-?}" "${l_left:-?}" "${l_gate:-?}" "${l_out:-?}"
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

# Files changed since the dispatch's base that are outside the unit's owns
# (git pathspecs, relative to the worktree). The return file and the tracker
# are the worker's to write wherever they live, so they never count.
outside="unchecked" outside_line="not checked (no owns or no base in the dispatch)"
if [ ${#owns[@]} -gt 0 ] && [ -n "$base" ] && git -C "$wt" cat-file -e "$base^{commit}" 2>/dev/null; then
  top="$(mc_norm_path "$(git -C "$wt" rev-parse --show-toplevel)")"
  all="$(git -C "$wt" -c core.quotePath=false diff --name-only "$base" HEAD | sort)"
  mine="$(git -C "$wt" -c core.quotePath=false diff --name-only "$base" HEAD -- "${owns[@]}" | sort)"
  list="$(comm -23 <(printf '%s\n' "$all") <(printf '%s\n' "$mine") | grep -v '^$' || true)"
  for x in "$(mc_norm_path "$rf")" "$tracker"; do
    case "$x" in "$top"/*) list="$(printf '%s\n' "$list" | grep -vxF -- "${x#"$top"/}" || true)" ;; esac
  done
  if [ -n "$list" ]; then
    outside="$(printf '%s\n' "$list" | grep -c .)"
    outside_line="$outside ($(printf '%s\n' "$list" | paste -sd, - | sed 's/,/, /g'))"
  else
    outside=0 outside_line="none"
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
  printf -- '- outside owns: %s\n' "$outside_line"
} >> "$rf"

# One outcome row per dispatch, from the artifacts only (never the worker's own
# report). ended: cap = the gauge reached the cap; unlanded = it stopped short
# of the cap but left work for this script to commit, or the stop gate released
# it unlanded; landed = it committed and filled its return itself.
ended=landed
case "$leftovers" in clean|"not committed"*) ;; *) ended=unlanded ;; esac
grep -q 'stop-gate released, still unlanded' "$disp.gauge" 2>/dev/null && ended=unlanded
case "$turns${cap:-x}" in *[!0-9]*) ;; *) [ "$turns" -ge "$cap" ] && ended=cap ;; esac
version="$(jq -r '.version // empty' "$(dirname "$0")/../.claude-plugin/plugin.json" 2>/dev/null)"
rows="$ddir/outcomes.tsv"
[ -s "$rows" ] || printf 'date\tunit\tagent\tversion\tturns\tcap\tended\tgate\toutside_owns\tleftovers\n' >> "$rows"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$unit" "${agent:-?}" "${version:-?}" \
  "$turns" "${cap:-?}" "$ended" "$gate_code" "$outside" "$leftovers" >> "$rows"

# A return file inside the worktree would leave it dirty again: commit the record.
rwt="$(mc_norm_path "$wt")"; rrf="$(mc_norm_path "$rf")"
case "$rrf" in "$rwt"/*)
  git -C "$wt" add -- "$rrf" && git -C "$wt" commit -q -m "land($unit): landing record" -- "$rrf" \
    || printf 'mc-land: could not commit the landing record in %s\n' "$wt" >&2 ;;
esac

printf '[mc-land] %s: turns=%s/%s leftovers=%s gate=%s%s outside=%s\n' "$unit" "$turns" "${cap:-?}" "$leftovers" "$gate_code" "${log:+ log=$log}" "$outside"
exit 0
