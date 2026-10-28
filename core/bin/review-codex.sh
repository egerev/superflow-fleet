#!/usr/bin/env bash
# Codex review launch (reviews.md; orchestration.md, Background jobs): one bounded run (plus at most
# one retry at capacity, below) with --disable hooks, -c service_tier="default", a read-only sandbox
# and </dev/null; the 30-second start check (trust or usage error, early exit); the report must
# exist at the end; the round count per packet (reviews.md, Rounds 4-5) and a status file.
# The task file is sent to the Codex model: put only the review packet in it, never secrets.
# Usage: review-codex.sh <astra|sol|model id> <task file> <report file> [--risk-path] [--over-cap REASON] [--minutes N] [--cd DIR]
#   --risk-path: start even when the Codex meter is over the Codex line (reviews.md, Codex budget).
#   --over-cap REASON: the orchestrator's one extra round (round 4) for this packet; the reason is recorded.
# Exit: 0 report written (also when Codex then exits non-zero, e.g. "model at capacity": the report
# is kept and the log tail printed as a warning), 2 usage or a bad Codex line config, 3 failed start,
# 4 no report, 6 over the line, 7 round past the cap, 8 another review of the packet runs, 124 time
# limit, 130 cancelled, else Codex's exit
# status with no report. A non-zero exit that is not the time limit, no report, an ERROR line with
# "capacity" in the last 3 log lines and a minute or more of the limit left: one retry in the time
# left (the first log is kept as <report>.log.1; each run has its own 30 s kill grace). The log is
# <report>.log.
# Rounds: the packet is the task file's directory (one per pull request, reused by its rechecks);
# <packet>/review-rounds gets one line per review that wrote a report. Rounds 1-3 (r1, r2 and the one
# scoped recheck after the cap) start by themselves; round 4 needs --over-cap; round 5 never starts
# (the open finding goes to the owner). One review per packet runs at a time (<packet>/review-rounds.lock,
# removed only by its holder; one left by a killed run is removed by hand, as exit 8 says).
# Status: <report>.status holds `exit: <starting|running|code>`, `round:`, `verdict:` (the report's
# last VERDICT line, or none) and `report:`. `running` means the start check passed: a caller waits
# on this file instead of sleep and tail.
# Config (optional): CODEX_ASTRA_MODEL, CODEX_SOL_MODEL, CODEX_SOL_EFFORT, REVIEW_TIMEOUT_MIN (60),
# CODEX_SANDBOX (read-only), CODEX_DAILY_POINTS and CODEX_LINE_OFFSET (the meter line),
# CODEX_EPHEMERAL (1: no session transcript under CODEX_HOME; such runs do not move the meter's
# reading).
set -euo pipefail
here=$(dirname "$0")
# shellcheck source=core/lib/config.sh
. "$here/../lib/config.sh"
[ -z "${HARNESS_CONFIG:-}" ] || harness_load_config
[ $# -ge 3 ] || { echo "usage: review-codex.sh <astra|sol|model> <task file> <report file> [--risk-path] [--over-cap REASON] [--minutes N] [--cd DIR]" >&2; exit 2; }
who=$1 task=$2 report=$3; shift 3
risk='' over='' min=${REVIEW_TIMEOUT_MIN:-60} cd_dir=$PWD
while [ $# -gt 0 ]; do
  case "$1" in
    --risk-path) risk=1 ;;
    --over-cap) over=$(printf '%s' "${2:?}" | tr '\n' ' '); shift ;;
    --minutes) min=${2:?}; shift ;;
    --cd) cd_dir=${2:?}; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
[[ $min =~ ^[1-9][0-9]*$ ]] || die "--minutes takes a positive number"
[ -s "$task" ] || die "empty or missing task file: $task"
[ -d "$cd_dir" ] || die "no directory: $cd_dir"
extra=()
case "$who" in
  astra) model=${CODEX_ASTRA_MODEL:-gpt-6-astra} ;;
  sol) model=${CODEX_SOL_MODEL:-gpt-6.1-sol}; extra=(-c "model_reasoning_effort=${CODEX_SOL_EFFORT:-xhigh}") ;;
  *) model=$who ;;
esac
[[ $model =~ ^[A-Za-z0-9._-]+$ ]] || die "unexpected model id: $model"
log=$report.log
mkdir -p "$(dirname "$report")"
[ ! -d "$report" ] || { echo "review-codex: the report path is a directory: $report" >&2; exit 2; }
packet=$(dirname "$task")
rounds=$packet/review-rounds lock=$packet/review-rounds.lock
round='?' locked='' pid=''
# write_status STATE: the status file (header, Status).
write_status() {
  local v; v=$(grep -oE 'VERDICT:.*' "$report" 2>/dev/null | tail -n 1 || true)
  printf 'exit: %s\nround: %s\nverdict: %s\nreport: %s\n' "$1" "$round" "${v:-none}" "$report" >"$report.status"
}
on_exit() {
  local rc=$?
  # Only the lock holder writes: a refused parallel launch leaves the running review's status alone.
  [ -n "$locked" ] || return 0
  write_status "$rc"
  rm -f "$lock"
}
# Cancelling this script stops the review too (timeout passes TERM on to Codex). Both traps are in
# place before the first status line, so a signal never leaves `starting` or a false `exit: 0`.
trap on_exit EXIT
# `|| true`: under errexit the killed child's status (143) would end the trap before `exit 130`.
trap '[ -z "$pid" ] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }; exit 130' INT TERM HUP
# One review per packet at a time (Sol r1: two parallel --over-cap launches both took round 4): the
# lock file holds from the count to the round line. It is created with O_EXCL (noclobber) and only
# its holder removes it: no automatic takeover, since every takeover scheme raced (Sol r2, r3). A
# holder killed with KILL leaves it; the message names the dead pid and the one manual step.
if ( set -C; echo $$ >"$lock" ) 2>/dev/null; then
  locked=1
else
  lp=$(cat "$lock" 2>/dev/null || true)
  if [ -n "$lp" ] && ! kill -0 "$lp" 2>/dev/null; then
    echo "review-codex: $lock is left by pid $lp, which is gone: if no review of $packet runs, rm $lock and launch again" >&2
  else
    echo "review-codex: another review of $packet is running${lp:+ (pid $lp)}" >&2
  fi
  exit 8
fi
round=1; [ ! -f "$rounds" ] || round=$(($(grep -c . "$rounds" || true) + 1))
write_status starting
# Retro 10-26 item 6 (owner 10-27): the scoped recheck after the cap runs without a go-ahead; the
# orchestrator grants at most one more round per pull request.
if [ "$round" -ge 5 ]; then
  echo "review-codex: round $round of $packet: past the over-cap round; the open finding is BLOCKED: a smaller scope, a follow-up card or a revert, the orchestrator's pick (reviews.md, Rounds 5)" >&2; exit 7
elif [ "$round" = 4 ] && [ -z "$over" ]; then
  echo "review-codex: round 4 of $packet is past the cap: needs the orchestrator's --over-cap \"<reason>\" (reviews.md, Rounds 5)" >&2; exit 7
elif [ "$round" -lt 4 ] && [ -n "$over" ]; then
  echo "review-codex: round $round is within the cap; --over-cap ignored" >&2; over=''
fi
mrc=0; "$here/codex-meter.sh" --check || mrc=$?
if [ "$mrc" = 1 ] && [ -z "$risk" ]; then echo "over the Codex line: only risk-path reviews start (--risk-path)" >&2; exit 6; fi
case "$mrc" in
  0|1) ;;
  3) echo "review-codex: no meter reading; starting anyway" >&2 ;;
  *) echo "STOP: Codex meter failed (exit $mrc): fix the Codex line in config.sh" >&2; exit 2 ;;
esac
t=$(timeout_bin)
[ -z "${CODEX_EPHEMERAL:-}" ] || extra+=(--ephemeral)
end=$((SECONDS + min * 60))
# run_codex SECONDS: one bounded Codex run into $report and $log; returns Codex's exit status.
run_codex() {
  # Called under ||, so errexit is off here: an unwritable report stops explicitly.
  : >"$report" || { echo "review-codex: cannot write the report: $report" >&2; exit 2; }
  # --kill-after: a Codex that ignores TERM is killed 30 s later. Codex keeps its session transcript
  # under CODEX_HOME/sessions (the meter reads it); CODEX_EPHEMERAL=1 runs without one.
  "$t" --kill-after=30 "$1" codex exec --disable hooks -m "$model" -c 'service_tier="default"' ${extra[@]+"${extra[@]}"} \
    -s "${CODEX_SANDBOX:-read-only}" -C "$cd_dir" -o "$report" "$(cat "$task")" </dev/null >"$log" 2>&1 &
  pid=$!
  echo "review-codex: $model round $round, pid $pid, log $log, report $report, limit $(($1 / 60)) min"
  # One start check about 30 s in; never a polling loop.
  for _ in 1 2 3 4 5 6; do kill -0 "$pid" 2>/dev/null || break; sleep 5; done
  # Only text before Codex's session banner counts: later the log holds the reviewer's own tool
  # output, which may contain any of these words.
  if ! grep -q '^session id:' "$log" \
      && grep -qiE 'not inside a trusted directory|^usage:|error: (unexpected|invalid)|unrecognized' "$log"; then
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    echo "review-codex: failed start:" >&2; tail -n 5 "$log" >&2; exit 3
  fi
  write_status running
  local rc=0; wait "$pid" || rc=$?
  pid=''
  return "$rc"
}
rc=0; run_codex "$((min * 60))" || rc=$?
# Incident (10-26): Codex exit 1 "model at capacity". With no report yet, one retry when a minute
# or more of the limit is left. Only Codex's own ERROR line counts (an optional [timestamp] before
# it), not the reviewer's tool output that mentions the word.
if [ "$rc" != 0 ] && [ "$rc" != 124 ] && [ "$rc" != 137 ] && [ ! -s "$report" ] \
    && tail -n 3 "$log" | grep -qiE '^(\[[^]]*\] *)?error\b.*capacity' && [ $((end - SECONDS)) -ge 60 ]; then
  echo "review-codex: codex exit $rc at capacity, one retry:" >&2; tail -n 3 "$log" >&2
  mv "$log" "$log.1"
  rc=0; run_codex "$((end - SECONDS))" || rc=$?
fi
[ "$rc" != 124 ] && [ "$rc" != 137 ] || { echo "review-codex: time limit ${min} min" >&2; exit 124; }
# The same incident had a complete report: a written report counts, Codex's exit status is a warning.
if [ "$rc" != 0 ] && [ -f "$report" ] && [ -s "$report" ]; then
  echo "review-codex: WARNING codex exit $rc after the report was written; report kept:" >&2; tail -n 5 "$log" >&2
elif [ "$rc" != 0 ]; then
  echo "review-codex: codex exit $rc:" >&2; tail -n 5 "$log" >&2; exit "$rc"
fi
[ -f "$report" ] && [ -s "$report" ] || { echo "review-codex: no report (a missing report is a failed review)" >&2; exit 4; }
echo "r$round $(date -u +%FT%TZ) $model $(basename "$report")${over:+ over-cap: $over}" >>"$rounds"
echo "review-codex: done, round $round, report $report"
