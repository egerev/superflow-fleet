# Module: superset

Superset is a desktop app and CLI that runs coding agents in parallel, one git worktree and terminal per
workspace (not Apache Superset). It provides the workspaces the harness assumes: one git worktree plus one terminal per
session, an agent preset per worker, and a CLI (`superset`) the scripts drive. This module holds
the scripts, templates and rules that use it. Enable it with `superset` in `Harness modules:` of
the project's AGENTS.md and in `HARNESS_MODULES` when you run `core/bin/new-orchestrator.sh`.

Without Superset, keep `core/` and replace the pieces below with your own (tmux windows or terminal
tabs plus `git worktree add` work): the rules in `core/orchestration.md` (restart, background jobs,
lanes) do not depend on it.

| Part | Does | Superset command it uses |
|---|---|---|
| `bin/worker-restart.sh [--keep-old] <handoff> <model> <effort> <brief>...` | A worker's self-restart: starts a successor from the handoff in the same workspace; the successor closes the old terminal after reading the handoff, unless `--keep-old` (or `Keep old session: yes` in the handoff) | `superset terminals create --local --workspace <id> --cwd <dir> --command <claude ...>`, `terminals close` (done by the successor) |
| `bin/orchestrator-restart.sh [--keep-old] <old name> [terminal]` | The orchestrator's self-restart in `ORCH_WORKSPACE_ID`; refuses a STATE.md older than `STATE_MAX_AGE_MIN`; terminal and workspace IDs must be UUIDs | `superset terminals create --local --workspace <id> --command <claude ...>` |
| `bin/watch.sh` | Zero-token watcher under Monitor: PR, check and workspace changes, stalled worker terminals | `superset workspaces list --local --project <id> --json`, `superset terminals read ... --json` |
| `bin/orchestrator-check.sh` | Read-only check of an orchestrator directory: config filled, files present, placeholders gone, tools installed | none (checks that `superset` exists) |
| `bin/owner-page.sh` | Publishes the digest and open owner questions as one Superset page per project (from `templates/owner-page.html`); with a new open question, a desktop notification | `superset pages`, `superset notifications show` |
| `templates/worker-settings.json` | Claude Code settings for the worker agent preset (`--settings`) | the preset is created in Superset |
| `templates/orchestrator-successor-prompt.md` | The prompt the restarted orchestrator receives | none |
| `orchestration-addendum.md` | Workspace rules: naming, the sweep that closes finished workspaces | `superset workspaces list` |
| `process-addendum.md` | Two lines the loader appends to `core/process.md`: where the workspace rules and commands are | none |

`config.sh` keys (core/templates/config.sh): `SUPERSET_PROJECT_ID`, `ORCH_WORKSPACE_ID`,
`WORKER_AGENT_ID`, `WORKTREES_DIR`, `WORKER_SETTINGS`, `WORKER_MCP`.

Commands the orchestrator uses (also in the orchestrator-facts template):

```sh
superset projects list --json
superset workspaces list --local --project <project id> --json | jq -r '.[] | select(.archivedAt==null) | "\(.id) \(.name)"'
superset workspaces create --local --project <project id> --name <type>-<slug> --branch <branch> \
  --skip-branch-prefix --base-branch main --agent <worker preset id> --model <model> --effort <effort> \
  --prompt "Read and follow <orchestrator dir>/briefs/common.md and <task brief>."
```

The `SUPERSET_WORKER_DONE` / `SUPERSET_WORKER_BLOCKED` blocks of `core/templates/messages.md` follow the envelope
of Superset's `orchestrate` skill. Read-only views that help an orchestrator: `superset snapshot --json` (every
workspace, its terminals and agent state in one call) and `superset terminals read`.

The restart scripts put the absolute paths of the handoff, briefs and STATE.md, the workspace and
terminal IDs into the successor's prompt; `worker-restart.sh` also passes the caller's cwd to Superset (`--cwd`). The
command-line flags above were checked against Superset CLI 1.39 (`superset schema` prints every command
and option as JSON); check it if a flag was renamed.
