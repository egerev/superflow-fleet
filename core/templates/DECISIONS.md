# <Project>: owner decisions

This file is how owner decisions reach workers. The owner talks to the orchestrator (or comments
on the owner page, harness orchestration.md); the orchestrator writes the owner's words here
verbatim, with the scope they authorise: these are the owner's words quoted by the orchestrator
(harness process.md section 2). A worker acts on an entry
that its brief or an orchestrator message names by number (D<n>), exactly within the entry's
scope, without asking the owner to repeat it. A missing entry is not a decision: ask the
orchestrator to add it. A standing approval holds only while all its conditions do.

Format: `D<n>. <title>. Owner (<date time UTC>): "<verbatim words>". Scope: <what it allows and
what it does not>. Expires: <date, event or "no">. Supersedes: D<m> (whole | part: <which>), if any.`

## <YYYY-MM-DD>

D1. Project start. Owner (<date time UTC>): "<the owner's words that start the project>". Scope:
<repositories, services, what the orchestrator may run without asking>. Expires: no.
