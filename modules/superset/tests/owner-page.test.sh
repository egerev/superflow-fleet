#!/usr/bin/env bash
# Fixture test for modules/superset/bin/owner-page.sh answers / pending / ack / reply / upgrade / publish pruning and kinds,
# and the digest's reverse items (r<n>): a stub
# `superset` keeps page storage in files (one value per key and scope, the caller is user u1, the page
# creator is $CREATOR), so every answer and ack decision runs without a network.
# Run: bash modules/superset/tests/owner-page.test.sh
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script=$root/bin/owner-page.sh
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/orch" "$tmp/st"
cat >"$tmp/bin/superset" <<'STUB'
#!/usr/bin/env bash
# superset pages get|storage|publish|comments (the calls owner-page.sh makes), file-backed.
set -euo pipefail
[ "$1" = pages ] || { echo "$*" >>"$ST/../notify.log"; exit 0; }
sub=$2; shift 2
case $sub in
  get) printf '{"createdByUserId":"%s"}\n' "${CREATOR:-u1}" ;;
  publish) echo '{"version":2,"visibility":"just_me","watching":true,"url":"https://x/page"}' ;;
  storage)
    shift; key= scope=slot set= rm=
    while [ $# -gt 0 ]; do
      case $1 in --key) key=$2; shift ;; --scope) scope=$2; shift ;; --set) set=$2; shift ;; --remove) rm=1 ;; esac
      shift
    done
    f=$ST/$scope.$key
    if [ -z "$key" ]; then
      for g in "$ST"/*.*; do
        [ -e "$g" ] || continue; b=${g##*/}
        jq -c --arg s "${b%%.*}" --arg k "${b#*.}" '{key: $k, scope: $s, records: 1, updatedAt}' "$g"
      done | jq -s '{keys: .}'
    elif [ -n "$set" ]; then
      jq -n --argjson v "$set" --arg t "${NOW:-2026-10-26T08:00:00.000Z}" '{userId: "u1", value: $v, updatedAt: $t}' >"$f"
      echo '{"ok":true}'
    elif [ -n "$rm" ]; then rm -- "$f"; echo '{"ok":true}'
    elif [ -e "$f" ]; then jq '{records: [.]}' "$f"
    else echo '{"records":[]}'; fi ;;
  *) exit 0 ;;
esac
STUB
chmod 755 "$tmp/bin/superset"
uuid=$(printf '%08d-%04d-4%03d-8%03d-%012d' 0 0 0 0 1)  # built, not spelled: the export rejects literal ids
printf 'PROJECT=t\nORCH_WORKSPACE_ID=%s\n' "$uuid" >"$tmp/orch/config.sh"
echo "$uuid" >"$tmp/orch/owner-page.id"
printf 'q1\nq2\n' >"$tmp/orch/owner-page.notified"
# A filled page: the template's answer blocks, two questions (kinds product and money) and reverse item r1.
python3 - "$root/templates/owner-page.html" "$tmp/orch/owner-page.html" <<'PY'
import re, sys
t = open(sys.argv[1], encoding='utf-8').read()
t = re.sub(r'<!--.*?-->\n', '', t, count=1, flags=re.S)
t = t.replace('</article>\n      </section>', '</article>\n        <article id="q2" data-kind="money" data-options="a|b"><h3 data-q="q2">Pick</h3>'
              '<dl><dt>Options</dt><dd>a) one b) two</dd></dl></article>\n      </section>', 1)
t = t.replace('{{product|user-data|money|publish|hands}}', 'product', 1)
t = re.sub(r'\{\{L:([^}]*)\}\}', r'\1', t)
t = re.sub(r'\{\{[^}]*\}\}', 'x', t)
open(sys.argv[2], 'w', encoding='utf-8').write(t)
PY
export PATH="$tmp/bin:$PATH" HARNESS_CONFIG=$tmp/orch/config.sh ST=$tmp/st
NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z); export NOW  # stored times; old() writes a past one
press() { # q<n> id choice rev: what the page script stores on a press
  superset pages storage p --key "answer:$1" --scope private \
    --set "{\"id\":\"$2\",\"rev\":\"$4\",\"question\":\"Q\",\"choice\":\"$3\",\"comment\":\"\"}" --json >/dev/null
}
fail=0
check() { # name expected-exit expected-output-pattern (!pattern: must not match) command...
  local name=$1 want=$2 pat=$3 got=0 hit=0; shift 3
  "$@" >"$tmp/out" 2>&1 || got=$?
  if [ "${pat#!}" = "$pat" ]; then grep -qE -- "$pat" "$tmp/out" && hit=1; else grep -qE -- "${pat#!}" "$tmp/out" || hit=1; fi
  if [ "$got" = "$want" ] && [ "$hit" = 1 ]; then echo "ok   $name"
  else echo "FAIL $name: exit $got want $want, output must match: $pat"; sed 's/^/     /' "$tmp/out"; fail=1; fi
}
op() { bash "$script" "$@"; }
kept() { # name 1|0 key: whether the private key is still stored
  local have=0; [ ! -e "$ST/private.$3" ] || have=1
  if [ "$have" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: $3 stored=$have want $2"; fail=1; fi
}
# A press with another revision is stale; q1's real revision comes from the script's own python part.
press q1 a0 Yes bad
check stale-rev 0 '"stale":true' op answers
sed -n "/^  python3 -I - \"\$@\" <<'PY'$/,/^PY$/p" "$script" | sed '1d;$d' >"$tmp/html.py"
r1=$(python3 -I "$tmp/html.py" rev "$tmp/orch/owner-page.html" q1)
[[ $r1 =~ ^[0-9a-f]{8}$ ]] || { echo "FAIL rev: '$r1'"; exit 1; }
press q1 a1 Yes "$r1"
check pending 0 '^q1 a1$' op pending
check answers 0 '"q":"q1","id":"a1".*"choice":"Yes".*"stale":false' op answers
check ack-wrong-id 1 'answer changed' op ack q1 D1 zz
check ack-no-id-unread 1 'unread page answer' op ack q1 D1
check ack-ok 0 'q1 recorded as D1' op ack q1 D1 a1
check pending-empty 0 '!.' op pending
press q1 a2 No "$r1"
check changed-after-ack 0 '^q1 a2$' op pending
press q2 b1 a stale
check ack-stale 1 'older version' op ack q2 D2 b1
check reply-privacy 1 'privacy check' op reply q2 b1 "write to someone@example.org"
check reply 0 'replied on q2' op reply q2 b1 "a or b?"
check reply-handled 0 '^q1 a2$' op pending
check ack-chat 1 'unread page answer' op ack q1 D3
check bad-q 1 usage op ack x1 D1
check ack-no-press 0 'q9 recorded as D9' op ack q9 D9
# A reverse press on an agent decision is an answer like a question's.
rr=$(python3 -I "$tmp/html.py" rev "$tmp/orch/owner-page.html" r1)
press r1 c1 Reverse "$rr"
check reverse-pending 0 '^r1 c1$' op pending
check reverse-answers 0 '"q":"r1","id":"c1".*"choice":"Reverse".*"stale":false' op answers
check reverse-ack 0 'r1 recorded as D5' op ack r1 D5 c1
check reverse-handled 0 '!^r1 ' op pending
press r1 c2 Reverse "$rr"
check reverse-reply 0 'replied on r1' op reply r1 c2 "which part?"
# A publish after q1 left the page deletes nothing; past 400 keys it warns.
op ack q1 D3 a2 >/dev/null
# A week-old ack naming the current answer: the pruning of r1 deleted exactly this pair.
NOW=2020-01-01T00:00:00.000Z superset pages storage p --key ack:q1 --scope private --set '{"d":"D3","id":"a2"}' --json >/dev/null
python3 -c 'import re,sys; p=sys.argv[1]; t=open(p).read(); open(p,"w").write(re.sub(r"\s*<article id=\"q1\".*?</article>", "", t, flags=re.S))' "$tmp/orch/owner-page.html"
# A reverse item is not a question: publishing a new one stays silent.
python3 -c 'import sys; p=sys.argv[1]; t=open(p).read(); open(p,"w").write(t.replace("<h3>Done since", "<article id=\"r2\" data-options=\"Reverse\"><h3 data-q=\"r2\">d</h3></article>\n        <h3>Done since", 1))' "$tmp/orch/owner-page.html"
check publish-keeps 0 '!storage keys' op publish "q1 answered"
if [ -e "$tmp/notify.log" ]; then echo "FAIL reverse-silent: $(cat "$tmp/notify.log")"; fail=1; else echo "ok   reverse-silent"; fi
kept keeps-answer 1 answer:q1
kept keeps-ack 1 ack:q1
for i in $(seq 3 402); do echo '{"updatedAt":"x"}' >"$ST/private.answer:q$i"; done
check publish-key-warning 0 '40[0-9] of 500 storage keys' op publish "many"
# Upgrade: a page without the answer blocks gets them once; publish warns until then.
python3 - "$tmp/orch/owner-page.html" <<'PY'
import re, sys
p = sys.argv[1]; t = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(re.sub(r'[ \t]*<(style|script) id="owner-page-answers">.*?</\1>\n?', '', t, flags=re.S))
PY
check publish-warns 0 'answer script missing' op publish "legacy"
check upgrade 0 '^upgraded$' op upgrade
check upgrade-again 0 '^up to date$' op upgrade
check publish-quiet 0 '!answer script' op publish "upgraded"
# Kinds: a question outside the five is refused (publish and check); a valid kind passes.
setkind() { python3 -c 'import re,sys; p=sys.argv[1]; t=open(p).read(); open(p,"w").write(re.sub(r"<article id=\"q2\"[^>]*>", "<article id=\"q2\"" + sys.argv[2] + " data-options=\"a|b\">", t))' "$tmp/orch/owner-page.html" "$1"; }
setkind ''
check kind-missing 1 'kind check: .*q2=$' op publish "no kind"
setkind ' data-kind="order"'
check kind-other 1 'q2=order' op check
setkind ' data-kind="order" data-kind="hands"'
check kind-duplicate 1 'q2=order' op check
setkind ' data-kind="hands"'
check kind-ok 0 'privacy and kind checks passed' op check
check kind-publish 0 'owner page v2' op publish "hands"
sed -i.bak 's|</section>|<article id="qa" data-options="x"><h3>q</h3></article></section>|' "$tmp/orch/owner-page.html"
check kind-any-q 1 'qa=$' op check
# The revision sees whitespace as the page script does (JavaScript \s: U+FEFF yes, U+001C no).
rv() { printf '<article id="q1" data-options="a">%s</article>\n' "$1" >"$tmp/ws.html"; python3 -I "$tmp/html.py" rev "$tmp/ws.html" q1; }
if [ "$(rv $'x\xef\xbb\xbfy')" = "$(rv 'x y')" ] && [ "$(rv $'x\x1cy')" != "$(rv 'x y')" ]; then echo "ok   rev-js-whitespace"
else echo "FAIL rev-js-whitespace"; fail=1; fi
exit "$fail"
