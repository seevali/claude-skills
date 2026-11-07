#!/usr/bin/env bash
# mc-run.sh [--dry-run] <dispatch.json> <agent> <brief-file> — headless
# launcher. Runs `claude -p` from the worktree with the dispatch's cap and
# permission mode and the definition's effort; output JSON to
# <dispatch dir>/<unit>.run.json. Exits non-zero on error_max_turns so a loop
# can call mc-land.sh. --dry-run prints the command and runs nothing.
set -uo pipefail

die() { printf 'mc-run: %s\n' "$*" >&2; exit 2; }
# mc_norm_path (one path normaliser, cygpath-aware) comes from the hook library.
. "$(dirname "$0")/mc-hook-lib.sh" || { printf '%s: cannot source mc-hook-lib.sh\n' "${0##*/}" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || die "jq is required and missing: install it (Windows: winget install jqlang.jq; Debian/Ubuntu: apt install jq; macOS: brew install jq)"
dry=0; args=()
for a in "$@"; do
  case "$a" in --dry-run) dry=1 ;; -h|--help) sed -n '2,7p' "$0"; exit 0 ;; *) args+=("$a") ;; esac
done
[ ${#args[@]} -eq 3 ] || die "usage: mc-run.sh [--dry-run] <dispatch.json> <agent> <brief-file>"
disp="$(mc_norm_path "${args[0]}")"; agent="${args[1]}"; brief="$(mc_norm_path "${args[2]}")"
[ -f "$disp" ] || die "no dispatch file: $disp"
[ -f "$brief" ] || die "no brief file: $brief"
f() { jq -r --arg f "$1" '.[$f] // empty' "$disp"; }
unit="$(f unit)"; wt="$(mc_norm_path "$(f worktree)")"; cap="$(f cap)"; mode="$(f permission_mode)"
[ -n "$unit" ] && [ -n "$wt" ] && [ -n "$cap" ] || die "dispatch lacks unit, worktree or cap"
[ -n "$mode" ] || mode=bypassPermissions

# The definition's frontmatter (model, effort) is read from the copy shipped
# next to this script when the agent is one of ours, so a plugin install reads
# nothing outside the plugin; a plugin-qualified name (plugin:agent) is looked
# up by its last segment. Otherwise it is read from the user-level copy at
# <config dir>/agents/<name>.md, where mc-install-agents.sh puts it for a
# copy that does not load as a plugin: a headless run starts in the worktree
# and sees only global and plugin definitions (references/landing.md, "Facts").
name="${agent##*:}"
shipped="$(mc_norm_path "$(dirname "$0")/../agents")/$name.md"
global="$(mc_config_dir)/agents/$name.md"
if [ -f "$shipped" ]; then
  def="$shipped"
  [ -f "$global" ] || printf 'mc-run: note: no user-level copy at %s; fine when the skill loads as a plugin (claude plugin list shows mission-command@…; address the agent as mission-command:%s), only a copy that does not needs scripts/mc-install-agents.sh first\n' "$global" "$name" >&2
elif [ -f "$global" ]; then
  def="$global"
else
  for d in "$PWD/.claude/agents/$agent.md" "$wt/.claude/agents/$agent.md"; do
    [ -f "$d" ] && die "'$agent' is defined only at $d; a headless run cannot see project definitions — run scripts/mc-install-agents.sh to install it at $global"
  done
  die "no agent definition for '$agent' at $global; run scripts/mc-install-agents.sh to install the shipped ones"
fi
fm() { awk -v k="$1" 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} index($0, k":")==1{sub(/^[^:]*:[ \t]*/,""); gsub(/[ \t"'"'"']/,""); print; exit}' "$def"; }
model="$(fm model)"; effort="$(fm effort)"

cmd=(claude -p "MC_DISPATCH=$disp
Read the brief at $brief and work it." --agent "$agent" --max-turns "$cap")
[ -n "$effort" ] && cmd+=(--effort "$effort")
cmd+=(--output-format json --strict-mcp-config --mcp-config '{"mcpServers":{}}' --disable-slash-commands --permission-mode "$mode")

out="$(dirname "$disp")/$unit.run.json"
if [ "$dry" = 1 ]; then
  printf 'cd %q && ' "$wt"; printf '%q ' "${cmd[@]}"; printf '< /dev/null > %q\n' "$out"
  printf '# model=%s effort=%s cap=%s mode=%s\n' "${model:-default}" "${effort:-default}" "$cap" "$mode"
  exit 0
fi

[ -d "$wt" ] || die "no worktree: $wt"
( cd "$wt" && "${cmd[@]}" < /dev/null ) > "$out"
rc=$?
subtype="$(jq -r '.subtype // empty' "$out" 2>/dev/null)"
turns="$(jq -r '.num_turns // empty' "$out" 2>/dev/null)"
gauge="$(head -1 "$disp.gauge" 2>/dev/null)"
printf '[mc-run] %s: subtype=%s num_turns=%s gauge: %s\n' "$unit" "${subtype:-unknown}" "${turns:-?}" "${gauge:-none}"
[ "$subtype" = "error_max_turns" ] && exit 3
[ "$rc" -eq 0 ] || exit "$rc"
[ -n "$subtype" ] || exit 1
exit 0
