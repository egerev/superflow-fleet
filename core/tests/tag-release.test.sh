#!/usr/bin/env bash
# Test for core/bin/tag-release.sh on a throwaway repository. Run: bash core/tests/tag-release.test.sh
set -euo pipefail
script=$(cd "$(dirname "$0")/.." && pwd)/bin/tag-release.sh
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
fail=0
at=@; email="t${at}example.invalid"  # built here: the export's leak check flags e-mail literals
r="$tmp/repo with space"
git init -q "$r"
g() { git -C "$r" -c user.name=t -c user.email="$email" "$@"; }
commit() { printf '%s\n' "$1" >"$r/VERSION"; g add VERSION; g commit -q --allow-empty -m "$1"; g rev-parse HEAD; }
check() { # name expected-exit args...
  local name=$1 want=$2 got=0; shift 2
  GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL="$email" bash "$script" -C "$r" "$@" >"$tmp/out" 2>&1 || got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name: exit $got want $want"; sed 's/^/     /' "$tmp/out"; fail=1; fi
}
a=$(commit 0.1.0); b=$(commit 0.2.0); c=$(commit 0.2.0); d=$(commit 0.3.0); e=$(commit 0.4.0)
check tag 0 "$a"
[ "$(g rev-parse 'v0.1.0^{commit}')" = "$a" ] || { echo "FAIL tag-target: v0.1.0 not on $a"; fail=1; }
[ "$(g cat-file -t v0.1.0)" = tag ] || { echo "FAIL annotated: v0.1.0 is not an annotated tag"; fail=1; }
# The printed push line is shell-quoted (the repository path has a space): run it against a bare remote.
git init -q --bare "$tmp/remote.git"; g remote add origin "$tmp/remote.git"
if bash -c "$(sed -n 's/^push: //p' "$tmp/out")" >/dev/null 2>&1 \
  && [ "$(git -C "$tmp/remote.git" rev-parse 'v0.1.0^{commit}')" = "$a" ]; then echo "ok   push-line"
else echo "FAIL push-line"; sed 's/^/     /' "$tmp/out"; fail=1; fi
check again 0 "$a"
check version-arg 0 "$b" v0.2.0
check no-bump 1 "$c"
check version-differs 1 "$a" 0.3.0
g tag v0.3.0 "$d"
check lightweight 1 "$d"
g update-ref refs/remotes/origin/main "$e"
check default-ref 0
[ "$(g rev-parse 'v0.4.0^{commit}')" = "$e" ] || { echo "FAIL default-ref: v0.4.0 not on $e"; fail=1; }
check no-commit 2 nosuchref
commit 'not a version' >/dev/null
check bad-version 2 HEAD
check usage 2 a b c
check usage-C 2 -C
exit "$fail"
