# Product work through Tiden

Tiden is the project's record of product requirements, planned work, delivery state and test
evidence. Keep no other editable queue in module documents, plans, PR descriptions or chat
summaries (a project may keep a navigation index). How a change records itself (the first-step
lookup, `spec:` markers, `Spec:`/`Delivers:` lines, check A, sync B) is in process.md section 4;
CI details in the project's Tiden CI document. The project names its Tiden product and workspace
IDs; pass them when a worktree is not bound.

Never create a replacement product, reimport existing tests or reset the drift watermark to make
a dashboard green. Skills come with the CLI (skills.md); use `product-context` for lookups,
`link-coverage` and `triage-issues` as their names say, and do not fork the vendor skill bodies.

## Specs and statuses

An Epic describes a product outcome, a Feature groups capabilities, a story is independently
reviewable behaviour with acceptance criteria. Markers and `Delivers:` lines name stories only.
Keep IDs, parents, components, sources and test links stable.

Status, merged source, coverage and deployment are separate facts. Agents keep every card's
status true by its evidence and never ask the owner to move one (owner 10-27): stories,
features and epics alike.
- `Backlog`: planned work not started, or stopped before its PR merged (ready with a `Ready:` or
  legacy `Accepted:` line; without either, a draft until a review branch adds `Ready:`). Enters at
  the ready merge, or back from `Active` when the work stops with neither a live worker nor an
  open PR (an open PR whose worker is gone stays `Active`: orchestration.md, Abandoned pull request).
- `Active`: a worker took it (its brief names the card, or `start-intent` when the intent loop
  runs) and its PR is not merged. Leaves at the merge. A card its building PR writes reaches main
  at that merge, in `Review` or `Done` by the evidence, never `Backlog`.
- `Review`: its code merged and some criterion still waits: on another card, an open live or
  measured check, a human look, or a fix for a criterion found unmet after `Done`.
- `Done`: every criterion proven (below); only the stated delivered scope.
- A feature or epic follows its children only: `Backlog` while no child has started, `Done` when
  every child is `Done` and its own criteria are proven the same way, `Review` when every child is
  `Done` and an own criterion is not, else `Active`.
- Back out of `Done` to `Review` (or `Active` when work restarts) when a criterion is found unmet,
  with the evidence (the failing run, the command output or report) recorded on the card in the
  same write.

Who moves: the orchestrator moves a card to `Active` when it dispatches its worker; the worker
moves it at its merge to `Review` or `Done` by the evidence; the orchestrator's status sweep
(orchestration.md, Orchestrator) moves parents and fixes all drift. A due move never blocks
work. A status update never weakens a contract, hides a failing test or removes it from
verification.

An open live or measured check is written in the spec as `[open: live]` or `[open: measured]` on
its criterion or evidence line. Whoever records its evidence (version, environment, run or
measurement, date) removes the marker in the same edit, and only then. A card with an open check
stays in `Review` until that evidence is recorded (next paragraph); where the project runs a
`Tiden health` report, it fails on a `Done` spec that carries one (text inside inline code or a
fenced block is ignored, so a spec may document the marker).

A card moves to `Done` only when every acceptance criterion is proven by one of:
- a test linked to it (`# spec:` or `// spec:`) that asserts the criterion and ran and passed, not
  skipped, on the green `main` push run of the squash whose PR `Delivers:` it;
- for a criterion no test can assert (a deploy, an image, a registry or config state, a release;
  the evidence line says why), checkable evidence that it holds, taken after that squash on `main`
  or the deployed version: a CI log line, registry or image data, a command's output, or a git
  commit or diff (only for a criterion about the repository's content), recorded on the card as a
  link or quote with the run, commit or command it came from, the version, the environment and
  the date. A measured criterion (`[open: measured]`) closes only with the
  number, which meets the criterion's bound, and the command that produced it.

A criterion that needs a human look at the running product with real users keeps the card in
`Review` until the owner's words on that look are recorded on the card (quoted, dated); the agent
then moves it without asking. Such a card is a digest FYI line naming what to look at, never an
owner ask, and is not stale while it waits. One without
such proof keeps it in `Review` as well; an `[open: live]` criterion whose check is CI, registry
or command data closes like the evidence above. Every move is a hand write in the maintenance window the orchestrator opens (its own
dispatch move in the next one; a project without sync B: by hand); a `Done` move happens after sync B's
read-back and records in the same edit on the evidence line the `main` run id and, per
criterion, the test ids or the evidence (removing the criterion's open marker, as above). A
worker lists its moves made or due, each with its evidence, in its DONE message, the orchestrator
its sweep's moves in the digest.

Agents delete cards and weaken criteria (owner 10-27, process.md section 2). An agent deletes only
a card no test (`# spec: <ID>`, a repository grep) and no merged PR (`Delivers: <ID>`, a `gh`
search) names, as a hand write in the maintenance window: a duplicate after the read-back shows
the card it duplicates; any other (stale, deferred, superseded) after one Fable round on its text,
the evidence and the card that replaces it, if any, agrees. A card whose `Ready:` names the owner
as asker goes only as a duplicate; removing it otherwise, or behaviour a linked card holds, is
item 1. A criterion is weakened only on evidence (unreachable as written, or contradicted by a
later owner decision, quoted) and after one Fable round agrees; a weakening that changes what the
user gets is the owner's (process.md section 2, item 1). Each is one "Decided by agents" digest
line (orchestration.md) whose undo is the deleted card's title and text or the old criterion.

Main holds maintained behaviour, known defects and ready cards (planned work, owner 10-26). An
idea is a draft on a proposal branch holding one readiness unit (a card, or an epic with its
features and stories) until it is ready; a current defect goes on a review branch. A spec on main
stays: no relocation preserves identity (none through CLI 0.41.0, checked 10-24), so a follow-up
card or a review branch changes it.

Main's Quality Gate counts a `Backlog` spec without tests as `no_test` (no status filter: open
Tiden limitation, feedback 10-21), so ready cards keep it `BLOCKED`. Read it per spec: `no_test` on
`Backlog` is planned work, any other failing row a finding. Never link tests or move a card to turn
it green; a job that fails on main's verdict filters those rows first.

## Card intake

New work comes from the owner, agent feedback (`submit_feedback`), production issue triage and
audits. A worker that finds work outside its task reports it to the orchestrator.

1. **Triage.** Search Tiden main and open branches. A match, merged or not, is updated, not
   duplicated. A new feature or epic idea from agents (feedback, audits, triage or any other
   source) is written as a draft without asking the owner first (owner 10-26): its reviews make
   it ready, and nothing builds before that; which features to build is not an owner question.
   A candidate declined at triage or step 3 gets its reason at its source; for agent feedback,
   the triage's dispositions file (per feedback ID: status, matched card or duplicate-of, reason),
   after which the status follows its card through the project's tool, not by hand.
2. **Write** from the template, on a proposal or review branch, never on main: Opus high for new
   capability, infrastructure and main research, Opus medium for defects and small improvements
   with clear evidence, Sonnet for simple ones. Value, Effort, Score and Depends on come last, from the written
   description: no estimate for an undescribed task, no list of estimates for approval first.
3. **Review** by kind (process.md section 5): product cards (feature, improvement, epic) one Fable
   round with the product-manager prompt, which also checks `How others solve it` (adopt | adapt |
   build, sized to the task) and whether the card should be split; cards that set a contract in
   code, CI, data or security, and operation plans, Astra r1 and at most one scoped recheck; small cards the author's
   self-check. A card that is both a product card and a contract card gets Fable + Astra r1; no
   separate Sol correctness round. Reviewers first
   judge whether the card should exist and may shrink or reject it.
4. **Ready.** Clean step-3 reviews make a card ready; no acceptance follows (owner 10-26: the
   owner's request, direct or through an agent or MCP, is the need). The writer fills `Ready:` from
   the reviews' verdicts and runs the ready merge. A ready feature or epic card counts as
   owner-asked, whatever its step-1 source.
5. **Queue.** Current breakages and deadlines first; then by Score, with the project's share
   rules (its AGENTS.md or workflow document); where it sets none, about 70% product and 30%
   engineering by Effort, with one refactoring slot per wave (owner 10-17, 10-24). No ready
   card stays deferred without a condition or a date: when the orchestrator orders the backlog
   (orchestration.md, Backlog order) it queues each deferred card or deletes it (Specs and
   statuses; owner 10-19: "I do not want to leave things for later").

```text
Title: <plain words: what changes for the owner>
Problem: <what is wrong or missing and the desired behaviour; evidence, source>
Acceptance criteria:
- <observable, testable criterion>
Category: defect | feature | improvement | infra | refactor | research
Lane: <lane>   Expected paths: <paths>
Depends on: <PREFIX-n, or none>
Priority: High | Medium | Low (Tiden's priority field)
Boundary: <what is already implemented; what remains>
Not in scope: <epics only: what this epic will not do>
Evidence to close: <tests and checks; any separately authorized live action>
Value: <1|2|3|5|8>   Effort: <1|2|3|5|8; 13 and 21 only before the split>   Score: <Value / Effort, two decimals>
History: <legacy identity, related specs, feedback IDs, source/PR links, as-of SHA>
How others solve it: <open-source projects or standards; adopt | adapt | build, and why>
Ready: <date>, <reviews and verdicts>; asked by <owner, date | agent or MCP relaying the owner | source>
```

Categories: defect = current behaviour breaks a contract or spec; feature = a new owner-visible
capability; improvement = a better existing one; infra = CI, release, deploy, observability,
operations, dependencies; refactor = structure without behaviour change, enablers included;
research = a time-boxed investigation that ends in a decision or cards. Defect, infra and
refactor work needs no new card when an existing spec covers it (process.md section 4).

Value is the benefit to the owner. Effort is story points (1, 2, 3, 5, 8, 13, 21) by comparison
with merged PRs (the project names its reference PRs). Agents give points only; hours and money
come only from the estimate script's measurements of the repository (the owner's `estimate-task`
and `estimate-backlog` skills, run on described cards only; no `--task` at card intake: the
orchestrator logs the task's forecast, orchestration.md, Estimates), never from a model's guess. A 13 or
21 becomes a parent with child stories of at most 8, each one PR. For a new module, an
infrastructure mechanism, an external integration or more than ~300 new lines, `How others
solve it` is a 30–60 minute study
(open source, standards, built-ins of the platforms the project uses), and the worker
re-checks it for 10–15 minutes before starting.

### Brainstorm and vision

A ritual with the owner in the orchestrator's live chat (owner 10-26) for: the owner's idea that
would add to or change who the product is for, what it builds or its Not in scope (VISION.md);
a brand-new project; or the owner asking for a brainstorm by name. In a project without VISION.md
the orchestrator proposes it when the owner's ask sets such a direction; the owner decides. Any
other ask above Effort 8 or with a product fork goes to Planning an ask, a smaller one to Card
intake; an agent's idea stays a draft (Card intake step 1).

- **B1 Kickoff.** The owner tells the idea (voice is fine). The orchestrator restates it in a few
  lines (problem, for whom, what success looks like), asks only what the roles need to start, and
  opens `brainstorm-<slug>.md` in its directory, named in STATE.md NOW, for each round's synthesis
  and the owner's answers verbatim, so a successor or the writer can resume.
- **B2 Roles.** Four role subagents in parallel (Agent tool, one message): product and user voice
  (Fable medium); architect and skeptic (Opus high: whether to build it at all, risks, cost; for a
  new project 2–3 stacks with trade-offs); marketing and growth, and designer (Sonnet medium each).
  Each gets the idea, the owner's answers, the last synthesis and, in an existing project,
  VISION.md and a `product-context` summary of at most 30 lines; no file dumps. Each replies in at
  most 300 words: 2–3 options with trade-offs, the main risks, at most 3 questions for the owner.
- **B3 Synthesis.** In the chat, as Owner talk (orchestration.md): each option and disagreement
  with its role's name, the orchestrator's own view, and at most 5 questions, each with options
  and a recommendation; "do as you recommend" accepts all.
- **B4 Rounds.** At most 3 rounds, the first included; the owner's "enough", or no open product
  fork, ends earlier. The owner's own ideas go to the next round as options the roles weigh; a
  question to one role by name reruns only that role. After each round the orchestrator appends
  the answers to the file and to one decision log entry. B1–B5 questions stay in chat, not on the
  owner page.
- **B5 Vision.** A new project's B1–B4 run in the chat of any orchestrator the owner starts them
  in; then one chat question: the stack (the architect's options) and creating the repository. On
  the owner's yes, README New project: the entry with its Scope becomes D1, and the file moves to
  its directory and leaves the first orchestrator's STATE.md.
  Then a writer worker (`research-vision-<slug>`, Opus high) drafts VISION.md in the project
  repository from modules/tiden/templates/VISION.md and the file; each direction line traces to an owner
  answer. The PR is AUTO+review: one Fable round on the draft and the owner's answers only (each
  line traced, Not in scope concrete, each stage with an observable sign), no Codex. The
  writer merges after that round: the ritual's answers are the owner's review, with no separate
  yes (owner 10-27); the digest FYI names the problem, for whom, Not in scope, the stages and
  which stage gets cards now. A later VISION.md PR is AUTO+review with one Fable round;
  one changing who it is for, what we build or Not in scope quotes the owner's words, one
  changing the stages quotes the merged epics or decisions behind the change.
- **B6 Plan.** The first stage goes to Planning an ask (Card intake when it is one card) with
  VISION.md and the file in the planner's or writer's brief; P1's lens subagents and P2 run only
  for what the vision leaves open. Each epic's Problem cites its VISION.md stage as source; P4's
  Fable round gets VISION.md. A later stage is planned in its turn, so its cards do not go stale.
- **B7 Refresh.** Weekly (a wake automation, orchestration.md, Wake-ups) where VISION.md exists,
  when a large ask goes to Planning an ask, and at P7 Close, a Sonnet subagent compares VISION.md
  with merged epics, open cards and owner decisions since. No drift is one log line; other drift
  is a digest FYI line and a writer worker opens the VISION.md PR and the stale cards' review
  branch (Ready merge). Only drift that changes who it is for, what we build or Not in scope is
  one decision brief (orchestration.md, Owner asks), and the writer waits for its answer. Deleting cards and
  weakening criteria: Specs and statuses.

### Planning an ask

An owner ask or research outcome bigger than one PR (expected Effort above 8) or with an open
product fork is planned here (owner 10-26). The orchestrator runs P0, P5's waves, P6 and P7;
the planner the rest.

- **P0 Depth.** A new direction or project has Brainstorm and vision first (above). Rate
  novelty (new module, infrastructure mechanism or external integration),
  blast radius (shared files, data or production paths) and ambiguity (one fork with clear
  options is medium; several forks or criteria the ask leaves open, high) low, medium or high.
  All low is light: no planner, the step-2 writer plans. Otherwise a planner worker
  (`research-<slug>`, Opus high, the depth in its brief): ambiguity high or two highs is
  critical, else standard.
- **P1 Research.** Step 1 triage (main and open branches; a match is updated) and
  `product-context` for every part; `How others solve it`. Critical only: three Opus lens
  subagents (product, staff engineer, ops and security) each give options with trade-offs, the
  biggest risk of the obvious approach and a recommendation, merged into a Board Memo:
  consensus, disagreements, risks, recommendation.
- **P2 Owner decisions.** Only a product-direction fork the ask leaves open: one decision brief
  (orchestration.md, Owner asks) sent as a question to the orchestrator, who relays it and logs
  the answer; one follow-up round at most; the planner waits or restarts (orchestration.md,
  Sessions). Technical choices go to the reviewers; whether to build is not asked (step 1).
- **P3 Cards.** On one proposal branch: an epic with Problem, `Not in scope:` and the owner's
  decisions quoted; stories of at most 8 SP, one PR each, with the step-2 fields. Open refactor and
  defect cards on the same paths go into the epic's `History:` for the refactor slot of the wave
  before the story that shares them (or as its Depends on).
- **P4 Reviews.** Step 3: one Fable round on the epic with its stories (split check; VISION.md
  where it exists), one Astra r1 on its contract stories together, self-check on small ones.
- **P5 Ready and waves.** The ready merge (below). Then the orchestrator's waves: the backlog table
  (`backlog pull` where Estimates is on, orchestration.md; else one it writes in the same shape,
  plan-check.sh header) gets lane and paths columns from each story's `Lane:` and `Expected paths:`
  (- for no lane). With Estimates: `estimate plan --json --agents <n> > plan.json`, then
  `core/bin/plan-check.sh <backlog> --plan plan.json`; else a wave column from Depends on and Lane, then
  `core/bin/plan-check.sh <backlog>`. Exit 3 (NOT CHECKED: no card in a wave, a missing column, or a card
  in a wave without lane or paths) is no check: fill them and rerun; no wave goes out before exit 0.
  A FAIL (exit 1) reorders the waves; a story that must split goes back through P3–P5 on a new
  branch.
  The waves go into STATE.md as a PLAN block; its stories enter the step-5 queue in wave order.
- **P6 Owner FYI, not a gate.** In the next digest's FYI (orchestration.md, Owner page): what
  the owner will notice, the waves, total SP, hours and money where Estimates is on, the
  assumptions made. No owner wait before dispatch.
- **P7 Close.** After its last story merges, leftovers become cards and the PLAN block's remaining
  lines go to the archive. After 4 or more PRs or a wave of parallel stories, the orchestrator
  starts the epic review (reviews.md, Rounds 9); it does not hold the close. Then the vision
  refresh (Brainstorm and vision, B7) where VISION.md exists.

### Ready merge

Before any PR names its cards, the card's writer (the planner for an epic) merges a ready
branch to main with the project's ready-merge job: sync B's workflow dispatched with the branch
name, inside B's concurrency group, so no maintenance window. The job refuses, naming the cause,
unless `branch merge-preview` holds only spec additions or text changes, each spec with a new or
refreshed `Ready:` line, and no conflict, intent session, `autoMerge` or `testDuplicates`; it reads
the merged specs back (IDs, `Backlog`), and that readback is the receipt. B's group keeps one
waiting run and drops an older one, so the dispatcher waits for its run and dispatches a dropped run
again (a squash sync it displaced too). A legacy card gets `Ready:` citing its `Accepted:` first.
IDs stay and nothing is recreated or deleted, so it is no card move. A review split writes the
split-off cards as new drafts on a new branch and deletes them from the unmerged branch (a draft
never on main is no card for process.md section 2). A project with sync B but no job merges by hand
in a batched maintenance window; one without sync B, by hand (differences.md). A card written by the
PR that builds it (one story under a parent on main) skips the merge: the PR names its branch and
the writer fills `Ready:` from its reviews.

A PR on a ready card names its stories on main and no proposal branch, so check A never meets an
Epic, a Feature or another card in a preview. A later criterion edit goes on a
`review/<name>` branch: the PR's own while coding, merged by sync B; before work starts, one
reviewed like the card, refreshing `Ready:`, and merged by the job. Check A also enforces the order:
it fails a story that is neither on main nor on the named branch. Weakening a criterion: Specs and statuses.

### Writing a card or spec text

Self-check before every submission and after every fix; record it in the card's research note
(process-diet 2026-10-18: these rules prevent most review findings):

1. Code facts: every claim about existing code, schema, limits or tests cites `file:line` or the
   command run; trace each new job/artifact through every existing consumer.
2. Failure scenarios for anything that mutates, releases or ingests: rerun, retry, partial
   failure, crash between two writes, concurrent actor, rollback, uncertain result.
3. External tools (GitHub Actions, Docker, Postgres, OpenSSH ...): back each claim with a minimal
   executed probe, quoted.
4. Adversary: for each security/integrity control, name the bypass and the test that shows it
   blocked.
5. Consistency sweep: grep each changed term; reconcile criteria, Boundary, Evidence, Depends on
   and sibling cards.
6. Testable criteria: each names its test, where it runs (is the binary in CI?) and a
   deterministic pass/fail.
7. Authority: name the acting principal; quote the owner decision and what it authorizes.
8. Data egress: list every datum crossing a trust boundary and who may see it.

### Issue triage

Issue triage (`triage-issues`, `issue fix-context`): read every suspect source path; `verified` on
a suspect spec is not proof that its tests cover the incident. Resolve an issue only after a
matching regression test fails before and passes after the fix, never on age or a nearby green
test, and never start a provider session or weaken redaction to diagnose one.

## One Tiden branch per pull request

A worker runs `tiden intent skip` and reads the card and `product-context` before code; it
opens no `intent/` branch. Tiden changes in step with each PR: the PR's proposal or review
branch carries the spec text it changes (a card it writes, every criterion edit or flag made while
coding, the settle text); the PR names it as `Tiden branch:`, the reviewers read it with the diff, check A reads its specs and compares
its merge preview with the `Spec:`/`Delivers:` lines, and sync B merges it right after the squash, so the
spec text is current at merge. This holds for every PR that changes behaviour; a PR that delivers no new card and changes no spec text names no branch.
Each deliverable has its own branch, because B merges only the specs a PR names. A project without
check A and sync B in CI does those steps by hand (differences.md).

Every PR description carries `Spec impact:` (the `Spec:` and `Delivers:` IDs, each with its
flags, such as a criterion deferred or not built, and the anchors it adds, or `none`) and
`Settle text:` (`none`, or a reviewer copy of the settle text on the PR's `Tiden branch:`).
A PR whose changed files all fall inside the project's anchor-exempt paths (`*.md`, `docs/`, `.claude/`,
tests, lockfiles: for example an `EXCLUDED` list in `scripts/tiden_drift.py`) has no `Spec:` line, `Spec impact: none`
and `Settle text: none`; tests it adds still carry their `spec:` markers. A `Spec:` or `Delivers:` line holds
only IDs: `Spec: none (...)` fails the PR check as a malformed list. A PR that changes any other code file
names a spec (the sync anchors the file if it has no anchor yet). Where the PR workflow does not run on
`edited`, a body edit does not re-run the check and `gh run rerun` reuses the old event and body: push a commit
or close and reopen the PR.
A project helper may build the `Spec impact:` list (for example `scripts/spec_impact.py`): the specs
anchored to the changed files and those the body names, each marked `named (Delivers)`,
`named (Spec)` or `anchor only`. It suggests flags; the author still checks every listed spec and
flags it by hand when needed. Anything a PR missed is the backstop's: `Tiden drift` and
`Tiden health` report it after the main push, and a follow-up PR's branch fixes it. Maintenance
windows (the project's Tiden CI document) remain only for hand repairs that B cannot do, a hand ready merge, a
status moves and the status sweep (Specs and statuses), bulk restructuring and deletions.

The intent loop is paused (owner 10-19, when the pilot ended): no PR runs `tiden intent
start`, settle and close or uses the `start-intent` and `capture-intent` skills, and none needs a
`Tiden intent branch:` line (CI then records a skipped route and stays green). The loop returns
after a trial the orchestrator starts once Tiden fixes settle and close at the scale of a large project (settle
times out reading an intent branch; close counts specs a rebase pulled in, reads main's run
instead of the PR's and times out reading branch specs). Three feature PRs in a row that the
orchestrator picks run the full loop as the exception, each on a worker CLI 0.40 or later (0.38
still counts files and specs merged in from main; probe 10-24), and each settles and closes without a
timeout or a finding left open; a failure restarts the count. The orchestrator reports the
trial's start and result in the digest, and the loop returns with that report.

Criteria change only through a card's branch reviewed with its PR or by the ready-merge job;
no daily delta audit runs.

## Commands (CLI 0.42.0)

```sh
tiden intent skip --reason "<why>"                                   # first Tiden call
tiden spec get <id> --format json | jq '{title, status, content}'     # the card, once
tiden intent lookup "<task>" --path <repo path> --output <file>       # context, once, saved
tiden spec list --branch main --include-sources --format json         # anchors; save, then jq
tiden branch list --format json
tiden branch create --name proposal/<date>-<slug> --description "<card>"   # card writers
tiden spec create --branch <branch> --title "<t>" --type "User Story" --parent-id <id> --content-file <f>
tiden spec update --id <id> --branch <branch> --content-file <f>      # only on the PR's branch
tiden branch merge-preview --name <branch> --format json              # before naming it in a PR
tiden branch update --name <branch> --description "<card>"            # CLI 0.40+; stale description
tiden branch close --name <branch>    # CLI 0.40+; final, no undo; rules below; closes its intent sessions
tiden issue resolve <id> --reason "<fixing PR URL>"                   # CLI 0.41+; Issue triage rules
tiden component update --id <id> --runtime-path <prefix> [--runtime-path <prefix> ...]  # rules below
tiden drift status --product-id <product-id> --format json
```

No `spec update` on main, `branch merge`, `test link-spec` or hand-written `--sources-file`:
sync B or the ready-merge job does those (a project without sync B: differences.md). A failed read-only listing is
rerun once; a write is never retried. Honour pagination (`nextPageToken` empty, `totalCount`
equal to the rows) and save complete JSON before summarizing it. A CLI failure is unknown state.
A shell or CI on an older CLI checks each command against its own `--help` first; a missing flag
is reported, not skipped.

A merge-preview reader ignores a key it does not know only with a warning naming it, or fails
naming the key; never silently. Server-side keys appear on every CLI version (`autoMerge`, Tiden
scheduling its own merge of an intent branch); CLI 0.41 adds `testDuplicates` (tests already on
main, omitted when empty; the merge copies them, so delete them on the branch first). A non-null
`autoMerge` or a non-empty `testDuplicates` is a finding in check A or the hand review, never a
pass. `autoMerge` does not see a merge made through a GitHub merge queue (it reports
`no_merged_pr` on a merged PR); a project with a merge queue does not rely on it, and the
orchestrator closes such a branch by hand (next paragraph).

`branch close` is final and has no undo. Only the orchestrator runs it, and only on a settled
intent branch whose PR has merged; an intent branch whose PR closed unmerged stays open and the
orchestrator reports it in the digest. Nobody closes a proposal or review branch: sync B or the ready-merge job merges it.

Errors find their component by runtime path, the path prefix the deployed code reports in stack
frames (`component list` shows them). When a PR adds a source file outside its component's
runtime paths, the worker's DONE handoff names the prefix and the orchestrator runs `component update`
right after the merge, or the file's errors stay unattributed and the Quality Gate's
`prod_issues` flags them. A frame from another component's file pulls an error to that
component while the error's own component has no runtime paths, so set paths on every
component whose code reports stack frames in one pass, then read back each open issue's
component (`issue fix-context`). The update replaces the list: pass every prefix and, for moved
code, the pre-move prefix while a deployed release still reports it.

Tool notes: `tiden spec get` needs the UUID (find it with `tiden spec list [--branch …]
--format json` and jq on `seqNum`); Tiden output is not piped to head, tail or grep (a hook
blocks it), use `--format json` and jq; a Tiden read costs about $0.21, so read saved JSON
instead of live when possible. CLI 0.41 writes a repo-local `.tiden/config.json` on first use,
so the project gitignores `.tiden/`. Keep `autoUpdate` off in `~/.tiden/config.json`; update the
CLI alone with `tiden upgrade --binary-only --version v<TIDEN_CLI_VERSION>` (the release tag has the `v`; without
it the download 404s; Tiden CLI version, below). A plain `tiden upgrade` also drops the version
pin: never run it. `tiden setup` and `permissions` rewrite skills, hooks and
`~/.claude/settings.json` allow rules; an agent runs them only after a pin bump merges and the
binary is on the pin (Tiden CLI version, below): it copies those files to its scratchpad first,
diffs them afterwards and puts the old allow rules back at once; a new allow rule returns only
after Astra r1 (process.md section 2). Then `tiden-version.sh check`.

### Tiden CLI version

Owner decision 10-26: every project runs one Tiden CLI version and moves to a new one on the
same day. The pin: the version and the release's SHA-256 of each platform in use (CI runners,
the local machine); `modules/tiden/bin/tiden-version.sh` reads these lines, a project's CI reads them from its
pinned copy. A CI on another platform gets its line here first.

```sh
TIDEN_CLI_VERSION=0.42.0
TIDEN_CLI_SHA256_linux_amd64=691850035886a903f67e3650e578786db1cd7418ab7d7296e9666ef7f3724380
TIDEN_CLI_SHA256_darwin_arm64=9ef396aadb7a8d2e695b64682f2a5c381080b7cb1e35eac5aa8feb391bf01909
```

- A project's CI installs Tiden with this step (after `actions/checkout`), never a version or
  checksum of its own, so a pinned-copy refresh moves its CI:

  ```sh
  pin="$GITHUB_WORKSPACE/docs/harness/modules/tiden/tiden.md"
  ver=$(sed -n 's/^TIDEN_CLI_VERSION=//p' "$pin" | head -n 1)
  sum=$(sed -n 's/^TIDEN_CLI_SHA256_linux_amd64=//p' "$pin" | head -n 1)
  [ -n "$ver" ] && [ -n "$sum" ] || { echo "no Tiden pin in $pin" >&2; exit 1; }
  curl --fail --silent --show-error --location -o "$RUNNER_TEMP/tiden.tar.gz" \
    "https://github.com/qase-tms/homebrew-tap/releases/download/v$ver/tiden_linux_amd64.tar.gz"
  echo "$sum  $RUNNER_TEMP/tiden.tar.gz" | sha256sum --check --strict
  tar -xzf "$RUNNER_TEMP/tiden.tar.gz" -C "$RUNNER_TEMP" tiden
  echo "$RUNNER_TEMP" >> "$GITHUB_PATH"
  ```

  A project with its own install moves once, in this order: a pinned-copy refresh PR to a
  harness version with the pin, then its own PR that replaces the install with this step.
- Local binary (binary install; a plain `tiden upgrade` drops the version pin):
  `tiden upgrade --binary-only --version "v$(git -C ~/agent-harness show origin/main:modules/tiden/tiden.md | sed -n 's/^TIDEN_CLI_VERSION=//p')"`.
  Scripts that call `tiden` on PATH use it.
- The harness orchestrator runs `tiden-version.sh check` on start and before each digest. LAG: a
  newer release, or the local binary or a project's pinned copy off the pin; RULE: a release URL
  or `TIDEN_CLI_VERSION` value written in a workflow; BAD: a checksum that differs from the
  release or the pin; WARN: a Tiden download the check cannot read (verify it by hand).
- New release, the same day `check` shows it: the harness orchestrator downloads
  `tiden_darwin_arm64.tar.gz` of the new tag into `mktemp -d`, checks it against that release's
  `checksums.txt`, extracts it and runs `tiden-version.sh smoke <that binary>` (the reads
  consumers parse: `product list`, `spec list` with pagination, `spec get`; a consumer that starts
  parsing another command adds it to the smoke). No `tiden upgrade` before the pin PR merges. It
  reads the release notes for removed or changed flags, then bumps the pin by PR with the
  checksum of each platform the pin covers (`PLATFORMS` in modules/tiden/bin/tiden-version.sh; not every line of
  `checksums.txt`); the PR body quotes the smoke's OK lines and the notes check, and
  its reviewer refuses it without them. After the merge it moves the local binary and sends every
  project's orchestrator one ask. A failed smoke keeps the pin; the digest names the command.
- A project's orchestrator, on the ask: a pinned-copy refresh PR (README, How a project consumes
  it) merged the same day, then a reply with its squash SHA. A refresh that cannot merge that day
  is BLOCKED to the harness orchestrator with the failing step; the harness digest names every
  project still LAG and why. A breakage found after a bump reverts the pin by PR, and the same
  ask follows. So every Tiden release is a harness version and one refresh PR per project;
  tiden.md is never copied alone.
