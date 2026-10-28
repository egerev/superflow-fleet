# <Project> orchestrator: facts

<!-- Kept in the orchestrator directory (never on the Desktop). Only facts the repository and the
     harness do not hold; rules live in harness orchestration.md and the project's AGENTS.md.
     The SessionStart hook (core/hooks/session-start.sh) points the orchestrator here on every start. -->
Read on start together with STATE.md (printed by the SessionStart hook). Decisions: DECISIONS.md.
Plan, follow-ups and session notes: <log file> (read on demand, never on start). Never read archive/ on start.

## Superset
- Project `<superset project id>`; orchestrator workspace `<orchestrator workspace id>` (restart:
  `modules/superset/bin/orchestrator-restart.sh [--keep-old] <old name>`, a new terminal in this workspace).
- New worker (forecast first, orchestration.md, Estimates): `superset workspaces create --local --project <superset project id> --name <type>-<slug>
  --branch <branch> --skip-branch-prefix --base-branch main --agent <worker agent preset id>
  --model <model> --effort <effort> --prompt "Read and follow <orchestrator dir>/briefs/common.md and <task brief>. Your orchestrator is <your session name>."` (the name
  filled in at each dispatch, never once in this file: it changes on every restart)
  Briefs via the Write tool. `--agent claude` only for a worker that needs tools the preset turns off.
- Hosts: `<none | name, ssh-target, machineId>`; this project's orchestrator and workers run there (orchestration.md, Hosts).
- List this project only: `superset workspaces list --local --project <superset project id> --json | jq -r '.[] | select(.archivedAt==null) | "\(.id) \(.name)"'`.
- Worker preset `<worker agent preset id>`: `--settings <WORKER_SETTINGS> --mcp-config <WORKER_MCP> --strict-mcp-config`.

## Repository and production
- Repository `<owner/name>`; required checks `<names>`; merge queue `<yes/no>`; ruleset `<file or "none: pre-push guard">`.
- Production: `<host, access (read-only unless the owner says yes), stacks or services>`; deploy `<command>`.
- Test database and other local services: `<how, and who removes containers>`.
- Estimate: `<estimate data dir>` (optional; turns on orchestration.md, Estimates; omit the line to opt out).

## Reviews and cost
- Budget: `<EUR n/month | unset>` without asking, monthly-cancellable spend only (owner `<D-entry>`; for example
  EUR 50/month). Spend above it, any annual payment and any hardware: owner item 3 (process.md
  section 2); unset or still a placeholder: any spend is the owner's. Copy it into AGENTS.md Harness values too.
- Codex: `CODEX_DAILY_POINTS` (`pace` or points) plus `CODEX_LINE_OFFSET` in config.sh on the shared meter (`core/bin/codex-meter.sh`); reviewer routing exceptions: `<none or list>`.
- Owner talk: `<language>`; capacity `<n workers in parallel>`; host cap `<n>`.

## Tool quirks
- <for example: dcg allowlist installed (agents remove their own temp files and test containers); false positives
  (README, Requirements); Tiden output only as --format json + jq; codex needs </dev/null>
