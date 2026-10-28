# <Project> agent rules

Process: harness egerev/superflow-fleet @ <version>, ~/agent-harness; this file adds project rules.
Claude Code loads harness core/process.md and the addendum of each module below through the SessionStart
hook (merged `origin/main`, else the pinned copy). Codex and cloud agents read the pinned copy docs/harness/core/process.md and the module addenda first. If no
harness text is in context, stop and report BLOCKED.

Harness modules: <superset, tiden, or none>

Harness values: ruleset `<ruleset file>`; required checks `<required checks>`; CI check IDs
`<check IDs that must not change>`; deploy command `<deploy command>` (promotion tool
`<tool>`, production doc `<path>`, backup gate `<where>`); security document `<path>`;
data-policy document `<path>` (from harness core/templates/DATA-POLICY.md; owner item 2 asks only what it
does not cover); money cap `Budget: <EUR n/month | unset>` (owner `<D-entry>`; item 3); Tiden
product `<product id>`, workspace `<workspace id>`, spec prefix `<PREFIX>`; unlinked-tests list
`<path>`; Tiden CI document `<path>` (and whether `Tiden health` runs); queue share rules
`<path>`; Effort reference PRs and platform built-ins `<path>`; Fable prompt `<path>`; critical
paths `<paths that new code must not break or silence>`; deployed consumers `<what question 3
checks>`; live actions `<sends, calls, sessions, ...>`; live activity `<e.g. an active call>`;
Codex line `<pace + offset (90), or n a day + offset>`; review notes `<path>` (Codex line, change-path grep); lanes
`<path>`; orchestrator directory, decision log, STATE.md and start command `<paths>`; word budget
`<n>`.

Override: <harness section> — <what this project does instead and why> (also in your differences list: the overlay's differences.md, or this file when you keep no overlay)

## Project rules
- <production, migrations, secrets, services, live providers, lanes>
- <backups: where, how often, over which network path>

<!-- Loader: copy core/templates/harness-hook.sh to .claude/hooks/harness.sh and core/ and the enabled modules/<m>/
     (markdown and templates) and VERSION to docs/harness/ (same relative paths) (a merged harness version; refresh by pull request).
     .claude/settings.json, merge into "hooks":
{"SessionStart":[{"hooks":[{"type":"command","command":"sh \"$CLAUDE_PROJECT_DIR/.claude/hooks/harness.sh\""}]}]}
-->
