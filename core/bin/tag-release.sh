#!/usr/bin/env bash
# Tag a squash merge with its version (README, How to change it): the annotated tag v<VERSION> on
# <commit> (default origin/main), VERSION read from that commit's tree. Idempotent: the annotated tag
# already on that commit is OK. Refuses a tag that exists on another commit (a merge without a VERSION
# bump), a lightweight tag of that name, and a <version> (with or without v) that differs from the
# commit's VERSION. It does not check that <commit> is on main: pass the pull request's merge commit.
# Local only: pushing the tag is a separate step (the printed `git push` line).
# Usage: tag-release.sh [-C <repo dir>] [<commit> [<version>]]
# Exit: 0 tagged or already tagged, 1 refused, 2 usage, no repository, commit or VERSION.
set -euo pipefail
usage() { echo "usage: tag-release.sh [-C <repo dir>] [<commit> [<version>]]" >&2; exit 2; }
dir=.
if [ "${1:-}" = -C ]; then
  if [ $# -lt 2 ] || [ -z "$2" ]; then usage; fi
  dir=$2; shift 2
fi
[ $# -le 2 ] || usage
commit=${1:-origin/main} want=${2:-}
git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $dir" >&2; exit 2; }
sha=$(git -C "$dir" rev-parse --verify --quiet "$commit^{commit}") || { echo "no commit: $commit" >&2; exit 2; }
version=$(git -C "$dir" show "$sha:VERSION" 2>/dev/null | tr -d '[:space:]') || true
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "no MAJOR.MINOR.PATCH VERSION in $sha: '$version'" >&2; exit 2; }
if [ -n "$want" ] && [ "${want#v}" != "$version" ]; then
  echo "REFUSED: $sha has VERSION $version, not ${want#v}" >&2; exit 1
fi
tag=v$version
if old=$(git -C "$dir" rev-parse --verify --quiet "refs/tags/$tag^{commit}"); then
  [ "$old" = "$sha" ] || { echo "REFUSED: $tag already tags $old, not $sha (VERSION not bumped?)" >&2; exit 1; }
  [ "$(git -C "$dir" cat-file -t "refs/tags/$tag")" = tag ] \
    || { echo "REFUSED: $tag on $sha is a lightweight tag, not an annotated one" >&2; exit 1; }
  echo "OK: $tag already on $sha"
else
  git -C "$dir" tag -a "$tag" -m "$tag" "$sha"
  echo "OK: tagged $tag on $sha"
fi
printf 'push: git -C %q push origin refs/tags/%s\n' "$dir" "$tag"
