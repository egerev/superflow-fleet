# <Project> orchestrator: state now
<!-- Self-contained, at most 60 lines and 8 KB (harness orchestration.md, STATE.md; orchestrator-check.sh
     warns above). The SessionStart hook prints only its first 80 lines in the orchestrator's session.
     Rewrite it after every step; move finished items to archive/, journal lines to archive/journal.md
     with core/bin/state-note.sh. A restart must not need the archive to understand it. -->
Orchestrator: <session name> (since <date time UTC>). Model <model> <effort>.
Keep old session: <no|yes> (yes = the previous orchestrator has live subagents; the successor closes nothing and resets this to no)
Wake automations: <name | schedule | purpose; or "none"> (from modules/superset/bin/wake.sh list plus the purpose; they survive a restart; wake.sh rm <slug> when the wait ends)

## Standing owner decisions
- <decision, scope, expiry; verbatim quotes in DECISIONS.md D<n>>

## APPROVED WAVE
<!-- An owner-approved wave or plan, or a PLAN block (modules/tiden/tiden.md (tiden module), Planning an ask), stays here until each item is dispatched or the owner cancels it. -->
- <card or goal, limits, owner words (DECISIONS.md D<n>)>
- PLAN <epic>: wave 1 <stories>; wave 2 <stories>; <D<n> if any>

## Production
- <live version, deploy state, release freeze, windows>

## Live facts
- <tool versions, quirks found this week, other orchestrators' directories (not mine)>

## Live workers (names change on self-restart; ListAgents)
| Worker (workspace name) | Model | Task | Next |
|---|---|---|---|
| <name (workspace id)> | <model effort> | <task> | <next event> |

## WAITING ON OWNER (next id: q<n>; ids never reused, they are the owner page's article ids)
- q1. <posted YYYY-MM-DD HH:MM UTC>; <kind: product | user-data | money | publish | hands | incident>. <question: what / why / cost / options / recommendation>

## DECIDED BY AGENTS (14 days; next id: r<n>; ids never reused, reversible by the owner)
- r1. <YYYY-MM-DD>; <what>; gate: <which>; undo: <how>

## NOW
- <what is in flight>

## NEXT
1. <next dispatch or step; if it waits: "waits on q<n>", "after PR #<n>">
