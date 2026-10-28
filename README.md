# agent-harness

A written operating process for one person (the **owner**) who runs many AI coding agents at once:
who decides what, how work is split, reviewed and merged, and how a session that runs out of
context hands over to the next one. Plain markdown plus a few shell scripts and hooks, built for
Claude Code. MIT licensed.

## What problem it solves

One agent on one task is easy to supervise. Five or ten at once, for days, are not: two agents
edit the same file, reviews happen when someone remembers, an approval given in chat is forgotten
by the next session, a long session degrades and its successor starts from nothing, and the owner
spends the day answering questions an agent could have settled. The harness turns those failures
into written rules, each with the incident that caused it and the script, hook or review step that
enforces it:

- **Roles.** One **orchestrator** session talks to the owner and keeps the plan (`STATE.md`, a
  decision log). Each **worker** runs in its own git worktree, takes one task from a **brief**,
  opens a pull request and ends with a `DONE` or `BLOCKED` block.
- **Who decides.** The owner keeps five things: product direction, user-data policy, money above
  a monthly cap, publication under the owner's name, and the owner's own hands (passwords, MFA,
  payment, devices). Everything else agents settle behind gates (reviews, a fresh backup and an
  undo, a digest line the owner can reverse); no known risk is ever accepted: agents narrow the
  scope, file a follow-up card or revert.
- **Reviews in rounds.** Routing by kind of change (a second model for code, a product reviewer
  for product cards), a review packet, a verdict format, a round cap and scoped rechecks.
- **Merging.** Lanes for files that collide, workers queue their own merges (`gh pr merge --auto`), and merge
  waits that end on failure as well as success.
- **Handoff and restart.** Near its context limit a session writes a handoff of at most 40 lines
  and starts its own successor, so long work survives without the owner noticing.
- **One copy for all projects.** Every project loads the same merged process at session start, so
  a rule change reaches all of them at once; a pinned copy covers readers without the checkout.

## Who it is for

A solo developer or a very small team who already drive Claude Code (or a similar agent) on
several tasks in parallel and have started to lose track. If you run one agent on one task at a
time, you do not need this. It is opinionated: the rules come from one owner's daily use, so read
them as a working example to adapt, not a standard.

## Quick start

Rules only, in one project (about ten minutes; works with any agent that reads `AGENTS.md`):

```sh
git clone https://github.com/egerev/superflow-fleet ~/agent-harness
cd <your project>
cat ~/agent-harness/core/templates/project-AGENTS-header.md AGENTS.md > AGENTS.md.new 2>/dev/null \
  || cp ~/agent-harness/core/templates/project-AGENTS-header.md AGENTS.md.new
mv AGENTS.md.new AGENTS.md                      # the header now starts AGENTS.md; fill it in
mkdir -p .claude/hooks docs/harness
cp ~/agent-harness/core/templates/harness-hook.sh .claude/hooks/harness.sh
cp -R ~/agent-harness/core ~/agent-harness/VERSION docs/harness/
```

In `AGENTS.md` set `Harness modules: none` (or the modules you use), fill `Harness values:` with
`none` for what you do not have, and add the SessionStart hook from the comment at the end of the
header to `.claude/settings.json`. Claude Code reads `CLAUDE.md`, not `AGENTS.md`: add the line
`@AGENTS.md` to the project's `CLAUDE.md` (create it if there is none), so the project rules load
with the process. The next Claude Code session starts with `core/process.md` in
context and names the source and commit (or pinned version) it loaded. Read `core/process.md` (about a page) before anything
else; [Adopt it in three steps](#adopt-it-in-three-steps) goes on to modules and the
orchestrator. Requirements for the full setup: `git`, `gh`, `jq`, `python3`, GNU `timeout`,
`claude`, `codex`, and the CLIs of the modules you enable.

Companion: [agent-estimate](https://github.com/egerev/agent-estimate) sizes a task in story
points and turns them into measured hours and dollars; the card template here uses the same
Effort scale.

## Core and modules

The repository has a **core**, meant to be tool-agnostic (not fully there yet, see below), and two add-on **modules** for the tools it was built
around. The full flow works best with both modules; the core alone is a starting point to adapt to
your own tools.

| Part | What it is | Depends on |
|---|---|---|
| `core/` | The process: always-rules, what the owner keeps, change paths, review routing and rounds, orchestrator and worker protocol, briefs, handoff and restart, cleanup rules; scripts for merge wait, main ruleset, Codex review and meter, orchestrator bootstrap; templates | Claude Code (hooks, restart prompts), GitHub and `gh`, `jq`, Codex for the second-model review |
| `modules/superset/` | Workspaces, terminals and agent presets: one worktree plus one terminal per worker. Scripts for worker and orchestrator self-restart, the watcher and the setup check; worker settings; the workspace rules | Superset (and its CLI) |
| `modules/tiden/` | Product specs and the card backlog: `tiden.md` (card intake and template, planning an ask bigger than one PR, the brainstorm and vision ritual, one Tiden branch per pull request, commands), the project VISION.md template, the process section on product context, Tiden skills, the product part of the worker brief | Tiden (and its CLI) |

The tools, in one line each: **Claude Code** is Anthropic's coding agent CLI; **Superset** is a desktop
app and CLI that runs coding agents in parallel, one git worktree and terminal per workspace (not Apache
Superset); **Tiden** is a product-spec and backlog tool with a CLI (specs with acceptance criteria, test
links, drift checks); **Codex** is OpenAI's coding agent CLI, used here as the second-model reviewer.
The review texts name models by role: **Astra** and **Sol** are two Codex model tiers (deep, faster),
**Fable** is a Claude model used for product and process-text review; substitute your own. The
**Codex line** is a usage budget on the shared Codex meter: over it, a non-risk Codex review waits or goes to another reviewer.
The session tools the texts name (`SendMessage`, `ListAgents`, `Monitor`, cron tools, a `fable` subagent)
are Claude Code and Superset features; the skill names in `core/skills.md` are the author's personal
skill set, so treat that file as an example to replace.

Core is not fully tool-free yet. Known couplings to replace in your copy: "accepted task" in
`core/process.md` section 2 is defined through a Tiden card; `core/reviews.md` (the packet's spec files and the
PR lines `Spec impact:` / `Settle text:`) assumes Tiden; the message blocks are named `SUPERSET_WORKER_*` (the envelope of Superset's `orchestrate` skill);
`core/templates/worker-brief-common.md` names the restart script and `core/templates/config.sh` and the
facts template carry Superset sections; model names (`gpt-6-astra`, `gpt-6.1-sol`) are written into
`core/reviews.md`. The module files are the concrete commands and flows to copy or rewrite for another tool:

| If you use instead of | Keep | Replace |
|---|---|---|
| tmux or terminal tabs plus `git worktree` instead of Superset | all of `core/` | `modules/superset/` (restart scripts, watcher, workspace rules); the `SUPERSET_*` keys in `config.sh` |
| An issue tracker or a backlog file instead of Tiden | all of `core/` | `modules/tiden/`: leave `tiden` out of `Harness modules:` and write "Tiden product: none" in `Harness values:`; say in `AGENTS.md` where the card and its acceptance criteria live |
| Another reviewer model or CLI instead of Codex | the rounds and verdict in `core/reviews.md` | the commands in `core/reviews.md`, `core/bin/review-codex.sh`, `core/bin/codex-meter.sh`, `CODEX_*` in `config.sh` |
| Another agent than Claude Code | the rules in `core/process.md` (any agent that reads an `AGENTS.md`) | `core/hooks/`, `core/templates/harness-hook.sh`, `modules/superset/templates/worker-settings.json` and the restart scripts (they start `claude`) |
| Another forge than GitHub | the rules | `core/bin/wait-merge.sh`, `core/bin/main-ruleset.sh`, `core/templates/main-ruleset.json`, `core/templates/githooks/pre-push` |

## Adopt it in three steps

Each step is usable on its own; stop where the cost stops paying off.

1. **Rules only (any agent that reads an `AGENTS.md`).** Read `core/process.md` (about a page): the
   always-rules, what the owner keeps, change paths. Clone this repository to `~/agent-harness`. Start the
   project's `AGENTS.md` with `core/templates/project-AGENTS-header.md`: set `Harness modules: none` and fill
   `Harness values:` (write `none` for what you do not have). For a Claude Code project add `core/templates/harness-hook.sh` as
   `.claude/hooks/harness.sh` and register it as a SessionStart hook (the settings snippet is in the header
   template), so every session starts with the rules in context. Copy `core/` and `VERSION` to `docs/harness/` as the pinned copy; other agents read
   `docs/harness/core/process.md` from `AGENTS.md`.
2. **Enable modules.** Set `Harness modules:` in `AGENTS.md` (`superset`, `tiden`, both or `none`) and add the
   enabled `modules/<m>/` (markdown and templates; the scripts are not needed) to `docs/harness/`, same relative
   paths, so readers without your checkout (cloud agents, CI) see the same rules.
3. **Add the orchestrator when you run more than two or three agents.** Install the launcher and the global
   hooks (below), run `HARNESS_MODULES="superset tiden" ~/.local/bin/harness-exec core/bin/new-orchestrator.sh <project>`
   (`HARNESS_MODULES` only picks which module scripts get a link in the orchestrator's `bin/`), fill
   `config.sh`, and follow [New project](#new-project). Without Superset the successor session after a
   restart has to be started by hand; the handoff file and `STATE.md` work the same.

The rules are written from their author's setup and still read like it: capacity, budget and model
numbers are the author's. Dates in the form `10-19` are the day (month-day, 2026) the owner settled
that rule; "owner 10-19" marks the owner's words behind it. Change the wording to yours in your own
copy; keep the incident and enforcer next to each rule you change (`core/process.md` section 6).

## Private overlay

The overlay is optional: you need it only if you keep this repository clean of your own projects (for
example a public fork) and still want your project names, personal overrides and the list of where a
project differs from the harness somewhere. A single-project adopter writes them in the project's
`AGENTS.md` instead (its `Override:` lines are then the record, in place of an overlay `differences.md`). Per-project facts, personal overrides, project names and that list do not belong in
this repository. Keep them in a separate private directory or
repository, the **overlay** (for example `~/agent-harness-private`), and point the loader at it with
`HARNESS_OVERLAY` (default `~/agent-harness-private`; the overlay is optional). The loader prints
`<overlay>/process-overlay.md` after the core and module text when the file exists (from the overlay's
`origin/main` when it is a git repository, else the plain file). Suggested contents: `process-overlay.md`
(a short list of the overrides in force, loaded every session), `differences.md` (the table of
`differences.md` in this repository, filled in for your projects) and `projects/<name>.md`
(read on demand). Never copy overlay files into a project's pinned `docs/harness/`. Precedence: `AGENTS.md` is the project's
word. The overlay may add project facts and tightenings; it never changes `core/process.md` sections 2 or 3 or the
review levels (`Override:` lines for those count only in a project's `AGENTS.md`). The loader reads a git
overlay from its `origin/main` only.

## Files

| Path | Holds | Loaded |
|---|---|---|
| `core/process.md` | Always-rules, owner-kept list, change paths, modules and overlay, review summary, working with the orchestrator | every Claude Code session (SessionStart hook) |
| `modules/<m>/process-addendum.md` | The module's rules that extend process.md (`tiden`: product context and Tiden, section 4; `superset`: a two-line pointer) | with process.md, for the modules in `Harness modules:` |
| `core/reviews.md` | Routing, packet, verdict, rounds, Codex budget, PR lines | on demand |
| `core/orchestration.md` | Lanes, merging, sessions (restart, background jobs), orchestrator rules, STATE.md | on demand |
| `core/skills.md` | Skill map and when to load which skill | on demand |
| `modules/tiden/` | `tiden.md`, `skills.md`, `orchestration-addendum.md`, `worker-brief-product.md`, `templates/VISION.md` | on demand |
| `modules/superset/` | `orchestration-addendum.md` (workspace rules), `README.md` (commands and flows) | on demand |
| `differences.md` | Where a project differs from the harness, open or overridden (an empty template here; fill it in your overlay) | on change |
| `core/bin/`, `core/lib/`, `core/hooks/` | Merge wait, Codex review and meter, wave plan check, ruleset, orchestrator bootstrap, the launcher; the global hooks (STATE.md at session start, context budget) | run through `core/bin/harness-exec.sh` |
| `modules/superset/bin/` | Worker and orchestrator self-restart, watcher, setup check | run through `core/bin/harness-exec.sh` |
| `core/templates/`, `modules/superset/templates/` | Project AGENTS.md header, loader hook, common worker brief, handoff, messages, orchestrator directory files (config.sh, STATE.md, DECISIONS.md, facts), data policy, ruleset JSON, pre-push guard; worker settings and the successor prompt | when adopting |

In the text, scripts and templates are named by their path in this tree, for example
`core/bin/wait-merge.sh`. Inside an orchestrator directory the same scripts are `bin/<name>.sh` links.

## How a project consumes it

1. Clone once: `git clone https://github.com/egerev/superflow-fleet ~/agent-harness`. The
   orchestrator runs `git -C ~/agent-harness fetch origin` on start and after each harness merge
   (fetch, not pull: the checkout may sit on a draft branch), so a merged change reaches every
   project at once.
2. The project's AGENTS.md starts with core/templates/project-AGENTS-header.md: the Process line,
   its `Harness modules:` (`superset`, `tiden`, both or `none`), its `Harness values:` (the placeholders
   in angle brackets) and any `Override:` lines.
   `<version>` is the harness version of the project's pinned copy.
3. Loader: core/templates/harness-hook.sh goes to `.claude/hooks/harness.sh`, run by a SessionStart
   hook (command in the header template). It prints core/process.md from `origin/main` only, never a
   branch or the working tree, so a draft edit acts only after its merge, then the
   `process-addendum.md` of each enabled module, then the overlay's `process-overlay.md` (Private overlay
   above); else the pinned copy (the overlay is never pinned);
   else a stop notice (HARNESS UNAVAILABLE: report BLOCKED, merge or deploy nothing). It names
   the source and commit or version it loaded. (A `@~/agent-harness/...` import in CLAUDE.md is
   not loaded in headless `claude -p` runs, checked 2026-10-21; the hook is.)
4. Pinned copy: `docs/harness/` holds `core/` and the enabled `modules/<m>/` (markdown and templates) and VERSION of
   a merged harness version, unedited, with the same relative paths; a project pull request refreshes
   it. It serves readers without the checkout and a missing or broken checkout. A refresh PR
   changes only these: the files above copied verbatim from one named harness commit (the PR names
   its SHA and version), and the two version pointers, `docs/harness/VERSION` (copied with the files) and the version in the
   Process line of its AGENTS.md. The Process line is the one hand edit. The copied files equal
   `git -C ~/agent-harness show <sha>:<file>`. A project's own rule change goes in its own PR.
   `core/bin/pin-refresh.sh -C <project checkout> v<version>` makes that PR from a harness tag. Its
   review checks only the copy and the pointers (reviews.md, Routing); with a clean review (no blocking
   or major finding) it merges without a new owner
   yes (process.md section 3; owner 10-27: the harness lives in one shared repository so
   that no project needs hand updates).
5. The orchestrator's `briefs/common.md` is core/templates/worker-brief-common.md filled in.

### Readers without the checkout

Codex sessions read only the repository's AGENTS.md (and `~/.codex/AGENTS.md`); cloud agents
and CI have no `~/agent-harness`. The project's AGENTS.md sends them to the pinned copy
docs/harness/core/process.md and the module addenda first, and to stop with BLOCKED when no harness text is in context.
Codex reviewers also get the four questions in the packet (reviews.md). A check that the pinned
copy equals a harness tag is a follow-up.

## Scripts and hooks

The scripts run from the merged harness only: `core/bin/harness-exec.sh` extracts the `origin/main`
tree of `~/agent-harness` (`HARNESS_DIR`) once per commit into `~/.cache/agent-harness/<sha>` and
runs the script from there, never from the working tree or a draft branch (the loader's rule).
Only an explicit `harness-exec --ref <ref> <script>` tests a branch; no environment variable
changes the ref. After a harness merge, `git -C ~/agent-harness fetch origin` moves every project at once.
A project keeps no copies: its orchestrator directory has `bin/harness-exec.sh` (a copy of
core/bin/harness-exec.sh) plus one link per script of core and of the enabled modules (run scripts through these links: they supply `config.sh`), and the link's directory names the project config (`<orchestrator dir>/config.sh`,
core/templates/config.sh filled in). Scripts carry no project names, paths or IDs.

| Script | Does | Exit / output |
|---|---|---|
| `core/bin/new-orchestrator.sh <project> [dir]` | creates `~/<project>-orchestrator`: `bin/` links, `briefs/common.md`, `handoffs/TEMPLATE.md`, `research/`, `archive/`, `inbox/`, `config.sh`, STATE.md, DECISIONS.md, `orchestrator-facts.md`; never overwrites a file | next steps |
| `modules/superset/bin/orchestrator-check.sh` | read-only: config filled, files present, placeholders gone, tools installed, a `bin/` link for every harness script, STATE.md within 60 lines / 8 KB; hygiene lines `STALE-WS`, `IDLE-FLEET`, `PIN-LAG n`, `BRIEF-NO-SENDMESSAGE`, `INBOX n` (each superset/gh read bounded by `READ_TIMEOUT_S`, 30 s; a failed read prints `NOT CHECKED`) | FAIL/WARN/hygiene lines; 1 on a FAIL |
| `modules/superset/bin/worker-restart.sh [--keep-old] <handoff> <model> <effort> <brief>...` | a worker's self-restart in its own workspace (orchestration.md, Sessions); the successor closes the old terminal last, `--keep-old` (or `HARNESS_KEEP_OLD=1`) leaves it open; lists each brief once; adds the usage and exit-code lines of `review-codex.sh` / `wait-merge.sh` when the handoff names them; refuses non-UUID IDs; `HARNESS_DRY_RUN=1` prints the command | new terminal |
| `modules/superset/bin/orchestrator-restart.sh [--keep-old] <old name> [terminal]` | the orchestrator's self-restart: a new terminal in `ORCH_WORKSPACE_ID`, never a new workspace, recorded as the wake target; refuses a STATE.md older than 30 min; same close order, flag, UUID check; refuses a successor template without `{CLOSE_STEP}` or a `boss-of.sh set` step; records the old name in the address registry first; first adds the `bin/` links of new harness scripts (never replaces a non-link file) | new terminal |
| `modules/superset/bin/boss-of.sh [<project>]\|set <name>` | the orchestrator address (orchestration.md, Sessions, Orchestrator address): prints a project's orchestrator session name from `<orchestrator dir>/orch-name` or the shared registry `~/.config/agent-harness/bosses.tsv` (`HARNESS_BOSSES`); `<project>` is a config `PROJECT`; `set` records this project's name in both (one row per project, a lock against parallel restarts), run only by the project's own orchestrator; `orchestrator-restart.sh` records the old name, the successor its own, `worker-restart.sh` names it in the prompt | 1 no record (ListAgents) or refused |
| `core/bin/wait-merge.sh <pr> [min] [--main]` | one background wait that also ends on a failed required check, a dequeue, a close or the limit (60 min; disarms auto-merge that never queued) | 0 merged (and main push runs green), 1 check failed, 2 closed, 3 dequeued, 4 limit, 5 main run red |
| `core/bin/review-codex.sh <astra\|sol\|model> <task> <report>` | a bounded Codex review: `--disable hooks`, `service_tier="default"`, read-only sandbox, `</dev/null`, start check at 30 s, report required (a written report counts even when Codex then exits non-zero); one retry on "capacity" with no report; refuses non-risk reviews over the line; counts rounds per packet directory (`review-rounds`): r4 only with `--over-cap "<reason>"`, never r5 (reviews.md, Rounds 5), one run per packet at a time (a lock); writes `<report>.status` (exit, round, verdict line) | 0 report, 3 failed start, 4 no report, 6 over the line, 7 round past the cap, 8 packet busy, 124 limit |
| `core/bin/plan-check.sh <backlog.md> [--plan FILE] [--config FILE]` | the wave check of tiden.md P5, on the `estimate` backlog table (lane, paths, wave columns) or `estimate plan --json`: Depends cycles, a dependency in the same, a later or no wave, and inside one wave path overlap or a lane over its limit (the file's `## Lanes`, else `lanes` of the `estimate` config.json) | 0 clean, 1 `FAIL` lines, 2 usage or an unreadable file, table or config, 3 not checked (no card in a wave, no lane or paths column, or a card in a wave without one) |
| `core/bin/tag-release.sh [-C <dir>] [<commit> [<version>]]` | the annotated tag `v<VERSION>` on a merge commit (default `origin/main`), VERSION read from that commit; idempotent; local only, prints the `git push` line | 0 tagged or already there, 1 refused (tag on another commit or lightweight, version differs), 2 usage, no repository, commit or VERSION |
| `modules/superset/bin/owner-page.sh publish <label>\|answers\|pending\|ack q<n> D<n> [<id>]\|reply q<n> <id> <text>\|upgrade\|comments\|check` | the owner page (orchestration.md, Owner page): privacy check, then a new version of `<orchestrator dir>/owner-page.html` (the first publish creates the `just_me` page, id in `owner-page.id`); with a question new since the last one notified (`owner-page.notified`) also a desktop notification with sound; a publish warns when the answer script is missing or old and warns past 400 of the 500 storage keys (answers are never deleted). `answers` lists button answers not yet handled (JSON lines, `stale` when the question changed), `pending` their ids, `ack` records one (refuses a changed or stale answer), `reply` answers a question back, `upgrade` puts the template's answer script into an older copy; `comments` lists open threads | 1 refused (privacy, config, usage, changed answer), 2 superset failed or timed out |
| `modules/tiden/bin/tiden-version.sh check [<project dir>...]\|smoke <binary> [<product id>]` | the one Tiden CLI version (tiden.md, Tiden CLI version): the pin against the release checksums (linux_amd64, darwin_arm64), a newer release, the local binary and each project's CI on `origin/main` (fetched; default: a checkout under `WORKTREES_DIR` of each `~/*-orchestrator/config.sh`): the pinned-copy step against the copy, RULE for a version written in a workflow, WARN for a download it cannot read; `smoke` runs the reads consumers parse (`product list`, `spec list` with pagination, `spec get`) with a new binary in an empty directory | 0 all OK (WARN allowed), 1 a LAG, RULE, BAD or smoke FAIL line, 2 usage or no pin |
| `core/bin/state-note.sh <section> "<line>"` | appends one dated journal line to `<orchestrator dir>/archive/journal.md`, so STATE.md stays the current state (orchestration.md, STATE.md) | 1 on an empty or multi-line note |
| `core/bin/codex-meter.sh [--check]` | the shared Codex meter and its line: pace plus `CODEX_LINE_OFFSET` (or a points line, `CODEX_DAILY_POINTS`) | 1 over the line with `--check` |
| `core/bin/pin-refresh.sh [-C <project checkout>] [--no-pr] <vX.Y.Z>` | refresh a project's pinned `docs/harness/` from a harness tag on `origin/main`: a new branch `harness-pin-<version>` from `origin/main`, the five documents and VERSION copied verbatim, the AGENTS.md `Process:` and docs/harness/README.md pointers, a refusal on any other changed file, commit (-s), push, PR (README, Pinned copy) | 0 PR opened, committed (`--no-pr`) or already at that version, 1 refused, 2 usage |
| `core/bin/main-ruleset.sh check\|create\|remove-classic\|rollback` | an agent applies the main ruleset after Astra r1 (process.md section 2) from a clean default-branch checkout; every step asserts its read-back | `OK:` or `STOP:` |
| `modules/superset/bin/wake.sh add\|list\|rm\|target` | orchestrator wake-ups as Superset automations that survive a restart; each run is a relay turn that sends `WAKE <name>: <purpose>` to the terminal in `orch-terminal` (orchestration.md, Wake-ups) | `OK:` / `STOP:` |
| `modules/superset/bin/watch.sh` | zero-token watcher under Monitor: PR, check and workspace changes; owner page button answers (`ANSWER q<n>`); worker agent states from `superset snapshot` (Superset CLI 1.39+): idle, blocked, exited, gone; a working turn with no agent event for `STALL_MIN` (checked with `agents explain`) | `CHANGE` / `AGENT` / `STALL` / `SNAPSHOT` / `ANSWER` / `ANSWERS not read` lines |
| `core/hooks/session-start.sh` | in an orchestrator's session (cwd = a `~/*-orchestrator/active-cwd`), prints the facts path and the first 80 lines of STATE.md (the path for the rest); silent elsewhere | text |
| `core/hooks/context-size.py` | one line past the budget: `ORCH_CONTEXT_LIMIT` (250k) in the orchestrator's cwd, `WORKER_CONTEXT_LIMIT` (170k) inside the project's `WORKTREES_DIR`; silent in any other session | hook JSON |

Data that leaves a process: `review-codex.sh` sends the task file to the Codex model, and Codex
keeps its session transcript under `CODEX_HOME/sessions` (the meter reads it; `CODEX_EPHEMERAL=1`
runs without one). `owner-page.sh` uploads the owner page (questions and digest) to Superset,
which hosts it and the owner's button answers (private page storage); `owner-page.sh answers` prints them into
the orchestrator's model context and session transcript. `core/hooks/session-start.sh` puts the first 80 lines of STATE.md and the facts path into the
orchestrator's model context. `worker-restart.sh` and `orchestrator-restart.sh` put the absolute
paths of the handoff, briefs and STATE.md, the workspace and terminal IDs into the successor's
prompt, and `worker-restart.sh` passes the caller's cwd to Superset (`--cwd`). core/templates/worker-mcp.json enables Context7, a remote MCP server
that receives the library names and questions a worker sends it; drop the entry for workers
without it.

Once per machine: install the launcher (it only resolves `origin/main`; reinstall when the
CHANGELOG says it changed) and add the global hooks to `~/.claude/settings.json`, one entry for
every project:

```sh
mkdir -p ~/.local/bin
git -C ~/agent-harness show origin/main:core/bin/harness-exec.sh > ~/.local/bin/harness-exec
chmod 755 ~/.local/bin/harness-exec
```

```json
"SessionStart": [{"hooks": [{"type": "command", "timeout": 10,
  "command": "~/.local/bin/harness-exec core/hooks/session-start.sh 2>/dev/null || true"}]}],
"PostToolUse": [{"matcher": "*", "hooks": [{"type": "command", "timeout": 5,
  "command": "~/.local/bin/harness-exec core/hooks/context-size.py 2>/dev/null || true"}]}]
```

Requirements: `git`, `gh` (logged in), `jq`, `python3`, GNU `timeout` (`brew install coreutils`),
`claude`, `codex`; with the modules: the `superset` CLI, the `tiden` CLI; optional `shellcheck` for harness changes. Computer use (GUI steps an agent
would otherwise hand to the owner; core/templates/worker-brief-common.md, GUI steps): Cua Driver
(`/bin/bash -c "$(curl -fsSL https://cua.ai/driver/install.sh)"`, the owner installs it), then the owner runs
`cua-driver permissions grant` once and allows macOS Accessibility and Screen & System Audio Recording; agents
drive it through the `superset:computer` skill (`cua-driver call <tool> '<json>'`). A `cua-driver` call can
hang until those permissions exist: wrap a probe in `timeout` (`timeout 20 cua-driver permissions status`).
Claims of apps and windows across projects: `~/.config/agent-harness/gui-claims.tsv` (orchestration.md, Live checks).
The Claude agent presets run `--autocompact 1M` (owner 10-27); restart thresholds are unchanged (orchestrator 250k).
Preset changes are an agent's: it reads them with `superset agents list --local --json`; the CLI (1.40) has no
preset edit command, so the agent edits the preset in the Superset app's settings by computer use, never an SQL file
for the owner; it is a window action, never a relaunch or quit of the app. dcg allowlist for agent cleanup (owner
10-27): the owner runs this once per machine (an agent's append under `~` is blocked; a rerun duplicates the entries):

```sh
mkdir -p ~/.config/dcg  # $HOME without `|`, `&`, `\` or quotes (sed replacement, TOML string)
git -C ~/agent-harness show origin/main:core/templates/dcg-allowlist.toml \
  | sed "s|@WORKTREES@|$HOME/.superset/worktrees|g" >> ~/.config/dcg/allowlist.toml
dcg allowlist validate
```

It passes `rm -r tmp...` of temp entries in the current directory (each one path component named `tmp...`; no `/`,
`..` or `-f`) with the cwd in a worktree (at least `<project>/<worktree>` below the worktrees directory; dcg scopes by
cwd, not session, so name no branch or workspace `tmp...`: a sibling worktree stays out) and `docker rm [-v]
<proj>_<name>`. dcg checks the name shape only (any lowercase prefix and `_`); that the container is the agent's own
is the brief's rule (`bash core/tests/dcg-allowlist.test.sh` checks the entries; undo: delete the two).
Known quirks, if you run `dcg` (a destructive-command guard hook for
Claude Code): the dcg guard blocks `rm -f`/`-f` flags and other deletions; plain `rm` of literal files and `rm -r` under /tmp (the
scratchpad) pass; `mv` under /opt or /root and `rm -r` of an absolute path need the owner's code: run
`! dcg allow-once <code> --yes` (from `!` stdin is not a TTY). False positives (a real destructive command still goes to the
owner, skills.md): `>` redirects to `$VAR` paths and to existing files under `~`; a dangerous word such as `mkfs`
anywhere on a line, even quoted: write such files with Write/Edit; `sqlite3` with a `$VAR` path or stdin: a literal
.sql file the owner runs with `!`; a hyphen-f token on a `docker run --rm` line (`--tmpfs`, a hyphenated name) reads
as rm-force: hyphen-free test containers started with `docker run --rm`, removed by `docker stop`. `codex exec` needs
`</dev/null`; Tiden output only as `--format json` with `jq`. Shell and Claude Code traps for workers (zsh separators,
Monitor waits, SendMessage delivery): core/templates/worker-brief-common.md, Project facts.

Host unit waits: a project whose long production steps run as transient systemd units keeps its `wait-unit.sh <unit>
<minutes>` (worker-written: polls the unit over ssh every 60 s up to the limit, then prints its result, exit status
and output tail) in the project repository; a copy found only in a scratchpad goes to the project. `superset agents
wait` waits on agents, not host units.

## New project

1. `git -C ~/agent-harness fetch origin`; install the launcher and global hooks once per machine (above).
2. `HARNESS_MODULES="superset tiden" ~/.local/bin/harness-exec core/bin/new-orchestrator.sh <project>`
   (launcher installed as above; `HARNESS_MODULES` picks the modules whose scripts get a link in `bin/`).
3. Fill `~/<project>-orchestrator/config.sh`: repository, Superset project, orchestrator workspace
   and worker preset IDs, worktrees directory, Codex line (`pace` or daily points, plus the add-on). No secrets in it.
4. Fill `briefs/common.md` (Project facts), `orchestrator-facts.md`, and DECISIONS.md D1: the
   owner's verbatim words that start the project and their scope.
5. Write the orchestrator's worktree path to `active-cwd`; the global hooks (above) then print
   STATE.md and apply the 250k budget there with no settings change.
6. Worker session files (worker-mcp.json enables remote Context7; see Data above): copy
   modules/superset/templates/worker-settings.json and core/templates/worker-mcp.json to the paths
   in `WORKER_SETTINGS`/`WORKER_MCP` (shared by projects; never rename files another project
   uses). Superset: create the worker agent preset with `--settings`, `--mcp-config` and
   `--strict-mcp-config` on those files; put its ID in config.sh and the facts.
7. Repository, one pull request: AGENTS.md header (core/templates/project-AGENTS-header.md), loader
   `.claude/hooks/harness.sh`, pinned `docs/harness/`; the project's rows in your overlay's differences.md.
8. Main protection: fill core/templates/main-ruleset.json into the repository (by pull request) and
   run `<orchestrator dir>/bin/main-ruleset.sh create` after Astra r1 (process.md section 2). Without rulesets
   on the plan (HTTP 403): core/templates/githooks/pre-push in `.githooks/` and
   `git config core.hooksPath .githooks` in every clone.
9. The required checks named in the ruleset, AGENTS.md header and `wait-merge.sh` results agree.
10. Module tiden: link the product; `tiden skill list --agent claude-code --global`; `.tiden/` in the
    repository's `.gitignore` (CLI 0.41 writes a repo-local `.tiden/config.json`; tiden.md, Tool notes).
11. `<orchestrator dir>/bin/orchestrator-check.sh` passes. Trial: a test worker runs `worker-restart.sh` and sends
    `RESTARTED`; `wait-merge.sh` on a test pull request; `codex-meter.sh` shows the line.
12. Start `<orchestrator dir>/bin/watch.sh` under Monitor; write `Wake automations:` in STATE.md (`modules/superset/bin/wake.sh list`).

## How to change it

- A pull request here, never a push to `main`; one subject per pull request. This repository is the
  source of truth; project names, personal paths and per-project overrides stay in the private overlay.
- Bump `VERSION` (MAJOR when projects must change their AGENTS.md, MINOR for a new or changed
  rule, PATCH for wording) and add a `CHANGELOG.md` entry with the reason: the incident or owner
  words, and the enforcer.
- Review (the maintainer runs these on incoming pull requests; contributors run the checks in
  CONTRIBUTING.md): process text gets an Opus subagent reviewer plus Fable (reviews.md, Routing) and the
  author's checklist (reviews.md, Rounds 8). A change that lets agents decide part of the
  five owner items of process.md section 2, drops or weakens a section 2 gate, or loosens section 3, is OWNER: it needs the owner's words, and a quoted owner request naming
  the change counts (process.md section 3); the agent then merges. Others merge after a clean review.
- Once `wait-merge.sh <pr>` exits 0, the merger tags the pull request's own merge commit (not
  `origin/main`, which may already hold a later merge) with the PR's VERSION, then runs the
  `git push` line the script prints. A refusal (VERSION not bumped) leaves that merge untagged;
  never move or force a tag.

  ```sh
  git -C ~/agent-harness fetch origin
  ~/.local/bin/harness-exec core/bin/tag-release.sh -C ~/agent-harness "$(gh pr view <pr> --json mergeCommit -q .mergeCommit.oid)" <VERSION>
  ```
- A project-only rule goes to that project's AGENTS.md, not here. A difference between projects
  goes to the overlay's differences.md (the template here shows the columns).
