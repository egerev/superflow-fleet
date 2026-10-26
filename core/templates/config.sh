# shellcheck shell=bash disable=SC2034
# Project config for the agent-harness scripts and hooks; kept as <orchestrator dir>/config.sh.
# Plain KEY=value lines only, values with spaces, $ or <...> in double quotes: the hooks read
# them without a shell ($HOME, ~ and $ORCH_DIR expand).
# ORCH_DIR is set to this file's directory before it is read. No secrets, tokens or keys here.
# Fill every <placeholder>; modules/superset/bin/orchestrator-check.sh lists the ones left.

PROJECT="<project>"                          # short name, as in ~/<project>-orchestrator
REPO="<owner/name>"                          # GitHub repository
MAIN_BRANCH=main

# Superset (superset projects list --json; superset workspaces list --local --json)
SUPERSET_PROJECT_ID="<superset project id>"
ORCH_WORKSPACE_ID="<orchestrator workspace id>"   # restarts stay in this workspace
WORKER_AGENT_ID="<worker agent preset id>"        # superset workspaces create --agent <id>
WORKTREES_DIR="$HOME/.superset/worktrees/<project>"   # workers' worktrees: worker context budget

# Briefs and worker session files (modules/superset/templates/worker-settings.json, core/templates/worker-mcp.json)
COMMON_BRIEF="$ORCH_DIR/briefs/common.md"
WORKER_SETTINGS="$HOME/.claude/agent-worker-settings.json"
WORKER_MCP="$HOME/.claude/agent-worker-mcp.json"
WORKER_CLAUDE_FLAGS=                       # extra claude flags for restarted workers (word-split)

# Orchestrator restarts (modules/superset/bin/orchestrator-restart.sh)
ORCH_MODEL=opus
ORCH_EFFORT=medium
ORCH_CLAUDE_FLAGS=
ORCH_SUCCESSOR_PROMPT=                     # empty: harness modules/superset/templates/orchestrator-successor-prompt.md
STATE_MAX_AGE_MIN=30
WAKE_AGENT=                                # empty: claude (Superset agent preset each wake relay runs; a preset with a cheaper model cuts its cost)

# Context budgets (core/hooks/context-size.py; orchestration.md, Sessions)
ORCH_CONTEXT_LIMIT=250000
WORKER_CONTEXT_LIMIT=170000

# Reviews (core/bin/review-codex.sh, core/bin/codex-meter.sh; reviews.md, Codex budget)
CODEX_DAILY_POINTS=pace                      # pace: whole shared meter, 100% over its window, + offset; <n>: points line
CODEX_LINE_OFFSET=90                         # add-on to either line: with the pace line the gate fires only above 90% in a fresh window (owner 10-24; the line only guards a nearly used-up meter at a window start)
CODEX_ASTRA_MODEL=gpt-6-astra
CODEX_SOL_MODEL=gpt-6.1-sol
CODEX_SOL_EFFORT=xhigh
CODEX_SANDBOX=read-only
REVIEW_TIMEOUT_MIN=60

# Merging (core/bin/wait-merge.sh) and main protection (core/bin/main-ruleset.sh, run by the owner)
MERGE_WAIT_MIN=60
WAIT_INTERVAL_S=30
RULESET_JSON=deploy/main-ruleset.json      # repository path (core/templates/main-ruleset.json)
PROTECTION_JSON=                           # repository path of classic protection, if any

# Watcher (modules/superset/bin/watch.sh under Monitor)
STALL_MIN=30
WATCH_INTERVAL_S=120
