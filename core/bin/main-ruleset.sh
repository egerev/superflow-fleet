#!/usr/bin/env bash
# Main branch ruleset: the owner runs it (process.md section 2, item 1); agents prepare the JSON.
# Usage: main-ruleset.sh check | create | remove-classic | rollback
# Run from the root of a clean checkout of the default branch that holds RULESET_JSON (and
# PROTECTION_JSON when the repository still has classic branch protection). Every step asserts
# its read-back and stops on the first failure; a stop never leaves main without protection.
# Config: REPO, RULESET_JSON (repository path; template core/templates/main-ruleset.json);
# optional PROTECTION_JSON (classic protection as the repository keeps it), MAIN_BRANCH (main),
# RULESET_MIN_RULES (rule types the ruleset must hold; default deletion non_fast_forward
# pull_request required_status_checks, the last with at least one check).
# A GitHub plan without rulesets for private repositories answers 403: use the pre-push guard
# (core/templates/githooks/pre-push) and record that in the project's facts.
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../lib/config.sh"
harness_load_config
require REPO RULESET_JSON
[[ $REPO =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "REPO must be owner/name"
B=${MAIN_BRANCH:-main}
R=repos/$REPO
OWNER=${REPO%%/*} RNAME=${REPO#*/}
[ -f "$RULESET_JSON" ] || die "run from the repository root ($RULESET_JSON not found)"
NAME=$(jq -er .name "$RULESET_JSON") || die "$RULESET_JSON has no name"
RULES=$(jq -c '[.rules[].type] | sort' "$RULESET_JSON")
# An empty or inactive ruleset would pass every read-back below (disabled rulesets have no
# effective rules), and remove-classic would then leave the branch unprotected. Rollback skips
# this guard: it restores classic protection whatever the ruleset file holds.
require_minimum() {
  jq -e '.enforcement=="active" and .target=="branch"' "$RULESET_JSON" >/dev/null \
    || die "$RULESET_JSON must be an active branch ruleset"
  local r
  for r in ${RULESET_MIN_RULES:-deletion non_fast_forward pull_request required_status_checks}; do
    jq -e --arg r "$r" 'any(.rules[]; .type==$r)' "$RULESET_JSON" >/dev/null || die "$RULESET_JSON has no $r rule"
  done
  jq -e 'any(.rules[]; .type=="required_status_checks" and (.parameters.required_status_checks|length)>0)' \
    "$RULESET_JSON" >/dev/null || die "$RULESET_JSON requires no status check"
}
P=${PROTECTION_JSON:-}
[ -z "$P" ] || [ -f "$P" ] || die "PROTECTION_JSON $P not found"
# Classic protection projected to the settings PROTECTION_JSON sets (both API shapes).
CLASSIC='def on: if type=="object" then .enabled else . end;
  {strict:.required_status_checks.strict, checks:(.required_status_checks.checks|sort_by(.context)),
   admins:(.enforce_admins|on), conversations:(.required_conversation_resolution|on),
   force_pushes:(.allow_force_pushes|on), deletions:(.allow_deletions|on),
   reviews:(.required_pull_request_reviews|{dismiss_stale_reviews,require_code_owner_reviews,
     required_approving_review_count,require_last_push_approval})}'
# Every value in RULESET_JSON must be present and equal in the live ruleset;
# array order is ignored (rules by type, checks by context, strings sorted).
# shellcheck disable=SC2016  # $a, $b, $want are jq variables
SUBSET='def norm: if type=="object" then map_values(norm)
    elif type=="array" then map(norm) | (if all(type=="object") and all(has("type")) then sort_by(.type)
      elif all(type=="object") and all(has("context")) then sort_by(.context) elif all(type=="string") then sort else . end)
    else . end;
  def sub($a;$b): if ($a|type)=="object" then ($b|type)=="object" and ([$a|keys[]|. as $k|sub($a[$k];$b[$k])]|all)
    elif ($a|type)=="array" then ($b|type)=="array" and ($a|length)==($b|length) and ([range($a|length) as $i|sub($a[$i];$b[$i])]|all)
    else $a==$b end;
  sub($want[0]|norm; norm)'
# shellcheck disable=SC2016  # GraphQL variables
QUEUE='query($o:String!,$n:String!,$b:String!){repository(owner:$o,name:$n){mergeQueue(branch:$b){entries{totalCount}}}}'

# The reviewed files are the ones on the default branch (DEPLOY_REF only for offline tests).
ref=${DEPLOY_REF:-}
if [ -z "$ref" ]; then git fetch -q origin "$B"; ref=FETCH_HEAD; fi
files=("$RULESET_JSON"); [ -z "$P" ] || files+=("$P")
git diff --quiet "$ref" -- "${files[@]}" \
  || die "ruleset files differ from $B; use a clean checkout of the current $B"

ruleset_ids() { gh api "$R/rulesets" | jq -c --arg n "$NAME" '[.[]|select(.name==$n)|.id]'; }
classic_present() {
  local out
  if out=$(gh api "$R/branches/$B/protection" 2>&1); then return 0; fi
  grep -q 'HTTP 404' <<<"$out" && return 1
  die "cannot read classic protection: $out"
}
assert_classic() {
  [ -n "$P" ] || die "classic protection is present but PROTECTION_JSON is not set"
  classic_present || die "classic protection is absent"
  [ "$(gh api "$R/branches/$B/protection" | jq -cS "$CLASSIC")" = "$(jq -cS "$CLASSIC" "$P")" ] \
    || die "classic protection differs from $P"
}
assert_ruleset() {
  gh api "$R/rulesets/$1" | jq -e --slurpfile want "$RULESET_JSON" ".enforcement==\"active\" and ($SUBSET)" >/dev/null \
    || die "ruleset $1 is not active or differs from $RULESET_JSON"
  gh api "$R/rules/branches/$B" | jq -e --argjson id "$1" --argjson want "$RULES" \
    'length>0 and ([.[]|.type]|sort)==$want and all(.[]; .ruleset_id==$id)' >/dev/null \
    || die "effective rules on $B are not exactly ruleset $1"
}
assert_queue_empty() {
  [ "$(gh api graphql -f query="$QUEUE" -F o="$OWNER" -F n="$RNAME" -F b="$B" \
      --jq '.data.repository.mergeQueue.entries.totalCount // 0')" = 0 ] \
    || die "merge queue is not empty; dequeue its entries first"
}

case "${1:-}" in check|create|remove-classic) require_minimum ;; esac
case "${1:-}" in
check)
  ids=$(ruleset_ids); echo "ruleset '$NAME': $ids"
  if [[ $ids =~ ^\[([0-9]+)\]$ ]]; then assert_ruleset "${BASH_REMATCH[1]}"; echo "OK: ruleset matches $RULESET_JSON"; fi
  if classic_present; then echo "classic protection: present"; else echo "classic protection: absent"; fi ;;
create)
  [ "$(ruleset_ids)" = '[]' ] || die "ruleset '$NAME' already exists"
  had_classic=; if classic_present; then assert_classic; had_classic=1; fi
  id=$(gh api --method POST "$R/rulesets" --input "$RULESET_JSON" --jq .id)
  [[ $id =~ ^[0-9]+$ ]] || die "ruleset creation returned no id"
  assert_ruleset "$id"; [ -z "$had_classic" ] || assert_classic
  echo "OK: ruleset $id active; classic protection unchanged" ;;
remove-classic)
  ids=$(ruleset_ids); [[ $ids =~ ^\[[0-9]+\]$ ]] || die "expected exactly one ruleset '$NAME', got $ids"
  id=$(jq '.[0]' <<<"$ids"); assert_ruleset "$id"
  if classic_present; then assert_classic; gh api --method DELETE "$R/branches/$B/protection"; fi
  ! classic_present || die "classic protection is still present"
  assert_ruleset "$id"
  echo "OK: classic protection removed; ruleset $id is the only protection" ;;
rollback)
  [ -n "$P" ] || die "no PROTECTION_JSON: a rollback would leave $B unprotected"
  assert_queue_empty
  ids=$(ruleset_ids); [[ $ids =~ ^\[([0-9]+)?\]$ ]] || die "expected at most one ruleset '$NAME', got $ids"
  gh api --method PUT "$R/branches/$B/protection" --input "$P" >/dev/null
  assert_classic
  if [ "$ids" != '[]' ]; then
    id=$(jq '.[0]' <<<"$ids"); gh api --method DELETE "$R/rulesets/$id"
  fi
  [ "$(ruleset_ids)" = '[]' ] || die "ruleset '$NAME' is still present"
  echo "OK: classic protection restored; ruleset removed" ;;
*) die "usage: main-ruleset.sh check | create | remove-classic | rollback" ;;
esac
