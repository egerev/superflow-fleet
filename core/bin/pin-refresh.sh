#!/usr/bin/env bash
# Refresh a project's pinned harness copy (README, How a project consumes it, Pinned copy) from a harness
# tag and open its pull request. A clean-reviewed refresh needs no new owner yes (process.md section 3).
# In the project checkout (clean working tree): a new branch harness-pin-<version> from origin/<main>,
# docs/harness/{process,reviews,tiden,orchestration,skills}.md and VERSION copied verbatim from the tag's
# commit of HARNESS_DIR (default ~/agent-harness, fetched first), and the two version pointers:
# `agent-harness @ <old>` in the AGENTS.md `Process:` line and in docs/harness/README.md (where present,
# with its `commit <sha>`). It refuses any other changed file, commits (-s), pushes and opens the PR;
# merging stays with the caller after the review. --no-pr stops after the commit. A refusal after the
# switch leaves the branch and its edits for inspection.
# Usage: pin-refresh.sh [-C <project checkout>] [--no-pr] <vX.Y.Z>
# Exit: 0 PR opened (or committed with --no-pr, or the pin is already at that version), 1 refused, 2 usage.
set -euo pipefail
usage() { echo "usage: pin-refresh.sh [-C <project checkout>] [--no-pr] <vX.Y.Z>" >&2; exit 2; }
refuse() { echo "REFUSED: $*" >&2; exit 1; }
dir=. pr=1
while [ $# -gt 1 ]; do
  case $1 in
    -C) [ -n "${2:-}" ] || usage; dir=$2; shift 2 ;;
    --no-pr) pr=; shift ;;
    *) usage ;;
  esac
done
[ $# -eq 1 ] && [[ $1 =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || usage
tag=$1 new=${BASH_REMATCH[1]}
h=${HARNESS_DIR:-$HOME/agent-harness}
main=${MAIN_BRANCH:-main}
files=(process.md reviews.md tiden.md orchestration.md skills.md VERSION)

git -C "$h" fetch -q --tags origin || refuse "cannot fetch $h"
sha=$(git -C "$h" rev-parse --verify --quiet "refs/tags/$tag^{commit}") || refuse "no tag $tag in $h"
[ "$(git -C "$h" show "$sha:VERSION" | tr -d '[:space:]')" = "$new" ] || refuse "$tag's VERSION is not $new"
# Only a merged harness version is pinned (README, Pinned copy): a local tag on a draft commit is refused.
git -C "$h" merge-base --is-ancestor "$sha" refs/remotes/origin/main 2>/dev/null \
  || refuse "$tag ($sha) is not on harness origin/main"
cd "$dir"
git rev-parse --git-dir >/dev/null 2>&1 || usage
[ -z "$(git status --porcelain --untracked-files=all)" ] || refuse "working tree of $dir is not clean"
git fetch -q origin "$main"
old=$(git show "FETCH_HEAD:docs/harness/VERSION" 2>/dev/null | tr -d '[:space:]') \
  || refuse "no docs/harness/VERSION on origin/$main"
[[ $old =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || refuse "docs/harness/VERSION on origin/$main is not a version: $old"
if [ "$old" = "$new" ]; then echo "OK: docs/harness is already at $new"; exit 0; fi
branch=harness-pin-$new
! git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null || refuse "branch $branch exists"
git switch -q --no-track -c "$branch" FETCH_HEAD

# A symlink at a destination would send the copy outside the checkout.
[ -d docs/harness ] && [ ! -L docs/harness ] || refuse "docs/harness is not a directory"
for p in AGENTS.md "${files[@]/#/docs/harness/}" docs/harness/README.md; do
  [ ! -L "$p" ] || refuse "$p is a symlink"
done
for f in "${files[@]}"; do git -C "$h" show "$sha:$f" >"docs/harness/$f"; done
# Only the version on the pointer lines changes; dots in $old are escaped for sed.
o=${old//./\\.}
sed -i.bak -E "/^Process: /s/agent-harness @ $o([^0-9]|$)/agent-harness @ $new\1/" AGENTS.md \
  || refuse "cannot edit AGENTS.md"
rm AGENTS.md.bak
grep -qE "^Process: .*agent-harness @ $new([^0-9]|$)" AGENTS.md || refuse "AGENTS.md has no Process line at $old"
if [ -f docs/harness/README.md ]; then
  # Only the pointer line (`Pinned copy of ... @ <version>`): its version and its `commit <sha>`.
  sed -i.bak -E "/^Pinned copy of .*agent-harness @ $o([^0-9]|$)/{s/agent-harness @ $o([^0-9]|$)/agent-harness @ $new\1/;s/commit [0-9a-f]{7,40}/commit ${sha:0:7}/;}" \
    docs/harness/README.md || refuse "cannot edit docs/harness/README.md"
  rm docs/harness/README.md.bak
  ! grep -qE "^Pinned copy of .*agent-harness @ $o([^0-9]|$)" docs/harness/README.md \
    || refuse "docs/harness/README.md pointer still names $old"
fi
paths=(AGENTS.md "${files[@]/#/docs/harness/}")
[ ! -e docs/harness/README.md ] || paths+=(docs/harness/README.md)
git add -- "${paths[@]}"
# Only the allowed paths are staged, and nothing else is left changed or untracked.
extra=$(git diff --cached --name-only | grep -vxF "$(printf '%s\n' "${paths[@]}")" || true)
[ -z "$extra" ] || refuse "unexpected staged files: $extra"
[ -z "$(git status --porcelain --untracked-files=all | grep -v '^[MA]  ' || true)" ] || refuse "unexpected changes left in $dir"
git commit -q -s -m "docs/harness: refresh pinned harness copy $old -> $new" \
  -m "Copied verbatim from egerev/agent-harness $tag ($sha)."
echo "OK: committed $branch ($old -> $new, harness $sha)"
[ -n "$pr" ] || exit 0
git push -q -u origin "$branch"
gh pr create --base "$main" --head "$branch" --title "docs/harness: harness pin $old -> $new" --body "\
Pinned-copy refresh: docs/harness/ copied verbatim from egerev/agent-harness $tag ($sha), plus the version
pointers (AGENTS.md Process line, docs/harness/README.md). No other file changes.

Change path: OWNER (harness process.md section 3: a clean-reviewed pinned-copy refresh needs no new owner yes)
Review: check each copied file equals \`git -C ~/agent-harness show $sha:<file>\` and the diff holds only these files."
