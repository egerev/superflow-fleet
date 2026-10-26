#!/usr/bin/env bash
# Fixture test for core/bin/review-codex.sh exit handling: a stub `codex` replays one line per call
# (`<exit> <report|-> <log text>`), a no-op `sleep` skips the start-check wait, an empty CODEX_HOME
# gives the meter no reading. Run: bash core/tests/review-codex.test.sh
set -euo pipefail
script=${REVIEW_CODEX:-$(cd "$(dirname "$0")/.." && pwd)/bin/review-codex.sh}  # REVIEW_CODEX: another copy
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/codex" <<'STUB'
#!/usr/bin/env bash
n=$(cat "$FIX.n" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$FIX.n"
read -r rc rep text < <(sed -n "${n}p" "$FIX")
while [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done
echo "session id: stub"
[ "$rep" = - ] || echo "$rep" >"$out"
printf '%b\n' "$text"
exit "$rc"
STUB
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/sleep"
chmod 755 "$tmp/bin/codex" "$tmp/bin/sleep"
echo "review this" >"$tmp/task"
fail=0
case_() { # name expected-exit expected-calls fixture-lines...
  local name=$1 want=$2 calls=$3 got=0; shift 3
  printf '%s\n' "$@" >"$tmp/$name"
  PATH="$tmp/bin:$PATH" FIX="$tmp/$name" CODEX_HOME="$tmp/home" \
    bash "$script" sol "$tmp/task" "$tmp/$name.report" >"$tmp/$name.out" 2>&1 || got=$?
  local n; n=$(cat "$tmp/$name.n" 2>/dev/null || echo 0)
  if [ "$got" = "$want" ] && [ "$n" = "$calls" ]; then echo "ok   $name"
  else echo "FAIL $name: exit $got want $want, codex calls $n want $calls"; sed 's/^/     /' "$tmp/$name.out"; fail=1; fi
}
case_ clean 0 1 "0 verdict ok"
case_ no-report 4 1 "0 - done"
# Incident (10-26): exit 1 "model at capacity" after the report was written.
case_ report-then-exit1 0 1 "1 verdict ERROR: model at capacity"
case_ capacity-retry 0 2 "1 - ERROR: model at capacity" "0 verdict ok"
case_ capacity-twice 1 2 "1 - ERROR: model at capacity" "1 - ERROR: model at capacity"
case_ other-error 1 1 "1 - ERROR: stream disconnected"
# "capacity" in the reviewer's earlier tool output, not in the last 3 lines: no retry.
case_ capacity-in-output 1 1 '1 - grep capacity review-codex.sh\nline\nline\nERROR: stream disconnected'
case_ capacity-tool-line 1 1 '1 - tool output: capacity\nERROR: stream disconnected'
# A report path that is a directory stops before Codex starts.
mkdir "$tmp/dir.report"
case_ dir 2 0 "0 verdict ok"
[ -s "$tmp/capacity-retry.report.log.1" ] || { echo "FAIL capacity-retry: first log not kept"; fail=1; }
grep -q WARNING "$tmp/report-then-exit1.out" || { echo "FAIL report-then-exit1: no warning"; fail=1; }
exit "$fail"
