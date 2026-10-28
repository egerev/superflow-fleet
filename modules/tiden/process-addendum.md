<!-- Section 4 of the process: appended to core/process.md by the loader when `Harness modules:` lists tiden. -->
## 4. Product context and Tiden

- First step of any task touching product code, specs or tests: `tiden intent skip`, the card
  and `product-context`, then code.
- Spec, tests, code: the ready card is the spec; failing tests come first. Each new test has
  `# spec: <PREFIX>-n` (Python) or `// spec: <PREFIX>-n` (JS, TS, Go) directly above it and its
  decorators, naming a story-level spec, or sits in the project's unlinked-tests list. Defects, infra and refactors
  need no card: a marked regression test and a `Spec:` line.
- PR lines: `Spec: <PREFIX>-n[, …]` (implements or keeps), `Delivers: <PREFIX>-n` (completes), at most one
  `Tiden branch: proposal/<name>` or `review/<name>`, the only place to edit criteria. The first
  ID is primary; new files are anchored to it.
- Wait for sync B (main push) on your squash and read back; rerun or dispatch a failed B, `Tiden
  drift` or `Tiden health`. Hand writes to Tiden need a maintenance window (the project's Tiden CI
  document).
