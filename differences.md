# Project differences

The harness is one process for every project. Where a project differs, the difference is listed
here until the project adopts the harness rule or the owner records an override. Status: `open`
(no decision yet), `override` (an `Override:` line in the project's `AGENTS.md`), `project fact`
(the difference stays) or `aligned`.

Keep one table per project. The rows below are synthetic examples.

## Example project (owner/example), as of YYYY-MM-DD

| # | Harness | Example project today | Status |
|---|---|---|---|
| 1 | Merge queue in the ruleset (core/templates/main-ruleset.json) | Personal repository without a merge queue; pre-push guard instead | project fact |
| 2 | Tiden first steps and `Spec:` lines (process.md section 4, tiden.md) | No Tiden product; the task brief or BACKLOG.md item is the spec | project fact (module tiden not enabled) |
| 3 | Production through a promotion tool from a green `main` SHA | Hosting auto-deploys `main`; no backup gate yet | project fact |
