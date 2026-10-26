# Handoff: <workspace name> — <task>, <date time UTC>

Context: <N>k tokens. Brief: <path>. Branch: <branch>. PR: #<n> (<state>). Worktree: <path>.
Keep old session: <no|yes> (yes = the old session has live subagents; the successor closes nothing; the script reads this line)

## State
- <what is done, with SHAs, PR numbers, CI run IDs and verdict lines>
- <what is in flight: a background command, a review, a queue entry, and how it reports back>

## Next steps
1. <the next concrete action, with the command>
2. <...>

## Open findings
- <reviewer, severity, file:line, one line; or "none">

## Paths
- Packet: <scratchpad path>
- Reports: <paths>
- Other: <files the next session must read, at most five>

## Do not
- <traps already hit: commands that hang, files busy in other PRs, decisions already made>
