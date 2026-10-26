#!/usr/bin/env bash
# Wait for an enqueued pull request (gh pr merge <n> --squash --auto) to land, and end on failure
# too (orchestration.md, Sessions): a failed required check, a dequeue or disarmed auto-merge, a
# closed PR, or the time limit. Run it as one background job; it never needs polling by an agent.
# Usage: wait-merge.sh <pr> [minutes] [--main]
#   --main: after the merge also wait for the squash's main push runs (Done = that run is green).
# Exit: 0 merged (and main green with --main), 1 required check failed, 2 closed, 3 dequeued or
# auto-merge disarmed, 4 time limit, 5 main push run failed, 6 cannot read the PR or its main runs.
# Config (optional): REPO (else the current checkout's repo), MERGE_WAIT_MIN (60), WAIT_INTERVAL_S (30).
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../lib/config.sh"
[ -z "${HARNESS_CONFIG:-}" ] || harness_load_config
pr=${1:-}; [[ $pr =~ ^[0-9]+$ ]] || die "usage: wait-merge.sh <pr> [minutes] [--main]"
shift; min=${MERGE_WAIT_MIN:-60} main=
for a in "$@"; do case "$a" in --main) main=1 ;; *[!0-9]*|'') die "bad argument: $a" ;; *) min=$a ;; esac; done
repo=${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}
owner=${repo%%/*} name=${repo#*/}
step=${WAIT_INTERVAL_S:-30}
deadline=$(( $(date +%s) + min * 60 ))
# shellcheck disable=SC2016  # GraphQL variables
q='query($o:String!,$n:String!,$p:Int!){repository(owner:$o,name:$n){pullRequest(number:$p){
  state isInMergeQueue autoMergeRequest{enabledAt} mergeCommit{oid}
  timelineItems(last:1,itemTypes:[REMOVED_FROM_MERGE_QUEUE_EVENT]){nodes{...on RemovedFromMergeQueueEvent{reason}}}}}}'
say() { echo "wait-merge #$pr: $*"; }
read_pr() {
  gh api graphql -f query="$q" -F o="$owner" -F n="$name" -F p="$pr" \
    --jq '.data.repository.pullRequest | [.state, (.isInMergeQueue|tostring), (.autoMergeRequest != null|tostring), (.mergeCommit.oid // "-"), (.timelineItems.nodes[0].reason // "-")] | @tsv'
}
armed_seen='' gone=0 fails=0
while :; do
  if ! row=$(read_pr 2>/dev/null); then
    fails=$((fails + 1)); [ "$fails" -lt 5 ] || { say "cannot read the PR (5 tries)"; exit 6; }
  else
    fails=0
    IFS=$'\t' read -r state queued armed sha left <<<"$row"
    case "$state" in
      MERGED) say "merged $sha"; break ;;
      CLOSED) say "closed without merge"; exit 2 ;;
    esac
    # GitHub records the queue exit (reason "merged") before state reads MERGED: keep waiting then.
    # Else neither queued nor armed on two reads in a row ends the wait.
    if [ "$queued" = true ] || [ "$armed" = true ] || [ "$left" = merged ]; then
      armed_seen=1 gone=0
    elif [ "$gone" -lt 1 ]; then gone=1
    elif [ -n "$armed_seen" ]; then say "left the merge queue (reason: $left) or auto-merge was disarmed (state $state)"; exit 3
    else say "not enqueued: run gh pr merge $pr --squash --auto first"; exit 3; fi
    # Required checks on the PR head (a merge-group failure shows up as a dequeue above).
    failed=$(gh pr checks "$pr" --repo "$repo" --required --json name,bucket \
      --jq '.[] | select(.bucket=="fail" or .bucket=="cancel") | .name' 2>/dev/null || true)
    if [ -n "$failed" ]; then say "a required check failed: $(tr '\n' ' ' <<<"$failed")"; exit 1; fi
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    say "time limit ${min} min; state: ${row:-unknown}"
    # Armed but not queued: disarm, so it cannot merge later unwatched. A queued PR stays queued.
    if [ "${armed:-}" = true ] && [ "${queued:-}" != true ]; then
      gh pr merge "$pr" --repo "$repo" --disable-auto || true
      # gh answers success without disarming a PR that entered the queue meanwhile: read back.
      if row=$(read_pr 2>/dev/null); then
        IFS=$'\t' read -r state queued armed sha left <<<"$row"
        if [ "$queued" = true ]; then say "entered the merge queue meanwhile: still queued, will merge unwatched"
        elif [ "$armed" = true ]; then say "auto-merge is still armed: disarm it by hand"
        else say "auto-merge disarmed (state $state)"; fi
      else say "cannot read the PR after --disable-auto: auto-merge state unknown"; fi
    fi
    exit 4
  fi
  sleep "$step"
done
[ -n "$main" ] || exit 0
# Main push runs of the squash commit: the first failed run ends the wait; else wait until none
# is pending. A repository without push workflows has none: after MAIN_RUN_GRACE_S (300) of none, stop.
# A failed read is never "no runs": 5 failed reads in a row end with exit 6.
none_until=$(( $(date +%s) + ${MAIN_RUN_GRACE_S:-300} )) fails=0
while :; do
  if ! runs=$(gh run list --repo "$repo" --commit "$sha" --event push --limit 100 --json databaseId,name,status,conclusion 2>/dev/null) \
      || ! jq -e 'type=="array"' <<<"$runs" >/dev/null 2>&1; then
    fails=$((fails + 1)); [ "$fails" -lt 5 ] || { say "cannot read main push runs of $sha (5 tries)"; exit 6; }
    sleep "$step"; continue
  fi
  fails=0
  bad=$(jq -r '.[]|select(.status=="completed" and .conclusion!="success" and .conclusion!="skipped")|"\(.name) \(.databaseId) \(.conclusion)"' <<<"$runs")
  if [ -n "$bad" ]; then say "main push run failed for $sha (one full gh run rerun <id>, never --failed):"; echo "$bad"; exit 5; fi
  if [ "$(jq 'length' <<<"$runs")" -gt 0 ] && [ "$(jq '[.[]|select(.status!="completed")]|length' <<<"$runs")" = 0 ]; then
    say "main push runs green for $sha"; exit 0
  fi
  if [ "$(jq 'length' <<<"$runs")" = 0 ] && [ "$(date +%s)" -ge "$none_until" ]; then
    say "no main push runs for $sha after ${MAIN_RUN_GRACE_S:-300} s"; exit 0
  fi
  [ "$(date +%s)" -lt "$deadline" ] || { say "time limit ${min} min waiting for main push runs of $sha"; exit 4; }
  sleep "$step"
done
