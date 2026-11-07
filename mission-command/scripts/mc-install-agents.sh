#!/usr/bin/env bash
# mc-install-agents.sh [--force] — only for a copy of the skill that does not
# load as a plugin. A skill folder under ~/.claude/skills or .claude/skills with
# .claude-plugin/plugin.json loads as the plugin mission-command@skills-dir,
# hooks/hooks.json and agents/ included, so the usual install needs nothing
# from here. Copies agents/mc-worker-opus.md and agents/mc-worker-sonnet.md to
# the agents/ folder of Claude Code's config directory ($CLAUDE_CONFIG_DIR,
# else ~/.claude), replacing the literal ${CLAUDE_PLUGIN_ROOT} (set only under
# a plugin) with this skill's absolute root. Refuses when `claude plugin list`
# already shows the plugin (a worker reached by both routes gets every hook
# twice) and refuses to overwrite an existing file; --force overrides both.
set -euo pipefail

die() { printf 'mc-install-agents: %s\n' "$*" >&2; exit 2; }
# mc_norm_path (one path normaliser, cygpath-aware) comes from the hook library.
. "$(dirname "$0")/mc-hook-lib.sh" || die "cannot source mc-hook-lib.sh"

force=0
for a in "$@"; do
  case "$a" in
    --force) force=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) die "usage: mc-install-agents.sh [--force]" ;;
  esac
done

root="$(mc_norm_path "$(cd "$(dirname "$0")/.." && pwd)")"
if [ "$force" != 1 ] && command -v claude >/dev/null 2>&1; then
  if claude plugin list 2>/dev/null | grep -q 'mission-command@'; then
    die "mission-command already loads as a plugin (claude plugin list shows mission-command@…): hooks/hooks.json registers the landing hooks and the workers are mission-command:mc-worker-opus and mission-command:mc-worker-sonnet, so there is nothing to install. A copy here would give those workers every hook twice. Use --force only if that listing is wrong."
  fi
fi
dest="$(mc_config_dir)/agents"
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
