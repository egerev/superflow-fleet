#!/usr/bin/env bash
# Fixture test for core/bin/wait-merge.sh: a stub `gh` replays GraphQL answers in the shape GitHub
# returns (read 10-26 from queue-merged pull requests). Run: bash core/tests/wait-merge.test.sh
set -euo pipefail
script=${WAIT_MERGE:-$(cd "$(dirname "$0")/.." && pwd)/bin/wait-merge.sh}  # WAIT_MERGE: another copy
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
# api graphql: print the next fixture line through the caller's --jq; pr checks: no failed checks.
[ "$1" = api ] || exit 0
n=$(cat "$FIX.n" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$FIX.n"
line=$(sed -n "${n}p" "$FIX"); [ -n "$line" ] || line=$(tail -n 1 "$FIX")
while [ $# -gt 0 ]; do [ "$1" = --jq ] && { jq -r "$2" <<<"$line"; exit; }; shift; done
STUB
chmod 755 "$tmp/bin/gh"
pr() { # state queued armed oid reason -> one GraphQL answer
  local oid=null reason='[]'
  [ "$4" = - ] || oid="{\"oid\":\"$4\"}"
  [ "$5" = - ] || reason="[{\"reason\":\"$5\"}]"
  printf '{"data":{"repository":{"pullRequest":{"state":"%s","isInMergeQueue":%s,"autoMergeRequest":%s,"mergeCommit":%s,"timelineItems":{"nodes":%s}}}}}\n' \
    "$1" "$2" "$( [ "$3" = true ] && echo '{"enabledAt":"x"}' || echo null)" "$oid" "$reason"
}
fail=0
case_() { # name expected-exit fixture-lines...
  local name=$1 want=$2 got=0; shift 2
  printf '%s\n' "$@" >"$tmp/$name"
  PATH="$tmp/bin:$PATH" FIX="$tmp/$name" REPO=o/r WAIT_INTERVAL_S=0 \
    bash "$script" 1 >"$tmp/$name.out" 2>&1 || got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"
  else echo "FAIL $name: exit $got, want $want"; sed 's/^/     /' "$tmp/$name.out"; fail=1; fi
}
# Queue merge: the removal (reason merged) is recorded before state reads MERGED (06:40:55Z, then 06:40:56Z).
case_ queue-merge-lag 0 "$(pr OPEN true false - -)" "$(pr OPEN false false - merged)" \
  "$(pr OPEN false false - merged)" "$(pr OPEN false false - merged)" "$(pr MERGED false false abc123 merged)"
# A later merge after an earlier manual dequeue: the old removal does not end the wait.
case_ requeue-then-merge 0 "$(pr OPEN true false - manual)" "$(pr OPEN false false - merged)" \
  "$(pr MERGED false false abc123 merged)"
# A real dequeue: two reads neither queued nor armed.
case_ dequeued 3 "$(pr OPEN true false - -)" "$(pr OPEN false false - manual)" "$(pr OPEN false false - manual)"
case_ closed 2 "$(pr CLOSED false false - -)"
case_ never-enqueued 3 "$(pr OPEN false false - -)" "$(pr OPEN false false - -)"
exit "$fail"
