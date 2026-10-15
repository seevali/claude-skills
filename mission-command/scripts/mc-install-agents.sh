#!/usr/bin/env bash
# mc-install-agents.sh [--force] — for a skills-folder install or headless runs.
# Copies agents/mc-worker-opus.md and agents/mc-worker-sonnet.md to
# ~/.claude/agents/, replacing the literal ${CLAUDE_PLUGIN_ROOT} (set only under
# a plugin install) with this skill's absolute root. Refuses to overwrite an
# existing file unless --force. Prints each file it wrote.
set -euo pipefail

die() { printf 'mc-install-agents: %s\n' "$*" >&2; exit 2; }
# mc_norm_path (one path normaliser, cygpath-aware) comes from the hook library.
. "$(dirname "$0")/mc-hook-lib.sh" || die "cannot source mc-hook-lib.sh"

force=0
for a in "$@"; do
  case "$a" in
    --force) force=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) die "usage: mc-install-agents.sh [--force]" ;;
  esac
done

root="$(mc_norm_path "$(cd "$(dirname "$0")/.." && pwd)")"
dest="$(mc_norm_path "$HOME")/.claude/agents"
# The copies carry the root unquoted in a hook command string, which bash splits on whitespace.
case "$root" in *[[:space:]]*) die "skill root contains whitespace: $root; move the skill to a path without spaces" ;; esac
names=(mc-worker-opus.md mc-worker-sonnet.md)

for n in "${names[@]}"; do
  [ -f "$root/agents/$n" ] || die "missing $root/agents/$n"
  if [ -e "$dest/$n" ] && [ "$force" != 1 ]; then
    die "$dest/$n exists; rerun with --force to overwrite"
  fi
done

mkdir -p "$dest"
# Escape the sed replacement's specials (\, & and the | delimiter); the path may contain /.
esc="$(printf '%s' "$root" | sed 's/[\\&|]/\\&/g')"
for n in "${names[@]}"; do
  sed 's|\${CLAUDE_PLUGIN_ROOT}|'"$esc"'|g' "$root/agents/$n" > "$dest/$n"
  printf 'wrote %s (hooks at %s/scripts/mc-hook.sh)\n' "$dest/$n" "$root"
done
