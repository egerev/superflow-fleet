# <Project> data policy

<!-- Copy to the project (path named in AGENTS.md, Harness values: data-policy document). It answers owner
     item 2 (process.md section 2): a user-data question this file covers is decided by agents under the section 2
     gates; one it does not cover goes to the owner as a `user-data` ask, and the answer becomes a line here.
     Every line cites the owner decision it rests on (`D<n>` in the project's decision log); a line without one is
     a proposal, not policy. The orchestrator assembles the first version from the decision log and asks the owner
     once to confirm it (a `user-data` ask); after that it changes only by a new owner decision.
     "None" is an answer: write `none (D<n>)`. A line still holding `<...>` or `D<n>` covers nothing: its
     questions go to the owner as `user-data` asks. Keep the fixed text outside `<...>` when filling. -->

Data held: <what user data the project stores or processes: kinds, where (database, files, logs, backups,
third-party services)> (D<n>).

- Retention: <how long each kind is kept, per store, backups and logs included; what triggers the clock> (D<n>).
- Deletion: <who may delete what: a user's request, the end of retention, a test or demo account; what a
  deletion leaves in backups> (D<n>). Gates: an Astra-reviewed plan, a fresh verified backup, an undo (process.md
  section 2).
- Visibility: <who and what may read user data: the owner, agents (production read-only, which tables or fields
  are masked), reviewers, third parties> (D<n>). Never in a PR, issue, log excerpt, screenshot or digest.
- Consent: <what the users agreed to and where it is recorded; what needs new consent (a new purpose, a new
  third party, a public mention)> (D<n>).
- Data egress: <which services receive user data (model providers, error tracking, analytics, email, backups)
  and what fields> (D<n>). Any other recipient or field is a `user-data` ask before it ships.
