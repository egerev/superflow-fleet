#!/usr/bin/env bash
# Fixture test for the STATE.md cap and the hygiene lines of modules/superset/bin/orchestrator-check.sh, core/bin/state-note.sh
# and the 80-line STATE.md print of core/hooks/session-start.sh. Stub `gh` and `superset` replay fixtures in
# the shapes the CLIs return (read 10-26). Run: bash modules/superset/tests/orchestrator-hygiene.test.sh
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
# A harness file by repository path; in the export (paths rewritten to core/...) this test sits in modules/superset/.
at() { if [ -e "$root/$1" ]; then echo "$root/$1"; else echo "$root/../../$1"; fi; }
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/orch/briefs" "$tmp/orch2" "$tmp/wt" "$tmp/fix"
cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
# pr list: GH_PRS (fail = exit 1), the open ones for --state open (GH_OPEN overrides); api: GH_PIN.
case "$1 $2" in
  "pr list") [ "$GH_PRS" = fail ] && exit 1
    case " $* " in
      *" --state open "*) if [ -n "${GH_OPEN:-}" ]; then cat "$FIX/$GH_OPEN"
                          else jq '[.[] | select(.state == "OPEN")]' "$FIX/$GH_PRS"; fi ;;
      *) cat "$FIX/$GH_PRS" ;;
    esac ;;
  "api "*) case $GH_PIN in
      fail) exit 1 ;;
      404) echo '{"message":"Not Found","status":"404"}'; echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
      *) echo "$GH_PIN" ;;
    esac ;;
esac
STUB
cat >"$tmp/bin/superset" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "workspaces list") [ "$SS_WS" = fail ] && exit 1; cat "$FIX/ws.json" ;;
  snapshot*) [ "$SS_SNAP" = fail ] && exit 1; cat "$FIX/$SS_SNAP" ;;
  *) exit 1 ;;
esac
STUB
chmod 755 "$tmp/bin/gh" "$tmp/bin/superset"
O=orch-ws
cat >"$tmp/orch/config.sh" <<EOF
PROJECT=demo
REPO=o/r
SUPERSET_PROJECT_ID=p1
ORCH_WORKSPACE_ID=$O
MAIN_BRANCH=main
HARNESS_DIR=$tmp/harness
READ_TIMEOUT_S=5
EOF
echo "export ORCH_WORKSPACE_ID='other-orch'   # a second orchestrator in the same Superset project" >"$tmp/orch2/config.sh"
ws() { printf '{"id":"%s","name":"%s","branch":"%s","archivedAt":%s}' "$1" "$2" "$3" "${4:-null}"; }
echo "[$(ws $O Boss orchestrator/x),$(ws w1 merged-ws feat/a),$(ws w2 open-ws feat/b),$(ws w3 fork-ws feat/c),
$(ws w4 archived-ws feat/a '"2026-10-25"'),$(ws w5 main-ws main),$(ws other-orch Boss2 feat/z),$(ws w7 old-boss orchestrator/y)]" \
  >"$tmp/fix/ws.json"
pr() { printf '{"number":%s,"state":"%s","headRefName":"%s","isCrossRepository":%s}' "$1" "$2" "$3" "${4:-false}"; }
prs="$(pr 7 MERGED feat/a),$(pr 3 CLOSED feat/a),$(pr 5 CLOSED feat/b),$(pr 9 OPEN feat/b),$(pr 1 MERGED main),
$(pr 11 MERGED feat/c true),$(pr 12 MERGED feat/z),$(pr 13 MERGED orchestrator/y)"
echo "[$prs]" >"$tmp/fix/prs.json"
echo "[$prs,$(pr 8 OPEN feat/a)]" >"$tmp/fix/race.json"   # opened between the two reads
echo '[]' >"$tmp/fix/empty.json"
echo "[$prs,{\"number\":2,\"headRefName\":\"feat/a\",\"isCrossRepository\":false}]" >"$tmp/fix/nostate.json"
jq -n '[range(1000) | {number: ., state: "OPEN", headRefName: "x\(.)", isCrossRepository: false}]' >"$tmp/fix/many.json"
term() { printf '{"id":"%s","name":"n","terminals":%s}' "$1" "$2"; }
agent() { printf '[{"id":"t","agent":{"id":"a","state":"%s"}}]' "$1"; }
snap() { printf '{"workspaces":[%s]}\n' "$(IFS=,; echo "$*")"; }
snap "$(term w1 '[]')" "$(term w2 "$(agent exited)")" "$(term w3 '[]')" "$(term w5 '[]')" \
  "$(term $O "$(agent idle)")" "$(term other-orch "$(agent working)")" >"$tmp/fix/idle.json"
snap "$(term w1 '[]')" "$(term w2 "$(agent idle)")" "$(term w3 '[]')" "$(term w5 '[]')" >"$tmp/fix/live.json"
snap "$(term w1 '{}')" "$(term w2 '[]')" "$(term w3 '[]')" "$(term w5 '[]')" >"$tmp/fix/badterm.json"
snap "$(term w1 '[]')" "$(term w2 '[]')" "$(term w5 '[]')" >"$tmp/fix/missing.json"
snap "$(term w1 '[{}]')" "$(term w2 '[]')" "$(term w3 '[]')" "$(term w5 '[]')" >"$tmp/fix/noagent.json"
echo '{"error":"x"}' >"$tmp/fix/bad.json"
git init -q "$tmp/harness"
# The public export writes bare "## <version>" headings; the private CHANGELOG adds a date.
printf '# Changelog\n\n## 0.29.0\n\nx\n\n## 0.28.0 (2026-10-25)\n\n## 0.27.0 (2026-10-24)\n' >"$tmp/harness/CHANGELOG.md"
git -C "$tmp/harness" add CHANGELOG.md
git -C "$tmp/harness" -c user.name=t -c user.email=t commit -qm c
git -C "$tmp/harness" update-ref refs/remotes/origin/main HEAD
state() { # next-items... -> STATE.md with a Wake line, $LINES filler lines, and a NEXT section
  { echo "# demo"; echo "Wake automations: none"
    for _ in $(seq 1 "${LINES:-10}"); do echo "- fact"; done
    echo "## NEXT"; printf '%s\n' "$@"; } >"$tmp/orch/STATE.md"
}
echo "Reply in this terminal with DONE." >"$tmp/orch/briefs/w1-old.md"
echo "Send DONE to the orchestrator with SendMessage." >"$tmp/orch/briefs/w2-new.md"
fail=0
run() { # name -> output of orchestrator-check.sh in $tmp/$name.out
  PATH="$tmp/bin:$PATH" FIX="$tmp/fix" HARNESS_CONFIG="$tmp/orch/config.sh" HARNESS_ORCH_GLOB="$tmp/orch $tmp/orch2" \
    bash "$root/bin/orchestrator-check.sh" >"$tmp/$1.out" 2>&1 || true
}
has() { # name pattern want-count
  local got; got=$(grep -cE "$2" "$tmp/$1.out" || true)
  if [ "$got" = "$3" ]; then echo "ok   $1: $2 x$3"
  else echo "FAIL $1: '$2' $got times, want $3"; sed 's/^/     /' "$tmp/$1.out"; fail=1; fi
}
state "1. dispatch card X" "2. after PR #9 merges: enable" "3. waits on q4" "4. enable flag" "   blocked on the deploy"
GH_PRS=prs.json GH_PIN=0.27.0 SS_WS=ok SS_SNAP=idle.json run base
has base '^STALE-WS merged-ws \(w1\): PR #7 merged' 1
has base '^STALE-WS' 1   # not: open PR (w2), fork PR only (w3), main, archived, either orchestrator
has base '^IDLE-FLEET .* 1 item' 1
has base '^PIN-LAG 2 docs/harness 0.27.0, harness main 0.29.0' 1
has base '^BRIEF-NO-SENDMESSAGE briefs/w1-old.md:1:' 1
has base '^BRIEF-NO-SENDMESSAGE' 1
has base 'NOT CHECKED' 0
has base 'STATE.md is' 0
state "1. Implement threshold alerts" "2. Enable flag" "   - waits on PR #9" "3. Cut release" "" "   Blocked on the deploy."
GH_PRS=prs.json GH_PIN=0.29.0 SS_WS=ok SS_SNAP=idle.json run word
has word '^IDLE-FLEET .* 1 item' 1   # "threshold" is not "hold"
state "  1. Dispatch ready task" "     - and its tests" "  2. Release" "     waits on q2"
GH_PRS=prs.json GH_PIN=0.29.0 SS_WS=ok SS_SNAP=idle.json run indented
has indented '^IDLE-FLEET .* 1 item' 1   # indented top-level items still count
has word '^PIN-LAG' 0
LINES=70 state "1. waits on the owner"
GH_PRS=prs.json GH_PIN=0.29.0 SS_WS=ok SS_SNAP=idle.json run cap
has cap '^WARN STATE.md is 74 lines / 1 KB' 1
has cap '^IDLE-FLEET|^PIN-LAG' 0
{ echo "Wake automations: none"; for _ in $(seq 1 59); do echo "- fact"; done; printf 'last line, no newline'; } \
  >"$tmp/orch/STATE.md"
GH_PRS=prs.json GH_PIN=404 SS_WS=ok SS_SNAP=idle.json run unterminated
has unterminated '^WARN STATE.md is 61 lines' 1
state "1. dispatch card X"
GH_PRS=prs.json GH_PIN=404 SS_WS=ok SS_SNAP=live.json run live
has live '^IDLE-FLEET|PIN-LAG|NOT CHECKED' 0
for s in bad badterm missing noagent fail; do
  v=$s.json; [ "$s" != fail ] || v=fail
  GH_PRS=prs.json GH_PIN=0.27.0 SS_WS=ok SS_SNAP=$v run "snap-$s"
  has "snap-$s" '^NOT CHECKED IDLE-FLEET: superset snapshot failed or incomplete' 1
  has "snap-$s" '^IDLE-FLEET' 0
done
GH_PRS=prs.json GH_PIN=fail SS_WS=fail SS_SNAP=idle.json run ssfail
has ssfail '^NOT CHECKED STALE-WS, IDLE-FLEET: superset workspaces list failed' 1
has ssfail '^STALE-WS|^IDLE-FLEET' 0
has ssfail '^NOT CHECKED PIN-LAG: gh api failed' 1
GH_PRS=fail GH_PIN=9.9.9 SS_WS=ok SS_SNAP=idle.json run ghfail
has ghfail '^NOT CHECKED STALE-WS: gh pr list failed' 1
has ghfail '^STALE-WS' 0
has ghfail '^NOT CHECKED PIN-LAG: pin 9.9.9 is not in the harness CHANGELOG' 1
GH_PRS=nostate.json GH_PIN=404 SS_WS=ok SS_SNAP=idle.json run nostate
has nostate '^NOT CHECKED STALE-WS: unexpected PR data' 1
has nostate '^STALE-WS' 0
GH_PRS=race.json GH_OPEN=empty.json GH_PIN=404 SS_WS=ok SS_SNAP=idle.json run race
has race '^STALE-WS' 0   # an OPEN record in the all-state read protects feat/a (and feat/b)
has race 'NOT CHECKED' 0
GH_PRS=prs.json GH_OPEN=many.json GH_PIN=404 SS_WS=ok SS_SNAP=idle.json run truncated
has truncated '^NOT CHECKED STALE-WS: 1000 or more open PRs' 1
has truncated '^STALE-WS' 0
echo "Report to the terminal when done." >"$tmp/orch/briefs/w3|x&y.md"
GH_PRS=prs.json GH_PIN=404 SS_WS=ok SS_SNAP=idle.json run oddname
has oddname '^BRIEF-NO-SENDMESSAGE briefs/w3\|x&y\.md:1:Report to the terminal' 1
# core/bin/state-note.sh: one dated line per call into archive/journal.md; a multi-line note is refused.
note() { HARNESS_CONFIG="$tmp/orch/config.sh" bash "$(at core/bin/state-note.sh)" "$@"; }
note NOW "PR #7 merged" >/dev/null && note "PR#9" "review r1 clean" >/dev/null
j="$tmp/orch/archive/journal.md"
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: want '$2' got '$3'"; fail=1; fi; }
check "journal lines" 2 "$(grep -cE '^- [0-9T:-]+Z \[(NOW|PR#9)\] ' "$j")"
check "journal header once" 1 "$(grep -c '^# Orchestrator journal' "$j")"
rc=0; note NOW $'two\nlines' 2>/dev/null || rc=$?
check "multi-line refused" 1 "$rc"
rc=0; note NOW 2>/dev/null || rc=$?
check "missing line refused" 1 "$rc"
# core/hooks/session-start.sh: the first 80 lines of STATE.md, then the path for the rest.
echo "$tmp/wt" >"$tmp/orch/active-cwd"
hook() { jq -n --arg c "$tmp/wt" '{cwd: $c}' | HARNESS_ORCH_GLOB="$tmp/orch" bash "$(at core/hooks/session-start.sh)"; }
LINES=100 state "1. x"
out=$(hook)
check "hook prints 80 STATE.md lines" 78 "$(grep -c '^- fact' <<<"$out")"
check "hook names the rest" 1 "$(grep -c "STATE.md has 104 lines; lines 81+ not shown" <<<"$out")"
{ for _ in $(seq 1 80); do echo "- fact"; done; printf 'line 81, no newline'; } >"$tmp/orch/STATE.md"
out=$(hook)
check "hook counts an unterminated last line" 1 "$(grep -c "STATE.md has 81 lines" <<<"$out")"
state "1. x"
out=$(hook)
check "short STATE.md printed whole" 1 "$(grep -c '^1. x' <<<"$out")"
check "no note for a short STATE.md" 0 "$(grep -c 'not shown' <<<"$out" || true)"
# Inbox: the hook lists unread peer FYI files (not dotfiles or read ones in archive/inbox/).
mkdir -p "$tmp/orch/inbox"; touch "$tmp/orch/inbox/.keep"
out=$(hook)
check "no inbox note when empty" 0 "$(grep -c '^INBOX' <<<"$out" || true)"
echo "version notice" >"$tmp/orch/inbox/2026-10-27-peer-version.md"
GH_PRS=prs.json GH_PIN=404 SS_WS=ok SS_SNAP=live.json run inbox
has inbox "^INBOX 1 unread file\\(s\\) in $tmp/orch/inbox" 1
chmod 000 "$tmp/orch/inbox"
GH_PRS=prs.json GH_PIN=404 SS_WS=ok SS_SNAP=live.json run inboxfail
chmod 755 "$tmp/orch/inbox"
has inboxfail '^NOT CHECKED INBOX: cannot read' 1
out=$(hook)
check "hook lists an unread inbox file" 1 "$(grep -c "^$tmp/orch/inbox/2026-10-27-peer-version.md$" <<<"$out")"
check "inbox header" 1 "$(grep -c '^INBOX: unread peer FYIs' <<<"$out")"
exit "$fail"
