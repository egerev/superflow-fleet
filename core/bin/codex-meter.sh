#!/usr/bin/env bash
# Codex meter (reviews.md, Codex budget): the shared weekly meter from the newest Codex session
# file and the line it is held to. One point is one percent.
# Pace line (default): 100% spread evenly over the meter window (window_minutes) plus the add-on,
# so line = CODEX_LINE_OFFSET + 100 x elapsed / window, at most 100. The meter counts every
# project's use and the rate_limits record has no per-project split, so this line is for the
# whole meter, not one project's share.
# Points line (CODEX_DAILY_POINTS=<n>): CODEX_LINE_OFFSET + n x days since the window started
# (resets_at - window), the 0.2 line, kept for configs that still set a number.
# Usage: codex-meter.sh [--check]   --check: exit 1 when the meter is over the line.
# Exit 3: no reading (no Codex sessions yet). Exit 2: CODEX_DAILY_POINTS is neither a number nor
# pace, or CODEX_LINE_OFFSET is not a number.
# Config (optional): CODEX_DAILY_POINTS (unset or "pace": pace line; a number: points line),
# CODEX_LINE_OFFSET (90, the owner's add-on of 10-24; both lines); CODEX_HOME (~/.codex).
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../lib/config.sh"
[ -z "${HARNESS_CONFIG:-}" ] || harness_load_config
bad() { echo "codex meter: $*" >&2; exit 2; }
pts=${CODEX_DAILY_POINTS:-pace}
off=${CODEX_LINE_OFFSET:-90}
[ "$pts" = pace ] || [[ $pts =~ ^[0-9]+([.][0-9]+)?$ ]] || bad "CODEX_DAILY_POINTS must be a number or pace, not '$pts'"
[[ $off =~ ^[0-9]+([.][0-9]+)?$ ]] || bad "CODEX_LINE_OFFSET must be a number, not '$off'"
dir=${CODEX_HOME:-$HOME/.codex}/sessions
nodata() { echo "codex meter: $*" >&2; exit 3; }
[ -d "$dir" ] || nodata "no Codex sessions under $dir"
# Newest session files first; the first with a rate_limits record holds the reading.
rl=
while IFS= read -r f; do
  rl=$(grep '"rate_limits"' "$f" 2>/dev/null | tail -n 1 | jq -c '.payload.rate_limits // empty' 2>/dev/null || true)
  [ -z "$rl" ] || break
done < <(find "$dir" -name '*.jsonl' -mtime -8 -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n 20)
[ -n "$rl" ] || nodata "no rate_limits record in the newest Codex session files"
used=$(jq -r '.primary.used_percent' <<<"$rl")
resets=$(jq -r '.primary.resets_at' <<<"$rl")
win=$(jq -r '.primary.window_minutes' <<<"$rl")
now=$(date +%s)
echo "codex meter: used ${used}% of the shared window; resets $(date -u -r "$resets" +%m-%dT%H:%MZ 2>/dev/null || date -u -d "@$resets" +%m-%dT%H:%MZ)"
# A record without a positive window_minutes has no pace: the pace line has no reading, the
# points line keeps its 0.2 value. Lines stay unrounded for the comparison; only output rounds.
pace=$(awk -v now="$now" -v r="$resets" -v w="$win" 'BEGIN { if (!(w + 0 > 0)) exit
  e = (now - (r - w * 60)) / (w * 60); if (e < 0) e = 0; if (e > 1) e = 1; printf "%.10f", 100 * e }')
pace1=; [ -z "$pace" ] || pace1=$(awk -v p="$pace" 'BEGIN { printf "%.1f", p }')
if [ "$pts" = pace ]; then
  [ -n "$pace" ] || nodata "no window_minutes in the rate_limits record"
  line=$(awk -v o="$off" -v p="$pace" 'BEGIN { l = o + p; if (l > 100) l = 100; printf "%.10f", l }')
  kind="pace line (whole-meter pace ${pace1}% + $off)"
else
  line=$(awk -v o="$off" -v p="$pts" -v now="$now" -v r="$resets" -v w="$win" \
    'BEGIN { d = (now - (r - w * 60)) / 86400; if (d < 0) d = 0; printf "%.10f", o + p * d }')
  kind="points line ($pts a day + $off); whole-meter pace ${pace1:-n/a}"; [ -z "$pace" ] || kind+="%"
fi
over=$(awk -v u="$used" -v l="$line" 'BEGIN { print (u > l) ? 1 : 0 }')
line=$(awk -v l="$line" 'BEGIN { printf "%.1f", l }')
if [ "$over" = 1 ]; then echo "line ${line}%: OVER (only risk-path reviews start); $kind"
else echo "line ${line}%: under; $kind"; fi
[ "${1:-}" != --check ] || [ "$over" = 0 ]
