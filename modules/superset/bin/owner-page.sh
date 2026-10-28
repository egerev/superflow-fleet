#!/usr/bin/env bash
# The project's owner page (orchestration.md, Owner page): the open owner questions, one item per
# question, and the digest, as one Superset page the owner answers with buttons and a comment box
# or with pinned comments. A press stores {id, rev, question, choice, comment} under the page
# storage key answer:q<n> in the owner's private scope (only that login reads or writes it); the
# orchestrator's ack:q<n> (same scope) names the answer id it consumed. Each question carries one of
# the five kinds the owner keeps (process.md sec. 2) as data-kind. The digest's "Decided by agents"
# items (<article id="r<n>">) carry a reverse button: its press is an answer:r<n> handled the same way.
# Usage: owner-page.sh publish <label> | answers | pending | ack q<n> D<n> [<id>]
#        | reply q<n> <id> <text> | upgrade | comments | check   (q<n> also r<n>, a reverse item)
#   publish: privacy and kind checks (a question without data-kind product, user-data, money, publish
#            or hands is refused: anything else is the agents' to decide), then publish $ORCH_DIR/owner-page.html as a new version of the
#            project's page (id kept in $ORCH_DIR/owner-page.id; the first publish creates the
#            page "<PROJECT>: owner", visibility just_me). A publish watches the page for comments
#            from the calling session (`watching` in the output; 1.39 once returned false on create).
#            <label> says what changed (shown in the version history and the output line).
#            When the page holds an open question (an <article id="q<n>">) missing from the set last
#            recorded in $ORCH_DIR/owner-page.notified, a publish also raises a desktop notification
#            with sound (`superset notifications show --sound`); a click opens the orchestrator
#            terminal recorded in $ORCH_DIR/orch-terminal (wake.sh target, orchestrator-restart.sh),
#            else the calling one. Questions already notified stay silent. Each publish records the
#            open set; a failed notification only warns and keeps the old set, so the next one retries.
#            Then it warns when the page's answer script is missing or older than the template's
#            (run upgrade), and when the owner's keys on the page pass 400 of Superset's 500 (answers
#            are never deleted: a delete could race a new press; a new page starts empty).
#   answers: the answers not yet handled (no ack naming their id), one JSON line each:
#            {"q","id","question","choice","comment","at","stale"}; stale = the question's text or
#            options changed since the press (or it left the page): never record it, reply instead.
#   pending: one "q<n> <id>" line per answer not yet handled (modules/superset/bin/watch.sh prints ANSWER lines).
#   ack:     marks q<n> recorded as D<n>: the page shows it, `answers` stops listing it. With <id>
#            (from answers) it refuses a changed or stale answer; without (a chat or comment answer)
#            it refuses while q<n> has an unhandled page answer.
#   reply:   answers the owner's answer <id> on q<n> without recording (a question back): the page
#            shows <text> and reopens the item; the owner's next press is pending again.
#   upgrade: puts the template's answer style and script into $ORCH_DIR/owner-page.html (replacing
#            an older copy of them; labels and data-options stay the author's).
#   comments: the open comment threads (thread id, anchor = question id, author, text).
#   check: the privacy and kind checks only.
# Every superset call is bounded (60 s). Exit: 0 done, 1 refused (privacy, kind, config, usage, changed
# answer), 2 superset failed or timed out.
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
harness_load_config
require PROJECT ORCH_WORKSPACE_ID
src=$ORCH_DIR/owner-page.html idf=$ORCH_DIR/owner-page.id nf=$ORCH_DIR/owner-page.notified
tpl=$(harness_root)/modules/superset/templates/owner-page.html
cmd=${1:-}
command -v jq >/dev/null || die "jq is required"
command -v python3 >/dev/null || die "python3 is required"
tb=$(timeout_bin)
sp() { "$tb" 60 superset "$@"; }

# Secret and personal-data patterns on stdin or the named file (grep: 0 hit, 1 none, >1 error).
scan() {
  grep -n -i -E \
    -e 'sk_(live|test)_|sk-(proj|ant|svcacct)-|sk-[A-Za-z0-9]{32,}|gh[pousr]_[A-Za-z0-9]{20}|github[_]pat_' \
    -e 'xox[abprs]-|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30}|BEGIN [A-Z ]*PRIVATE KEY' \
    -e "(password|passwd|secret|token|api[_-]?key)[\"']?[[:space:]]*[:=]" \
    -e '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    -e '\+[0-9][0-9 ()-]{9,}[0-9]' \
    -e '[a-z][a-z0-9+.-]*://[^ /:@]*:[^ /@]+@' \
    "$@"
}

# The page leaves the machine (Superset hosts it) and can be widened to the org: refuse anything
# that looks like a secret or personal data. Patterns, not proof: the author still reads the page.
# grep exit 1 = no match; any other exit refuses, so a broken scan never passes.
privacy_check() {
  [ -f "$src" ] || die "no $src: copy the harness modules/superset/templates/owner-page.html there and fill it"
  local hits rc=0
  hits=$(scan "$src") || rc=$?
  case $rc in
    0) printf '%s\n' "$hits" | cut -c1-160 >&2
       die "privacy check: remove secrets and personal data from $src (lines above)" ;;
    1) ;;
    *) die "privacy check: cannot scan $src (grep exit $rc)" ;;
  esac
  rc=0; grep -q '{{' "$src" || rc=$?
  case $rc in
    0) die "$src still has {{placeholders}}" ;;
    1) ;;
    *) die "privacy check: cannot scan $src (grep exit $rc)" ;;
  esac
}

# The five kinds the owner keeps (process.md sec. 2): a question of another kind is not asked.
kinds_check() {
  local bad
  bad=$(html kinds "$src") || die "kind check: cannot read $src"
  [ -z "$bad" ] || die "kind check: each question needs data-kind product, user-data, money, publish or hands; decide the others and list them under \"Decided by agents\": $(paste -sd ' ' - <<<"$bad")"
}

# html.py <mode> <file> [<arg>]: kinds prints each q... article without a valid data-kind (q<n>=<kind>);
# rev q<n> prints the question's revision (the page script computes
# the same: FNV-1a over UTF-16 units of data-options + " " + the article text, spaces collapsed;
# empty when the article is missing); script prints ok / old / missing for the answer script
# against <arg> (the template); upgrade writes the template's answer style and script into <file>.
html() {
  python3 -I - "$@" <<'PY'
import re, sys
from html.parser import HTMLParser
mode, path = sys.argv[1], sys.argv[2]
text = open(path, encoding='utf-8').read()
BLOCK = r'[ \t]*<(style|script) id="owner-page-answers">.*?</\1>\n?'
# What the page script sees: a browser keeps the first of duplicate attributes; JavaScript's \s.
def first(attrs):
    a = {}
    for k, v in attrs: a.setdefault(k, v)
    return a
JS_WS = '[\t\n\v\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+'
class Art(HTMLParser):
    def __init__(self, q):
        super().__init__(); self.q, self.depth, self.opts, self.buf = q, 0, None, []
    def handle_starttag(self, tag, attrs):
        if tag != 'article': return
        if self.depth: self.depth += 1
        elif self.opts is None and first(attrs).get('id') == self.q:
            self.depth, self.opts = 1, first(attrs).get('data-options') or ''
    def handle_endtag(self, tag):
        if tag == 'article' and self.depth: self.depth -= 1
    def handle_data(self, d):
        if self.depth: self.buf.append(d)
def blocks(t):
    return [m.group(0) for m in re.finditer(BLOCK, t, re.S)]
if mode == 'rev':
    p = Art(sys.argv[3]); p.feed(text); p.close()
    if p.opts is None: print(''); sys.exit()
    s, h = re.sub(JS_WS, ' ', p.opts + ' ' + ''.join(p.buf)).strip(' '), 0x811c9dc5
    b = s.encode('utf-16-le')
    for i in range(0, len(b), 2):
        h = ((h ^ (b[i] | b[i + 1] << 8)) * 0x01000193) & 0xffffffff
    print('%08x' % h)
elif mode == 'kinds':
    class Kinds(HTMLParser):
        def handle_starttag(self, tag, attrs):
            a = first(attrs)  # the page script answers every article whose id starts with q
            if tag == 'article' and (a.get('id') or '').startswith('q') \
                    and a.get('data-kind') not in ('product', 'user-data', 'money', 'publish', 'hands'):
                print('%s=%s' % (a['id'], a.get('data-kind') or ''))
    k = Kinds(); k.feed(text); k.close()
elif mode == 'script':
    mine, want = blocks(text), blocks(open(sys.argv[3], encoding='utf-8').read())
    print('missing' if not mine else 'ok' if [x.strip() for x in mine] == [x.strip() for x in want] else 'old')
elif mode == 'upgrade':
    want = blocks(open(sys.argv[3], encoding='utf-8').read())
    assert len(want) == 2, 'template has no answer style and script'
    t = re.sub(BLOCK, '', text, flags=re.S)
    for tag, block in zip(('</head>', '</body>'), want):
        assert t.count(tag) == 1, 'no single ' + tag
        t = re.sub(r'([ \t]*)' + tag, lambda m: block + m.group(1) + tag, t, count=1)
    if t != text:
        open(path, 'w', encoding='utf-8').write(t); print('upgraded')
    else: print('up to date')
PY
}

# The stored page id; refuses a missing or malformed one (an empty --page would sweep every page).
page_id() {
  local id
  [ -s "$idf" ] || die "no $idf: publish the owner page first"
  id=$(cat "$idf") || die "cannot read $idf"
  is_uuid "$id" || die "$idf does not hold a page id"
  printf '%s\n' "$id"
}

# Only the page creator's records count (private scope already keeps others out; this also
# refuses a CLI login that is not the page's owner).
owner_id() { sp pages get "$id" --json | jq -er .createdByUserId; }
# rec <key>: the owner's private record of <key> as JSON, or null.
rec() {
  sp pages storage "$id" --key "$1" --scope private --json \
    | jq -c --arg o "$owner" '([.records[] | select(.userId == $o)][0]) // null'
}
# The q<n> ids with a private answer key (key listing, one call).
answer_ids() {
  sp pages storage "$id" --json \
    | jq -r '[.keys[] | select(.scope == "private" and (.key | test("^answer:[qr][0-9]+$"))) | .key[7:]] | .[]'
}
# State of q<n>: the answer (a), its id, the ack (k), whether the ack names that answer.
# shellcheck disable=SC2016  # a jq program: its $ names are jq's
state='{q: $q, a: $a, k: $k, aid: ($a | if . == null then null else (.value.id // .updatedAt) end)}
  | .handled = (.a == null or (.k != null and .k.value.id == .aid))'
load() { # q<n>: sets st (JSON) or returns 2
  local a k
  a=$(rec "answer:$1") || return 2
  k=$(rec "ack:$1") || return 2
  st=$(jq -nc --arg q "$1" --argjson a "$a" --argjson k "$k" "$state") || return 2
}
need_q() { [[ ${1:-} =~ ^[qr][0-9]+$ ]] || die "usage: owner-page.sh $cmd q<n>|r<n> ..."; }
set_ack() { # q<n> <json>
  sp pages storage "$id" --key "ack:$1" --scope private --set "$2" --json >/dev/null || exit 2
}

case "$cmd" in
  check) privacy_check; kinds_check; echo "owner page: privacy and kind checks passed" ;;
  publish)
    label=${2:-}; [ -n "$label" ] || die "usage: owner-page.sh publish <what changed>"
    privacy_check; kinds_check
    if [ -e "$idf" ]; then
      id=$(page_id)
      out=$(sp pages publish "$src" --page "$id" --label "$label" --json) || exit 2
    else
      [ -w "$ORCH_DIR" ] || die "cannot write $idf"
      out=$(sp pages publish "$src" --title "$PROJECT: owner" \
        --description "Open owner questions (answer with the buttons or a comment) and the digest" \
        --visibility just_me --workspace "$ORCH_WORKSPACE_ID" --label "$label" --json) || exit 2
      id=$(jq -r .id <<<"$out" 2>/dev/null) || id=
      if ! is_uuid "$id" || ! printf '%s\n' "$id" >"$idf"; then
        printf '%s\n' "$out" >&2
        die "page created but its id was not saved: write the page id above to $idf"
      fi
    fi
    jq -r --arg l "$label" '"owner page v\(.version) (\(.visibility), watching \(.watching)): \(.url) — \($l)"' \
      <<<"$out" || { printf '%s\n' "$out"; exit 2; }
    # Open question ids (q<n>, sorted, one per line); notify only when one is not in the last set.
    ids=$({ grep -o -E '<article id="q[0-9]+"' "$src" || true; } | sed -E 's/.*"(q[0-9]+)"/\1/' | sort -u)
    new=$(comm -23 <(printf '%s\n' "$ids" | sed '/^$/d') <({ cat "$nf" 2>/dev/null || true; } | sed '/^$/d' | sort -u))
    ok=1
    if [ -n "$new" ]; then
      term=$(head -n 1 "$ORCH_DIR/orch-terminal" 2>/dev/null || true)
      is_uuid "$term" || { term=${SUPERSET_TERMINAL_ID:-}; is_uuid "$term" || term=; }
      sp notifications show "$PROJECT: owner question" --body "new: $(paste -sd ' ' - <<<"$new") — $label" \
        --sound --workspace "$ORCH_WORKSPACE_ID" ${term:+--terminal "$term"} >/dev/null \
        || { ok=0; echo "owner page: notification failed (the page is published)" >&2; }
    fi
    [ "$ok" = 0 ] || printf '%s\n' "$ids" >"$nf" || echo "owner page: cannot record $nf" >&2
    s=$(html script "$src" "$tpl") || s=unknown
    [ "$s" = ok ] || echo "owner page: answer script $s in $src: run owner-page.sh upgrade, then publish" >&2
    # Storage outlives versions; answers and acks are kept (two keys per question).
    n=$(sp pages storage "$id" --json | jq '[.keys[] | select(.scope == "private")] | length') || n=0
    [ "$n" -le 400 ] || echo "owner page: $n of 500 storage keys used: start a new page (move owner-page.id aside, publish)" >&2 ;;
  pending|answers)
    id=$(page_id)
    owner=$(owner_id) || exit 2
    qs=$(answer_ids) || exit 2
    for q in $qs; do
      load "$q" || exit 2
      jq -e .handled <<<"$st" >/dev/null && continue
      if [ "$cmd" = pending ]; then jq -r '"\(.q) \(.aid)"' <<<"$st"; continue; fi
      cur=$(html rev "$src" "$q") || exit 2
      jq -c --arg cur "$cur" '.a as $a | ($a.value | if type == "object" then . else {} end) as $v
        | def s(x): if (x | type) == "string" then x else "" end;
        {q, id: .aid, question: s($v.question), choice: s($v.choice), comment: s($v.comment), at: $a.updatedAt,
         stale: ($cur == "" or s($v.rev) != $cur)}' <<<"$st" || exit 2
    done ;;
  ack)
    q=${2:-} d=${3:-} want=${4:-}
    need_q "$q"; [[ $d =~ ^D[0-9]+$ ]] || die "usage: owner-page.sh ack q<n> D<n> [<answer id>]"
    id=$(page_id); owner=$(owner_id) || exit 2
    load "$q" || exit 2
    if [ -n "$want" ]; then
      [ "$(jq -r '.aid // ""' <<<"$st")" = "$want" ] || die "$q: answer changed: run owner-page.sh answers again"
      [ "$(jq -r '.a.value.rev // ""' <<<"$st")" = "$(html rev "$src" "$q")" ] \
        || die "$q: answer was given to an older version of the question: reply instead"
    else
      jq -e .handled <<<"$st" >/dev/null || die "$q has an unread page answer: run owner-page.sh answers"
    fi
    set_ack "$q" "$(jq -c --arg d "$d" '{d: $d, id: (.aid // "")}' <<<"$st")"
    echo "owner page: $q recorded as $d" ;;
  reply)
    q=${2:-} want=${3:-} text=${4:-}
    need_q "$q"; [ -n "$want" ] && [ -n "$text" ] || die "usage: owner-page.sh reply q<n> <answer id> <text>"
    rc=0; printf '%s\n' "$text" | scan >/dev/null || rc=$?
    [ "$rc" = 1 ] || die "privacy check: the reply looks like a secret or personal data (or cannot be scanned)"
    id=$(page_id); owner=$(owner_id) || exit 2
    load "$q" || exit 2
    [ "$(jq -r '.aid // ""' <<<"$st")" = "$want" ] || die "$q: answer changed: run owner-page.sh answers again"
    set_ack "$q" "$(jq -nc --arg r "$text" --arg i "$want" '{reply: $r, id: $i}')"
    echo "owner page: replied on $q" ;;
  upgrade)
    [ -f "$src" ] || die "no $src"
    html upgrade "$src" "$tpl" || die "upgrade failed: $src unchanged" ;;
  comments)
    id=$(page_id)
    sp pages comments list --page "$id" --open || exit 2 ;;
  *) die "usage: owner-page.sh publish <label> | answers | pending | ack q<n> D<n> [<id>] | reply q<n> <id> <text> | upgrade | comments | check" ;;
esac
