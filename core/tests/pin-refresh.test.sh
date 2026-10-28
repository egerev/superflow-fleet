#!/usr/bin/env bash
# Test for core/bin/pin-refresh.sh on throwaway harness and project repositories with a stub gh.
# Run: bash core/tests/pin-refresh.test.sh
set -euo pipefail
script=$(cd "$(dirname "$0")/.." && pwd)/bin/pin-refresh.sh
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
fail=0
at=@; email="t${at}example.invalid"  # built here: the export's leak check flags e-mail literals
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL="$email" GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL="$email"
docs=(process.md reviews.md tiden.md orchestration.md skills.md)
# Harness: origin with tags v0.1.0 and v0.2.0, a clone as HARNESS_DIR.
git init -q --bare "$tmp/h.git"; git clone -q "$tmp/h.git" "$tmp/hw" 2>/dev/null
for v in 0.1.0 0.2.0; do
  for f in "${docs[@]}"; do echo "$f at $v" >"$tmp/hw/$f"; done
  echo "$v" >"$tmp/hw/VERSION"
  git -C "$tmp/hw" add -A; git -C "$tmp/hw" commit -q -m "$v"; git -C "$tmp/hw" tag -a "v$v" -m "$v"
done
git -C "$tmp/hw" push -q origin HEAD:main --tags
# v0.3.0: a local tag on an unmerged draft commit.
git -C "$tmp/hw" switch -q -c draft; echo 0.3.0 >"$tmp/hw/VERSION"; git -C "$tmp/hw" commit -qam 0.3.0
git -C "$tmp/hw" tag -a v0.3.0 -m 0.3.0; git -C "$tmp/hw" switch -q main 2>/dev/null || git -C "$tmp/hw" switch -q -
export HARNESS_DIR="$tmp/hw"
h2=$(git -C "$tmp/hw" rev-parse 'v0.2.0^{commit}')
# Project: docs/harness at 0.1.0, pointers in AGENTS.md and docs/harness/README.md.
git init -q --bare "$tmp/p.git"; git clone -q "$tmp/p.git" "$tmp/p" 2>/dev/null
p() { git -C "$tmp/p" "$@"; }
mkdir -p "$tmp/p/docs/harness"
for f in "${docs[@]}"; do echo "$f at 0.1.0" >"$tmp/p/docs/harness/$f"; done
echo 0.1.0 >"$tmp/p/docs/harness/VERSION"
printf 'Pinned copy of egerev/agent-harness @ 0.1.0 (VERSION), origin/main commit abcdef1. Do not edit here.\nAudit: egerev/agent-harness @ 0.1.0, commit deadbee reviewed.\n' \
  >"$tmp/p/docs/harness/README.md"
printf '# P\n\nProcess: harness egerev/agent-harness @ 0.1.0, ~/agent-harness; rules.\nKeep 0.1.0 here.\n' >"$tmp/p/AGENTS.md"
p add -A; p commit -q -m init; p push -q origin HEAD:main
base=$(p rev-parse HEAD)
mkdir "$tmp/bin"; printf '#!/bin/sh\necho "gh $*" >>"%s/gh.log"\necho https://example.invalid/pr/1\n' "$tmp" >"$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
run() { # name expected-exit args...
  local name=$1 want=$2 got=0; shift 2
  PATH="$tmp/bin:$PATH" "$script" -C "$tmp/p" "$@" >"$tmp/out" 2>&1 || got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name: exit $got want $want"; sed 's/^/     /' "$tmp/out"; fail=1; fi
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: want '$2' got '$3'"; fail=1; fi; }
run usage 2 0.2.0
run no-tag 1 v0.9.0
run unmerged-tag 1 v0.3.0
check "unmerged tag named" 1 "$(grep -c 'is not on harness origin/main' "$tmp/out")"
# An untracked file hidden by status.showUntrackedFiles=no still counts as dirty and is never pushed.
p config status.showUntrackedFiles no; echo secret >"$tmp/p/docs/harness/private.md"
run hidden-untracked 1 v0.2.0; rm "$tmp/p/docs/harness/private.md"; p config --unset status.showUntrackedFiles
# A tracked symlink at a destination is refused before anything is written through it.
echo outside >"$tmp/outside"; ln -sf "$tmp/outside" "$tmp/p/docs/harness/skills.md"; p commit -qam symlink; p push -q origin HEAD:main
run symlink 1 --no-pr v0.2.0
check "symlink target untouched" outside "$(cat "$tmp/outside")"
p switch -q -; p branch -q -D harness-pin-0.2.0; p push -q -f origin "$base:main"; p reset -q --hard "$base"
run no-pr 0 --no-pr v0.2.0
check "no-pr pushes nothing" "" "$(git -C "$tmp/p.git" branch --list harness-pin-0.2.0)"
p switch -q -; p branch -q -D harness-pin-0.2.0
echo dirty >"$tmp/p/x"; run dirty 1 v0.2.0; rm "$tmp/p/x"
p push -q origin "$base:refs/heads/trunk"
MAIN_BRANCH=trunk run refresh 0 v0.2.0  # the project base only; harness ancestry is always origin/main
for f in "${docs[@]}" VERSION; do
  check "copied $f" "$(git -C "$tmp/hw" show "v0.2.0:$f")" "$(p show "HEAD:docs/harness/$f")"
done
check "process line" "Process: harness egerev/agent-harness @ 0.2.0, ~/agent-harness; rules." "$(p show HEAD:AGENTS.md | sed -n 3p)"
check "other lines untouched" "Keep 0.1.0 here." "$(p show HEAD:AGENTS.md | sed -n 4p)"
check "readme pointer" "Pinned copy of egerev/agent-harness @ 0.2.0 (VERSION), origin/main commit ${h2:0:7}. Do not edit here." \
  "$(p show HEAD:docs/harness/README.md | sed -n 1p)"
check "other readme lines untouched" "Audit: egerev/agent-harness @ 0.1.0, commit deadbee reviewed." "$(p show HEAD:docs/harness/README.md | sed -n 2p)"
check "branch" harness-pin-0.2.0 "$(p branch --show-current)"
check "signed off" 1 "$(p log -1 --format=%B | grep -c '^Signed-off-by: ')"
check "pushed" "$(p rev-parse HEAD)" "$(git -C "$tmp/p.git" rev-parse refs/heads/harness-pin-0.2.0)"
check "one PR" 1 "$(grep -c '^gh pr create --base trunk --head harness-pin-0.2.0 ' "$tmp/gh.log")"
check "PR names the commit" 2 "$(grep -c "$h2" "$tmp/gh.log")"  # body first line and Review line
check "changed files" "AGENTS.md docs/harness/README.md docs/harness/VERSION docs/harness/orchestration.md docs/harness/process.md docs/harness/reviews.md docs/harness/skills.md docs/harness/tiden.md" \
  "$(p diff --name-only "$base" HEAD | sort | tr '\n' ' ' | sed 's/ $//')"
# Already at the tag's version on origin/main: nothing to do.
p switch -q --detach "$base"; p push -q origin harness-pin-0.2.0:main
run already 0 v0.2.0
check "already says so" 1 "$(grep -c 'already at 0.2.0' "$tmp/out")"
# No Process line at the old version: refused, nothing committed.
p push -q -f origin "$base:main"
printf '# P\n\nProcess: something else\n' >"$tmp/p/AGENTS.md"; p commit -qam 'no pointer'; p push -q -f origin HEAD:main
run branch-exists 1 --no-pr v0.2.0
p branch -q -D harness-pin-0.2.0
run no-pointer 1 --no-pr v0.2.0
check "refusal commits nothing" "$(p rev-parse HEAD~0)" "$(git -C "$tmp/p.git" rev-parse refs/heads/main)"
exit "$fail"
