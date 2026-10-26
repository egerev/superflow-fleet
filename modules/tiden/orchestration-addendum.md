# Tiden: orchestration addendum

Rules of core/orchestration.md (Merging, Sessions) that only apply with Tiden.

- Tiden after a GitHub merge: act on Tiden main only after the squash's `main` push run has
  finished.
- Tiden commands use `--format json` with a `jq` projection (modules/tiden/tiden.md, Commands).
