<!-- Add to the orchestrator's briefs/common.md for product cards when the tiden module is in force. -->
## Product work (add for product cards)
Read the ready Tiden card on main first: acceptance criteria, boundary, expected paths, "How others solve it" and research
are the contract; re-check the research for freshness (10–15 min). The card is on Tiden main, or on the PR's Tiden branch for a card the PR
writes (harness tiden.md, Ready merge).
Flow (harness process.md section 4; intent loop PAUSED): `tiden intent skip` → the card (`tiden spec get`) +
product-context → failing tests first → implement → draft PR with lines `Spec:`, `Delivers:`, `Tiden branch:
review/<name>` for the spec text it changes: criteria, flags, settle text, `Actual:` (the only place to edit criteria), Lane, Change path, Spec impact, Settle text → reviews per harness
reviews.md → merge yourself when the process.md conditions hold and no freeze is on → wait for sync B on your squash and
read back → tell the orchestrator the squash SHA. No `tiden intent start/settle/close`. `Actual:` hours line: put it on
the PR's Tiden branch before merge (hand writes on main need the orchestrator's window).
Writing a card or spec text: the self-check in harness tiden.md (Writing a card or spec text).

## Also
- Tiden after a GitHub merge: act on Tiden main only after the squash's `main` push run has finished.
