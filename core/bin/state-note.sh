#!/usr/bin/env bash
# Appends one journal line to <orchestrator dir>/archive/journal.md, so STATE.md stays a short
# current state (orchestration.md, STATE.md: at most ~60 lines; modules/superset/bin/orchestrator-check.sh warns
# above 60 lines or 8 KB). The SessionStart hook never prints the journal.
# Usage: <orchestrator dir>/bin/state-note.sh <section> "<line>"
#   section: the STATE.md section or topic the line belongs to (NOW, Live workers, PR#12, ...)
set -uo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../lib/config.sh"
harness_load_config
[ $# -eq 2 ] || die "usage: state-note.sh <section> \"<line>\""
section=$1 line=$2
[ -n "${section// /}" ] && [ -n "${line// /}" ] || die "section and line must not be empty"
case "$section$line" in *$'\n'*|*$'\r'*) die "one line only: call state-note.sh once per line" ;; esac
mkdir -p "$ORCH_DIR/archive" || die "cannot create $ORCH_DIR/archive"
journal="$ORCH_DIR/archive/journal.md"
[ -s "$journal" ] || printf '# Orchestrator journal (core/bin/state-note.sh; never read on start)\n\n' >>"$journal" \
  || die "cannot write $journal"
printf -- '- %s [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$section" "$line" >>"$journal" || die "cannot write $journal"
echo "noted in $journal"
