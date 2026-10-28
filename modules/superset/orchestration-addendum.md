# Superset: orchestration addendum

Workspace rules of the orchestrator (core/orchestration.md, Orchestrator) when workspaces are Superset workspaces.

- Workspaces: no tags on any workspace; the type lives in the workspace name (`code-…`,
  `research-…`, `ops-…`, `process-…`).
- Workspace sweep (owner 10-22): after each merge and on every start, restart or wake-up, run
  `modules/superset/bin/orchestrator-check.sh` and act on each line: `STALE-WS` names a workspace with no open PR and
  a merged or closed one (close it if it is yours and no step after the merge is left), `IDLE-FLEET`
  means no live worker while NEXT holds an item that names no wait (dispatch), `PIN-LAG n` a
  docs/harness pin n versions behind (refresh it: a worker runs `core/bin/pin-refresh.sh -C <its checkout>
  v<version>`; README, Pinned copy), `BRIEF-NO-SENDMESSAGE` a brief that has workers
  report in a terminal (fix the brief), `INBOX n` unread peer FYIs (Wake-ups, Inbox). A failed read prints `NOT CHECKED`, never a finding: do that
  part by hand. Then list your project's workspaces (`superset workspaces list --local --project
  <superset project id>`) and close every one of yours with no open task: PR merged or closed with
  no step after the merge left (core/orchestration.md, After a worker's DONE), superseded, a finished research or mockup, an old session
  workspace. Look at a worktree before archiving (uncommitted work is lost). Never close another
  orchestrator's or a peer project's workspace.
