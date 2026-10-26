#!/bin/sh
# SessionStart: put the shared rulebook into the session context: core/process.md, the
# process-addendum.md of each enabled module, then the optional private overlay.
# Source order: the merged harness (origin/main of ~/agent-harness; never a draft branch or the
# working tree), then this repository's pinned copy docs/harness/; otherwise a stop notice.
# Modules: the "Harness modules:" line of this repository's AGENTS.md only (names separated by
# spaces or commas, case ignored, lowercase letters, digits and dashes; "none" or no line = core only). An unknown name prints a stop notice.
# Overlay: $HARNESS_OVERLAY (default ~/agent-harness-private), optional. A git repository is read
# from its origin/main only (never its working tree); a plain directory is read as a file. It is
# never pinned.
root=$(cd "$(dirname "$0")/../.." && pwd)
dir=${HARNESS_DIR:-$HOME/agent-harness}
mods=$(sed -n 's/^Harness modules:[[:space:]]*//p' "$root/AGENTS.md" 2>/dev/null | head -n 1 \
  | tr '[:upper:]' '[:lower:]' | tr ',' ' ')
set -f   # module names are words, never globs
blank() { [ -z "$(printf '%s' "$1" | tr -d '[:space:]')" ]; }

text=$(git -C "$dir" show origin/main:core/process.md 2>/dev/null)
src="egerev/superflow-fleet origin/main $(git -C "$dir" rev-parse --short origin/main 2>/dev/null)"
pinned=
if blank "$text"; then
  pinned=1
  text=$(cat "$root/docs/harness/core/process.md" 2>/dev/null)
  src="pinned copy docs/harness, version $(cat "$root/docs/harness/VERSION" 2>/dev/null)"
fi
if blank "$text"; then
  echo "HARNESS UNAVAILABLE: the shared rulebook (owner-kept list, change paths, reviews) is not loaded."
  echo "Stop: report BLOCKED to the orchestrator. Do not merge, deploy or take any owner-kept action."
  exit 0
fi
echo "Harness core/process.md ($src), modules: ${mods:-none}. Other harness files: git -C ~/agent-harness show origin/main:<file>, or docs/harness/."
printf '%s\n' "$text"
for m in $mods; do
  [ "$m" = none ] && continue
  case $m in *[!a-z0-9-]*|-*) m_bad=1 ;; *) m_bad= ;; esac
  known=; add=
  if [ -n "$m_bad" ]; then :
  elif [ -z "$pinned" ]; then
    git -C "$dir" cat-file -e "origin/main:modules/$m/README.md" 2>/dev/null && known=1
    add=$(git -C "$dir" show "origin/main:modules/$m/process-addendum.md" 2>/dev/null)
  else
    [ -f "$root/docs/harness/modules/$m/README.md" ] && known=1
    add=$(cat "$root/docs/harness/modules/$m/process-addendum.md" 2>/dev/null)
  fi
  if [ -z "$known" ] && blank "$add"; then
    printf '\nHARNESS MODULE UNKNOWN: "%s" in AGENTS.md (Harness modules:) is not a module of this harness, or not in the pinned copy docs/harness/.\n' "$m"
    echo "Stop: report BLOCKED to the orchestrator. Do not merge, deploy or take any owner-kept action."
    continue
  fi
  # Every module ships a non-empty process-addendum.md: an empty read is a failure, never "no rules".
  if blank "$add"; then
    printf '\nHARNESS MODULE UNAVAILABLE: the rules of module "%s" (process-addendum.md) are not loaded.\n' "$m"
    echo "Stop: report BLOCKED to the orchestrator. Do not merge, deploy or take any owner-kept action."
    continue
  fi
  printf '\n# Module %s\n%s\n' "$m" "$add"
done
ov=${HARNESS_OVERLAY:-$HOME/agent-harness-private}
if [ -d "$ov" ]; then
  if git -C "$ov" rev-parse --git-dir >/dev/null 2>&1; then
    extra=$(git -C "$ov" show origin/main:process-overlay.md 2>/dev/null); how="origin/main"
  else
    extra=$(cat "$ov/process-overlay.md" 2>/dev/null); how="file"
  fi
  blank "$extra" || printf '\n# Overlay (private, %s)\n%s\n' "$how" "$extra"
fi
