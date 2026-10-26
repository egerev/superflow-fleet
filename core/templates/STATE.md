# <Project> orchestrator: state now
<!-- Self-contained, at most ~60 lines (harness orchestration.md, STATE.md). The SessionStart hook
     prints this file in the orchestrator's session. Rewrite it after every step; move finished
     items to archive/. A restart must not need the archive to understand it. -->
Orchestrator: <session name> (since <date time UTC>). Model <model> <effort>.
Keep old session: <no|yes> (yes = the previous orchestrator has live subagents; the successor closes nothing and resets this to no)
Wake automations: <name | schedule | purpose; or "none"> (from modules/superset/bin/wake.sh list plus the purpose; they survive a restart; wake.sh rm <slug> when the wait ends)

## Standing owner decisions
- <decision, scope, expiry; verbatim quotes in DECISIONS.md D<n>>

## APPROVED WAVE
<!-- An owner-approved wave or plan, or a PLAN block (tiden.md, Planning an ask), stays here until each item is dispatched or the owner cancels it. -->
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
- q1. <question: what / why / cost / options / recommendation>

## NOW
- <what is in flight>

## NEXT
1. <next dispatch or step>
