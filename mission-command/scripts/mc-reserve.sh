#!/usr/bin/env bash
# mc-reserve.sh — PreToolUse hook (matcher ""): from the first reserve turn on,
# allows only landing actions. Contract: references/landing.md, hook 2.
[ "${MC_HOOKS_OFF:-}" = "1" ] && exit 0
set -u
. "$(dirname "$0")/mc-hook-lib.sh" 2>/dev/null || exit 0

# Drop heredoc bodies (the lines after a line with <<DELIM, through the DELIM
# line) so a `git commit` heredoc message stays one segment.
strip_heredocs() {
  local line delim="" out="" hre="(^|[^<])[<][<]-?[[:space:]]*['\"]?([A-Za-z_][A-Za-z0-9_]*)"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$delim" ]; then
      local t="${line#"${line%%[![:space:]]*}"}"
      [ "$t" = "$delim" ] && delim=""
      continue
    fi
    out+="$line"$'\n'
    if [[ "$line" =~ $hre ]]; then
      delim="${BASH_REMATCH[2]}"
    fi
  done <<< "$1"
  printf '%s' "$out"
}

# Split on unquoted && || ; | and newlines; one segment per output line
# (newlines inside quotes become spaces).
split_segments() {
  local s="$1" i c n seg="" q=""
  n=${#s}
  for (( i = 0; i < n; i++ )); do
    c="${s:i:1}"
    if [ -n "$q" ]; then
      if [ "$c" = "\\" ] && [ "$q" = '"' ]; then seg+="$c${s:i+1:1}"; i=$(( i + 1 )); continue; fi
      [ "$c" = "$q" ] && q=""
      [ "$c" = $'\n' ] && c=' '
      seg+="$c"; continue
    fi
    case "$c" in
      "'"|'"') q="$c"; seg+="$c" ;;
      "\\") seg+="$c${s:i+1:1}"; i=$(( i + 1 )) ;;
      ';'|'|'|$'\n') printf '%s\n' "$seg"; seg=""; [ "${s:i+1:1}" = '|' ] && [ "$c" = '|' ] && i=$(( i + 1 )) ;;
      '&') if [ "${s:i+1:1}" = '&' ]; then printf '%s\n' "$seg"; seg=""; i=$(( i + 1 )); else seg+="$c"; fi ;;
      *) seg+="$c" ;;
    esac
  done
  printf '%s\n' "$seg"
}

resolve() { realpath -m -- "$1" 2>/dev/null || printf '%s' "$1"; }

bash_allowed() {
  local seg wt="$2" re='^[[:space:]]*git([[:space:]]+-C[[:space:]]+([^[:space:]]+))?[[:space:]]+(add|commit|status|diff|log|rev-parse|show)([^A-Za-z0-9_]|$)'
  # The one allowed command substitution: $(cat <<TAG ... TAG) as a git commit
  # -m argument. Heredoc bodies are stripped before splitting, so what remains
  # of that idiom is just its residual opener immediately followed by the
  # closing paren/quote, e.g. `$(cat <<'EOF' )"`. Recognise that residual and
  # blank it out before the general $( check.
  local heredoc_re="\\\$\\(cat[[:space:]]+<<-?[[:space:]]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\\1[[:space:]]*\\)"
  local any=0 dir stripped
  while IFS= read -r seg; do
    [[ "$seg" =~ ^[[:space:]]*$ ]] && continue
    stripped="$(printf '%s' "$seg" | sed -E "s/${heredoc_re}/COMMIT_HEREDOC/g")"
    # Command substitution or backticks anywhere in a segment are denied
    # outright, even inside an otherwise-allowed git invocation, except the
    # commit-heredoc idiom just blanked out above.
    [[ "$stripped" == *'$('* || "$seg" == *'`'* ]] && return 1
    [[ "$seg" =~ $re ]] || return 1
    dir="${BASH_REMATCH[2]}"
    if [ -n "$dir" ]; then
      [ -n "$wt" ] && [ "$(resolve "$dir")" = "$(resolve "$wt")" ] || return 1
    fi
    any=1
  done < <(split_segments "$(strip_heredocs "$1")")
  [ "$any" = 1 ]
}

path_allowed() {
  local p="$1" f rp
  [ -n "$p" ] || return 1
  rp="$(resolve "$p")"
  for f in "$(mc_field return_file)" "$(mc_field tracker)"; do
    [ -n "$f" ] || continue
    [ "$p" = "$f" ] && return 0
    [ "$rp" = "$(resolve "$f")" ] && return 0
  done
  return 1
}

main() {
  mc_read_input
  MC_DISPATCH_FILE="$(mc_dispatch)"
  [ -n "$MC_DISPATCH_FILE" ] || return 0
  mc_numbers || return 0
  [ "$MC_T" -ge "$MC_S" ] || return 0
  local tool mode rf reason
  tool="$(mc_in '.tool_name')"
  mode="$(mc_landing)"
  case "$tool" in
    Bash)
      [ "$mode" = "commit" ] && bash_allowed "$(mc_in '.tool_input.command')" "$(mc_field worktree)" && return 0 ;;
    Read|Write|Edit)
      path_allowed "$(mc_in '.tool_input.file_path')" && return 0 ;;
  esac
  rf="$(mc_field return_file)"
  if [ "$mode" = "return-only" ]; then
    reason="[mc] Reserve: turn $MC_T of $MC_C. Only landing actions are allowed: Read/Write/Edit of $rf. Fill '## Return', then stop."
  else
    reason="[mc] Reserve: turn $MC_T of $MC_C. Only landing actions are allowed: git add/commit/status/diff, and Read/Write/Edit of $rf. Commit what is on disk, fill '## Return', then stop. Allowed forms: git add …, git commit -m \"…\", git commit -F - <<'EOF', git commit -m \"\$(cat <<'EOF' … EOF)\"."
  fi
  jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null || true
}

main 2>/dev/null || true
exit 0
