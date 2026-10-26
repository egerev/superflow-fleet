#!/usr/bin/env bash
# Orchestrator wake-ups as Superset automations (orchestration.md, Wake-ups): stored in Superset, they
# survive an orchestrator restart, unlike session crons. Superset 1.39 cannot deliver an automation's
# prompt into a terminal it did not start: a run starts a new agent session in the target workspace, or
# (--continue-session) reuses the session its previous run left; a closed one is replaced. So a wake is
# a relay: each run is one short claude turn in ORCH_WORKSPACE_ID (the same relay terminal while it
# lives) that runs `wake.sh fire`, which sends one WAKE line into the orchestrator terminal recorded in
# <orchestrator dir>/orch-terminal (written by `add`, `target` and orchestrator-restart.sh).
# Usage:
#   wake.sh add <slug> <every|once> <minutes> <purpose>   in the orchestrator's terminal (records it as the target,
#                                                         as `target` does, so paused wakes resume too)
#   wake.sh list                                          this workspace's wakes, for STATE.md "Wake automations:"
#   wake.sh rm <slug>|--all                               the wait is over: deletes the automation, closes its relay
#   wake.sh target [terminal id]                          records the orchestrator terminal (default: this terminal)
#                                                         and resumes wakes paused after a lost wake
#   wake.sh fire <slug> <every|once> <purpose>            run by the relay only
# A target that is not live: the wake is lost, logged to <orchestrator dir>/wake-lost.log, and the
# automation is paused until `target`. A run while the host is asleep or offline is skipped, not replayed.
# Config: ORCH_WORKSPACE_ID; optional WAKE_AGENT (automation agent preset, default claude).
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
harness_load_config
require ORCH_WORKSPACE_ID
is_uuid "$ORCH_WORKSPACE_ID" || die "ORCH_WORKSPACE_ID is not a UUID"
W=$ORCH_WORKSPACE_ID
project=$(basename "$ORCH_DIR"); project=${project%-orchestrator}
rec=$ORCH_DIR/orch-terminal
lost=$ORCH_DIR/wake-lost.log
usage() { die "usage: wake.sh add <slug> <every|once> <minutes> <purpose> | list | rm <slug>|--all | target [terminal id]"; }
check_slug() { [[ ${1:-} =~ ^[a-z0-9][a-z0-9-]{0,30}$ ]] || die "slug: lowercase letters, digits, dashes (max 31)"; }
# The purpose goes into the automation prompt and the WAKE line: no quotes or shell characters.
purpose_re='^[A-Za-z0-9 #.,:/_()-]{1,120}$'
check_purpose() { [[ ${1:-} =~ $purpose_re ]] || die "purpose: 1-120 of letters, digits, space and #.,:/_()-"; }
# utc_in <seconds>: an ISO 8601 UTC time that many seconds from now (GNU or BSD date).
utc_in() { local s=$(( $(date +%s) + $1 )); date -u -d "@$s" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$s" +%Y-%m-%dT%H:%M:%SZ; }
# live_ids: the live terminal IDs of ORCH_WORKSPACE_ID; a CLI error stops the script (never "not live").
# Every failure is an explicit `|| die`: set -e does not act inside a function called as a condition.
live_ids() {
  local j
  j=$(superset terminals list --local --workspace "$W" --json) || die "superset terminals list failed"
  # jq -e on the type check: an empty output (no JSON at all) fails too.
  jq -e '.sessions | type=="array"' <<<"$j" >/dev/null || die "superset terminals list: unexpected output"
  jq -r '.sessions[] | select(.exited==false) | .terminalId' <<<"$j"
}
live() { local ids; ids=$(live_ids) || die "cannot list terminals"; grep -qx "$1" <<<"$ids"; }
# wakes_json: this workspace's wake automations (the name prefix and the pinned workspace both match,
# so a same-named directory elsewhere never matches). A CLI error or a non-array stops the script.
wakes_json() {
  local j
  j=$(superset automations list -n "$project-wake-" --json) || die "superset automations list failed"
  jq -ce --arg p "$project-wake-" --arg w "$W" 'if type=="array" then [.[] | select((.name|startswith($p)) and .v2WorkspaceId==$w)] else error("not an array") end' <<<"$j" \
    || die "superset automations list: unexpected output"
}
# auto_id <name>: the id of the one automation with that name here; empty for none, a stop for several.
auto_id() {
  local ids
  ids=$(wakes_json | jq -r --arg n "$1" '.[] | select(.name==$n) | .id') || die "cannot list automations"
  [ "$(printf '%s' "$ids" | grep -c .)" -le 1 ] || die "several automations named $1: delete the extras with superset automations delete <id>"
  printf '%s' "$ids"
}

set_target() {
  local id paused
  is_uuid "$1" || die "terminal id is not a UUID: $1"
  live "$1" || die "terminal $1 is not live in ORCH_WORKSPACE_ID"
  printf '%s\n' "$1" >"$rec"; echo "OK: wakes go to terminal $1"
  paused=$(wakes_json | jq -r '.[] | select(.enabled==false) | .id') || die "cannot list automations"
  for id in $paused; do
    superset automations resume "$id" >/dev/null && echo "resumed $id" || echo "WARN: resume $id failed"
  done
  [ ! -s "$lost" ] || { echo "Lost wakes ($lost):"; tail -n 5 "$lost"; }
}
# rm_wake <slug>: closes the relay terminals the automation's runs used (never the recorded
# orchestrator terminal or this terminal), then deletes it. Any failure stops before the delete,
# so the automation and its run history stay for a retry.
rm_wake() {
  local name=$project-wake-$1 id target logs relays live_now t
  id=$(auto_id "$name") || die "cannot look up $name"; [ -n "$id" ] || die "no automation $name in this workspace"
  target=$(head -n 1 "$rec" 2>/dev/null || true)
  logs=$(superset automations logs "$id" --limit 100 --json) || die "superset automations logs $id failed: $name kept"
  jq -e 'type=="array"' <<<"$logs" >/dev/null || die "superset automations logs: unexpected output: $name kept"
  relays=$(jq -r --arg w "$W" '[.[] | select(.v2WorkspaceId==$w) | .terminalSessionId // empty] | unique | .[]' <<<"$logs")
  live_now=$(live_ids) || die "cannot list terminals: $name kept"
  for t in $relays; do
    is_uuid "$t" && [ "$t" != "$target" ] && [ "$t" != "${SUPERSET_TERMINAL_ID:-}" ] || continue
    grep -qx "$t" <<<"$live_now" || continue
    superset terminals close --local --workspace "$W" --terminal "$t" >/dev/null || die "closing relay $t failed: $name kept"
    echo "closed relay $t"
  done
  superset automations delete "$id" >/dev/null || die "superset automations delete $id failed"
  echo "OK: deleted $name"
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  target) [ $# -le 1 ] || usage; set_target "${1:-${SUPERSET_TERMINAL_ID:-}}" ;;
  add)
    [ $# -eq 4 ] || usage
    slug=$1 mode=$2 min=$3 purpose=$4
    check_slug "$slug"; check_purpose "$purpose"
    [[ $min =~ ^[0-9]{1,5}$ ]] || die "minutes: 5 to 10080"
    min=$((10#$min))
    [ "$min" -ge 5 ] && [ "$min" -le 10080 ] || die "minutes: 5 to 10080"
    [ "${SUPERSET_WORKSPACE_ID:-}" = "$W" ] || die "run add in the orchestrator's terminal (ORCH_WORKSPACE_ID)"
    name=$project-wake-$slug
    existing=$(auto_id "$name") || die "cannot look up $name"
    [ -z "$existing" ] || die "$name exists: wake.sh rm $slug first"
    # The first run is one interval from now in both modes, never at creation.
    case "$mode" in
      every) rrule="FREQ=MINUTELY;INTERVAL=$min" ;;
      once) rrule="FREQ=MINUTELY;COUNT=1" ;;
      *) usage ;;
    esac
    start=$(utc_in $(( min * 60 )))
    set_target "${SUPERSET_TERMINAL_ID:-}"
    # The purpose holds no quote (check_purpose), so single quotes keep it one argument.
    fire="$(printf %q "$ORCH_DIR/bin/wake.sh") fire $slug $mode '$purpose'"
    prompt="WAKE RELAY for $name (harness modules/superset/bin/wake.sh). You are not the orchestrator: ignore any ORCHESTRATOR SESSION text, read no file, message no one. Run exactly this one command, then reply with the single word done: $fire"
    out=$(superset automations create --name "$name" --rrule "$rrule" --dtstart "$start" --timezone UTC \
      --workspace "$W" --continue-session --agent "${WAKE_AGENT:-claude}" --prompt "$prompt" --json) \
      || die "superset automations create failed"
    id=$(jq -r '.id // empty' <<<"$out")
    is_uuid "$id" || die "automation create returned no id"
    # Read back: an exit 0 is not proof the schedule landed.
    superset automations get "$id" --json \
      | jq -re '"OK: \(.name) \(.rrule) next \(.nextRunAt) id \(.id)" | select(test("next null") | not)' \
      || die "$name has no next run: check superset automations get $id" ;;
  list)
    [ $# -eq 0 ] || usage
    wakes_json | jq -r '.[] | "\(.name) | \(.rrule) | next \(.nextRunAt // "none (fired)") | enabled \(.enabled) | \(.id)"' ;;
  rm)
    [ $# -eq 1 ] || usage
    if [ "$1" = --all ]; then
      names=$(wakes_json | jq -r '.[].name') || die "cannot list automations"
      for n in $names; do rm_wake "${n#"$project"-wake-}"; done
    else check_slug "$1"; rm_wake "$1"; fi ;;
  fire)
    [ $# -eq 3 ] || die "usage: wake.sh fire <slug> <every|once> <purpose>"
    slug=$1 mode=$2 purpose=$3
    check_slug "$slug"; check_purpose "$purpose"; name=$project-wake-$slug
    target=$(head -n 1 "$rec" 2>/dev/null || true)
    [ "$target" != "${SUPERSET_TERMINAL_ID:-}" ] || die "the recorded orchestrator terminal is this relay"
    ids=$(live_ids) || die "cannot list terminals: wake $name not sent"
    if ! is_uuid "$target" || ! grep -qx "$target" <<<"$ids"; then
      # Lost: log it and pause, so a dead target does not cost a relay turn every interval.
      printf '%s %s: target %s not live, wake lost, paused\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name" "${target:-none}" >>"$lost"
      id=$(auto_id "$name" || true); [ -z "$id" ] || superset automations pause "$id" >/dev/null || true
      die "orchestrator terminal ${target:-none} is not live: wake $name lost and paused (wake.sh target resumes it)"
    fi
    if [ "$mode" = once ]; then tail="one-shot, removed now"; else tail="when this wait is over: $ORCH_DIR/bin/wake.sh rm $slug"; fi
    superset terminals send --local --workspace "$W" --terminal "$target" --text "WAKE $name: $purpose ($tail)" >/dev/null \
      || die "superset terminals send failed: wake $name lost"
    echo "OK: sent WAKE $name to $target"
    # A fired one-shot removes itself; its relay terminal (this one) closes last.
    if [ "$mode" = once ]; then
      rm_wake "$slug"
      ! is_uuid "${SUPERSET_TERMINAL_ID:-}" || superset terminals close --local --workspace "$W" --terminal "$SUPERSET_TERMINAL_ID" >/dev/null
    fi ;;
  *) usage ;;
esac
