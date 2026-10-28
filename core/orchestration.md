# Orchestration

Several agent sessions work at once: one orchestrator per project and its workers. Worker rules
that every brief carries are in core/templates/worker-brief-common.md; this file holds the parallel-work
rules a repository relies on and the orchestrator's own rules. The project names its lanes, its
merge queue facts and its tool IDs (workspace project, presets, hosts).

## Lanes

A lane never has more concurrent pull requests than its limit; where two are allowed, their
files must not overlap. Before starting, compare your planned paths with the changed paths of
open pull requests (`gh pr list`, `gh pr diff <n> --name-only`) and the files your brief marks
busy. A task that needs two lanes holds both; prefer splitting it. The project's lane table names
the paths and limits; a lane exists where single large functions, numbered files or files that
affect every pull request make parallel edits collide.

## Merging

- Enqueue with `gh pr merge <n> --squash --auto`. The merge is asynchronous: confirm it landed,
  not that the command returned. A failed group check drops the pull request; fix it and enqueue
  again. Update a branch only for a real conflict, never just to stay current. A conflict in
  another task's files goes to the orchestrator.
- Draft first (owner 10-27, paid CI minutes): workers open pull requests as drafts, run the
  project's local checks before every push and mark the pull request ready (`gh pr ready <n>`)
  once local checks and reviews pass; nothing skips a required check or the `main` push run.
  Whoever enqueues (the worker, or the orchestrator when it merges) enqueues only a ready pull
  request, and only after the run that `ready_for_review` (or a later push) started for the
  head SHA has finished with no required job `skipped`: a draft's skipped checks read as
  passed, and a gate job's dependants get new check runs only once it ends. "First CI run green" (Sessions) means the first run after ready.
- Project-side CI change for a private repository with paid minutes (the project's Boss, named
  in its AGENTS.md; not a harness script): `pull_request.types` lists
  `opened, synchronize, reopened, ready_for_review`, and jobs skip drafts with
  `if: github.event_name != 'pull_request' || !github.event.pull_request.draft` (on each job,
  or on one first gate job the others need); `push` and `merge_group` runs stay. Draft pushes
  then cost nothing; `ready_for_review` starts the real run.
- A red `main` push run: never `gh run rerun --failed` (a partial rerun can never pass a release
  record job that needs the whole run). Use one full `gh run rerun <id>`. If it is still red
  outside your code, report DONE with the run link; a later green main SHA carries your code.

## Sessions

- Every session has its own worktree and branch; the stash stack is shared across worktrees, so
  never use bare `git stash`.
- Files over about 20k characters are read by range or `grep`. Whole exports never go into a session or a reviewer packet.
- Models for code: Opus on risk paths (reviews.md, Codex budget), which wins over the rest. Sonnet
  high, as an extended trial (owner 10-19, 10-24: more Sonnet work), on small and
  medium cards (Effort up to 3, one lane). Clear feature cards of Effort 5 (the orchestrator's
  band for the owner's "more complex tasks") alternate, in dispatch order, Sonnet high and Opus
  medium (Opus medium on clear feature code: owner 10-21). The read compares the two models within each card Effort band, from the
  `Model:` line: r1 blocking and major findings per PR, PRs with such findings in a later round,
  first CI run green, post-merge defects within 72 h (revert, fix PR, red `main`). After about 10
  Sonnet PRs in the band, a read-only Sonnet subagent writes the read and the orchestrator reports
  it to the owner; the band goes back to Opus at that read on twice Opus's r1 blocking and major,
  more than 1 in 5 PRs with later-round findings or a first-green drop of 20 points or more, and at
  once on a post-merge defect of blocking severity (reviews.md). Search and exploration
  in subagents run on Sonnet; reviews (r1 and rechecks) keep the model reviews.md names (Routing; Rounds 4, 5; owner 10-19, 10-21, 10-23).
- Orchestrator address: `modules/superset/bin/boss-of.sh <project>` prints a project's orchestrator session name from one
  registry (`<orchestrator dir>/orch-name` and the shared `~/.config/agent-harness/bosses.tsv`, one row per
  project). `orchestrator-restart.sh` records the old name, the successor its own (`boss-of.sh set <name>`), and an
  orchestrator whose name differs from `orch-name` on a start or resume records it the same way (the SessionStart
  hook says so). Take an address from there or from the latest message's `from`, never from a brief, STATE.md or an older
  message; briefs carry no orchestrator name (a worker has it from its start prompt, which `worker-restart.sh` and
  the dispatch command fill in, or `cat <orchestrator dir>/orch-name`). A send that fails with "No agent named" is
  retried once with the registry's name (ListAgents when it is the same name or `orch-name` cannot be read) and not reported; only a second
  failure is. Exit 1 (no record): ListAgents; only a project's own orchestrator runs `set`, and
  `orchestrator-check.sh` warns while `orch-name` or its row is missing. A new name goes only to live workers, never
  to peer orchestrators: they read the registry.
- Restart. A worker near its brief's token limit (process.md section 6; the orchestrator near 250k), at the next natural boundary,
  writes a handoff of at most 40 lines (core/templates/handoff.md, kept as `handoffs/TEMPLATE.md` in the orchestrator's directory)
  that lists the files and ranges already read and the decisions taken, waits for its own
  background jobs (closing the terminal kills them), then restarts itself with the orchestrator's
  `worker-restart.sh` (handoff, your current model and effort, brief), sends the orchestrator `RESTARTED <path>` and
  stops. Not with about 30 calls left (only merge, `main` push run, read-back, DONE): finish.
  Restart early, from 150k, before an expected idle of over an hour (owner gate, usage limit,
  overnight). The orchestrator's `Hold` to a worker names an ETA (a clock time or event) or says `no ETA`
  (core/templates/messages.md); a worker above 150k treats `no ETA` or an ETA over an hour away as that idle
  and restarts before it waits, also with about 30 calls left (nothing finishes during a hold; a warm idle
  re-bills its whole context on resume). The script lists each brief once (COMMON_BRIEF included) and,
  when the handoff names `review-codex.sh` or `wait-merge.sh` anywhere (its `Commands:` line is the place),
  puts that script's usage and exit-code lines in the prompt, so the successor need not read its header.
  The successor closes the old terminal as its last step, after it has read the handoff and the briefs. Background jobs
  are waited for (closing kills them); live subagents are the case for `--keep-old` (or `HARNESS_KEEP_OLD=1`), which takes
  the close step out of the prompt; a line `Keep old session: yes` in the handoff (STATE.md for the orchestrator) does the
  same, and the script reads it. The old session then sends `RESTARTED`, does nothing else, and closes its own terminal
  when its last subagent has reported (the workspace sweep of modules/superset/orchestration-addendum.md closes a leftover). Wake-ups go only to the terminal in
  `orch-terminal`, which the successor takes over (`wake.sh target`) before any close, so a kept old orchestrator
  gets none; it deletes its own session crons first (CronDelete), or two sessions would act. Both scripts refuse
  a workspace or terminal ID that is not a UUID, extra arguments, and (orchestrator) a successor template without a
  `{CLOSE_STEP}` line or with its own close command.
- Background jobs (a Codex review, a backup, a CI or merge wait): started with `run_in_background`; one
  check about 30 s after the start that the job runs (the log shows progress, no usage or trust error), as a
  Monitor until-loop on its log (`until grep -q <progress> log; do sleep 5; done` under `timeout 60`), never
  `sleep N; tail` (Claude Code refuses it); a `timeout` on every
  job (a merge wait: 60 minutes; on its timeout run `gh pr merge --disable-auto` or read the state
  once with `gh pr view` before reporting); a wait that ends on failure too (a failed required check, a
  dequeue, a closed pull request), because `gh pr merge --auto` stays armed on a failed one; then
  read the exit status and the report. A missing report is a failure, not "still running". That
  is one check, never polling. `core/bin/wait-merge.sh` and `core/bin/review-codex.sh` do this (README, Scripts).
- Limits (owner decision, after limits kept causing problems): every timeout,
  cap or quota added in product code or prompts names why it exists and what happens when it trips,
  and is set with generous headroom, user paths included.
- Owner questions (only process.md section 2's five, or an incident; Orchestrator, Owner asks): they
  wait for the morning or evening digest on the owner page (Orchestrator, Owner page); only an
  incident goes out at once, and a chat the owner started is answered in that chat. Work that needs no answer keeps running.
- Host load: locally run only the test modules your change touches and the new tests, never a
  full suite (CI runs it); one local run at a time. Stop only your own processes by PID; never
  `pkill`/`killall` by pattern (other workers share the user).

## Hosts

Workers can run on another machine that Superset knows as a host (CLI 1.39; owner 10-26).

- `superset hosts add <ssh-target>` installs the CLI there, signs it in with a new API key and
  keeps it running as a systemd user service or LaunchAgent; `superset hosts remove <ssh-target>`
  undoes it and revokes the key. It changes that machine and adds credentials and host access, so
  it takes the process.md section 2 gates: the proposal names the machine, the logins and the
  cost (above the `Budget:` cap: the owner's), nothing is installed before a clean Astra r1, and `--yes` only after it. Never a production
  server. It needs `ssh <ssh-target>` to work from here, macOS or glibc Linux (x64 or arm64,
  not Alpine), `curl` and, on Linux, a valid `/etc/machine-id` and systemd user services
  (`loginctl enable-linger` keeps them running without a login). The machineId: `superset hosts list --json`; offline: `superset hosts wake <id>`.
- A project moves whole: its orchestrator runs on the host with its directory there, because briefs
  and handoffs are read by absolute path, the restart scripts and `modules/superset/bin/watch.sh` call `superset ...
  --local` (`superset snapshot` reads this machine by default), and session messages (SendMessage) travel between sessions of one machine. On the host
  the facts file's commands stay `--local`. A project whose tasks need production keys or
  production database credentials (deploy, prod diagnostics) stays on the owner's machine.
- Once per project on the host: `superset projects setup <project id> --host <machineId>
  --parent-dir <dir>` (private repos clone only with `gh` signed in there). Agent presets are per
  host (`superset agents list --host <machineId>`): the facts file's worker preset line holds the
  host's ID.
- The host gets its own tools and logins (git, gh, claude, codex, Docker, the harness checkout and
  launcher with the global hooks, README Once per machine; `~/.claude`; the worker settings and MCP
  files, README New project 6), never production SSH keys or production database credentials. It
  does not raise Claude or Codex usage limits.
- From the owner's machine, `--host <machineId>` on `terminals`, `agents` and `snapshot` shows
  those workers; the owner takes one over in their own shell with `superset terminals attach --ssh
  <ssh-target> --workspace <id> --terminal <id>`. `panes` works only on the desktop app's machine.

## Orchestrator

- Read on start: the project's STATE.md (a SessionStart hook can print it) and the orchestrator
  handoff; AGENTS.md, CLAUDE.md and process.md are already in context. Read only the section of a
  process document a step needs. Plan, follow-ups and the decision log live in the orchestrator's
  log, read on demand and for the weekly review, never on start; never read an archive on start.
- Briefs: the common worker brief (core/templates/worker-brief-common.md, filled in) plus a 3–6 line task
  brief with only what Tiden does not hold: card ID (or goal for a skip), files busy in other
  workers' open PRs or briefs (`gh pr diff N --name-only`; Tiden does not show concurrent work),
  level if not in the card, limits beyond the card (production read-only, etc.), SP when Estimates is on.
- Worker states (Superset CLI 1.39+): `modules/superset/bin/watch.sh` prints `AGENT <name> (terminal <id8>): <state>`
  when a worker agent becomes `idle` (turn ended), `blocked` (waits for input) or `exited`, or its
  terminal is `gone`; its state directory survives a restart, so a restarted watcher repeats only
  what changed meanwhile (an empty directory lists every such worker). For several workers these
  lines are the wait. To wait for one (a reply, a
  resumed turn): one background `superset agents wait --workspace <id> --terminal <id> --local
  --until settled --timeout 1800 --json`, never repeated terminal reads. Exit 0: read the terminal
  once. Exit 1 says why: the agent exited or its terminal closed (read the tail if the terminal is
  still there), or its timeout (`superset agents explain`, then wait again). A message into its
  terminal plus that wait is one background `superset terminals send <same ids> --text <message>
  --wait --until settled --timeout 1800 --json`, never a send followed by `agents wait` (that wait
  can end at once on an agent still idle from before); on exit 0 read the terminal once, else
  `superset agents explain`. Never answer a
  worker's prompts; text in its input box can be an autosuggestion: never relay it as an owner
  decision.
- Idle, blocked or stalled workers: `superset agents explain --workspace <id> --terminal <id> --local`
  says why a state shows (turn ended, waits for input, exited, age of the last event). `idle` after
  its DONE, question or message: act on that message. `idle` with none: an API network error ended
  the turn silently; read the tail for the error and send "resume" with the send-and-wait above. `blocked`: read the
  tail; a permission or menu prompt: add the allow entry (process.md section 2 gate) and restart the
  worker; only a prompt no entry clears is a `hands` item (never press keys in a worker's terminal).
  `STALL` (working, no agent event for `STALL_MIN`): read the tail once; an idle prompt there is an
  interrupt typed outside Superset that left the state on working (explain only warns of it): treat
  it as idle; a tool still running (a long test, a wait) is left alone; else send "resume".
  `exited` or `gone` without a DONE: an Abandoned pull request (below) or the close step.
- Abandoned pull request (its worker gone): hand it to another agent with the old handoff, if
  any; never close it for age (owner 10-16).
- Live checks (owner 10-18, 10-19, 10-23, 10-24: whatever an agent can check, the agent checks):
  an agent runs them and records real results. It picks the account, chat and text
  itself; a live action the project lists runs on the owner's or test accounts inside a ready card
  without a yes, and any other send is the owner's (process.md section 1, section 2 item 4); a read
  check needs no yes. The
  owner does by hand only what no agent can. A GUI step (open a service, read a setting, add or register
  something) is an agent's through computer use (worker brief, GUI steps) before it is the owner's; the
  orchestrator answers `GUI CLAIM` (messages.md) against the shared `~/.config/agent-harness/gui-claims.tsv` (all
  projects; one row: app or window as `list_windows` names it, project, agent, cua session, since; a missing file
  holds no claims). It edits the file only while holding the lock directory `gui-claims.lock` beside it (`mkdir`
  succeeds; `rmdir` after), and grants an app or window that no row holds (a whole-app row holds all its windows)
  and `foreground` to one agent at a time. It adds the row, removes it at `GUI FREE`, and at a holder's
  `exited`/`gone`, and on its own start or restart for its project's rows whose agent is not live, ends the row's
  cua session (`timeout 20 cua-driver call end_session '{"session":"<name>"}'`) and removes the row. A row of a
  project with no live orchestrator (`modules/superset/bin/boss-of.sh <project>`, ListAgents) may be removed by any orchestrator.
- After a worker's DONE, or when its last PR merges (whoever merged it): check its worktree is clean and its test
  containers are gone (`docker ps -a`; `docker stop` running leftovers and `docker rm <proj>_<name>` stopped ones
  yourself, dcg allowlist in README Requirements, which checks the name shape only, not whose container it is; for a
  name dcg blocks, the `! dcg allow-once` line goes in the owner digest), run `estimate record` when Estimates is on,
  close its terminal and archive its workspace at once, unless its task has steps after the merge (enable after
  deploy, a measurement after N hours, a follow-up PR; from its brief, card or a `Post-merge:` line in its DONE): then
  move them with their conditions into STATE.md NEXT, or wait for its DONE, and close after.
- Status sweep (owner 10-27): before each digest (at least daily) and in every Tiden maintenance
  window, read the project's `Active`, `Review` and `Done` cards (with the `Tiden health` and
  `Tiden drift` lines) and every feature and epic whose child moved since the last sweep, and fix
  drift yourself, evidence on the card (tiden.md, Specs and statuses); open a window when a move
  is due. A story: `Active` with neither a live worker nor an open PR → `Backlog`; `Active` with
  its PR merged → `Review` or `Done`; `Review` with every criterion proven → `Done`; `Done` with a
  failing linked test or an unmet criterion → `Review`. A feature or epic: per its children only. A `Review` card with an
  unproven criterion and no STATE.md NEXT line for it: dispatch the check; a human look an agent can take
  (computer use, worker brief GUI steps) is dispatched too, one only the owner can take is a `hands` question. List the moves in the digest.
- On dispatch, move the brief's card to `Active` (tiden.md, Specs and statuses).
- Merge queue: a queued PR shows `autoMergeRequest=null`; dequeue only via GraphQL
  `dequeuePullRequest`. Announce a release freeze before giving merge oks.
- Release apply notice (owner 10-18): the release worker announces the apply time ahead only when
  another live production action (stop window, drill, live check) is running or planned;
  otherwise it applies right away and just reports RELEASE APPLIED. The merge freeze still holds
  from the candidate SHA until RELEASE APPLIED.
- The orchestrator does not change product or production config itself (owner 10-18): every
  change goes to a worker through the process.
- Cost (process-diet 10-18): no "ok/noted" replies to workers; each wake-up re-reads the whole
  context, so wake less: rely on worker standing approvals and answer worker questions in one
  message. Orchestrator effort medium (owner 10-19).
- Capacity (owner 10-18): run at least 7 workers in parallel (owner wants 10–15 later). A
  worker's context limit is a restart signal at a natural boundary; never stop a worker just for
  the number.
- Process and rule changes (owner 10-18, 10-27): agents decide them without asking: research,
  review (reviews.md, Rounds 8), merge, a "Decided by agents" digest line; the
  owner reverses with one word. Only a change process.md section 3 makes OWNER needs the owner's
  words; a quoted owner request naming it counts. Give your own opinion and say plainly when an owner idea looks wrong or costly.
- Partner, not yes-man (owner 10-18): hold an evidence-based opinion; when the owner pushes back,
  re-check the facts and concede only what the facts support (say which part stands). Disagree
  openly with a recommendation.
- Owner asks (owner 10-18, 10-19, 10-27): never ask the order, start or parallelism of work, a technical choice
  or config value, the review level or who merges, naming (a public name is item 4), process text, or whether you
  understood the owner (restate it in the digest instead). Every ask names its kind, one of the five of process.md
  section 2 (`product`, `user-data`, `money`, `publish`, `hands`), or is an `incident`; an ask that names none
  is decided by the agent. An `incident` is production or a user-facing path broken or at risk, data loss
  or exposure, a security breach, or spend past the cap already happening; a blocked worker, a failed
  check, an open finding or a waiting PR is not one. An owner-kept item is a short explanation for a yes, never
  commands for the owner to run; after the yes an agent runs it. The one allowed command: a dcg block outside the
  agent-cleanup allowlist (README, Requirements) that only the owner can clear goes in the report with its exact
  `! dcg allow-once CODE --yes` line (worker brief, Tool traps). The owner's own checklist holds
  only what no agent can do (a device in hand, a payment, a password, MFA or passkey entry). Mark each item FYI
  or QUESTION; an incident is one plain sentence on what breaks for the owner; each question
  restates its context in full (the owner does not reread). Several decisions go in one decision
  brief (owner 10-26), one owner-page question with numbered items: each a question (Owner talk)
  with 2–3 options, trade-off, reversibility and when to override; it lists the assumptions made
  for items that block nothing and ends with: answer "do as you recommend" to accept all, or send
  only the corrections. On the owner page its `data-options` is the one "do as you recommend" button;
  corrections go in its comment box (with the press: those items corrected, the rest as recommended;
  corrections only: "comment only"). The log entry quotes the answer and lists every item as decided.
- Decided by agents (owner 10-27, replacing the 24 h owner-default trial of the same day): the kinds that trial
  decided after 24 h (scope and order of tasks, review level and who merges, naming, one project's process text)
  are never asked (Owner asks). Every owner ask is `default: none`: it waits for the owner, and work that needs no
  answer goes on.
  - Only these get a digest line under "Decided by agents": a process.md section 2 gate step (ruleset or required
    checks, secrets or access, destructive SQL, restore, rollback, production change, release), a process text
    change, a deleted card or weakened criterion, a GUI or ops step on a live service, a review finding closed
    by narrowing, a follow-up card or a revert (reviews.md, Rounds 5 and the epic review). Each line: `r<n>` (never
    reused), what, why, the gate it passed, the undo. The never-asked kinds and answered worker questions get no
    line. STATE.md DECIDED BY AGENTS keeps each `r<n>` with its undo for 14 days (the page shows it for one digest).
  - The owner reverses one by naming it in chat or with the page's reverse item; that is an owner answer (Owner
    page, Answers).
  - A later owner answer that differs from an agent's decision or an earlier entry supersedes it: the orchestrator
    has the deciding agent, or a new worker, undo the change or carry it forward as the owner says (unsaid: the
    cheaper one), without argument; the new entry says which (`undone` or `carried`).
  - Re-measure by 2026-11-10: every entry that decides an owner ask ends with `Kind: <kind>; default: none; took
    recommendation: yes|no|part`, the kind one of `product`, `user-data`, `money`, `publish`, `hands`, or
    `incident`. The harness orchestrator counts these in every project's decision log (asks per week and per kind,
    override rate, agent decisions reversed); the owner then keeps or changes the five.
- Owner talk: the owner's language, plain names (never a bare card code), each question = what /
  why / cost / options / recommendation. Owner text is only what the owner types to the
  orchestrator, pins as a comment or sends with an answer button on the owner page. Owner decisions go to the orchestrator's decision log, verbatim with their scope.
  When two differ, the newer wins within its own scope: a narrower newer decision leaves the rest
  of a wider older one standing; the newer entry's `Supersedes:` names whole or part (a general rule;
  example: "every product card gets a Fable and a Sol round" was later narrowed to product-only
  cards, while product-and-contract cards got Astra instead; the rest of the older rule stood).
- Packages and asks bigger than one PR: modules/tiden/tiden.md (tiden module), Planning an ask (a new direction or project:
  Brainstorm and vision first). Its ready cards, duplicates merged, run their waves back to back
  (STATE.md APPROVED WAVE, PLAN block) without asking again about items already discussed (owner decision; acceptance superseded by the
  ready-card flow); only process.md section 2 items go back to the owner.
- Cross-project (owner decision): a request to another project goes to
  that project's orchestrator (address: `boss-of.sh <project>`, Sessions), whose workers report only to it; the requester sends the request and
  gets only the end result. A finding that also applies to another project's copy goes to that
  orchestrator with file:line on its `main`; never fix another project's repository. Another
  project's pause or plan binds this project only on the owner's words for this project, or as a
  harness-wide decision (owner 10-27): an entry of the harness orchestrator's DECISIONS.md whose Scope says all
  projects binds every project. The harness orchestrator relays it verbatim with its date and id as an inbox
  file (Wake-ups, Inbox; one that pauses or stops work also by SendMessage); the receiver copies it into its own DECISIONS.md with `Source: harness <id> (<date>)`
  and acts within that Scope without asking its owner again (process.md section 2). FYIs go to the peer's inbox,
  never by SendMessage (Wake-ups, Inbox).
- Backlog order: Score = Value / Effort (Fibonacci); breakages and deadlines override.
- Estimates (owner 10-26; only when the facts' `Estimate:` line names a data dir). Every command but `link` takes `--repo
  <owner/repo>` before the subcommand (`estimate --repo <owner/repo> record`). Once: `estimate link --dir <estimate
  dir> --repo <owner/repo>` (add `--claude-project-dir <Claude transcript dir>`, a `~/.claude/projects/...` path, only
  for sessions whose cwd lacks the repo's git remote); `doctor` must show it linked. Before creating a code worker:
  `forecast --sp <the card's Effort, or your SP for a skip> --task <its --branch> --model <your model
  id>` (you adopt the SP); the SP go into its task brief and the worker keeps that branch. Only this forecast logs a `--task`; never
  size after the work started (a retro, not accuracy data). The Superset automation `estimate-nightly` (not yours) runs
  `record --all` and `dashboard --all` (no `--repo`) for every linked project; still run `record` after merges and
  before any planning. Agent count (within Capacity) and waves: `plan --agents <n>` or `dashboard`, after `estimate
  setup` named the backlog (`backlog pull` refreshes Tiden cards first). Hours and money: only the script (tiden.md, Effort).

### Owner page

Owner decision 10-26 (Superset 1.39 points 1-4: "probably do all four of these points"): the
digest and the open owner questions reach the owner as one Superset page per project, not as long
terminal messages. `modules/superset/bin/owner-page.sh` (README, Scripts) publishes it.

- Page: title `<PROJECT>: owner`, source `<orchestrator dir>/owner-page.html` (from
  modules/superset/templates/owner-page.html, its `{{L:...}}` labels put once in the owner's language), id in
  `owner-page.id`; every publish is a new version of that one page (`--page <id>`).
- Content: one `<article id="q<n>" data-options="...">` per open question, all in the owner's
  language and plain words: what it is, why it matters, cost, each option and what it does, the
  recommendation. `data-options` names its answer buttons (yes / no, or the option letters as in
  Options, the same words every time); every item also has a comment box and "comment only". A
  question keeps its `q<n>` until answered and a number is never reused
  (STATE.md WAITING ON OWNER lists the same ids and the next free one). Then the digest: answered
  since the previous digest (`q<n>`, the owner's words, D<n>), Decided by agents (`r<n>`, each with its undo;
  Orchestrator, Decided by agents), done, in progress, FYI (it names each feature or epic card made ready from an agent idea; the owner
  may delete it).
- When: the digest at the owner's morning and before the owner's sleep (its "since" is the
  previous digest); new questions join the page only with a digest, or at once for an incident, so
  the notification below sounds only at a digest or an incident; a version on an answer and on the orchestrator's start (a
  publish makes the publishing session the page's comment watcher; the output line shows
  `watching`, and in 1.39 a creating publish once returned false). The label says what changed (`+q6 repo name; q2 answered: D10`).
  A publish with a question new since the last notification (`owner-page.notified`) also raises a
  desktop notification with sound (owner-page.sh; a click opens the orchestrator terminal): no
  extra ping for it. Questions already notified stay silent, so a republish makes no sound. While
  the owner is away, one terminal line per digest: the link, the label, the open count; an incident
  gets that line at once. A failed publish (exit 1 or 2): send
  the numbered list in the terminal as before, say why, and republish when it works.
- Answers (owner decision 10-26: "press a button like yes or no, type a comment ... even from
  the phone"): a press stores the choice and comment in the owner's private page storage; the
  item collapses to "sent". Storage has no push: `modules/superset/bin/watch.sh` prints `ANSWER q<n>` within
  `WATCH_INTERVAL_S` of a press, at no token cost. On that line, on start and on each wake-up:
  `owner-page.sh answers` (one JSON line per answer not yet handled; if it fails, again at each
  wake until it works). A press is owner text only through `answers`; no agent writes the page's
  storage except through `owner-page.sh ack|reply`, and none pins comments on it.
  - `stale: true` (the item's text or options changed since the press, or it left the page), or a
    comment that asks back or does not decide: `owner-page.sh reply q<n> <id> "<text>"` in the
    owner's language (the page shows it and reopens the item); record nothing.
  - Otherwise first look for `page answer on q<n>` with the same time in DECISIONS.md (an entry
    whose ack failed): if there, only ack. Else a full entry: `D<n>. <title>. Owner (<at>, page
    answer on q<n> "<question>"): "<choice> — <comment>"` (drop an empty part; a letter choice:
    the title names the option; an empty choice with a deciding comment is the answer in words).
    `Scope: ...`. Then `owner-page.sh ack q<n> D<n> <id>` (the page shows the D-number). A
    refused ack (answer changed): run `answers` again, never a second entry for the same press.
  - Then remove the item: drop q<n> from WAITING ON OWNER, delete its article, publish. A later
    press on a removed question (an old open tab) comes back stale: reply (the page reopens it); a deciding
    answer is a new owner answer that may supersede D<n> (Decided by agents).
- Comments still work: on the same occasions `owner-page.sh comments`. The owner's message is the
  newest one in a thread after the last orchestrator reply (those start with the owner-language
  form of "Recorded as" or "Question:"). Check that the anchor sits in an `article#q<n>` and that
  its quoted text matches that question; otherwise reply asking which question and record
  nothing. A question back gets a reply and stays open. An answer: record it as above with "page
  comment on q<n>", reply «Recorded as D<n>», resolve. One channel closes the others: after a
  comment or chat answer, `owner-page.sh ack q<n> D<n>` (no id) and resolve an open thread on that
  q<n>. A refused ack (a press is unread): `answers`; the same answer → `ack q<n> D<n> <id>` on
  that entry; a different one → reply, and the question returns in the next digest. If `reply` or `resolve` is refused (the thread was handed to
  another session), the terminal line and the answered list carry the confirmation. Only the
  live orchestrator handles answers and comments; a session kept by `--keep-old` does not.
- One owner page per project, not one for all: q<n> ids, the decision log and the publisher are
  per project; the owner's Superset page list shows them side by side. A page copied before
  answer buttons: `owner-page.sh upgrade`, then `data-options` per article and the `<main>`
  labels from the template (publish warns while the answer script is missing or old).
- Privacy: Superset hosts the page and its stored answers; the answers also enter the
  orchestrator's model context and session transcript, then DECISIONS.md. `just_me` means the publishing account, which must be the
  owner's login (never another account's `SUPERSET_API_KEY`); never widened without the owner's
  words. Still no secrets, tokens, credentials, emails, phone numbers, user data, names of people
  other than the owner or internal hostnames. The script refuses the common patterns; the author
  reads the page before publishing.

- Module rules: modules/superset/orchestration-addendum.md (workspaces) and modules/tiden/orchestration-addendum.md
  (Tiden after a merge, Tiden output) apply when the module is in `Harness modules:`.

### STATE.md

Self-contained, at most 60 lines and 8 KB: live facts, live workers table, APPROVED WAVE (with any PLAN
block, modules/tiden/tiden.md (tiden module), Planning an ask), NOW, NEXT, owner reminders. An owner-approved wave or plan
(cards, limits, owner words) or a PLAN block stays in STATE.md until each item is dispatched or the
owner cancels it; trimming and restarts never drop it. On start, dispatch from it before composing
anything new: an owner-approved wave first, a PLAN block's stories through the step-5 queue in wave
order. Rewrite it after every step; move finished items to an archive instead of keeping them, and
journal lines (what happened, when) to `archive/journal.md` with `core/bin/state-note.sh <section> "<line>"`,
never as appends to STATE.md. `modules/superset/bin/orchestrator-check.sh` warns above 60 lines or 8 KB; the
SessionStart hook prints only the first 80 lines and the path for the rest. A NEXT item that waits
says so with "waits on", "after", "blocked", "hold", "owner" or a q id ("waits on q3", "after PR
#12"); `IDLE-FLEET` counts any other item as ready. A restart block must not need the archive to be
understood.

### Orchestrator self-restart

When the context hook says 250k or more, at the next boundary (same exceptions as workers: finish
if 30 calls or fewer are left; restart from 150k before over an hour idle):

1. Move every session-cron wait still open to `wake.sh add`, CronDelete the crons, then rewrite STATE.md
   (self-contained, current workers, NOW/NEXT, approvals, wake automations).
2. Start the successor in the orchestrator's workspace (`modules/superset/bin/orchestrator-restart.sh [--keep-old] <old name>`): it reads
   STATE.md, records its name (`boss-of.sh set`), sends the live workers (never peer orchestrators) its name as the new address, checks the wake automations against STATE.md,
   records itself as the wake target (`wake.sh target`) and only then closes the old orchestrator's terminal.
3. The successor announces itself to the live workers, closes the old terminal (after `wake.sh target` printed OK), continues
   NOW/NEXT, and sets `Keep old session:` back to `no` in STATE.md. With `--keep-old`, or when STATE.md says
   `Keep old session: yes` (the old session has live subagents), the old terminal stays open (rules: Restart, Sessions).

### Wake-ups

Pick the cheapest form that outlives the wait: `modules/superset/bin/watch.sh` for "something changed"; a session cron
(CronCreate) or Monitor for a wait that ends inside this session; `modules/superset/bin/wake.sh` for a wait that must outlive
a restart (overnight, an owner gate, a recurring check). Superset 1.39 cannot send an automation into a
terminal it did not start: each run starts an agent session in the target workspace or, with
`--continue-session`, reuses the one its previous run left. So a wake is a relay: `wake.sh add <slug>
<every|once> <minutes 5-10080> <purpose>`, run in the orchestrator's terminal, creates `<project>-wake-<slug>`
on `ORCH_WORKSPACE_ID` and records that terminal in `<orchestrator dir>/orch-terminal`; each run (first one
interval after `add`) is one claude turn in a relay terminal of that workspace (the same one while it stays
open) that sends `WAKE <name>: <purpose>` to the recorded terminal.
- Cost: per wake, one relay turn on top of the orchestrator's own wake-up. The relay is a full Claude Code
  session (project CLAUDE.md and AGENTS.md; the SessionStart hook gives it one line, not STATE.md) whose
  context grows by one small turn per run, on the `WAKE_AGENT` preset (default `claude`; a preset with a
  cheaper model, made in Superset settings, cuts it). Prefer one wake at the longest interval the wait allows.
- Cleanup: `wake.sh rm <slug>` when the wait ends (closes its relay terminal, then deletes the automation;
  a failure keeps both for a retry); a `once` wake removes itself after it is delivered; `wake.sh rm --all`
  when the project ends. Leave relay terminals (first prompt `WAKE RELAY`) alone otherwise.
- A lost wake (the recorded terminal is not live) is logged to `<orchestrator dir>/wake-lost.log` and its
  automation paused. `wake.sh target`, in the orchestrator's terminal, re-records it, resumes paused wakes
  and shows the log; run it after a failed restart or an orchestrator started by hand. A run while the host
  is asleep or offline is skipped, not replayed.
- Inbox (owner 10-27): an FYI to another orchestrator (a version notice, a "no action needed"
  note, a harness-wide decision relay; never a new name: peers read `boss-of.sh`) is one file `<peer orchestrator dir>/inbox/<YYYYMMDD-HHMM>-<from
  project>-<slug>.md`, never a SendMessage: it wakes nobody and is read on the peer's next real wake (its own, not a relay turn). SendMessage
  only for an ask, a blocker or an answer (a harness-wide decision that pauses or stops work is a blocker:
  inbox file plus SendMessage). The SessionStart hook lists the inbox's files and
  `modules/superset/bin/orchestrator-check.sh` prints `INBOX n` on every wake-up: read each, act, then move it to
  `<orchestrator dir>/archive/inbox/` (a file left in `inbox/` is unread).
- STATE.md line `Wake automations:` holds name, schedule and purpose from `wake.sh list`. Automations survive
  a restart and are the truth: the successor recreates nothing, corrects STATE.md to the list and removes a
  wake whose wait is over.
