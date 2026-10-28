#!/usr/bin/env bash
# Fixture test for core/bin/review-codex.sh exit handling, round count and status file: a stub `codex`
# replays one line per call (`<exit> <report|-> <log text>`), a no-op `sleep` skips the start-check
# wait, an empty CODEX_HOME gives the meter no reading. Each case has its own packet directory.
# Run: bash core/tests/review-codex.test.sh
set -euo pipefail
script=${REVIEW_CODEX:-$(cd "$(dirname "$0")/.." && pwd)/bin/review-codex.sh}  # REVIEW_CODEX: another copy
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/codex" <<'STUB'
#!/usr/bin/env bash
n=$(cat "$FIX.n" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$FIX.n"
read -r rc rep text < <(sed -n "${n}p" "$FIX")
while [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done
# rep `nosession`: no session banner and no report (a failed start); text BLOCK: run until killed.
[ "$rep" = nosession ] || echo "session id: stub"
[ "$text" != BLOCK ] || exec /bin/sleep 30
[ "$rep" = - ] || [ "$rep" = nosession ] || echo "$rep" >"$out"
printf '%b\n' "$text"
exit "$rc"
STUB
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/sleep"
chmod 755 "$tmp/bin/codex" "$tmp/bin/sleep"
fail=0
# run_ packet report expected-exit expected-calls [args...]: one script run in packet dir $tmp/<packet>
# against the fixture $tmp/<packet>.fix.
run_() {
  local p=$tmp/$1 name=$1/$2 want=$3 calls=$4 got=0; shift 4
  mkdir -p "$p"; [ -s "$p/task" ] || echo "review this" >"$p/task"
  PATH="$tmp/bin:$PATH" FIX="$p.fix" CODEX_HOME="$tmp/home" \
    bash "$script" sol "$p/task" "$p/$(basename "$name")" "$@" >"$p/$(basename "$name").out" 2>&1 || got=$?
  local n; n=$(cat "$p.fix.n" 2>/dev/null || echo 0)
  if [ "$got" = "$want" ] && [ "$n" = "$calls" ]; then echo "ok   $name"
  else echo "FAIL $name: exit $got want $want, codex calls $n want $calls"; sed 's/^/     /' "$p/$(basename "$name").out"; fail=1; fi
}
case_() { # name expected-exit expected-calls fixture-lines...
  local name=$1 want=$2 calls=$3; shift 3
  printf '%s\n' "$@" >"$tmp/$name.fix"
  run_ "$name" report "$want" "$calls"
}
case_ clean 0 1 "0 VERDICT:APPROVE ok"
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
mkdir -p "$tmp/dir/report"
case_ dir 2 0 "0 verdict ok"
[ -s "$tmp/capacity-retry/report.log.1" ] || { echo "FAIL capacity-retry: first log not kept"; fail=1; }
grep -q WARNING "$tmp/report-then-exit1/report.out" || { echo "FAIL report-then-exit1: no warning"; fail=1; }
# Status file: final exit code and the report's VERDICT line.
expect() { # label file pattern
  if grep -qF -- "$3" "$2" 2>/dev/null; then echo "ok   $1"; else echo "FAIL $1: no '$3' in $2"; fail=1; fi
}
expect clean-status-exit "$tmp/clean/report.status" "exit: 0"
expect clean-status-verdict "$tmp/clean/report.status" "verdict: VERDICT:APPROVE"
expect no-report-status "$tmp/no-report/report.status" "exit: 4"
expect no-report-verdict "$tmp/no-report/report.status" "verdict: none"
# Round count (reviews.md, Rounds 5): a failed run counts no round; rounds 1-3 start by themselves,
# round 4 needs --over-cap, round 5 never starts.
printf '%s\n' "0 - done" "0 r1 ok" "0 r2 ok" "0 r3 ok" "0 r4 ok" "0 r5 ok" >"$tmp/pr.fix"
run_ pr fail 4 1
run_ pr r1 0 2
run_ pr r2 0 3
run_ pr r3 0 4 --over-cap "within the cap"
run_ pr r4-no-grant 7 4
expect r4-no-grant-status "$tmp/pr/r4-no-grant.status" "exit: 7"
run_ pr r4 0 5 --over-cap "fix of a new blocking in r3"
run_ pr r5 7 5 --over-cap "again"
if [ "$(grep -c . "$tmp/pr/review-rounds")" = 4 ]; then echo "ok   pr/rounds-file"
else echo "FAIL pr/rounds-file:"; sed 's/^/     /' "$tmp/pr/review-rounds"; fail=1; fi
expect r3-no-over-cap-record "$tmp/pr/review-rounds" "r3 "
grep -q "^r3 .*over-cap" "$tmp/pr/review-rounds" && { echo "FAIL r3 recorded as over-cap"; fail=1; }
expect r4-over-cap-record "$tmp/pr/review-rounds" "over-cap: fix of a new blocking in r3"
expect r4-status-round "$tmp/pr/r4.status" "round: 4"
# Status and accounting on the other exits (Sol r1): a final code, never `starting`/`running`, no round.
no_round() { if [ -e "$tmp/$1/review-rounds" ]; then echo "FAIL $1: counted a round"; fail=1; else echo "ok   $1/no-round"; fi; }
case_ failed-start 3 1 "1 nosession usage: codex exec"
expect failed-start-status "$tmp/failed-start/report.status" "exit: 3"
no_round failed-start
case_ time-limit 124 1 "124 - slow"
expect time-limit-status "$tmp/time-limit/report.status" "exit: 124"
no_round time-limit
no_round no-report
if [ "$(grep -c . "$tmp/capacity-retry/review-rounds")" = 1 ]; then echo "ok   capacity-retry/one-round"
else echo "FAIL capacity-retry: retry counted twice"; fail=1; fi
# Over the Codex line: a copy of the script beside a meter stub that reports "over".
mkdir -p "$tmp/tree/bin" "$tmp/tree/lib"
cp "$script" "$tmp/tree/bin/review-codex.sh"; cp "$(dirname "$script")/../lib/config.sh" "$tmp/tree/lib/"
printf '#!/bin/sh\nexit 1\n' >"$tmp/tree/bin/codex-meter.sh"; chmod 755 "$tmp/tree/bin/codex-meter.sh"
printf '%s\n' "0 verdict ok" >"$tmp/over-line.fix"
script_main=$script; script=$tmp/tree/bin/review-codex.sh
run_ over-line report 6 0
script=$script_main
expect over-line-status "$tmp/over-line/report.status" "exit: 6"
# Cancellation: TERM while Codex runs gives exit 130 in the status, frees the lock, counts no round.
mkdir -p "$tmp/cancel"; echo "review this" >"$tmp/cancel/task"; printf '%s\n' "0 - BLOCK" >"$tmp/cancel.fix"
PATH="$tmp/bin:$PATH" FIX="$tmp/cancel.fix" CODEX_HOME="$tmp/home" \
  bash "$script" sol "$tmp/cancel/task" "$tmp/cancel/report" >"$tmp/cancel/out" 2>&1 & cpid=$!
seen=''
for _ in $(seq 100); do grep -q "exit: running" "$tmp/cancel/report.status" 2>/dev/null && { seen=1; break; }; sleep 0.1; done
kill -TERM "$cpid"; got=0; wait "$cpid" || got=$?
if [ -n "$seen" ] && [ "$got" = 130 ]; then echo "ok   cancel"; else echo "FAIL cancel: running seen '${seen}', exit $got"; fail=1; fi
expect cancel-status "$tmp/cancel/report.status" "exit: 130"
no_round cancel
if [ -e "$tmp/cancel/review-rounds.lock" ]; then echo "FAIL cancel: lock left"; fail=1; else echo "ok   cancel/unlocked"; fi
# A live lock refuses a parallel launch (exit 8) and leaves that review's status alone. A dead
# holder's lock is never taken over (Sol r2, r3: takeovers raced): exit 8 names the manual step.
mkdir -p "$tmp/busy"; echo $$ >"$tmp/busy/review-rounds.lock"
printf '%s\n' "0 verdict ok" >"$tmp/busy.fix"
run_ busy report 8 0
if [ -e "$tmp/busy/report.status" ]; then echo "FAIL busy: wrote a status"; fail=1; else echo "ok   busy/no-status"; fi
echo 999999 >"$tmp/busy/review-rounds.lock"
run_ busy stale 8 0
expect busy-stale-hint "$tmp/busy/stale.out" "which is gone: if no review of"
expect busy-stale-kept "$tmp/busy/review-rounds.lock" "999999"
rm "$tmp/busy/review-rounds.lock"
run_ busy free 0 1
if [ -e "$tmp/busy/review-rounds.lock" ]; then echo "FAIL busy: lock left"; fail=1; else echo "ok   busy/unlocked"; fi
# Parallel launches: one packet with r1-r3 done, three --over-cap launches at once, 10 times: one r4 each.
# shellcheck disable=SC2016  # the stub's own variables
printf '#!/bin/sh\necho "session id: s"\nwhile [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done\necho VERDICT:ok >"$out"\n' >"$tmp/bin/codex"
for i in $(seq 10); do
  d=$tmp/race$i; mkdir "$d"; echo t >"$d/task"; printf 'r1\nr2\nr3\n' >"$d/review-rounds"
  for j in 1 2 3; do
    PATH="$tmp/bin:$PATH" CODEX_HOME="$tmp/home" bash "$script" sol "$d/task" "$d/rep$j" --over-cap x >"$d/out$j" 2>&1 &
  done
  wait
  [ "$(grep -c '^r4' "$d/review-rounds")" = 1 ] && [ ! -e "$d/review-rounds.lock" ] \
    || { echo "FAIL race$i: $(grep -c '^r4' "$d/review-rounds") r4 lines or a lock left"; fail=1; }
done
[ "$fail" = 1 ] || echo "ok   race/one-r4"
exit "$fail"
