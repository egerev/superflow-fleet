#!/usr/bin/env bash
# Run a harness script from the merged harness (origin/main of the checkout), never from its
# working tree or a draft branch, the same source rule as core/templates/harness-hook.sh.
# Install once per machine (README, Scripts and hooks): ~/.local/bin/harness-exec.
# Usage: harness-exec [--ref <git ref>] <core/bin/name|core/hooks/name|modules/<m>/bin/name|modules/<m>/hooks/name> [args...]
#   --ref: test a branch; only as an explicit argument, never inherited from the environment.
#   Or a symlink to this file named after the script (an orchestrator's bin/worker-restart.sh):
#   the link name picks core/bin/<name> or modules/*/bin/<name>, and the project config defaults
#   to <link dir>/../config.sh.
# The tree of each origin/main commit is extracted once to a cache; a fetch moves every project
# to the new commit at once.
set -euo pipefail
h=${HARNESS_DIR:-$HOME/agent-harness}
ref=origin/main
self=$(basename "$0")
script=
if [ "$self" = harness-exec.sh ] || [ "$self" = harness-exec ]; then
  if [ "${1:-}" = --ref ]; then ref=${2:?--ref needs a git ref}; shift 2; fi
  [ $# -ge 1 ] || { echo "usage: harness-exec [--ref <git ref>] <core/bin/name|modules/<m>/bin/name|core/hooks/name> [args...]" >&2; exit 2; }
  script=$1; shift
  case "$script" in
    core/bin/*|core/hooks/*|modules/*/bin/*|modules/*/hooks/*) ;;
    *) echo "harness-exec: only core/ or modules/<m>/ bin and hooks scripts run, not '$script'" >&2; exit 2 ;;
  esac
  case "$script" in *..*) echo "harness-exec: no '..' in '$script'" >&2; exit 2 ;; esac
else
  cfg="$(cd "$(dirname "$0")/.." && pwd)/config.sh"
  [ -n "${HARNESS_CONFIG:-}" ] || [ ! -f "$cfg" ] || export HARNESS_CONFIG="$cfg"
fi
rev=$(git -C "$h" rev-parse --verify -q "$ref^{commit}") \
  || { echo "harness-exec: no $ref in $h (clone it and run git -C $h fetch origin)" >&2; exit 3; }
cache=${XDG_CACHE_HOME:-$HOME/.cache}/agent-harness/$rev
if [ ! -d "$cache" ]; then
  mkdir -p "$(dirname "$cache")"
  tmp=$(mktemp -d "$cache.tree.XXXXXX")
  git -C "$h" archive "$rev" core modules | tar -x -C "$tmp" \
    || { rm -rf "$tmp"; echo "harness-exec: cannot extract harness $rev" >&2; exit 3; }
  # Publish with a symlink: ln -n without -f fails when a concurrent run published first, and then
  # this run's copy goes (mv onto an existing directory would nest it inside).
  ln -sn "$(basename "$tmp")" "$cache" 2>/dev/null || rm -rf "$tmp"
fi
if [ -z "$script" ]; then
  for d in "$cache/core/bin" "$cache"/modules/*/bin; do
    if [ -f "$d/$self" ]; then script=${d#"$cache"/}/$self; break; fi
  done
fi
[ -n "$script" ] && [ -f "$cache/$script" ] || { echo "harness-exec: ${script:-$self} is not in harness $rev" >&2; exit 2; }
export HARNESS_REV=$rev
exec "$cache/$script" "$@"
