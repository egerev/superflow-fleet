#!/usr/bin/env bash
# Read-only check of an orchestrator directory: config filled, files present, placeholders gone,
# tools installed, harness reachable, STATE.md within its cap; then hygiene and drift lines (STALE-WS,
# IDLE-FLEET, PIN-LAG, BRIEF-NO-SENDMESSAGE, INBOX, or NOT CHECKED when a read fails), run on every start, restart
# or wake-up (orchestration.md, Workspace sweep). Prints one line per finding; exit 1 on any FAIL.
# Optional config: READ_TIMEOUT_S (30) bounds each superset/gh read.
# Usage: <orchestrator dir>/bin/orchestrator-check.sh
set -uo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
harness_load_config
bad=0
fail() { echo "FAIL $*"; bad=1; }
warn() { echo "WARN $*"; }
for v in PROJECT REPO SUPERSET_PROJECT_ID ORCH_WORKSPACE_ID WORKER_AGENT_ID WORKTREES_DIR COMMON_BRIEF \
         WORKER_SETTINGS WORKER_MCP ORCH_MODEL ORCH_EFFORT CODEX_DAILY_POINTS; do
  val=${!v:-}
  if [ -z "$val" ]; then fail "config.sh: $v is empty"
  elif [[ $val == *'<'*'>'* ]]; then fail "config.sh: $v is still a placeholder ($val)"; fi
done
[[ ${CODEX_DAILY_POINTS:-pace} =~ ^(pace|[0-9]+([.][0-9]+)?)$ ]] \
  || fail "config.sh: CODEX_DAILY_POINTS must be pace or a number ($CODEX_DAILY_POINTS)"
[[ ${CODEX_LINE_OFFSET:-90} =~ ^[0-9]+([.][0-9]+)?$ ]] \
  || fail "config.sh: CODEX_LINE_OFFSET must be a number ($CODEX_LINE_OFFSET)"
for f in STATE.md DECISIONS.md orchestrator-facts.md handoffs/TEMPLATE.md; do
  [ -f "$ORCH_DIR/$f" ] || fail "missing $ORCH_DIR/$f"
done
for f in "${COMMON_BRIEF:-}" "${WORKER_SETTINGS:-}" "${WORKER_MCP:-}"; do
  [ -z "$f" ] || [ -f "$f" ] || fail "missing $f"
done
for f in "${WORKER_SETTINGS:-}" "${WORKER_MCP:-}"; do
  [ -f "$f" ] && ! jq -e . "$f" >/dev/null 2>&1 && fail "not valid JSON: $f"
done
# Placeholders the templates leave for the project (generic ones like <pr> or <model> stay).
if [ -f "${COMMON_BRIEF:-}" ]; then
  grep -nE '<(orchestrator dir|PROJECT|project review notes)>' "$COMMON_BRIEF" | sed "s|^|FAIL placeholder in $COMMON_BRIEF:|" | grep . && bad=1
  awk '/^## Project facts/{on=1; next} /^## /{on=0} on && /<[^>]+>/ && !/^<!--/' "$COMMON_BRIEF" \
    | sed "s|^|FAIL unfilled project fact: |" | grep . && bad=1
fi
for f in orchestrator-facts.md DECISIONS.md; do
  [ -f "$ORCH_DIR/$f" ] || continue
  n=$(grep -v '^ *<!--' "$ORCH_DIR/$f" | grep -cE '<[a-z][^>]*>' || true)
  [ "$n" = 0 ] || warn "$f: $n line(s) still hold <placeholders>"
done
if grep -q '^Wake automations:' "$ORCH_DIR/STATE.md" 2>/dev/null; then :
elif grep -q '^Wake crons:' "$ORCH_DIR/STATE.md" 2>/dev/null; then
  warn "STATE.md 'Wake crons:' is the old line: move the wakes to modules/superset/bin/wake.sh and rename it 'Wake automations:'"
else fail "STATE.md has no 'Wake automations:' line"; fi
# STATE.md cap (orchestration.md, STATE.md): the SessionStart hook prints only its first 80 lines.
# awk counts an unterminated last line too.
if [ -f "$ORCH_DIR/STATE.md" ]; then
  lines=$(awk 'END {print NR}' "$ORCH_DIR/STATE.md") bytes=$(wc -c <"$ORCH_DIR/STATE.md" | tr -d ' ')
  [ "$lines" -le 60 ] && [ "$bytes" -le 8192 ] \
    || warn "STATE.md is $lines lines / $(( (bytes + 1023) / 1024 )) KB (cap 60 lines, 8 KB): journal lines go to core/bin/state-note.sh, finished items to archive/"
fi
# Every superset/gh read below is bounded (READ_TIMEOUT_S, 30 s); a failed read prints NOT CHECKED and judges nothing.
tb=$(command -v timeout || command -v gtimeout || true)
rd() { [ -n "$tb" ] && "$tb" "${READ_TIMEOUT_S:-30}" "$@" 2>/dev/null; }
if [ -f "$ORCH_DIR/orch-terminal" ] && is_uuid "${ORCH_WORKSPACE_ID:-}"; then
  t=$(head -n 1 "$ORCH_DIR/orch-terminal")
  if ! tl=$(rd superset terminals list --local --workspace "$ORCH_WORKSPACE_ID" --json) \
     || ! jq -e '.sessions | type == "array"' >/dev/null 2>&1 <<<"$tl"; then
    echo "NOT CHECKED orch-terminal: superset terminals list failed"
  elif ! jq -e --arg t "$t" '.sessions[] | select(.terminalId==$t and .exited==false)' >/dev/null 2>&1 <<<"$tl"; then
    warn "orch-terminal $t is not a live terminal of ORCH_WORKSPACE_ID: wakes are lost; run modules/superset/bin/wake.sh target in the orchestrator"
  fi
fi
# The address (orchestration.md, Sessions, Orchestrator address): workers and peers read orch-name and the registry.
if [ ! -s "$ORCH_DIR/orch-name" ]; then
  warn "no orch-name: the orchestrator runs modules/superset/bin/boss-of.sh set <its session name> (workers and peers read the address there)"
elif ! own=$("$(dirname "$0")/boss-of.sh" 2>/dev/null) || [ "$own" != "$(head -n 1 "$ORCH_DIR/orch-name")" ]; then
  warn "no registry row for $PROJECT matching orch-name: the orchestrator runs modules/superset/bin/boss-of.sh set <its session name>"
fi
[ ! -s "$ORCH_DIR/wake-lost.log" ] || warn "lost wakes in $ORCH_DIR/wake-lost.log (paused; modules/superset/bin/wake.sh target resumes them)"
for s in $(harness_link_scripts "$ORCH_DIR"); do
  warn "no bin/$s link: run  ln -sfn harness-exec.sh $ORCH_DIR/bin/$s  (orchestrator-restart.sh also adds it)"
done
if [ -f "$ORCH_DIR/active-cwd" ]; then
  a=$(head -n 1 "$ORCH_DIR/active-cwd"); [ -d "$a" ] || fail "active-cwd points to a missing directory: $a"
else
  warn "no active-cwd: the SessionStart hook and the 250k budget do not know the orchestrator's worktree yet"
fi
[ -z "${WORKTREES_DIR:-}" ] || [ -d "$WORKTREES_DIR" ] || warn "WORKTREES_DIR does not exist yet: $WORKTREES_DIR"
for c in git gh jq superset claude codex python3; do command -v "$c" >/dev/null 2>&1 || fail "tool missing: $c"; done
command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1 || fail "tool missing: timeout (coreutils)"
h=${HARNESS_DIR:-$HOME/agent-harness}
git -C "$h" rev-parse -q --verify origin/main >/dev/null 2>&1 || fail "harness checkout $h has no origin/main"

# Hygiene and drift (orchestration.md, Workspace sweep): one line per finding, never a FAIL.
# Orchestrator workspaces (this one, every orchestrator directory's config, orchestrator/ branches) are never workers.
orchs=$( { printf '%s\n' "${ORCH_WORKSPACE_ID:-}"
  for c in ${HARNESS_ORCH_GLOB:-$HOME/*-orchestrator}; do
    # The config is read the way harness_load_config reads it, in a child shell.
    [ -f "$c/config.sh" ] && ORCH_DIR=$c bash -c '. "$1" >/dev/null 2>&1; printf "%s\n" "${ORCH_WORKSPACE_ID:-}"' _ "$c/config.sh"
  done; } | grep . | jq -R . | jq -sc .)
wsjson=$(rd superset workspaces list --local --project "${SUPERSET_PROJECT_ID:-}" --json) || wsjson=""
workers=$(jq -c --argjson o "${orchs:-[]}" 'if type != "array" then error("not a list") else . end
  | [.[] | select(.archivedAt == null and (.id | IN($o[]) | not) and ((.branch // "") | startswith("orchestrator/") | not))
     | if (.id | type) == "string" and (.name | type) == "string" then . else error("bad workspace") end]' \
  <<<"$wsjson" 2>/dev/null) || workers=""
# STALE-WS: a worker workspace (a worktree of REPO) with no open PR from its branch in this repository
# (fork PRs never match; an OPEN record in either read counts) and a merged or closed one. The open list must be complete; every record must have a known state.
prok=1
openjson=$(rd gh pr list --repo "${REPO:-}" --state open --limit 1000 --json number,state,headRefName,isCrossRepository) || prok=0
alljson=$(rd gh pr list --repo "${REPO:-}" --state all --limit 300 --json number,state,headRefName,isCrossRepository) || prok=0
valid='type == "array" and all(.[]; (.number | type) == "number" and (.headRefName | type) == "string"
  and (.isCrossRepository | type) == "boolean" and (.state | IN("OPEN", "CLOSED", "MERGED")))'
if [ -z "$workers" ]; then echo "NOT CHECKED STALE-WS, IDLE-FLEET: superset workspaces list failed"
elif [ "$prok" = 0 ]; then echo "NOT CHECKED STALE-WS: gh pr list failed"
elif ! jq -e "$valid" >/dev/null 2>&1 <<<"$openjson" || ! jq -e "$valid" >/dev/null 2>&1 <<<"$alljson"; then
  echo "NOT CHECKED STALE-WS: unexpected PR data"
elif [ "$(jq length <<<"$openjson")" -ge 1000 ]; then echo "NOT CHECKED STALE-WS: 1000 or more open PRs"
else
  jq -r --argjson open "$openjson" --argjson all "$alljson" --arg m "${MAIN_BRANCH:-main}" '
    [$open[], $all[] | select(.state == "OPEN" and (.isCrossRepository | not)) | .headRefName] as $busy
    | .[] | select((.branch // "") != "" and .branch != $m and (.branch | IN($busy[]) | not)) | . as $w
    | [$all[] | select((.isCrossRepository | not) and .headRefName == $w.branch and .state != "OPEN")]
    | select(length > 0) | max_by(.number)
    | "STALE-WS \($w.name) (\($w.id)): PR #\(.number) \(.state | ascii_downcase); close it if yours and no step after the merge remains"' \
    <<<"$workers" 2>/dev/null || echo "NOT CHECKED STALE-WS: unexpected workspace data"
fi
# IDLE-FLEET: no worker agent alive while NEXT holds an item that names no wait: the words wait/waits/
# waiting/after/blocked/hold/owner or a q<n> id. An item is a list line at the section's top indent (that
# of its first list line) plus every more indented line after it (nested bullets, paragraphs after a
# blank line) up to the next line at or left of that indent.
if [ -n "$workers" ] && [ -f "$ORCH_DIR/STATE.md" ]; then
  ready=$(awk '
    function done_item() { if (item != "") { t = " " tolower(item) " "; gsub(/[^a-z0-9]+/, " ", t)
      if (t !~ / (wait|waits|waiting|after|blocked|hold|owner|q[0-9]+) /) n++ } item = "" }
    function indent(s) { match(s, /^[ \t]*/); return RLENGTH }
    /^## / { done_item(); on = ($0 ~ /^## NEXT/); top = -1; next }
    !on { next }
    /^[ \t]*$/ { next }
    /^[ \t]*([0-9]+[.)]|[-*]) / && (top < 0 || indent($0) <= top) { done_item(); top = indent($0); item = $0; next }
    item != "" && indent($0) > top { item = item " " $0; next }
    { done_item() }
    END { done_item(); print n + 0 }' "$ORCH_DIR/STATE.md")
  if [ "${ready:-0}" -gt 0 ]; then
    snap=$(rd superset snapshot --json) || snap=""
    # Every worker workspace must be in the snapshot with a terminal list; anything else is NOT CHECKED.
    live=$(jq -r --argjson w "$workers" '.workspaces as $s | if ($s | type) != "array" then error("bad") else . end
      | [$w[].id as $id | ([$s[] | select(.id == $id)] | if length == 1 then .[0] else error("missing") end)
         | .terminals | if type == "array" then .[] else error("bad terminals") end
         | if type == "object" and has("agent") then . else error("bad terminal") end
         | select(.agent != null) | .agent
         | if type == "object" and (.state | type) == "string" then . else error("bad agent") end
         | select(.state != "exited")] | length' <<<"$snap" 2>/dev/null) || live=""
    if ! [[ $live =~ ^[0-9]+$ ]]; then echo "NOT CHECKED IDLE-FLEET: superset snapshot failed or incomplete"
    elif [ "$live" = 0 ]; then
      echo "IDLE-FLEET no live worker agent while STATE.md NEXT holds $ready item(s) naming no wait: dispatch, or write what each waits on"
    fi
  fi
fi
# PIN-LAG: versions between the project's docs/harness pin and harness origin/main (as of its last fetch).
pin=$(rd gh api "repos/${REPO:-}/contents/docs/harness/VERSION?ref=${MAIN_BRANCH:-main}" -H "Accept: application/vnd.github.raw")
rc=$?
if [ "$rc" = 0 ] && [[ $pin =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  heads=$(git -C "$h" show origin/main:CHANGELOG.md 2>/dev/null | sed -nE 's/^## ([0-9]+\.[0-9]+\.[0-9]+)([[:space:]].*)?$/\1/p')
  if [ -z "$heads" ]; then echo "NOT CHECKED PIN-LAG: no CHANGELOG.md on $h origin/main"
  elif ! grep -qxF "$pin" <<<"$heads"; then echo "NOT CHECKED PIN-LAG: pin $pin is not in the harness CHANGELOG"
  else
    n=$(awk -v p="$pin" '$0 == p {print NR - 1; exit}' <<<"$heads")
    [ "$n" = 0 ] || echo "PIN-LAG $n docs/harness $pin, harness main $(head -n 1 <<<"$heads"): refresh the pin"
  fi
elif [ "$rc" = 0 ]; then echo "NOT CHECKED PIN-LAG: docs/harness/VERSION is not a version"
# gh exits 1 on a 404 too: the project pins no harness copy (the harness itself) only when the body says so.
elif ! grep -q '"status":"404"' <<<"$pin"; then echo "NOT CHECKED PIN-LAG: gh api failed"
fi
# BRIEF-NO-SENDMESSAGE: a brief telling a worker to report in its terminal (core/templates/messages.md: SendMessage).
for f in "$ORCH_DIR"/briefs/*.md; do
  [ -f "$f" ] || continue
  b=$(basename "$f")
  grep -niE '(reply|report|answer|respond|write)[a-z ]{0,20} (in|to|into|from) (this|the|your) terminal' "$f" \
    | while IFS= read -r m; do printf 'BRIEF-NO-SENDMESSAGE briefs/%s:%s  (workers report by SendMessage)\n' "$b" "$m"; done
done
# INBOX: peer FYI files not yet read (orchestration.md, Wake-ups, Inbox).
if [ -e "$ORCH_DIR/inbox" ]; then
  if ! list=$(find "$ORCH_DIR/inbox" -maxdepth 1 -type f ! -name '.*' 2>/dev/null); then
    echo "NOT CHECKED INBOX: cannot read $ORCH_DIR/inbox"
  else
    n=$(grep -c . <<<"$list" || true)
    [ "$n" = 0 ] || echo "INBOX $n unread file(s) in $ORCH_DIR/inbox: read each, act, then move it to archive/inbox/"
  fi
fi
[ "$bad" = 0 ] && echo "OK: $ORCH_DIR"
exit "$bad"
