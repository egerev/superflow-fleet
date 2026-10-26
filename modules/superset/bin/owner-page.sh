#!/usr/bin/env bash
# The project's owner page (orchestration.md, Owner page): the open owner questions, one item per
# question, and the digest, as one Superset page the owner reads and answers by pinned comments.
# Usage: owner-page.sh publish <label> | comments | check
#   publish: privacy check, then publish $ORCH_DIR/owner-page.html as a new version of the
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
#   comments: the open comment threads (thread id, anchor = question id, author, text).
#   check: the privacy check only.
# Exit: 0 done, 1 refused (privacy check, config, usage), 2 superset failed.
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
harness_load_config
require PROJECT ORCH_WORKSPACE_ID
src=$ORCH_DIR/owner-page.html idf=$ORCH_DIR/owner-page.id nf=$ORCH_DIR/owner-page.notified
cmd=${1:-}
command -v jq >/dev/null || die "jq is required"

# The page leaves the machine (Superset hosts it) and can be widened to the org: refuse anything
# that looks like a secret or personal data. Patterns, not proof: the author still reads the page.
# grep exit 1 = no match; any other exit refuses, so a broken scan never passes.
privacy_check() {
  [ -f "$src" ] || die "no $src: copy the harness modules/superset/templates/owner-page.html there and fill it"
  local hits rc=0
  hits=$(grep -n -i -E \
    -e 'sk_(live|test)_|sk-(proj|ant|svcacct)-|sk-[A-Za-z0-9]{32,}|gh[pousr]_[A-Za-z0-9]{20}|github[_]pat_' \
    -e 'xox[abprs]-|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30}|BEGIN [A-Z ]*PRIVATE KEY' \
    -e "(password|passwd|secret|token|api[_-]?key)[\"']?[[:space:]]*[:=]" \
    -e '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    -e '\+[0-9][0-9 ()-]{9,}[0-9]' \
    -e '[a-z][a-z0-9+.-]*://[^ /:@]*:[^ /@]+@' \
    "$src") || rc=$?
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

# The stored page id; refuses a missing or malformed one (an empty --page would sweep every page).
page_id() {
  local id
  [ -s "$idf" ] || die "no $idf: publish the owner page first"
  id=$(cat "$idf") || die "cannot read $idf"
  is_uuid "$id" || die "$idf does not hold a page id"
  printf '%s\n' "$id"
}

case "$cmd" in
  check) privacy_check; echo "owner page: privacy check passed" ;;
  publish)
    label=${2:-}; [ -n "$label" ] || die "usage: owner-page.sh publish <what changed>"
    privacy_check
    if [ -e "$idf" ]; then
      id=$(page_id)
      out=$(superset pages publish "$src" --page "$id" --label "$label" --json) || exit 2
    else
      [ -w "$ORCH_DIR" ] || die "cannot write $idf"
      out=$(superset pages publish "$src" --title "$PROJECT: owner" \
        --description "Open owner questions (answer by comment) and the digest" \
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
      superset notifications show "$PROJECT: owner question" --body "new: $(paste -sd ' ' - <<<"$new") — $label" \
        --sound --workspace "$ORCH_WORKSPACE_ID" ${term:+--terminal "$term"} >/dev/null \
        || { ok=0; echo "owner page: notification failed (the page is published)" >&2; }
    fi
    [ "$ok" = 0 ] || printf '%s\n' "$ids" >"$nf" || echo "owner page: cannot record $nf" >&2 ;;
  comments)
    id=$(page_id)
    superset pages comments list --page "$id" --open || exit 2 ;;
  *) die "usage: owner-page.sh publish <label> | comments | check" ;;
esac
