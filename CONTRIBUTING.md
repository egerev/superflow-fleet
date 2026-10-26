# Contributing

Thanks for helping. This repository is a process (markdown) plus shell scripts and hooks. It is
written for one owner running many agents, so a change should make the process clearer or safer
for that case, not add ceremony.

Layout: `core/` is tool-agnostic; `modules/superset/` and `modules/tiden/` hold what depends on those
tools. A rule that names a tool belongs in its module. Per-project facts, names and overrides belong in
a private overlay, never here.

## Rules

- One subject per pull request. Say which rule changes, why (the incident or the request), and what
  enforces it (a script, a hook, a review step). A rule without an enforcer is a wish.
- `core/process.md` stays within 1,000 words: a change replaces or deletes words, it does not only add.
- Bump `VERSION` (MAJOR when projects must change their `AGENTS.md`, MINOR for a new or changed
  rule, PATCH for wording).
- Examples and templates use placeholders or synthetic names. Never commit real project or card
  names, personal paths, e-mails, IDs, tokens or session transcripts.
- Scripts are POSIX `sh` or `bash` with no project names or paths; project values live in
  `config.sh`. Scripts of a module source `../../../core/lib/config.sh`.

## Checks

```sh
shellcheck -x core/bin/*.sh modules/*/bin/*.sh core/lib/*.sh core/hooks/*.sh core/templates/harness-hook.sh core/templates/githooks/pre-push
python3 -m py_compile core/hooks/context-size.py
```

`modules/superset/bin/orchestrator-check.sh` runs against a filled `config.sh` and fails on a left-over placeholder.

## Security

Report a problem privately through GitHub security advisories on this repository, not in a
public issue.
