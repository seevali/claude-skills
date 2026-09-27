#!/usr/bin/env bash
# mc-reserve.sh — PreToolUse hook (matcher ""): from the first reserve turn on,
# allows only landing actions. Contract: references/landing.md, hook 2.
[ "${MC_HOOKS_OFF:-}" = "1" ] && exit 0
set -u
. "$(dirname "$0")/mc-hook-lib.sh" 2>/dev/null || exit 0

# `git [-C dir] commit` at the start of a segment.
GIT_COMMIT_RE='^[[:space:]]*git([[:space:]]+-C[[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+))?[[:space:]]+commit([[:space:]]|$)'
# The two landing heredoc openers: `… commit … -F -` then `<<`, and `… commit … -m "` then `$(cat <<`.
F_HD_RE="${GIT_COMMIT_RE}(.*[[:space:]])?-F[[:space:]]+-[[:space:]]*\$"
M_HD_RE="${GIT_COMMIT_RE}(.*[[:space:]])?-m[[:space:]]*\"\$"

CAT_HD_RE='^[$][(]cat[[:space:]]+<<'
# take_heredoc S POS: at S[POS] is `<<`. Accepts only a quoted tag
# (<<'TAG' or <<"TAG") that is the last token of its line; skips the body
# through the line whose trimmed text is TAG (trimming accepts a superset of
# bash's terminators, so it can only end the body early, never late). Sets
# HD_END to the index after the TAG line (or the end of S). Returns 1 otherwise.
take_heredoc() {
  local s="$1" pos="$2" n=${#1} j line t tag
  local re="^<<-?[ 	]*('([A-Za-z_][A-Za-z0-9_]*)'|\"([A-Za-z_][A-Za-z0-9_]*)\")[ 	]*"$'\n'
  [[ "${s:pos}" =~ $re ]] || return 1
  tag="${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
  j=$(( pos + ${#BASH_REMATCH[0]} ))
  while (( j < n )); do
    line="${s:j}"; line="${line%%$'\n'*}"
    j=$(( j + ${#line} + 1 ))
    t="${line#"${line%%[![:space:]]*}"}"; t="${t%"${t##*[![:space:]]}"}"
    if [ "$t" = "$tag" ]; then HD_END=$j; return 0; fi
  done
  HD_END=$n
  return 0
}

# segments CMD: contract steps 1-2. Prints one segment per line: split on
# unquoted && || ; | & and newlines (newlines inside quotes become spaces),
# with the two landing heredocs stripped (the $(cat <<'TAG' … TAG) idiom is
# replaced by COMMIT_HEREDOC). Returns 1 (deny) on any other unquoted `<<`,
# on unquoted process substitution and on any unquoted redirection (> >> <).
segments() {
  local s="$1" n=${#1} i=0 c nx q="" seg="" dq=-1 out=""
  while (( i < n )); do
    c="${s:i:1}"; nx="${s:i+1:1}"
    if [ "$q" = "'" ]; then
      [ "$c" = "'" ] && q=""
      [ "$c" = $'\n' ] && c=' '
      seg+="$c"; i=$(( i + 1 )); continue
    fi
    if [ "$q" = '"' ]; then
      if [ "$c" = "\\" ]; then
        [ "$nx" = $'\n' ] && nx=' '
        seg+="$c$nx"; i=$(( i + 2 )); continue
      fi
      if [ "$c" = '$' ] && (( i == dq + 1 )) && [[ "${s:i}" =~ $CAT_HD_RE ]] \
         && [[ "$seg" =~ $M_HD_RE ]]; then
        local p="${s:i}"; p="${p%%<<*}"
        take_heredoc "$s" $(( i + ${#p} )) || return 1
        [[ "${s:HD_END}" =~ ^[[:blank:]]*\) ]] || return 1
        seg+="COMMIT_HEREDOC"; i=$(( HD_END + ${#BASH_REMATCH[0]} )); continue
      fi
      [ "$c" = '"' ] && q=""
      [ "$c" = $'\n' ] && c=' '
      seg+="$c"; i=$(( i + 1 )); continue
    fi
    case "$c" in
      "'"|'"') q="$c"; dq=$i; seg+="$c" ;;
      "\\") [ "$nx" = $'\n' ] && nx=' '; seg+="$c$nx"; i=$(( i + 1 )) ;;
      ';'|$'\n') out+="$seg"$'\n'; seg="" ;;
      '|'|'&') out+="$seg"$'\n'; seg=""; [ "$nx" = "$c" ] && i=$(( i + 1 )) ;;
      '<'|'>')
        if [ "$c$nx" = '<<' ]; then
          [[ "$seg" =~ $F_HD_RE ]] || return 1
          take_heredoc "$s" "$i" || return 1
          out+="$seg"$'\n'; seg=""; i=$HD_END; continue
        fi
        return 1 ;;  # process substitution or an unquoted redirection
      *) seg+="$c" ;;
    esac
    i=$(( i + 1 ))
  done
  printf '%s%s\n' "$out" "$seg"
}

resolve() { realpath -m -- "$1" 2>/dev/null || printf '%s' "$1"; }

# norm_dir DIR CWD: a -C argument as bash would pass it: one layer of matching
# quotes stripped, a leading ~ expanded (unquoted only, as bash does), and a
# relative path taken against the hook input's cwd.
norm_dir() {
  local d="$1" cwd="$2" q=""
  if [ ${#d} -ge 2 ] && { [[ "$d" == \"*\" ]] || [[ "$d" == \'*\' ]]; }; then q=1; d="${d:1:${#d}-2}"; fi
  if [ -z "$q" ]; then
    case "$d" in "~") d="$HOME" ;; "~/"*) d="$HOME/${d#\~/}" ;; esac
  fi
  case "$d" in /*) ;; *) [ -n "$cwd" ] && d="$cwd/$d" ;; esac
  resolve "$d"
}

# bash_allowed CMD WORKTREE CWD. On a bare git outside the worktree sets
# DENY_NOTE so the reason can say why.
DENY_NOTE=""
bash_allowed() {
  local seg wt="$2" cwd="$3" segs dir any=0 rwt
  local re='^[[:space:]]*git([[:space:]]+-C[[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+))?[[:space:]]+(add|commit|status|diff|log|rev-parse|show)([^A-Za-z0-9_]|$)'
  [ -n "$wt" ] || return 1
  rwt="$(resolve "$wt")"
  segs="$(segments "$1")" || return 1
  while IFS= read -r seg; do
    [[ "$seg" =~ ^[[:space:]]*$ ]] && continue
    # Contract step 3: substitutions anywhere in a segment (quoted or not),
    # other than the recognised commit heredoc, and any `<<` left over.
    [[ "$seg" == *'$('* || "$seg" == *'`'* || "$seg" == *'<<'* || "$seg" == *'<('* || "$seg" == *'>('* ]] && return 1
    [[ "$seg" =~ $re ]] || return 1
    dir="${BASH_REMATCH[2]}"
    # --output of diff/log/show writes a file (git accepts abbreviations, so any --ou…).
    case "${BASH_REMATCH[3]}" in diff|log|show)
      [[ "$seg" =~ (^|[[:space:]])[\"\']?--ou ]] && return 1 ;;
    esac
    # Contract step 4: the repository is the worktree.
    if [ -n "$dir" ]; then
      [ "$(norm_dir "$dir" "$cwd")" = "$rwt" ] || return 1
    elif [ -z "$cwd" ] || [ "$(resolve "$cwd")" != "$rwt" ]; then
      DENY_NOTE=" A git without -C runs in ${cwd:-an unknown directory}, not the worktree: use git -C $wt."
      return 1
    fi
    any=1
  done <<< "$segs"
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
  local tool mode rf reason wt
  wt="$(mc_field worktree)"
  tool="$(mc_in '.tool_name')"
  mode="$(mc_landing)"
  case "$tool" in
    Bash)
      [ "$mode" = "commit" ] && bash_allowed "$(mc_in '.tool_input.command')" "$wt" "$(mc_in '.cwd')" && return 0 ;;
    Read|Write|Edit)
      path_allowed "$(mc_in '.tool_input.file_path')" && return 0 ;;
  esac
  rf="$(mc_field return_file)"
  if [ "$mode" = "return-only" ]; then
    reason="[mc] Reserve: turn $MC_T of $MC_C. Only landing actions are allowed: Read/Write/Edit of $rf. Fill '## Return', then stop."
  else
    reason="[mc] Reserve: turn $MC_T of $MC_C. Only landing actions are allowed: git -C $wt add …, git -C $wt commit -m \"…\", git -C $wt commit -F - <<'EOF', git -C $wt commit -m \"\$(cat <<'EOF' … EOF)\", and Read/Write/Edit of $rf. Commit what is on disk, fill '## Return', then stop.$DENY_NOTE"
  fi
  jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null || true
}

main 2>/dev/null || true
exit 0
