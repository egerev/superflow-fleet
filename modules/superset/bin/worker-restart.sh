#!/usr/bin/env bash
# Worker self-restart: start a fresh session in this Superset workspace from a handoff; the new
# session closes this terminal once it has read the handoff and briefs (orchestration.md, Sessions).
# Usage: worker-restart.sh [--keep-old] <handoff.md> <model> <effort> <brief.md> [more briefs...]
#   --keep-old (or HARNESS_KEEP_OLD=1, or a line "Keep old session: yes" in the handoff): the prompt has no
#   close step; use it when the old session has live subagents. Otherwise the prompt closes the old terminal
#   only after the successor has read the briefs and the handoff.
# HARNESS_DRY_RUN=1 prints the terminal command (with the prompt) and starts nothing.
# Config: COMMON_BRIEF, WORKER_SETTINGS, WORKER_MCP; optional WORKER_CLAUDE_FLAGS (word-split).
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
harness_load_config
require COMMON_BRIEF WORKER_SETTINGS WORKER_MCP
keep_old=
[ "${HARNESS_KEEP_OLD:-}" != 1 ] || keep_old=1
if [ "${1:-}" = --keep-old ]; then keep_old=1; shift; fi
[ $# -ge 4 ] || die "usage: worker-restart.sh [--keep-old] <handoff.md> <model> <effort> <brief.md> [more briefs...]"
handoff=$1 model=$2 effort=$3; shift 3
[[ $model =~ ^[a-z0-9.-]+$ && $effort =~ ^[a-z]+$ ]] || die "model or effort has unexpected characters"
: "${SUPERSET_WORKSPACE_ID:?not in a Superset terminal}" "${SUPERSET_TERMINAL_ID:?not in a Superset terminal}"
is_uuid "$SUPERSET_WORKSPACE_ID" || die "SUPERSET_WORKSPACE_ID is not a UUID: $SUPERSET_WORKSPACE_ID"
is_uuid "$SUPERSET_TERMINAL_ID" || die "SUPERSET_TERMINAL_ID is not a UUID: $SUPERSET_TERMINAL_ID"
# Absolute paths: the successor terminal does not start in this cwd by default.
abs() { [ -f "$1" ] || die "missing file: $1"; printf '%s/%s' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"; }
# One assignment per line: a multiple assignment's status is only its last substitution's.
handoff=$(abs "$handoff")
if grep -qiE '^Keep old session: *yes' "$handoff"; then keep_old=1; fi
common=$(abs "$COMMON_BRIEF")
settings=$(abs "$WORKER_SETTINGS")
mcp=$(abs "$WORKER_MCP")
briefs=$common
for b in "$@"; do p=$(abs "$b"); briefs="$briefs, $p"; done
# The close step comes last: a successor that closes first never reads "keep the old session".
prompt="Read and follow $briefs and your handoff $handoff. Do not run anything else before you have read them."
if [ -n "$keep_old" ]; then
  prompt="$prompt Your previous session stays open: do not close it."
else
  prompt="$prompt Then, unless the handoff says \"Keep old session: yes\", close your previous session with exactly: superset terminals close --local --workspace $SUPERSET_WORKSPACE_ID --terminal $SUPERSET_TERMINAL_ID ."
fi
prompt="$prompt Continue from the handoff Next steps. Keep context lean."
# Every word is shell-quoted: paths and the prompt may hold spaces or quotes.
read -r -a extra <<<"${WORKER_CLAUDE_FLAGS:-}"
# Start at the worktree root: from a subdirectory Claude asks to allow the CLAUDE.md import of the
# root AGENTS.md, and the unattended successor hangs on that prompt.
cwd=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cmd=$(printf '%q ' claude --dangerously-skip-permissions --mcp-config "$mcp" --strict-mcp-config \
  --settings "$settings" ${extra[@]+"${extra[@]}"} --model "$model" --effort "$effort" "$prompt")
if [ -n "${HARNESS_DRY_RUN:-}" ]; then echo "DRY RUN: superset terminals create --local --workspace $SUPERSET_WORKSPACE_ID --cwd $cwd --command $cmd"; exit 0; fi
superset terminals create --local --workspace "$SUPERSET_WORKSPACE_ID" --cwd "$cwd" --command "$cmd"
