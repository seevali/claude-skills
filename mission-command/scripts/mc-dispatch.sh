#!/usr/bin/env bash
# mc-dispatch.sh — write a worker's dispatch file and return skeleton, print
# the prompt header. Contract: references/landing.md, "Conductor scripts".
#
#   mc-dispatch.sh --unit W-12 --agent mc-worker-opus --worktree DIR --return FILE
#     [--tracker FILE] [--gate "CMD"] [--reserve 6] [--cap N]
#     [--permission-mode MODE] [--landing commit|return-only] [--scope PATH]...
#     --out FILE
set -euo pipefail

die() { printf 'mc-dispatch: %s\n' "$*" >&2; exit 2; }

unit="" agent="" worktree="" ret="" tracker="" gate="" reserve=6 cap="" mode="bypassPermissions" landing="commit" out=""
scope=()
while [ $# -gt 0 ]; do
  case "$1" in
    --unit) unit="${2:?}"; shift 2 ;;
    --agent) agent="${2:?}"; shift 2 ;;
    --worktree) worktree="${2:?}"; shift 2 ;;
    --return) ret="${2:?}"; shift 2 ;;
    --tracker) tracker="${2:?}"; shift 2 ;;
    --gate) gate="${2-}"; shift 2 ;;
    --reserve) reserve="${2:?}"; shift 2 ;;
    --cap) cap="${2:?}"; shift 2 ;;
    --permission-mode) mode="${2:?}"; shift 2 ;;
    --landing) landing="${2:?}"; shift 2 ;;
    --scope) scope+=("${2:?}"); shift 2 ;;
    --out) out="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$unit" ] && [ -n "$agent" ] && [ -n "$worktree" ] && [ -n "$ret" ] && [ -n "$out" ] \
  || die "--unit, --agent, --worktree, --return and --out are required"
case "$landing" in commit|return-only) ;; *) die "--landing must be commit or return-only" ;; esac

# maxTurns from the definition's frontmatter: <cwd>/.claude/agents, then ~/.claude/agents.
if [ -z "$cap" ]; then
  for def in "$PWD/.claude/agents/$agent.md" "$HOME/.claude/agents/$agent.md"; do
    [ -f "$def" ] || continue
    cap="$(awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} /^maxTurns:/{sub(/^maxTurns:[ \t]*/,""); gsub(/[ \t"'"'"']/,""); print; exit}' "$def")"
    [ -n "$cap" ] && break
  done
fi
[ -n "$cap" ] || die "no maxTurns for agent '$agent' in ./.claude/agents or ~/.claude/agents, and no --cap"
case "$cap$reserve" in *[!0-9]*) die "cap and reserve must be integers (cap=$cap reserve=$reserve)" ;; esac
[ "$reserve" -lt "$cap" ] || die "reserve ($reserve) must be below cap ($cap)"

abs() { realpath -m -- "$1"; }
worktree="$(abs "$worktree")"; ret="$(abs "$ret")"; out="$(abs "$out")"
# The MC_DISPATCH= token is read up to the first whitespace.
case "$out$ret" in *[[:space:]]*) die "--out and --return must not contain whitespace ($out, $ret)" ;; esac
[ -n "$tracker" ] && tracker="$(abs "$tracker")"

mkdir -p "$(dirname "$out")"
scope_json='null'
[ ${#scope[@]} -gt 0 ] && scope_json="$(printf '%s\n' "${scope[@]}" | jq -R . | jq -sc .)"
jq -n --arg unit "$unit" --arg worktree "$worktree" --arg return_file "$ret" \
  --arg tracker "$tracker" --argjson cap "$cap" --argjson reserve "$reserve" \
  --arg gate "$gate" --arg permission_mode "$mode" --arg landing "$landing" \
  --argjson scope "$scope_json" '
  {unit: $unit, worktree: $worktree, return_file: $return_file}
  + (if $tracker != "" then {tracker: $tracker} else {} end)
  + {cap: $cap, reserve: $reserve, gate: $gate, permission_mode: $permission_mode, landing: $landing}
  + (if $scope != null then {scope: $scope} else {} end)' > "$out"

if [ ! -e "$ret" ]; then
  mkdir -p "$(dirname "$ret")"
  printf '# Return: %s\n\n## Return\n' "$unit" > "$ret"
fi

printf 'MC_DISPATCH=%s\n' "$out"
