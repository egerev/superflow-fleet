#!/usr/bin/env bash
# Checks core/templates/dcg-allowlist.toml with the installed dcg: it allows only an agent's own cleanup (`rm -r tmp...`
# inside a worktree, `docker rm` of `<proj>_<name>` containers) and leaves the rest blocked. Uses a throwaway
# XDG_CONFIG_HOME with inherited DCG_* overrides cleared and history off, never the user's dcg config or state.
# The checkout's parent stands in for the worktrees directory: <wt>/tests is two levels below it, <wt> one.
# Skips without dcg.
# Run: bash core/tests/dcg-allowlist.test.sh
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
command -v dcg >/dev/null || { echo "SKIP dcg not installed"; exit 0; }
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
mkdir -p "$tmp/dcg" "$tmp/bare/dcg"
printf '[packs]\nenabled = ["core.filesystem", "containers.docker"]\n' >"$tmp/dcg/config.toml"
cp "$tmp/dcg/config.toml" "$tmp/bare/dcg/config.toml"
sed "s|@WORKTREES@|$(dirname "$root")|g" "$root/templates/dcg-allowlist.toml" >"$tmp/dcg/allowlist.toml"
fail=0
check() { # expected-decision cwd command; XDG: config without the allowlist
  local got
  got=$(cd "$2" && env -u DCG_CONFIG -u DCG_ALLOWLIST_SYSTEM_PATH -u DCG_HISTORY_DB -u DCG_SESSION_ID \
    DCG_HISTORY_DISABLED=1 XDG_CONFIG_HOME="${XDG:-$tmp}" dcg test --robot "$3" 2>/dev/null | jq -r .decision) || true
  if [ "$got" = "$1" ]; then echo "ok   $1 ${2/#$root/<wt>}: $3"
  else echo "FAIL want $1 got $got in ${2/#$root/<wt>}: $3"; fail=1; fi
}
wt=$root/tests
# Control: without the allowlist dcg blocks these, so the allow cases below prove the entries.
XDG=$tmp/bare check deny "$wt" 'rm -r tmp'
XDG=$tmp/bare check deny "$HOME" 'docker rm proj_pg_x-fixtures'
check allow "$wt" 'rm -r tmp'
check allow "$wt" 'rm -r tmp_build tmp-out tmp.1'
check allow "$root/public/modules" 'rm -r tmp'  # deeper than <project>/<worktree>: the second path entry
check deny "$wt" 'rm -r build'  # only tmp... names: a sibling worktree is never one
check deny "$wt" 'rm -r tmp build'
check deny "$wt" 'rm -r tmp/x'  # one path component: no traversal through a symlink
check deny "$root" 'rm -r tmp'  # one level below the worktrees directory: a project directory
# shellcheck disable=SC2016 # literal commands for dcg
for c in 'rm -r .' 'rm -r ./tmp' 'rm -r tmp/' 'rm -r ../tmp' 'rm -r tmp/../../x' 'rm -r /tmp_x' \
  'rm -r ~/tmp' 'rm -r tmp*' 'rm -r $HOME' 'rm -r tmp; rm -r ../x' 'cd .. && rm -r tmp' 'rm -rf tmp' \
  'rm -r -f tmp' 'rm -R tmp' 'rm -r .tmp'; do
  check deny "$wt" "$c"
done
check deny "$HOME" 'rm -r tmp'  # outside the worktrees directory
check allow "$HOME" 'docker rm proj_pg_fix474'
check allow "$HOME" 'docker rm proj_pg_x-fixtures'
check allow "$HOME" 'docker rm -v proj_pg_a proj_pg_b-fix'
check allow "$HOME" 'docker container rm proj_pg_a-fix'
for c in 'docker rm -f proj_pg_a' 'docker rm proj_pg_a -f' 'docker rm proj_pg_a --force' 'docker rm proj-pg-fix' \
  'docker rm proj_pg_a; docker rm -f x-f'; do
  check deny "$HOME" "$c"
done
exit "$fail"
