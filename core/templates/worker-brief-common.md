## Common rules (all <PROJECT> workers)
<!-- Copy to the orchestrator's briefs/common.md and fill <...>. Repository rules: harness process.md (loaded by the SessionStart
     hook) + the project's AGENTS.md. Parallel-work rules: harness orchestration.md. -->
- AGENTS.md and harness process.md are the rulebook (auto-loaded; do not re-read them). This file adds only session facts.
- The orchestrator is the Claude session named in your start prompt or in its latest message; reply to its `from`
  address with SendMessage. Reports in English. The owner is not watching your terminal. Never fix another project's
  repository; a finding for its copy goes to your orchestrator (orchestration.md, Cross-project).
- Events only (question that leaves scope, BLOCKED, DONE). Never poll; wait with one background command. That wait must
  also end on failure (a failed required check, dequeue, closed PR) and on a time limit (merge wait: 60 min), never only on
  success: `gh pr merge --auto` stays armed on a PR whose checks failed, so a merged-only wait never ends.
- Background jobs: every long job (Codex review, backup, CI wait) is (a) checked once ~30 s after start that it really runs
  (log has progress, no "Not inside a trusted directory"/usage error), (b) bounded by `timeout`, and (c) read for its exit
  status/report when it ends; a missing report = failed, not "still running". This is one check, not polling.
- A blocking/major finding fixed after the round cap: run one scoped recheck on Sol (harness reviews.md, Rounds 5; no new round
  needed for that). Never merge with it unconfirmed. If that recheck still finds a blocking: BLOCKED to the orchestrator.
- Tokens: batch independent commands/reads into one call or one parallel tool round; read file ranges, not whole files; no
  re-reads of what you already hold. Two or more independent reads go out in ONE tool round; three single read-only calls
  in a row are a mistake.
- Host load: locally run ONLY the test modules your change touches and the new tests; never a full suite (CI runs it). One
  local run at a time; stop your test DB container right after your last local run. Stop only your own processes by PID
  (kill <pid>); never pkill/killall by pattern (other workers share the user).
- Subagents: search/exploration runs with model sonnet; reviews (r1 and rechecks) keep the model reviews.md
  names (Routing; Rounds 4, 5). Put `Model: <model> <effort>` in every PR description (quality metrics).
- Skills: load the matching skill before writing tests (harness skills.md). Astra and Fable remain the reviews: do not add
  /code-review or /security-review on top of them. Name used skills in the DONE block.
- Final message: a `SUPERSET_WORKER_DONE` or `SUPERSET_WORKER_BLOCKED` block with task, summary, files, checks;
  DONE adds handoff (squash SHA, what the owner should know, how to undo), BLOCKED adds reason and needs.
- Context near 170k (owner 10-21; orchestrator stays 250k): at the next natural boundary write a handoff of at most 40 lines
  in the format of `<orchestrator dir>/handoffs/TEMPLATE.md` (harness core/templates/handoff.md) to
  `<orchestrator dir>/handoffs/<workspace-name>.md`, then restart YOURSELF: wait for your own background jobs (reviews!) to
  finish first, since closing your terminal kills them; then run `<orchestrator dir>/bin/worker-restart.sh <handoff>
  <opus|sonnet> <medium|high> <your task brief> [<extra common brief>]` with your current model/effort and the briefs from
  your start prompt. The new session closes your terminal after it has read the handoff (with live subagents write `Keep old session: yes` in the handoff and pass `--keep-old`). Send the orchestrator one line `RESTARTED <handoff path>` (no
  action needed from it) and stop. Exceptions: do not restart when about 30 calls or fewer remain (only merge, B wait,
  read-back, DONE): finish instead. Restart early, from 150k, before an expected idle of over an hour (owner gate, usage
  limit, overnight wait). The handoff lists files and line ranges already read and decisions taken, so the new session
  does not re-explore.
- Test containers: start every one with `docker run --rm ...` (or `docker create --rm`), so `docker stop <name>`
  alone removes it. Name it without hyphens (`<proj>_pg_<slug>`): on a line with `rm` or `--rm`, dcg's rm-force rule reads
  any hyphen token with an f in its leading letters (a name segment like hyphen-fix474, `--platform`, `--tmpfs`,
  `test-fixtures`) as the force flag and blocks the line, a `docker rm` included; avoid those tokens and `$VAR`/`$(...)` on
  that line. If a project script starts one without `--rm` or with a hyphenated name, say so in DONE. When you
  finish, list yours with `docker ps -a` and stop each, one command per container. Never `rm -f`, `prune`, or a container you did not start. A container left stopped
  is the owner's `docker rm`: name it in DONE.
- A red main push run: never `gh run rerun --failed` (harness orchestration.md, Merging). Use one full `gh run rerun <id>`.
  If it is still red outside your code, report DONE with the run link; a later green main SHA carries your code.
- Standing approvals in force are quoted in your brief with their conditions and expiry; nothing else is one.
- Reviews: round cap, scoped rechecks, severity rubric, routing, the Codex line and `-c service_tier="default"` on every
  Codex run are in harness reviews.md (the project's points and line: <project review notes>); read the section you need.
- Feature enablement (owner 10-19: "Enable new features by default. Do not route this through me."): a feature from
  a ready card the owner asked for ships enabled. After its merge AND deploy, the agent that built it (or an ops worker) applies the
  production enable itself: operation opt-in, action grant to existing owner/agent principals, config flag. No owner
  question. Report it in DONE with the exact commands and the undo. Cleanup/deletions and migration apply INSIDE a
  task are the agent's (fresh verified backup first; follow the project's production document). Still the
  owner's: new secrets or credentials, and irreversible steps outside a task. Never deploy or restart a live service
  during a live activity the project names: check read-only first and wait for it to end.
- Owner questions (owner 10-20): ask the owner (through the orchestrator) only product direction, money, secrets/new
  credentials, data deletion, irreversible steps and accepting risk. DB grants and schema of an owner-asked card,
  release steps and other technical approvals go to the reviewers of the level (Astra for access/data); the owner gets
  the summary in DONE. Manual releases: the project's standing manual-release approval.
- Owner-requested settings (owner 10-21): when the owner asks for a reversible prod setting (enable/disable a connection,
  flag, grant) that needs no code, do it as one ops step: read-only pre-check, quick backup if it touches a DB, apply,
  verify, receipt with undo. No card, no PR, no plan review round. This includes issuing, extending or revoking a key
  and one non-secret config line (owner 10-23): back up the files, apply, verify with one real read request (never a
  listed live action); rollback is a few manual lines. No scripts beyond the step; Astra only when code changes or other
  principals are touched. Its estimate is 30 min, so the time box below stops it at 60. A brief that asks for more
  does not override this rule: say so and follow the rule.
- Time box (owner 10-23): an ops task past twice its estimate stops at a safe point and reports BLOCKED with what is
  slow, instead of another review round.
- A defect found on the way (wrong doc, host drift, missing reload) goes into your DONE/BLOCKED at once as a card
  candidate, even when it is out of scope.
- Messages: harness core/templates/messages.md (question, DONE, BLOCKED, RESTARTED, RELEASE APPLIED). Owner decisions
  are kept verbatim in `<orchestrator dir>/DECISIONS.md`; act on an entry your brief or the orchestrator names by number
  (D<n>), within its written scope.
- Merge wait: `<orchestrator dir>/bin/wait-merge.sh <pr> 60 --main` as one background job (exit 0 merged and main green;
  other codes in the script header). A hand-written merge wait reads `isInMergeQueue` (or `mergeQueueEntry.state`),
  never `autoMergeRequest` alone: it reads null once the PR is queued, a false "dequeued". A queue exit whose latest
  `RemovedFromMergeQueueEvent` reason is `merged` is a merge: `state` reads MERGED a moment later (`core/bin/wait-merge.sh`
  reads all three). Codex reviews: `<orchestrator dir>/bin/review-codex.sh <astra|sol> <task> <report>`.

## Project facts
<!-- Required; modules/superset/bin/orchestrator-check.sh fails while a <...> placeholder is left in this file. -->
- Test database: <how to start a disposable one, its DSN rule, who removes it>
- Deploy and production: <promotion command or "auto-deploy">, <host access rule>
- Busy lanes: <paths held by other workers' open PRs, or "see the task brief">
- Local tool quirks: <dcg, Tiden output, other CLIs>
- Product-work flow: <append modules/tiden/worker-brief-product.md, or name the project's own>

