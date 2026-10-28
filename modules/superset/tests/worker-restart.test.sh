#!/usr/bin/env bash
# Fixture test for modules/superset/bin/worker-restart.sh in dry-run mode: each brief is listed once in the successor
# prompt (also COMMON_BRIEF passed again, or by a symlink), and the prompt carries the Usage lines of
# review-codex.sh / wait-merge.sh (with their exit codes) only when the handoff names them. Run: bash modules/superset/tests/worker-restart.test.sh
set -euo pipefail
script=${WORKER_RESTART:-$(cd "$(dirname "$0")/.." && pwd)/bin/worker-restart.sh}  # WORKER_RESTART: another copy
root=$(mktemp -d); trap 'rm -r "$root"' EXIT
tmp="$(cd "$root" && pwd -P)/with space"  # paths with spaces reach the config and the prompt
mkdir -p "$tmp/real/sub"
printf 'common\n' >"$tmp/common.md"
printf 'other\n' >"$tmp/real/common.md"
ln -s real/sub "$tmp/link"
ln -s ../common.md "$tmp/real/sub/alias.md"  # link/alias.md is real/common.md, not common.md
printf 'task\n' >"$tmp/task.md"
printf 'extra\n' >"$tmp/extra.md"
printf '{}\n' >"$tmp/settings.json"
printf '{}\n' >"$tmp/mcp.json"
ln -s common.md "$tmp/common-link.md"
printf '# Handoff\n## Next steps\n1. Commit.\n' >"$tmp/plain.md"
printf '# Handoff\n## Next steps\n1. Run core/bin/review-codex.sh sol task.md report.md\n' >"$tmp/codex.md"
printf '# Handoff\nCommands: review-codex.sh sol t r; wait-merge.sh 12 60 --main\n' >"$tmp/both.md"
printf 'COMMON_BRIEF=%q\nWORKER_SETTINGS=%q\nWORKER_MCP=%q\n' \
  "$tmp/common.md" "$tmp/settings.json" "$tmp/mcp.json" >"$tmp/config.sh"
fail=0
z=00000000-0000-0000-0000  # UUIDs are built here: a literal one trips the export leak check
run() { # handoff briefs... -> dry-run output in $out
  out=$(HARNESS_CONFIG="$tmp/config.sh" HARNESS_DRY_RUN=1 \
    SUPERSET_WORKSPACE_ID=$z-000000000001 SUPERSET_TERMINAL_ID=$z-000000000002 \
    bash "$script" "$1" opus medium "${@:2}" 2>&1) || { echo "FAIL run $*: $out"; fail=1; out=; }
}
count() { grep -oF -- "$1" <<<"${out//\\/}" | wc -l | tr -d ' '; }
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi
}
run "$tmp/plain.md" "$tmp/common.md" "$tmp/task.md"
check common-passed-again 1 "$(count "$tmp/common.md")"
check task-listed 1 "$(count "$tmp/task.md")"
run "$tmp/plain.md" "$tmp/common-link.md" "$tmp/task.md" "$tmp/extra.md" "$tmp/task.md"
check common-by-symlink 1 "$(count "$tmp/common.md")"
check symlink-path-dropped 0 "$(count common-link.md)"
check task-passed-twice 1 "$(count "$tmp/task.md")"
check extra-listed 1 "$(count "$tmp/extra.md")"
check no-usage-without-names 0 "$(count 'Script usage')"
run "$tmp/plain.md" "$tmp/link/alias.md"
check dirlink-relative-target 1 "$(count "$tmp/real/common.md")"
check dirlink-not-common 1 "$(count "$tmp/common.md")"
run "$tmp/codex.md" "$tmp/task.md"
check codex-usage 1 "$(count 'Usage: review-codex.sh')"
check no-wait-usage 0 "$(count 'Usage: wait-merge.sh')"
run "$tmp/both.md" "$tmp/task.md"
check both-codex 1 "$(count 'Usage: review-codex.sh')"
check both-wait 1 "$(count 'Usage: wait-merge.sh')"
check wait-main-option 1 "$(count '--main: after the merge')"
check wait-exit-codes 1 "$(count '6 cannot read the PR or its main runs.')"
check codex-exit-codes 1 "$(count 'else Codex'"'"'s exit status with no report.')"
check codex-exit-first-sentence 0 "$(count 'A non-zero exit that')"
# The prompt names the current orchestrator from <orchestrator dir>/orch-name (the brief names none); no file, no line.
check no-orch-name 0 "$(count 'Your orchestrator is')"
printf 'proj-boss-7\n' >"$tmp/orch-name"
run "$tmp/plain.md" "$tmp/common.md"
check orch-name-in-prompt 1 "$(count 'Your orchestrator is proj-boss-7')"
exit "$fail"
