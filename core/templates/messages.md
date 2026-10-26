# Messages between workers and the orchestrator

<!-- Generic protocol; the common worker brief (worker-brief-common.md) points here. Messages go by
     SendMessage to the orchestrator named in the start prompt or its latest message. Events only:
     no status pings, no "ok/noted" replies. -->

| Message | Sent by | When | Format | Receiver does |
|---|---|---|---|---|
| Question | worker | before leaving its scope (another task's files, process.md section 2, the card's criteria, a fork without an obvious answer) | one message: the question, options, recommendation | answers in one message; an owner question goes to the owner (what / why / cost / options / recommendation) and the answer to DECISIONS.md |
| `SUPERSET_WORKER_DONE` | worker | task finished | block: task, summary, files, checks, handoff (squash SHA, what the owner should know, how to undo), skills used | checks the worktree is clean and test containers are gone, closes the terminal, archives the workspace, updates STATE.md |
| `SUPERSET_WORKER_BLOCKED` | worker | cannot continue inside its scope | block: task, summary, files, checks, reason, needs | unblocks or asks the owner; never answers in the worker's input box |
| `RESTARTED <handoff path>` | worker | after `modules/superset/bin/worker-restart.sh`, before it stops | one line | nothing (the successor reports from the same workspace); updates the worker's name in STATE.md |
| `RELEASE APPLIED <sha>` | release worker | a production release finished | one line plus receipt path | lifts the merge freeze |
| New orchestrator address | successor orchestrator | first step after `modules/superset/bin/orchestrator-restart.sh` | one line: its name | workers reply to the new name from then on |
| `resume` | orchestrator | a worker went idle after an API or network error | one word plus the step to continue | the worker continues from its last step |

Block format (the last message of a worker):

```
SUPERSET_WORKER_DONE
task: <brief name>
summary: <2-5 lines>
files: <changed files or PR link>
checks: <tests, CI run, review verdicts>
handoff: <squash SHA; what the owner should know; how to undo>
skills: <skills loaded, or none>
```

`SUPERSET_WORKER_BLOCKED` keeps task, summary, files and checks and replaces handoff with
`reason:` and `needs:`.
