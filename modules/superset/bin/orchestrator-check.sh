#!/usr/bin/env bash
# Read-only check of an orchestrator directory: config filled, files present, placeholders gone,
# tools installed, harness reachable. Prints one line per finding; exit 1 on any FAIL.
# Usage: <orchestrator dir>/bin/orchestrator-check.sh
set -uo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
harness_load_config
bad=0
fail() { echo "FAIL $*"; bad=1; }
warn() { echo "WARN $*"; }
for v in PROJECT REPO SUPERSET_PROJECT_ID ORCH_WORKSPACE_ID WORKER_AGENT_ID WORKTREES_DIR COMMON_BRIEF \
         WORKER_SETTINGS WORKER_MCP ORCH_MODEL ORCH_EFFORT CODEX_DAILY_POINTS; do
  val=${!v:-}
  if [ -z "$val" ]; then fail "config.sh: $v is empty"
  elif [[ $val == *'<'*'>'* ]]; then fail "config.sh: $v is still a placeholder ($val)"; fi
done
[[ ${CODEX_DAILY_POINTS:-pace} =~ ^(pace|[0-9]+([.][0-9]+)?)$ ]] \
  || fail "config.sh: CODEX_DAILY_POINTS must be pace or a number ($CODEX_DAILY_POINTS)"
[[ ${CODEX_LINE_OFFSET:-90} =~ ^[0-9]+([.][0-9]+)?$ ]] \
  || fail "config.sh: CODEX_LINE_OFFSET must be a number ($CODEX_LINE_OFFSET)"
for f in STATE.md DECISIONS.md orchestrator-facts.md handoffs/TEMPLATE.md; do
  [ -f "$ORCH_DIR/$f" ] || fail "missing $ORCH_DIR/$f"
done
for f in "${COMMON_BRIEF:-}" "${WORKER_SETTINGS:-}" "${WORKER_MCP:-}"; do
  [ -z "$f" ] || [ -f "$f" ] || fail "missing $f"
done
for f in "${WORKER_SETTINGS:-}" "${WORKER_MCP:-}"; do
  [ -f "$f" ] && ! jq -e . "$f" >/dev/null 2>&1 && fail "not valid JSON: $f"
done
# Placeholders the templates leave for the project (generic ones like <pr> or <model> stay).
if [ -f "${COMMON_BRIEF:-}" ]; then
  grep -nE '<(orchestrator dir|PROJECT|project review notes)>' "$COMMON_BRIEF" | sed "s|^|FAIL placeholder in $COMMON_BRIEF:|" | grep . && bad=1
  awk '/^## Project facts/{on=1; next} /^## /{on=0} on && /<[^>]+>/ && !/^<!--/' "$COMMON_BRIEF" \
    | sed "s|^|FAIL unfilled project fact: |" | grep . && bad=1
fi
for f in orchestrator-facts.md DECISIONS.md; do
  [ -f "$ORCH_DIR/$f" ] || continue
  n=$(grep -v '^ *<!--' "$ORCH_DIR/$f" | grep -cE '<[a-z][^>]*>' || true)
  [ "$n" = 0 ] || warn "$f: $n line(s) still hold <placeholders>"
done
if grep -q '^Wake automations:' "$ORCH_DIR/STATE.md" 2>/dev/null; then :
elif grep -q '^Wake crons:' "$ORCH_DIR/STATE.md" 2>/dev/null; then
  warn "STATE.md 'Wake crons:' is the old line: move the wakes to modules/superset/bin/wake.sh and rename it 'Wake automations:'"
else fail "STATE.md has no 'Wake automations:' line"; fi
if [ -f "$ORCH_DIR/orch-terminal" ] && is_uuid "${ORCH_WORKSPACE_ID:-}"; then
  t=$(head -n 1 "$ORCH_DIR/orch-terminal")
  superset terminals list --local --workspace "$ORCH_WORKSPACE_ID" --json 2>/dev/null \
    | jq -e --arg t "$t" '.sessions[] | select(.terminalId==$t and .exited==false)' >/dev/null 2>&1 \
    || warn "orch-terminal $t is not a live terminal of ORCH_WORKSPACE_ID: wakes are lost; run modules/superset/bin/wake.sh target in the orchestrator"
fi
[ ! -s "$ORCH_DIR/wake-lost.log" ] || warn "lost wakes in $ORCH_DIR/wake-lost.log (paused; modules/superset/bin/wake.sh target resumes them)"
for s in $(harness_link_scripts "$ORCH_DIR"); do
  warn "no bin/$s link: run  ln -sfn harness-exec.sh $ORCH_DIR/bin/$s  (orchestrator-restart.sh also adds it)"
done
if [ -f "$ORCH_DIR/active-cwd" ]; then
  a=$(head -n 1 "$ORCH_DIR/active-cwd"); [ -d "$a" ] || fail "active-cwd points to a missing directory: $a"
else
  warn "no active-cwd: the SessionStart hook and the 250k budget do not know the orchestrator's worktree yet"
fi
[ -z "${WORKTREES_DIR:-}" ] || [ -d "$WORKTREES_DIR" ] || warn "WORKTREES_DIR does not exist yet: $WORKTREES_DIR"
for c in git gh jq superset claude codex python3; do command -v "$c" >/dev/null 2>&1 || fail "tool missing: $c"; done
command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1 || fail "tool missing: timeout (coreutils)"
h=${HARNESS_DIR:-$HOME/agent-harness}
git -C "$h" rev-parse -q --verify origin/main >/dev/null 2>&1 || fail "harness checkout $h has no origin/main"
[ "$bad" = 0 ] && echo "OK: $ORCH_DIR"
exit "$bad"
