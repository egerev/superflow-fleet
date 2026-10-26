#!/usr/bin/env bash
# Codex review launch (reviews.md; orchestration.md, Background jobs): one bounded run (plus at most
# one retry at capacity, below) with --disable hooks, -c service_tier="default", a read-only sandbox
# and </dev/null; the 30-second start check (trust or usage error, early exit); the report must
# exist at the end.
# The task file is sent to the Codex model: put only the review packet in it, never secrets.
# Usage: review-codex.sh <astra|sol|model id> <task file> <report file> [--risk-path] [--minutes N] [--cd DIR]
#   --risk-path: start even when the Codex meter is over the Codex line (reviews.md, Codex budget).
# Exit: 0 report written (also when Codex then exits non-zero, e.g. "model at capacity": the report
# is kept and the log tail printed as a warning), 2 usage or a bad Codex line config, 3 failed start,
# 4 no report, 6 over the line, 124 time limit, 130 cancelled, else Codex's exit status with no
# report. A non-zero exit that is not the time limit, no report, an ERROR line with "capacity" in
# the last 3 log lines and a minute or more of the limit left: one retry in the time left (the first log is kept as
# <report>.log.1; each run has its own 30 s kill grace). The log is <report>.log.
# Config (optional): CODEX_ASTRA_MODEL, CODEX_SOL_MODEL, CODEX_SOL_EFFORT, REVIEW_TIMEOUT_MIN (60),
# CODEX_SANDBOX (read-only), CODEX_DAILY_POINTS and CODEX_LINE_OFFSET (the meter line),
# CODEX_EPHEMERAL (1: no session transcript under CODEX_HOME; such runs do not move the meter's
# reading).
set -euo pipefail
here=$(dirname "$0")
# shellcheck source=core/lib/config.sh
. "$here/../lib/config.sh"
[ -z "${HARNESS_CONFIG:-}" ] || harness_load_config
[ $# -ge 3 ] || { echo "usage: review-codex.sh <astra|sol|model> <task file> <report file> [--risk-path] [--minutes N] [--cd DIR]" >&2; exit 2; }
who=$1 task=$2 report=$3; shift 3
risk='' min=${REVIEW_TIMEOUT_MIN:-60} cd_dir=$PWD
while [ $# -gt 0 ]; do
  case "$1" in
    --risk-path) risk=1 ;;
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
mrc=0; "$here/codex-meter.sh" --check || mrc=$?
if [ "$mrc" = 1 ] && [ -z "$risk" ]; then echo "over the Codex line: only risk-path reviews start (--risk-path)" >&2; exit 6; fi
case "$mrc" in
  0|1) ;;
  3) echo "review-codex: no meter reading; starting anyway" >&2 ;;
  *) echo "STOP: Codex meter failed (exit $mrc): fix the Codex line in config.sh" >&2; exit 2 ;;
esac
t=$(timeout_bin)
log=$report.log
mkdir -p "$(dirname "$report")"
[ ! -d "$report" ] || { echo "review-codex: the report path is a directory: $report" >&2; exit 2; }
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
  # Cancelling this script stops the review too (timeout passes TERM on to Codex).
  trap 'kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; exit 130' INT TERM HUP
  echo "review-codex: $model pid $pid, log $log, report $report, limit $(($1 / 60)) min"
  # One start check about 30 s in; never a polling loop.
  for _ in 1 2 3 4 5 6; do kill -0 "$pid" 2>/dev/null || break; sleep 5; done
  # Only text before Codex's session banner counts: later the log holds the reviewer's own tool
  # output, which may contain any of these words.
  if ! grep -q '^session id:' "$log" \
      && grep -qiE 'not inside a trusted directory|^usage:|error: (unexpected|invalid)|unrecognized' "$log"; then
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    echo "review-codex: failed start:" >&2; tail -n 5 "$log" >&2; exit 3
  fi
  local rc=0; wait "$pid" || rc=$?
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
echo "review-codex: done, report $report"
