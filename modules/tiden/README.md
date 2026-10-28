# Module: tiden

Tiden is a product-spec and backlog tool with a CLI. It holds the project's product requirements (specs with acceptance criteria), the card backlog,
test links and drift checks. This module is the flow built on it: a card is the spec, failing tests
come first, every pull request names the specs it implements, and the spec text changes with the
code. Enable it with `tiden` in `Harness modules:` of the project's AGENTS.md.

| File | Holds |
|---|---|
| `process-addendum.md` | The always-on rules (process.md "section 4"): first steps of a task, `# spec:` markers, the `Spec:` / `Delivers:` / `Tiden branch:` PR lines, sync after the merge. The loader appends it to `core/process.md` |
| `tiden.md` | Specs and statuses, card intake and the card template, planning an ask bigger than one PR (its waves checked by `core/bin/plan-check.sh`), brainstorm and vision before a new direction, one Tiden branch per pull request, issue triage, the intent loop (optional; off in the author's setup), CLI commands |
| `skills.md` | The Tiden skills that come with the CLI (`product-context`, `link-coverage`, `triage-issues`, ...) |
| `orchestration-addendum.md` | Two orchestrator rules that only apply with Tiden (act on Tiden after the squash's main run; Tiden output as JSON) |
| `worker-brief-product.md` | The product-card part of the common worker brief; append it to `briefs/common.md` |
| `templates/VISION.md` | The project's VISION.md (who it is for, what it builds, Not in scope, stages), drafted by the brainstorm ritual |

Prerequisites this repository does not ship: the CI automation `tiden.md` calls check A, sync B, `Tiden drift`
and `Tiden health` (workflows that compare a PR's `Spec:` lines with its Tiden branch and merge that branch after
the squash). Without them, do those steps by hand as `tiden.md` (One Tiden branch per pull request) describes,
and write the gap in your overlay's or project's differences list.

Without Tiden: leave `tiden` out of `Harness modules:` (no section 4 loads) and write `Tiden product: none`
in `Harness values:`. If the project keeps its specs elsewhere (a backlog file, issues), say in `AGENTS.md` where
the card and its acceptance criteria live and how a PR names them; the review packet in `core/reviews.md` then
lists that card text where it says `specs.md`.

Needs the `tiden` CLI logged in; install its skills with `tiden skill install --agent claude-code --global`.
The CLI version the commands were written against is named in `tiden.md` (Commands); check
`tiden --help` for current flags.
