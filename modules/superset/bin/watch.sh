#!/usr/bin/env bash
# Zero-token orchestrator watcher: prints one line only when something worth a look changes.
# Watches open and recently merged PRs, failing checks, the project's worker workspaces, and the
# state of each worker agent (`superset snapshot`, `superset agents explain`; Superset CLI 1.39+):
# AGENT lines when one goes idle, blocked or exited or its terminal is gone, STALL when a working
# turn sends no agent event for STALL_MIN minutes, SNAPSHOT when the agent states cannot be read.
# Run it under the Monitor tool; quiet periods cost nothing.
# Config: REPO, SUPERSET_PROJECT_ID; optional ORCH_WORKSPACE_ID (not watched),
# STALL_MIN (30), WATCH_INTERVAL_S (120), WATCH_STATE_DIR (${TMPDIR}/<project>-watch).
set -uo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
harness_load_config
require REPO SUPERSET_PROJECT_ID
stall=${STALL_MIN:-30}
state_dir=${WATCH_STATE_DIR:-${TMPDIR:-/tmp}/$(basename "$ORCH_DIR")-watch}
mkdir -p "$state_dir"
prev=""
snapwarn=0
# A decimal number without a leading zero, at most 12 digits (state records, event times).
is_num() { case "$1" in ''|*[!0-9]*|0?*) return 1 ;; esac; [ "${#1}" -le 12 ]; }
while true; do
  prok=1
  prs=$(gh pr list --repo "$REPO" --state open --limit 200 --json number,isDraft,statusCheckRollup \
    -q '.[] | "PR#\(.number) draft=\(.isDraft) failing=\([.statusCheckRollup[]? | select(.conclusion=="FAILURE")] | length > 0)"' 2>/dev/null | sort) || prok=0
  merged=$(gh pr list --repo "$REPO" --state merged --limit 5 --json number -q '.[].number' 2>/dev/null | tr '\n' ' ') || prok=0
  wsok=1
  wsjson=$(superset workspaces list --local --project "$SUPERSET_PROJECT_ID" --json 2>/dev/null) || wsjson=""
  jq -e 'type == "array"' >/dev/null 2>&1 <<<"$wsjson" || { wsjson='[]'; wsok=0; }
  ws=$(jq -r '[.[] | select(.archivedAt==null) | .name] | sort | join(",")' <<<"$wsjson")
  now="$prs
merged: $merged
workspaces: $ws"
  if [ "$now" != "$prev" ]; then
    # Report only the changed lines, never the full state.
    diff <(printf '%s\n' "$prev") <(printf '%s\n' "$now") | grep '^>' | sed 's/^> /CHANGE /'
    # An open PR that vanished and is not among the merged ones was closed without a merge
    # (not judged when a gh read failed: both lists are then empty).
    [ "$prok" = 1 ] && while read -r gone; do
      case "$gone" in "PR#"*) ;; *) continue ;; esac
      num=${gone%% *}; num=${num#PR#}
      case " $merged " in *" $num "*) continue ;; esac
      grep -q "^PR#$num " <<<"$prs" || echo "CHANGE PR#$num closed without a merge"
    done < <(diff <(printf '%s\n' "$prev") <(printf '%s\n' "$now") | sed -n 's/^< //p')
    prev="$now"
  fi
  # Agent states from one snapshot of this machine (Superset 1.39): report a worker agent that
  # went idle (turn ended: a DONE, a question, or a silent stop on an API error), blocked (waits
  # for input) or exited, and a terminal that is gone. A turn "working" for STALL_MIN gets one
  # `agents explain`; with no agent event for STALL_MIN it is a STALL (a hung tool, or an interrupt
  # typed outside Superset that left the state on working), once per last event.
  # State file per terminal: <state> <agent> <since> <reported event> <workspace id> <name>.
  # Rows are built in full before any state changes; a failed or malformed snapshot changes nothing.
  snap=$(superset snapshot --json 2>/dev/null) || snap=""
  ok=$wsok rows=""
  if [ "$ok" = 1 ] && jq -e '.workspaces | type == "array"' >/dev/null 2>&1 <<<"$snap"; then
    rows=$(jq -r --argjson ws "$(jq -c --arg o "${ORCH_WORKSPACE_ID:-}" \
        '[.[] | select(.archivedAt==null and .id!=$o) | .id]' <<<"$wsjson")" \
      '.workspaces[] | select(.id as $i | $ws | index($i)) | .id as $w | .name as $n
       | if (.terminals | type) == "array" then .terminals[] else error("bad terminals") end
       | if type == "object" then . else error("bad terminal") end
       | select(.agent != null) | [$w, $n, .id, .agent.id, .agent.state]
       | if all(type == "string") then @tsv else error("bad row") end' <<<"$snap" 2>/dev/null) || ok=0
  else
    ok=0
  fi
  if [ "$ok" = 1 ]; then
    [ "$snapwarn" = 0 ] || echo "SNAPSHOT ok again"
    snapwarn=0
    seen=" "
    while IFS=$'\t' read -r wid name tid aid st; do
      [ -n "$tid" ] || continue
      seen="$seen$tid "
      label="$name (terminal ${tid:0:8})"
      f="$state_dir/$tid"
      t=$(date +%s)
      pst="" paid="" since="" rev="" pwid="" pname=""
      [ -f "$f" ] && read -r pst paid since rev pwid pname < "$f"
      # A malformed or incomplete record starts over.
      is_num "$since" && is_num "$rev" && [ -n "$paid" ] && [ -n "$pwid" ] && [ -n "$pname" ] || pst=""
      if [ "$st" != "$pst" ] || [ "$aid" != "$paid" ]; then
        case "$st" in working|starting) ;; *) echo "AGENT $label: $st" ;; esac
        since=$t rev=0
      elif [ "$st" = working ] && [ $(( (t - since) / 60 )) -ge "$stall" ]; then
        ex=$(superset agents explain --workspace "$wid" --terminal "$tid" --local --json 2>/dev/null) || ex=""
        last=$(jq -er 'select(.state == "working") | .lastEventAt | numbers | . / 1000 | floor' \
          <<<"$ex" 2>/dev/null) || last=""
        # A failed explain, or a state that moved on, changes nothing: the next round looks again.
        if is_num "$last"; then
          if [ $(( (t - last) / 60 )) -ge "$stall" ] && [ "$last" != "$rev" ]; then
            echo "STALL $label: working, no agent event for $(( (t - last) / 60 )) min"
            rev=$last
          fi
          since=$t
        fi
      fi
      printf '%s %s %s %s %s %s\n' "$st" "$aid" "$since" "$rev" "$wid" "$name" > "$f.tmp" && mv "$f.tmp" "$f"
    done <<<"$rows"
    # A tracked terminal missing from this snapshot (closed, agent gone, workspace archived).
    for f in "$state_dir"/*; do
      tid=$(basename "$f")
      case "$tid" in *.tmp|'*') continue ;; esac
      case "$seen" in *" $tid "*) continue ;; esac
      name=""
      read -r _ _ _ _ _ name < "$f"
      [ -z "$name" ] || echo "AGENT $name (terminal ${tid:0:8}): gone"
      rm "$f"
    done
  elif [ "$snapwarn" = 0 ]; then
    echo "SNAPSHOT failed (superset workspaces list or snapshot): agent states not checked until it works"
    snapwarn=1
  fi
  sleep "${WATCH_INTERVAL_S:-120}"
done
