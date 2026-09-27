#!/usr/bin/env bash
# tests/run.sh — the landing contract's cases (references/landing.md, "Tests").
# bash tests/run.sh   → one line per case, then "passed X failed Y".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
S="$HERE/../scripts"
T="$(mktemp -d "${TMPDIR:-/tmp}/mc-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT
export MC_HOOK_TMP="$T/hooktmp"
unset MC_HOOKS_OFF
PASS=0 FAIL=0

check() { # check NAME COMMAND...
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "ok $name"; PASS=$((PASS + 1)); else echo "FAIL $name"; FAIL=$((FAIL + 1)); fi
}
has() { printf '%s' "$1" | grep -qF -- "$2"; }
hasnt() { ! printf '%s' "$1" | grep -qF -- "$2"; }
empty() { [ -z "$1" ]; }

# --- fixtures -----------------------------------------------------------------
# Fixture helpers run inside $(...), so unique names come from mktemp, not counters.
mk_wt() { # fresh git repo with one commit; prints its path
  local d; d="$(mktemp -d "$T/wt.XXXXXX")"
  git -C "$d" init -q && git -C "$d" config user.email t@t && git -C "$d" config user.name t \
    && git -C "$d" config commit.gpgsign false && echo base > "$d/base.txt" && git -C "$d" add -A && git -C "$d" commit -q -m base >/dev/null 2>&1
  printf '%s' "$d"
}
filled() { printf '# Return: W-1\n\n## Return\nDid the thing because of the reason.\nChanged foo.ts; test passed 12/12.\nCommand: bash tests/run.sh, 30 cases.\n' > "$1"; }
placeholder() { printf '# Return: W-1\n\n## Return\n<decisions with their why>\nStatus: TBD\n_fill_\n' > "$1"; }

mk_disp() { # mk_disp WORKTREE [EXTRA_JSON] → dispatch path; return file is <dir>/ret.md, tracker <dir>/TRACKER.md
  local dir; dir="$(mktemp -d "$T/d.XXXXXX")"
  jq -n --arg wt "$1" --arg rf "$dir/ret.md" --arg tr "$dir/TRACKER.md" --argjson x "${2:-{\}}" \
    '{unit:"W-1",worktree:$wt,return_file:$rf,tracker:$tr,cap:40,reserve:6,gate:"",permission_mode:"bypassPermissions"} + $x' > "$dir/W-1.dispatch.json"
  printf '%s' "$dir/W-1.dispatch.json"
}

# mk_transcript N [FILE] [DISPATCH] [array] — N assistant messages with distinct
# ids; every even message has two tool_use lines sharing its id (so a
# line count would be wrong). First user line carries MC_DISPATCH= unless
# DISPATCH is "-". "array" writes the prompt as text blocks.
mk_transcript() {
  local n="$1" f="${2:-$T/transcript.jsonl}" d="${3:-${DISP:-}}" form="${4:-string}" i prompt
  mkdir -p "$(dirname "$f")"; : > "$f"
  echo '{"type":"agent-setting","id":null}' >> "$f"
  if [ "$d" = "-" ]; then prompt="Read the brief and work it."; else prompt="MC_DISPATCH=$d
Read the brief and work it."; fi
  if [ "$form" = array ]; then
    jq -nc --arg p "$prompt" '{type:"user",message:{role:"user",content:[{type:"text",text:$p}]}}' >> "$f"
  else
    jq -nc --arg p "$prompt" '{type:"user",message:{role:"user",content:$p}}' >> "$f"
  fi
  for ((i = 1; i <= n; i++)); do
    printf '{"type":"assistant","message":{"id":"msg_%04d","role":"assistant","content":[{"type":"thinking","thinking":""}]}}\n' "$i" >> "$f"
    printf '{"type":"assistant","message":{"id":"msg_%04d","role":"assistant","content":[{"type":"tool_use","id":"tu_%da","name":"Bash","input":{}}]}}\n' "$i" "$i" >> "$f"
    printf '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu_%da","content":"x"}]}}\n' "$i" >> "$f"
    if (( i % 2 == 0 )); then
      printf '{"type":"assistant","message":{"id":"msg_%04d","role":"assistant","content":[{"type":"tool_use","id":"tu_%db","name":"Read","input":{}}]}}\n' "$i" "$i" >> "$f"
      printf '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu_%db","content":"y"}]}}\n' "$i" >> "$f"
    fi
  done
  printf '%s' "$f"
}

# hook EVENT SCRIPT TRANSCRIPT [TOOL] [TOOL_INPUT_JSON] [EXTRA_JSON] → stdout of the hook
# (fresh session id per call, so the dispatch cache never leaks between cases).
# A non-zero hook exit prints HOOK-EXIT-<rc>, which fails every assertion.
hook() {
  local sid; sid="$(basename "$(mktemp -u "$T/sess.XXXXXXXX")")"
  local ev="$1" sc="$2" tp="$3" tool="${4:-}" ti="${5:-{\}}" x="${6:-{\}}" in
  in="$(jq -nc --arg s "$sid" --arg tp "$tp" --arg ev "$ev" --arg tool "$tool" --argjson ti "$ti" --argjson x "$x" \
    '{session_id:$s,transcript_path:$tp,cwd:"/",agent_type:"mc-worker-opus",hook_event_name:$ev}
     + (if $tool != "" then {tool_name:$tool,tool_input:$ti} else {} end) + $x')"
  local out rc
  out="$(printf '%s' "$in" | bash "$S/$sc")"; rc=$?
  printf '%s' "$out"; [ "$rc" -eq 0 ] || printf 'HOOK-EXIT-%s' "$rc"
}
post() { hook PostToolUse mc-gauge.sh "$1" Bash '{"command":"ls"}'; }
pre_bash() { hook PreToolUse mc-reserve.sh "$1" Bash "$(jq -nc --arg c "$2" '{command:$c}')" "${3:-{\}}"; }
pre_file() { hook PreToolUse mc-reserve.sh "$1" "$2" "$(jq -nc --arg p "$3" '{file_path:$p}')"; }
stop() { hook Stop mc-stop-gate.sh "$1" "" '{}' "${2:-{\"stop_hook_active\":false\}}"; }
denied() { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and .hookSpecificOutput.hookEventName == "PreToolUse"'; }
blocked() { printf '%s' "$1" | jq -e '.decision == "block" and (.reason | startswith("[mc] Not landed: "))'; }
ctx() { printf '%s' "$1" | jq -er '.hookSpecificOutput | select(.hookEventName == "PostToolUse") | .additionalContext'; }

# --- gauge ----------------------------------------------------------------------
WT="$(mk_wt)"; DISP="$(mk_disp "$WT")"; RF="$(dirname "$DISP")/ret.md"; filled "$RF"
o="$(post "$(mk_transcript 10)")"
check "gauge band 1 text" [ "$(ctx "$o")" = "[mc] turn 11 of 40. Reserve opens at turn 35." ]
check "gauge file line" grep -qE '^turns=11 cap=40 reserve_at=35 updated=[0-9T:-]+Z$' "$DISP.gauge"
check "gauge counts ids not lines (10 ids, 25 assistant lines)" [ "$(grep -c '"assistant"' "$T/transcript.jsonl")" -eq 25 ]
o="$(post "$(mk_transcript 33)")"
check "gauge band 2 text" [ "$(ctx "$o")" = "[mc] turn 34 of 40. Reserve opens at turn 35: land now — commit what is on disk, then fill '## Return' in $RF." ]
o="$(post "$(mk_transcript 31)")"
check "gauge band 2 starts at S-3" has "$(ctx "$o")" "land now"
o="$(post "$(mk_transcript 30)")"
check "gauge band 1 ends at S-4" hasnt "$(ctx "$o")" "land now"
o="$(post "$(mk_transcript 34)")"
check "gauge band 3 text" [ "$(ctx "$o")" = "[mc] RESERVE: turn 35 of 40. Only git add/commit/status/diff and the return file are allowed. Commit, fill '## Return', stop." ]
o="$(post "$(mk_transcript 12 "$T/arr.jsonl" "$DISP" array)")"
check "gauge with array prompt content" has "$(ctx "$o")" "turn 13 of 40"
check "gauge keeps event lines" bash -c "echo 'event: x kept' >> '$DISP.gauge'; printf '%s' '$(jq -nc --arg tp "$T/arr.jsonl" '{session_id:"g-ev",transcript_path:$tp,hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{}}')' | bash '$S/mc-gauge.sh' >/dev/null; head -1 '$DISP.gauge' | grep -q '^turns=13' && grep -q '^event: x kept' '$DISP.gauge'"
mkdir -p "$T/main"; mk_transcript 7 "$T/main/sess/subagents/agent-a1.jsonl" "$DISP" >/dev/null
o="$(hook PostToolUse mc-gauge.sh "$T/main/sess.jsonl" Bash '{}' '{"agent_id":"a1"}')"
check "gauge finds in-session transcript via agent_id" has "$(ctx "$o")" "turn 8 of 40"

# --- reserve --------------------------------------------------------------------
TR="$(mk_transcript 33)"
check "reserve silent before S" empty "$(pre_bash "$TR" "pnpm test")"
TR="$(mk_transcript 36)"; INWT="$(jq -nc --arg c "$WT" '{cwd:$c}')"
for c in "git add -A" "git commit -m 'wip'" "git status" "git diff --stat" "git -C $WT log --oneline -3" "git rev-parse HEAD" "git show HEAD"; do
  check "reserve allows: $c" empty "$(pre_bash "$TR" "$c" "$INWT")"
done
check "reserve allows compound git add -A && git commit" empty "$(pre_bash "$TR" "git -C $WT add -A && git -C $WT commit -q -m \"fix: a; b | c\"" "$INWT")"
check "reserve allows git commit heredoc (-F -)" empty "$(pre_bash "$TR" "git commit -F - <<'EOF'
subject; with | separators
body && more
EOF" "$INWT")"
check "reserve denies git -C of a foreign directory" denied "$(pre_bash "$TR" "git -C $T add -A")"
check "reserve denies command substitution \$(...)" denied "$(pre_bash "$TR" "git commit -m \"\$(rm -rf src)\"")"
check "reserve denies backtick substitution" denied "$(pre_bash "$TR" "git commit -m \"\`rm -rf src\`\"")"
check "reserve allows commit heredoc idiom \$(cat <<'EOF' ...)" empty "$(pre_bash "$TR" "git commit -m \"\$(cat <<'EOF'
msg
EOF
)\"" "$INWT")"
check "reserve denies background & (finding 1)" denied "$(pre_bash "$TR" "git status & rm -rf src")"
check "reserve denies process substitution <( (finding 4)" denied "$(pre_bash "$TR" "git diff <(touch pwned)")"
check "reserve denies << inside a quoted message (finding 5)" denied "$(pre_bash "$TR" "git commit -m \"a <<EOF\"
rm -rf src
EOF")"
check "reserve denies unquoted-tag heredoc -F - (finding 6)" denied "$(pre_bash "$TR" "git commit -F - <<EOF
\$(touch pwned)
EOF")"
check "reserve denies unquoted-tag \$(cat <<EOF) (finding 6)" denied "$(pre_bash "$TR" "git commit -m \"\$(cat <<EOF
\$(touch pwned)
EOF
)\"")"
check "reserve denies a heredoc on another command" denied "$(pre_bash "$TR" "cat <<'EOF'
x
EOF")"
check "reserve denies \$(pnpm test) as commit message" denied "$(pre_bash "$TR" "git commit -m \"\$(pnpm test)\"")"
check "reserve denies pnpm test" denied "$(pre_bash "$TR" "pnpm test")"
check "reserve denial reason text" has "$(pre_bash "$TR" "pnpm test" | jq -r .hookSpecificOutput.permissionDecisionReason)" "[mc] Reserve: turn 37 of 40. Only landing actions are allowed: git -C $WT add …, git -C $WT commit -m \"…\", git -C $WT commit -F - <<'EOF', git -C $WT commit -m \"\$(cat <<'EOF' … EOF)\", and Read/Write/Edit of $RF. Commit what is on disk, fill '## Return', then stop."
check "reserve denies redirection > (finding 2)" denied "$(pre_bash "$TR" "git status > src/a.ts" "$INWT")"
check "reserve denies redirection >> (finding 2)" denied "$(pre_bash "$TR" "git status >> /etc/x" "$INWT")"
check "reserve denies --output (finding 3)" denied "$(pre_bash "$TR" "git log --output=src/a.ts -1" "$INWT")"
check "reserve allows 2>/dev/null after a git segment" empty "$(pre_bash "$TR" "git -C $WT status 2>/dev/null")"
check "reserve allows 2>&1 after a git segment" empty "$(pre_bash "$TR" "git -C $WT status 2>&1")"
check "reserve denies 2>x" denied "$(pre_bash "$TR" "git -C $WT status 2>x")"
check "reserve denies >/dev/null" denied "$(pre_bash "$TR" "git -C $WT status >/dev/null")"
check "reserve allows > inside a quoted message" empty "$(pre_bash "$TR" "git commit -m 'a > b'" "$INWT")"
check "reserve allows -C \"<worktree>\" (finding 7)" empty "$(pre_bash "$TR" "git -C \"$WT\" status")"
check "reserve allows -C '<worktree>' (finding 7)" empty "$(pre_bash "$TR" "git -C '$WT' status")"
check "reserve allows -C ~/<worktree> (finding 8)" empty "$(HOME="$(dirname "$WT")" pre_bash "$TR" "git -C ~/$(basename "$WT") status")"
o="$(pre_bash "$TR" "git add -A && git commit -m x")"
check "reserve denies bare git outside the worktree (finding 14)" denied "$o"
check "reserve bare-git reason names git -C <worktree>" has "$o" "use git -C $WT."
check "reserve denial reason contains -F -" has "$(pre_bash "$TR" "pnpm test")" "-F -"
check "reserve denies git add && pnpm test" denied "$(pre_bash "$TR" "git add -A && pnpm test")"
check "reserve denies git status; rm" denied "$(pre_bash "$TR" "git status; rm -rf src")"
check "reserve denies git push" denied "$(pre_bash "$TR" "git push")"
check "reserve denies Edit of a source file" denied "$(pre_file "$TR" Edit "$WT/base.txt")"
check "reserve denies Read of a source file" denied "$(pre_file "$TR" Read "$WT/base.txt")"
check "reserve allows Write of the return file" empty "$(pre_file "$TR" Write "$RF")"
check "reserve allows Write of the return file via .. path" empty "$(pre_file "$TR" Write "$(dirname "$RF")/../$(basename "$(dirname "$RF")")/ret.md")"
check "reserve allows Read of the return file" empty "$(pre_file "$TR" Read "$RF")"
check "reserve allows Edit of the tracker (not yet on disk)" empty "$(pre_file "$TR" Edit "$(dirname "$DISP")/TRACKER.md")"
check "reserve denies other tools" denied "$(hook PreToolUse mc-reserve.sh "$TR" Glob '{"pattern":"**"}')"
# second refute (L-4b)
check "reserve denies text after EOF) in a \$(cat body (L-4b finding 1)" denied "$(pre_bash "$TR" "git -C $WT commit --allow-empty -m \"\$(cat <<'EOF'
body
EOF)\"
touch $T/pwned1
EOF
)\"")"
check "reserve denies text after EOF ) in a \$(cat body (L-4b finding 1)" denied "$(pre_bash "$TR" "git -C $WT commit --allow-empty -m \"\$(cat <<'EOF'
body
EOF )\"
touch $T/pwned1
EOF
)\"")"
check "reserve allows the one-line EOF)\" end of a \$(cat body" empty "$(pre_bash "$TR" "git -C $WT commit -m \"\$(cat <<'EOF'
body
EOF)\"")"
check "reserve denies text after the tag in a -F - body" denied "$(pre_bash "$TR" "git -C $WT commit -F - <<'EOF'
body
EOF; touch $T/pwned1")"
LONG="$(head -c 2100 /dev/zero | tr '\0' a)"
IN2K="$(jq -nc --arg tp "$TR" --arg c "git -C $WT commit -m \"$LONG\"" '{session_id:"long-m",transcript_path:$tp,cwd:"/",hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}')"
t0=$(date +%s%N); o="$(printf '%s' "$IN2K" | bash "$S/mc-reserve.sh")"; ms=$(( ($(date +%s%N) - t0) / 1000000 ))
check "reserve denies a 2,100-byte -m message in under 100 ms (L-4b finding 2; ${ms} ms)" bash -c '[ "$2" -lt 100 ] && printf "%s" "$1" | jq -e ".hookSpecificOutput.permissionDecision == \"deny\"" >/dev/null' _ "$o" "$ms"
check "reserve long-command reason ends with the -F - sentence (L-4b finding 2)" bash -c '[[ "$1" == *"$2" ]]' _ "$(printf '%s' "$o" | jq -r .hookSpecificOutput.permissionDecisionReason)" "Put a long message in git -C $WT commit -F - <<'EOF'."
check "reserve allows a 2,100-byte -F - body (L-4b finding 2)" empty "$(pre_bash "$TR" "git -C $WT commit -F - <<'EOF'
$LONG
EOF")"

# --- stop gate --------------------------------------------------------------------
WT="$(mk_wt)"; DISP="$(mk_disp "$WT")"; RF="$(dirname "$DISP")/ret.md"; TR="$(mk_transcript 20)"
filled "$RF"; echo new > "$WT/new.txt"
o="$(stop "$TR")"
check "stop gate blocks on dirty worktree" blocked "$o"
check "stop gate reports path count" has "$o" "dirty worktree: 1 paths"
git -C "$WT" add -A && git -C "$WT" commit -q -m done >/dev/null
placeholder "$RF"
o="$(stop "$TR")"
check "stop gate blocks on placeholder return" has "$o" "'## Return' is empty or placeholder"
filled "$RF"
check "stop gate passes when clean and filled" empty "$(stop "$TR")"
check "stop gate never blocks when stop_hook_active" empty "$(placeholder "$RF"; stop "$TR" '{"stop_hook_active":true}')"
# one block, then the stop_hook_active re-check releases with an event (finding 13)
IN="$(jq -nc --arg tp "$TR" '{session_id:"rel-1",transcript_path:$tp,hook_event_name:"Stop",stop_hook_active:false}')"
o1="$(printf '%s' "$IN" | bash "$S/mc-stop-gate.sh")"; o2="$(printf '%s' "$IN" | jq -c '.stop_hook_active = true' | bash "$S/mc-stop-gate.sh")"; rc2=$?
check "stop gate blocks once, then re-check releases (finding 13)" bash -c '[ -n "$1" ] && [ -z "$2" ] && [ "$3" -eq 0 ]' _ "$o1" "$o2" "$rc2"
check "stop gate blocked event in gauge file" grep -q "^event: .*stop-gate blocked ('## Return' is empty or placeholder)" "$DISP.gauge"
check "stop gate release event in gauge file (finding 13)" grep -q "^event: .*stop-gate released, still unlanded ('## Return' is empty or placeholder)" "$DISP.gauge"
check "stop gate blocks again on a fresh stop, no counter (finding 16)" blocked "$(printf '%s' "$IN" | bash "$S/mc-stop-gate.sh")"
filled "$RF"; nrel="$(grep -c 'released' "$DISP.gauge")"
check "stop gate re-check passes silently once landed (finding 16)" bash -c "[ -z '$(stop "$TR" '{"stop_hook_active":true}')' ] && [ \$(grep -c released '$DISP.gauge') -eq $nrel ]"
two='# Return: W-1\n\n## Return\nDid the thing because of the reason.\nChanged foo.ts; test passed 12/12.\n'
for ph in "TBD - later" "TODO: write this" "tbd" "[TBD]" "TODO:" "- tbd later" "* TODO" "**TODO** later" "1. TODO later" "\`TODO\` later" "> TODO later"; do
  printf "$two%s\n" "$ph" > "$RF"
  check "stop gate: '$ph' is a placeholder (finding 15)" blocked "$(stop "$TR")"
done
for ct in "Todoist sync fixed" "TBDx"; do
  printf "$two%s\n" "$ct" > "$RF"
  check "stop gate: '$ct' is content (whole-word rule)" empty "$(stop "$TR")"
done
printf '# Return: W-1\n\n## Return\n### Decisions\n### Changes\n### Commands\n' > "$RF"
check "stop gate: headings are not content lines (finding 15)" blocked "$(stop "$TR")"
printf '# Return: W-1\n\n## Return\nfixed the TODO in foo.ts\nwrote <return_file> into the prompt text\nall green\n' > "$RF"
check "stop gate accepts prose mentioning TODO and <...>" empty "$(stop "$TR")"

# --- landing: return-only -------------------------------------------------------
WT="$(mk_wt)"; DISP="$(mk_disp "$WT" '{"landing":"return-only"}')"; RF="$(dirname "$DISP")/ret.md"; TR="$(mk_transcript 36)"
check "return-only: reserve denies git commit" denied "$(pre_bash "$TR" "git commit -m x")"
check "return-only: reserve allows Write of return file" empty "$(pre_file "$TR" Write "$RF")"
filled "$RF"; echo dirt > "$WT/dirt.txt"
check "return-only: stop gate ignores dirty worktree" empty "$(stop "$TR")"
placeholder "$RF"
check "return-only: stop gate still checks the return" blocked "$(stop "$TR")"

# --- scope ----------------------------------------------------------------------
WT="$(mk_wt)"; mkdir -p "$WT/unit" "$WT/other"; DISP="$(mk_disp "$WT" '{"scope":["unit"]}')"; RF="$(dirname "$DISP")/ret.md"; TR="$(mk_transcript 20)"
filled "$RF"; echo dirt > "$WT/other/x.txt"
check "scope: dirt outside the scope does not block" empty "$(stop "$TR")"
echo dirt > "$WT/unit/y.txt"
check "scope: dirt inside the scope blocks" has "$(stop "$TR")" "dirty worktree: 1 paths"

# --- inert / robustness ----------------------------------------------------------
WT="$(mk_wt)"; DISP="$(mk_disp "$WT")"; TR="$(mk_transcript 38 "$T/nodisp.jsonl" -)"; echo dirt > "$WT/d.txt"
check "inert without MC_DISPATCH: gauge" empty "$(post "$TR")"
check "inert without MC_DISPATCH: reserve" empty "$(pre_bash "$TR" "pnpm test")"
check "inert without MC_DISPATCH: stop gate" empty "$(stop "$TR")"
TR="$(mk_transcript 38)"
check "MC_HOOKS_OFF=1 makes hooks inert" bash -c "export MC_HOOKS_OFF=1; printf '%s' '{\"session_id\":\"off\",\"transcript_path\":\"$TR\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pnpm test\"}}' | bash '$S/mc-reserve.sh' | grep -q . && exit 1; exit 0"
check "garbage stdin: exit 0, no output" bash -c "for h in mc-gauge mc-reserve mc-stop-gate; do o=\$(echo 'not json{' | bash '$S/'\$h.sh) || exit 1; [ -z \"\$o\" ] || exit 1; done"
check "missing transcript: exit 0, no output" empty "$(post "$T/does-not-exist.jsonl")"
check "missing dispatch file: inert" empty "$(pre_bash "$(mk_transcript 38 "$T/gone.jsonl" "$T/gone.dispatch.json")" "pnpm test")"
D9="$(mktemp -d "$T/d9.XXXXXX")/W-1.dispatch.json"; echo '{not json' > "$D9"; TR9="$(mk_transcript 37 "$T/f9.jsonl" "$D9")"
check "unreadable dispatch: stop gate inert with event: error (finding 9)" bash -c "[ -z '$(stop "$TR9")' ] && grep -q '^event: .* error stop-gate: dispatch missing or unreadable' '$D9.gauge'"
WT="$(mk_wt)"; echo dirt > "$WT/d.txt"
D10="$(mk_disp "$WT")"; jq 'del(.return_file)' "$D10" > "$D10.x" && mv "$D10.x" "$D10"; TR10="$(mk_transcript 37 "$T/f10.jsonl" "$D10")"
check "dispatch without return_file: stop gate inert with event: error (finding 10)" bash -c "[ -z '$(stop "$TR10")' ] && grep -q '^event: .* error stop-gate: dispatch missing or unreadable: return_file' '$D10.gauge'"
D11="$(mk_disp "$WT")"; jq 'del(.worktree)' "$D11" > "$D11.x" && mv "$D11.x" "$D11"; TR11="$(mk_transcript 37 "$T/f11.jsonl" "$D11")"
check "dispatch without worktree: reserve inert on pnpm test and Write (finding 11)" bash -c "[ -z '$(pre_bash "$TR11" "pnpm test")' ] && [ -z '$(pre_file "$TR11" Write "$WT/any.txt")' ] && grep -q '^event: .* error reserve: dispatch missing or unreadable: worktree' '$D11.gauge'"
D12="$(mk_disp "$WT")"; jq 'del(.worktree)' "$D12" > "$D12.x" && mv "$D12.x" "$D12"; TR12="$(mk_transcript 37 "$T/f12.jsonl" "$D12")"
IN12="$(jq -nc --arg tp "$TR12" '{session_id:"err-once",transcript_path:$tp,cwd:"/",hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"pnpm test"}}')"
printf '%s' "$IN12" | bash "$S/mc-reserve.sh" >/dev/null; printf '%s' "$IN12" | bash "$S/mc-reserve.sh" >/dev/null
check "broken dispatch: event: error logged once per worker key" [ "$(grep -c '^event: .* error ' "$D12.gauge")" -eq 1 ]
BASH_BIN="$(command -v bash)"
check "PATH=/nonexistent: all hooks silent on stderr (finding 12)" bash -c "for h in mc-gauge mc-reserve mc-stop-gate; do e=\$(printf '{}' | PATH=/nonexistent '$BASH_BIN' '$S/'\$h.sh 2>&1); [ -z \"\$e\" ] || exit 1; done"
mkdir -p "$T/nojq"; for b in bash cat dirname mkdir date tr git grep realpath mv rm; do ln -sf "$(command -v $b)" "$T/nojq/$b"; done
check "missing jq: one line in errors.log (finding 12)" bash -c "o=\$(printf '{}' | PATH='$T/nojq' MC_HOOK_TMP='$T/nojqtmp' '$BASH_BIN' '$S/mc-reserve.sh' 2>&1); [ -z \"\$o\" ] && [ \$(wc -l < '$T/nojqtmp/errors.log') -eq 1 ] && grep -q 'mc-reserve.sh: jq missing' '$T/nojqtmp/errors.log'"

# --- mc-hook.sh wrapper ---------------------------------------------------------
WT="$(mk_wt)"; DISP="$(mk_disp "$WT")"; TR="$(mk_transcript 10)"
B="$T/broken"; cp -r "$S" "$B"; printf '\nif then fi (\n' >> "$B/mc-reserve.sh"
check "wrapper: broken target exits 0, no stdout, one errors.log line" bash -c "o=\$(printf '{}' | MC_HOOK_TMP='$T/wrap1' bash '$B/mc-hook.sh' reserve); rc=\$?; [ \$rc -eq 0 ] && [ -z \"\$o\" ] && [ \$(wc -l < '$T/wrap1/errors.log') -eq 1 ] && grep -q 'mc-reserve.sh: syntax error' '$T/wrap1/errors.log'"
IN="$(jq -nc --arg tp "$TR" '{session_id:"wrap-g",transcript_path:$tp,hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{}}')"
o="$(printf '%s' "$IN" | bash "$S/mc-hook.sh" gauge)"
check "wrapper: passes stdin through, prints the gauge JSON" [ "$(ctx "$o")" = "[mc] turn 11 of 40. Reserve opens at turn 35." ]

# --- mc-land.sh -----------------------------------------------------------------
WT="$(mk_wt)"; DISP="$(mk_disp "$WT" '{"gate":"test -f base.txt"}')"; RF="$(dirname "$DISP")/ret.md"; filled "$RF"
echo 'turns=41 cap=40 reserve_at=35 updated=x' > "$DISP.gauge"; echo left > "$WT/left.txt"
o="$(bash "$S/mc-land.sh" "$DISP")"; rc=$?
check "mc-land exits 0" [ $rc -eq 0 ]
check "mc-land commits leftovers" bash -c "[ -z \"\$(git -C '$WT' status --porcelain)\" ] && git -C '$WT' log -1 --format=%s | grep -qF \"wip(W-1): capped worker's leftovers, unreviewed\""
check "mc-land appends ## Landing" bash -c "grep -q '^## Landing' '$RF' && grep -q 'turns: 41 of 40' '$RF' && grep -q \"leftovers: \$(git -C '$WT' rev-parse --short HEAD)\" '$RF' && grep -q 'gate: exit 0, log $(dirname "$DISP")/W-1.gate.log' '$RF'"
check "mc-land prints one summary line" bash -c "[ \$(printf '%s\n' '$o' | wc -l) -eq 1 ] && printf '%s' '$o' | grep -q '^\[mc-land\] W-1: turns=41/40'"
H1="$(git -C "$WT" rev-parse HEAD)"; rm -f "$(dirname "$DISP")/W-1.gate.log"
o="$(bash "$S/mc-land.sh" "$DISP")"
check "mc-land second run: no commit, no gate, one ## Landing (finding 18)" bash -c "[ \"\$(git -C '$WT' rev-parse HEAD)\" = '$H1' ] && [ ! -e '$(dirname "$DISP")/W-1.gate.log' ] && [ \$(grep -c '^## Landing' '$RF') -eq 1 ]"
check "mc-land second run prints the existing summary (finding 18)" has "$o" "[mc-land] W-1: turns=41/40 leftovers=$(git -C "$WT" rev-parse --short HEAD) gate=0 log=$(dirname "$DISP")/W-1.gate.log (already landed"
WT="$(mk_wt)"; DISP="$(mk_disp "$WT")"; jq --arg rf "$WT/ret.md" '.return_file = $rf' "$DISP" > "$DISP.x" && mv "$DISP.x" "$DISP"; filled "$WT/ret.md"; echo left > "$WT/left.txt"
bash "$S/mc-land.sh" "$DISP" >/dev/null 2>&1
check "mc-land commits its record inside the worktree (finding 19)" bash -c "[ -z \"\$(git -C '$WT' status --porcelain)\" ] && git -C '$WT' log -1 --format=%s | grep -qx 'land(W-1): landing record' && git -C '$WT' log -1 --skip=1 --format=%s | grep -q '^wip(W-1)' && grep -q '^## Landing' '$WT/ret.md'"
WT="$(mk_wt)"; mkdir -p "$WT/unit"; DISP="$(mk_disp "$WT" '{"scope":["unit"]}')"; filled "$(dirname "$DISP")/ret.md"; echo o > "$WT/other.txt"; H1="$(git -C "$WT" rev-parse HEAD)"
bash "$S/mc-land.sh" "$DISP" >/dev/null 2>&1
check "mc-land limits leftovers to scope, usage says so (finding 17)" bash -c "[ \"\$(git -C '$WT' rev-parse HEAD)\" = '$H1' ] && git -C '$WT' status --porcelain | grep -q other.txt && bash '$S/mc-land.sh' 2>&1 | grep -q scope"

# --- mc-dispatch.sh -------------------------------------------------------------
P="$T/proj"; mkdir -p "$P/.claude/agents" "$T/home/.claude/agents"
printf -- '---\nname: fake\nmodel: opus\neffort: low\nmaxTurns: 40\n---\nBody mentions maxTurns: 99\n' > "$P/.claude/agents/fake.md"
printf -- '---\nname: homeonly\nmaxTurns: 25\n---\n' > "$T/home/.claude/agents/homeonly.md"
WT="$(mk_wt)"
o="$(cd "$P" && HOME="$T/home" bash "$S/mc-dispatch.sh" --unit W-9 --agent fake --worktree "$WT" --return "$T/r9/W-9.md" --gate "true" --out "$T/r9/W-9.dispatch.json")"
check "mc-dispatch reads maxTurns from the definition" [ "$(jq -r .cap "$T/r9/W-9.dispatch.json")" = 40 ]
check "mc-dispatch prints the prompt header" [ "$o" = "MC_DISPATCH=$T/r9/W-9.dispatch.json" ]
check "mc-dispatch writes the return skeleton" grep -qx '## Return' "$T/r9/W-9.md"
check "mc-dispatch fields" jq -e '.unit == "W-9" and .reserve == 6 and .gate == "true" and .landing == "commit" and .permission_mode == "bypassPermissions" and (has("tracker") | not)' "$T/r9/W-9.dispatch.json"
(cd "$P" && HOME="$T/home" bash "$S/mc-dispatch.sh" --unit W-8 --agent homeonly --worktree "$WT" --return "$T/r9/W-8.md" --out "$T/r9/W-8.dispatch.json" --landing return-only --scope a --scope b) >/dev/null
check "mc-dispatch falls back to ~/.claude/agents, landing and scope" jq -e '.cap == 25 and .landing == "return-only" and .scope == ["a","b"]' "$T/r9/W-8.dispatch.json"
(cd "$P" && HOME="$T/home" bash "$S/mc-dispatch.sh" --unit W-7 --agent fake --cap 12 --worktree "$WT" --return "$T/r9/W-7.md" --out "$T/r9/W-7.dispatch.json") >/dev/null
check "mc-dispatch --cap overrides" [ "$(jq -r .cap "$T/r9/W-7.dispatch.json")" = 12 ]
check "mc-dispatch fails without a cap" bash -c "cd '$P' && HOME='$T/home' bash '$S/mc-dispatch.sh' --unit X --agent nosuch --worktree '$WT' --return '$T/x.md' --out '$T/x.json'; [ \$? -eq 2 ]"
check "mc-dispatch keeps an existing return file" bash -c "filled() { :; }; echo keep > '$T/r9/W-6.md'; cd '$P' && HOME='$T/home' bash '$S/mc-dispatch.sh' --unit W-6 --agent fake --worktree '$WT' --return '$T/r9/W-6.md' --out '$T/r9/W-6.json' >/dev/null && [ \"\$(cat '$T/r9/W-6.md')\" = keep ]"
check "mc-dispatch refuses whitespace in --out (L-4b finding 5)" bash -c "cd '$P' && HOME='$T/home' bash '$S/mc-dispatch.sh' --unit W-5 --agent fake --worktree '$WT' --return '$T/r9/W-5.md' --out '$T/r 9/W-5.json' 2>/dev/null; [ \$? -eq 2 ] && [ ! -e '$T/r 9/W-5.json' ]"
check "mc-dispatch refuses whitespace in --return (L-4b finding 5)" bash -c "cd '$P' && HOME='$T/home' bash '$S/mc-dispatch.sh' --unit W-5 --agent fake --worktree '$WT' --return '$T/r9/W 5.md' --out '$T/r9/W-5.json' 2>/dev/null; [ \$? -eq 2 ] && [ ! -e '$T/r9/W-5.json' ]"

# --- mc-run.sh (dry run only; never launches claude) ------------------------------
echo "work it" > "$T/brief.md"; cp "$P/.claude/agents/fake.md" "$T/home/.claude/agents/fake.md"
o="$(cd "$P" && HOME="$T/home" bash "$S/mc-run.sh" --dry-run "$T/r9/W-9.dispatch.json" fake "$T/brief.md")"
check "mc-run dry-run command line" bash -c 'o="$1"; for w in "claude -p" "MC_DISPATCH='"$T"'/r9/W-9.dispatch.json" "--agent fake" "--max-turns 40" "--effort low" "--output-format json" "--strict-mcp-config" "--disable-slash-commands" "--permission-mode bypassPermissions" "< /dev/null" "W-9.run.json"; do printf "%s" "$o" | grep -qF -- "$w" || exit 1; done' _ "$o"
check "mc-run dry-run runs from the worktree" has "$o" "cd $WT && "
o="$(cd "$P" && HOME="$T/home" bash "$S/mc-run.sh" --dry-run "$T/r9/W-8.dispatch.json" homeonly "$T/brief.md")"
check "mc-run omits --effort when the definition has none" hasnt "$o" "--effort"
check "mc-run rejects wrong argument count" bash -c "bash '$S/mc-run.sh' --dry-run '$T/r9/W-9.dispatch.json' fake; [ \$? -eq 2 ]"
mkdir -p "$T/emptyhome"
check "mc-run requires a global definition (project-only: exit 2, says copy)" bash -c "o=\$(cd '$P' && HOME='$T/emptyhome' bash '$S/mc-run.sh' --dry-run '$T/r9/W-9.dispatch.json' fake '$T/brief.md' 2>&1); rc=\$?; [ \$rc -eq 2 ] && [ \$(printf '%s\n' \"\$o\" | wc -l) -eq 1 ] && printf '%s' \"\$o\" | grep -qF 'cannot see project definitions' && printf '%s' \"\$o\" | grep -qF '~/.claude/agents/fake.md'"
check "mc-run rejects a missing brief" bash -c "cd '$P' && HOME='$T/home' bash '$S/mc-run.sh' --dry-run '$T/r9/W-9.dispatch.json' fake '$T/nope.md'; [ \$? -eq 2 ]"

echo "passed $PASS failed $FAIL"
[ "$FAIL" -eq 0 ]
