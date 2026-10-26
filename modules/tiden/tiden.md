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

Status, merged source, coverage and deployment are separate facts. `Backlog` is planned work
(ready with a `Ready:` or legacy `Accepted:` line; without either, a draft until a review branch
adds `Ready:`), `Active` work being implemented, `Review` an implementation or acceptance
awaiting evidence, `Done` only the stated delivered scope. A status update never weakens a
contract, hides a failing test or removes it from verification.

An open live or measured check is written in the spec as `[open: live]` or `[open: measured]` on
its criterion or evidence line. Whoever records its evidence (version, environment, run or
measurement, date) removes the marker in the same edit, and only then. A card with an open check
stays in `Review`; where the project runs a `Tiden health` report, it fails on a `Done` spec that
carries one (text inside inline code or a fenced block is ignored, so a spec may document the
marker).

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
   (orchestration.md, Backlog order) it queues each deferred card or proposes its deletion to the
   owner; deletion stays owner-kept (owner 10-19: "I do not want to leave things for later").

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

### Planning an ask

An owner ask or research outcome bigger than one PR (expected Effort above 8) or with an open
product fork is planned here (owner 10-26). The orchestrator runs P0, P5's waves and P6; the
planner the rest.

- **P0 Depth.** Rate novelty (new module, infrastructure mechanism or external integration),
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
- **P4 Reviews.** Step 3: one Fable round on the epic with its stories (split check), one Astra
  r1 on its contract stories together, self-check on small ones.
- **P5 Ready and waves.** The ready merge (below), then waves: `estimate plan --agents <n>`
  where Estimates is on (orchestration.md; `backlog pull` reads main), else from Depends on and
  Lane; then `core/bin/plan-check.sh` when present (cycles, lane limits, path overlap in a wave). A
  failure reorders the waves; a story that must split goes back through P3–P5 on a new branch.
  The waves go into STATE.md as a PLAN block; its stories enter the step-5 queue in wave order.
- **P6 Owner FYI, not a gate.** On the owner page (orchestration.md, Owner page; one message while
  the owner is online): what the owner will notice, the waves, total SP, hours and money where
  Estimates is on, the defaults assumed. No owner wait before dispatch.
- **P7 Close.** After its last story merges, leftovers become cards and the PLAN block's remaining
  lines go to the archive. After 4 or more PRs or a wave of parallel stories, the orchestrator
  starts the epic review (reviews.md, Rounds 9); it does not hold the close.

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
it fails a story that is neither on main nor on the named branch. Weakening a criterion stays the owner's.

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
windows (the project's Tiden CI document) remain only for hand repairs that B cannot do, a hand ready merge, bulk
restructuring and deletions.

The intent loop is paused (owner 10-19, when the pilot ended): no PR runs `tiden intent
start`, settle and close or uses the `start-intent` and `capture-intent` skills, and none needs a
`Tiden intent branch:` line (CI then records a skipped route and stays green). The loop returns
after a trial the orchestrator starts once Tiden fixes settle and close at the scale of a large project (settle
times out reading an intent branch; close counts specs a rebase pulled in, reads main's run
instead of the PR's and times out reading branch specs). Three feature PRs in a row that the
orchestrator picks run the full loop as the exception, each on a worker CLI 0.40 or later (0.38
still counts files and specs merged in from main; probe 10-24), and each settles and closes without a
timeout or an owner risk acceptance; a failure restarts the count. The orchestrator reports the
trial's start and result in the digest, and the loop returns with that report.

Criteria change only through a card's branch reviewed with its PR or by the ready-merge job;
no daily delta audit runs.

## Commands (CLI 0.41.0)

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
CLI alone with `tiden upgrade --binary-only`. A plain `tiden upgrade`, `setup` and `permissions`
rewrite skills, hooks and `~/.claude/settings.json` allow rules (the owner's, process.md section 2),
so run them only in an owner-approved task and diff those files afterwards.
