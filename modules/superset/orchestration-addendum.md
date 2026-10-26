# Superset: orchestration addendum

Workspace rules of the orchestrator (core/orchestration.md, Orchestrator) when workspaces are Superset workspaces.

- Workspaces: no tags on any workspace; the type lives in the workspace name (`code-…`,
  `research-…`, `ops-…`, `process-…`).
- Workspace sweep (owner 10-22): after each merge and on every start or restart, list your
  project's workspaces (`superset workspaces list --local --project <superset project id>`) and
  close every one of yours with no open task: PR merged or closed with no step after the merge left (core/orchestration.md, After a worker's DONE),
  superseded, a finished research or mockup, an old session workspace. Look at a worktree before
  archiving (uncommitted work is lost). Never close another orchestrator's or a peer project's
  workspace.
