#!/usr/bin/env bash
# The orchestrator address of a project (orchestration.md, Sessions, Orchestrator address): one registry,
# written on every orchestrator start and restart, read instead of a name copied into a brief or STATE.md.
# Usage: boss-of.sh [<project>]   print the project's orchestrator session name (no argument: this config's PROJECT)
#        boss-of.sh set <name>    record <name> for this config's PROJECT: <orchestrator dir>/orch-name and its
#                                 row in the shared registry (one row per project, older rows replaced)
# Registry: HARNESS_BOSSES, default ~/.config/agent-harness/bosses.tsv; rows <project> TAB <name> TAB
# <orchestrator dir> TAB <UTC time>. A read prefers the row's <orchestrator dir>/orch-name (the project's own
# record), then the last row of the project. <project> is the PROJECT of that project's config.sh. Only a project's
# own orchestrator runs set (it always writes its own PROJECT). Exit 0 printed or recorded; 1 no record (ListAgents
# finds the session; never set another project's name) or refused (usage, a bad name or directory, no config, the
# lock held 5 s, a failed write: nothing is printed as OK).
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
reg=${HARNESS_BOSSES:-$HOME/.config/agent-harness/bosses.tsv}
valid() { [[ $1 =~ ^[A-Za-z0-9._-]+$ ]]; }

if [ "${1:-}" = set ]; then
  [ $# -eq 2 ] || die "usage: boss-of.sh set <name>"
  name=$2
  valid "$name" || die "name has unexpected characters: $name"
  harness_load_config
  require PROJECT
  # shellcheck disable=SC2153  # PROJECT comes from the config
  valid "$PROJECT" || die "config.sh: PROJECT has unexpected characters"
  # A tab or newline would split the TSV row.
  case $ORCH_DIR in *$'\t'* | *$'\n'*) die "orchestrator directory holds a tab or newline: $ORCH_DIR" ;; esac
  mkdir -p "$(dirname "$reg")"
  # mkdir is the lock (no flock on macOS): two orchestrators restarting at once must not drop each other's row.
  lock=$reg.lock n=0
  until mkdir "$lock" 2>/dev/null; do
    n=$((n + 1)); [ "$n" -lt 50 ] || die "registry lock $lock held for 5 s: remove it if no boss-of.sh runs"
    sleep 0.1
  done
  trap 'rmdir "$lock"' EXIT
  # Explicit checks: a failed redirect inside && or if is exempt from set -e.
  { printf '%s\n' "$name" >"$ORCH_DIR/orch-name.tmp" && mv "$ORCH_DIR/orch-name.tmp" "$ORCH_DIR/orch-name"; } \
    || die "cannot write $ORCH_DIR/orch-name"
  tmp=$(mktemp "$reg.XXXXXX") || die "cannot create a temporary file beside $reg"
  # ("" $1) keeps the comparison a string one: awk compares numeric-looking fields as numbers (01 == 1).
  # A failed awk must not publish a registry without the other projects' rows.
  if ! { { [ ! -f "$reg" ] || awk -F'\t' -v p="$PROJECT" '("" $1) != ("" p)' "$reg"; } \
         && printf '%s\t%s\t%s\t%s\n' "$PROJECT" "$name" "$ORCH_DIR" "$(date -u +%Y-%m-%dT%H:%MZ)"; } >"$tmp" \
     || ! mv "$tmp" "$reg"; then
    rm "$tmp" 2>/dev/null; die "cannot write $reg"
  fi
  echo "OK: $PROJECT -> $name"
  exit 0
fi

[ $# -le 1 ] || die "usage: boss-of.sh [<project>] | set <name>"
if [ $# -eq 1 ]; then project=$1
else harness_load_config; require PROJECT; project=$PROJECT; fi
valid "$project" || die "project has unexpected characters: $project"
row=
[ ! -f "$reg" ] || row=$(awk -F'\t' -v p="$project" '("" $1) == ("" p) { r = $0 } END { if (r != "") print r }' "$reg")
[ -n "$row" ] || { echo "STOP: no registry row for $project in $reg: find its orchestrator with ListAgents (only that project's orchestrator runs set)" >&2; exit 1; }
IFS=$'\t' read -r _ name dir _ <<<"$row"
if [ -n "$dir" ] && [ -s "$dir/orch-name" ]; then
  own=$(head -n 1 "$dir/orch-name")
  ! valid "$own" || name=$own
fi
valid "$name" || die "registry row for $project has a bad name: $name"
echo "$name"
