#!/usr/bin/env bash
# Worker self-restart: start a fresh session in this Superset workspace from a handoff; the new
# session closes this terminal once it has read the handoff and briefs (orchestration.md, Sessions).
# Usage: worker-restart.sh [--keep-old] <handoff.md> <model> <effort> <brief.md> [more briefs...]
#   --keep-old (or HARNESS_KEEP_OLD=1, or a line "Keep old session: yes" in the handoff): the prompt has no
#   close step; use it when the old session has live subagents. Otherwise the prompt closes the old terminal
#   only after the successor has read the briefs and the handoff.
#   A brief that resolves to COMMON_BRIEF or to an earlier brief is listed once. When the handoff names
#   review-codex.sh or wait-merge.sh, the prompt carries that script's Usage and Exit header lines, so the
#   successor does not re-read the header.
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
# Symlinks are resolved (the file's own, then pwd -P), so one brief reached by two paths is one path
# (the dedupe below).
abs() {
  local f=$1 l
  [ -f "$f" ] || die "missing file: $1"
  while [ -L "$f" ]; do
    l=$(readlink "$f")
    # cd -P: a logical cd would fold "dirlink/../x" to the wrong directory.
    case $l in /*) f=$l ;; *) f=$(cd -P -- "$(dirname "$f")" && pwd)/$l ;; esac
  done
  printf '%s/%s' "$(cd -P -- "$(dirname "$f")" && pwd)" "$(basename "$f")"
}
# One assignment per line: a multiple assignment's status is only its last substitution's.
handoff=$(abs "$handoff")
if grep -qiE '^Keep old session: *yes' "$handoff"; then keep_old=1; fi
common=$(abs "$COMMON_BRIEF")
settings=$(abs "$WORKER_SETTINGS")
mcp=$(abs "$WORKER_MCP")
briefs=$common seen=$'\n'$common$'\n'
for b in "$@"; do
  p=$(abs "$b")
  case $seen in *$'\n'"$p"$'\n'*) continue ;; esac
  briefs="$briefs, $p" seen="$seen$p"$'\n'
done
# usage_of SCRIPT: its "# Usage:" header line, the indented "#   " lines after it and the first
# sentence of its "# Exit:" paragraph (the exit codes), on one line.
usage_of() {
  awk '/^# Usage:/ { u = 1; sub(/^# /, ""); out = $0; next }
       u == 1 && /^#   / { sub(/^# +/, ""); sub(/\.$/, ""); out = out "; " $0; next }
       u == 1 { u = 2 }
       u == 2 && /^# Exit:/ { u = 3 }
       u == 2 && !/^#/ { exit }
       u == 3 && /^# / { sub(/^# /, ""); x = (x == "" ? $0 : x " " $0)
                         if (match(x, /\. [A-Z]|\.$/)) { x = substr(x, 1, RSTART); exit }
                         next }
       u == 3 { exit }
       END { if (x != "") out = out "; " x; if (out != "") print out }' "$1"
}
here=$(dirname "$0")
usage=
for s in review-codex.sh wait-merge.sh; do
  grep -qF "$s" "$handoff" || continue
  # Flat tree: bin/ beside this script; exported tree: modules/superset/bin, the script in core/bin.
  for f in "$here/$s" "$here/../../../core/bin/$s"; do
    [ -f "$f" ] || continue
    u=$(usage_of "$f"); [ -z "$u" ] || usage="$usage ${u%.}."
    break
  done
done
# The close step comes last: a successor that closes first never reads "keep the old session".
prompt="Read and follow $briefs and your handoff $handoff. Do not run anything else before you have read them."
# The brief names no orchestrator (orchestration.md, Sessions, Orchestrator address): the prompt gives the current one.
if [ -s "$ORCH_DIR/orch-name" ]; then
  prompt="$prompt Your orchestrator is $(head -n 1 "$ORCH_DIR/orch-name") (its current name: cat $ORCH_DIR/orch-name)."
fi
[ -z "$usage" ] || prompt="$prompt Script usage (no need to read the headers):$usage"
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
