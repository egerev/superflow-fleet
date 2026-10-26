#!/usr/bin/env bash
# SessionStart hook for every project: in an orchestrator's session, re-inject that project's
# state after startup, resume, clear or compaction; silent in every other session.
# An orchestrator directory is any $HARNESS_ORCH_GLOB match (default ~/*-orchestrator) whose
# active-cwd file holds the orchestrator's worktree path. Prints the directory's
# orchestrator-facts.md path and its STATE.md. Never fails the session: every error is silent.
# A second session there (a wake relay, a kept old orchestrator: <dir>/orch-terminal names another live
# terminal) gets one line instead, so a relay turn does not load STATE.md (orchestration.md, Wake-ups).
# settings.json: {"type":"command","command":"<harness-exec.sh> core/hooks/session-start.sh","timeout":10}
cwd=$(jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -n "$cwd" ] || exit 0
cwd=$(cd "$cwd" 2>/dev/null && pwd -P) || exit 0
for dir in ${HARNESS_ORCH_GLOB:-$HOME/*-orchestrator}; do
  [ -f "$dir/active-cwd" ] && [ -f "$dir/STATE.md" ] || continue
  active=$(head -n 1 "$dir/active-cwd")
  active=$(cd "$active" 2>/dev/null && pwd -P) || continue
  [ "$cwd" = "$active" ] || continue
  project=$(basename "$dir"); project=${project%-orchestrator}
  rec=$(head -n 1 "$dir/orch-terminal" 2>/dev/null)
  if [ -n "$rec" ] && [ -n "${SUPERSET_TERMINAL_ID:-}" ] && [ "$rec" != "$SUPERSET_TERMINAL_ID" ] \
     && to=$(command -v timeout || command -v gtimeout) \
     && "$to" 5 superset terminals list --local --workspace "${SUPERSET_WORKSPACE_ID:-}" --json 2>/dev/null \
        | jq -e --arg t "$rec" '.sessions[] | select(.terminalId==$t and .exited==false)' >/dev/null 2>&1; then
    echo "Not the recorded $project orchestrator terminal ($dir/orch-terminal). A WAKE RELAY or a kept old orchestrator ignores this; only a new orchestrator started by hand runs $dir/bin/wake.sh target, then reads $dir/STATE.md."
    exit 0
  fi
  cat <<EOF
ORCHESTRATOR SESSION: $project. Read $dir/orchestrator-facts.md (project facts, short) once. AGENTS.md,
CLAUDE.md and harness process.md are already loaded: do not re-read them; read process docs only by
section when a step needs it (harness orchestration.md, Orchestrator); never read an archive on start.
Run ListAgents and list only this project's workspaces; then continue from NOW/NEXT below.
Keep $dir/STATE.md current (self-contained, ~60 lines). Current state:

EOF
  cat "$dir/STATE.md"
  exit 0
done
exit 0
