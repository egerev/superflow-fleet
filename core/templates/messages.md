# Messages between workers and the orchestrator

<!-- Generic protocol; the common worker brief (worker-brief-common.md) points here. Messages go by
     SendMessage to the orchestrator named in the start prompt or its latest message (current name:
     `cat <orchestrator dir>/orch-name`; orchestration.md, Sessions, Orchestrator address). Events only:
     no status pings, no "ok/noted" replies. -->

| Message | Sent by | When | Format | Receiver does |
|---|---|---|---|---|
| Question | worker | before leaving its scope (another task's files, process.md section 2, the card's criteria, a fork without an obvious answer), and for any yes/no go-ahead such as an `over-cap` review round (reviews.md, Rounds 5) | one message: the question, options, recommendation | answers in one message; an owner question goes to the owner only when it is one of the five kinds of process.md section 2 or an incident (what / why / cost / options / recommendation; the orchestrator adds its kind, orchestration.md, Owner asks), in the next digest, and the answer to DECISIONS.md; anything else the orchestrator decides; a section 2 gate step, process text, a card deletion or weakening, or a GUI or ops step on a live service also gets a "Decided by agents" line with its undo (orchestration.md, Decided by agents) |
| `SUPERSET_WORKER_DONE` | worker | task finished | block: task, summary, files, checks, handoff (squash SHA, what the owner should know, how to undo), card moves made or due with their evidence, skills used | checks the worktree is clean and test containers are gone, closes the terminal, archives the workspace, updates STATE.md |
| `SUPERSET_WORKER_BLOCKED` | worker | cannot continue inside its scope (also a review finding still open after the last round allowed, reviews.md, Rounds 5); never for a yes/no go-ahead (a Question) or a step the rules already allow, such as the post-cap recheck | block: task, summary, files, checks, reason, needs | unblocks, or asks the owner only one of the five kinds (orchestration.md, Owner asks); never answers in the worker's input box |
| `RESTARTED <handoff path>` | worker | after `modules/superset/bin/worker-restart.sh`, before it stops | one line | nothing (the successor reports from the same workspace); updates the worker's name in STATE.md |
| `RELEASE APPLIED <sha>` | release worker | a production release finished | one line plus receipt path | lifts the merge freeze |
| New orchestrator address | successor orchestrator, to live workers only (peer orchestrators read `modules/superset/bin/boss-of.sh`) | after `boss-of.sh set`, first message after `modules/superset/bin/orchestrator-restart.sh` | one line: its name, then "No action needed if you already sent DONE" | workers reply to the new name from then on; a worker that already sent DONE sends nothing |
| `Hold <ETA or no ETA>` | orchestrator | a worker must wait (owner gate, usage limit, merge freeze, outage) | one line: the reason and a clock time or event, else `no ETA` | waits; above 150k with `no ETA` or an ETA over an hour away, restarts first (orchestration.md, Sessions, Restart) |
| FYI to a peer orchestrator | orchestrator | a version notice, a "no action needed" note, a harness-wide decision relay (orchestration.md, Wake-ups, Inbox) | one file `<peer orchestrator dir>/inbox/<YYYYMMDD-HHMM>-<from project>-<slug>.md`, never SendMessage (SendMessage only for an ask, a blocker or an answer; a decision that pauses or stops work is a blocker: file plus SendMessage) | reads it on its next real wake (hook and `INBOX n` list it), acts, moves it to `archive/inbox/` |
| `GUI CLAIM <app or window\|foreground> <cua session>` / `GUI FREE <app or window\|foreground>` | worker | before its `start_session` (or its foreground input) on that app or window / right after its `end_session` (or the foreground input) (worker brief, GUI steps) | one line | grants or refuses against `gui-claims.tsv` and updates it (orchestration.md, Live checks); FREE needs no reply |
| `resume` | orchestrator | a worker went idle after an API or network error | one word plus the step to continue | the worker continues from its last step |

Block format (the last message of a worker):

```
SUPERSET_WORKER_DONE
task: <brief name>
summary: <2-5 lines>
files: <changed files or PR link>
checks: <tests, CI run, review verdicts>
handoff: <squash SHA; what the owner should know; how to undo>
moves: <card: from -> to, evidence (run id, test ids or evidence link), made or due; or none>
skills: <skills loaded, or none>
```

`SUPERSET_WORKER_BLOCKED` keeps task, summary, files and checks and replaces handoff with
`reason:` and `needs:`.
