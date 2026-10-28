#!/usr/bin/env bash
# Orchestrator self-restart (orchestration.md, Orchestrator self-restart): a new terminal in the
# orchestrator's own Superset workspace, never a new workspace. The successor reads STATE.md,
# records its name (modules/superset/bin/boss-of.sh set), announces it to live workers and then closes this terminal. The new terminal's ID goes to
# <orchestrator dir>/orch-terminal, so wake automations (modules/superset/bin/wake.sh) wake the successor, not this session.
# Usage: orchestrator-restart.sh [--keep-old] <old orchestrator name> [old terminal id]
#   --keep-old (or HARNESS_KEEP_OLD=1, or a line "Keep old session: yes" in STATE.md): the prompt has no
#   close step (the old session has live subagents). Otherwise the close step is generated here and put
#   where the template has {CLOSE_STEP} (after the successor has read STATE.md); the template itself
#   must not hold a `superset terminals` command. HARNESS_DRY_RUN=1 prints the command only.
# Before the successor starts, the old name goes to the address registry (modules/superset/bin/boss-of.sh set; PROJECT in the config): a
# held lock or an unwritable registry stops the restart before any terminal is created (a dry run writes nothing).
# A template without a `boss-of.sh set` step is refused like one without {CLOSE_STEP}.
# Config: PROJECT, ORCH_WORKSPACE_ID, ORCH_MODEL, ORCH_EFFORT; optional ORCH_CLAUDE_FLAGS (word-split),
# ORCH_SUCCESSOR_PROMPT (file; {OLD_NAME}, {STATE}, {WORKSPACE}, {ORCH_DIR}, {CLOSE_STEP} are replaced), STATE_MAX_AGE_MIN.
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../../../core/lib/config.sh"
harness_load_config
require PROJECT ORCH_WORKSPACE_ID ORCH_MODEL ORCH_EFFORT
keep_old=
[ "${HARNESS_KEEP_OLD:-}" != 1 ] || keep_old=1
if [ "${1:-}" = --keep-old ]; then keep_old=1; shift; fi
[ $# -ge 1 ] && [ $# -le 2 ] || die "usage: orchestrator-restart.sh [--keep-old] <old orchestrator name> [old terminal id]"
old=$1 term=${2:-${SUPERSET_TERMINAL_ID:-}}
[ -n "$term" ] || die "no old terminal id (argument 2 or SUPERSET_TERMINAL_ID)"
[ -z "${SUPERSET_WORKSPACE_ID:-}" ] || [ "$SUPERSET_WORKSPACE_ID" = "$ORCH_WORKSPACE_ID" ] \
  || die "this terminal is not in ORCH_WORKSPACE_ID; restart only inside the orchestrator's workspace"
[[ $old =~ ^[A-Za-z0-9._-]+$ ]] || die "name has unexpected characters"
is_uuid "$term" || die "old terminal id is not a UUID: $term"
is_uuid "$ORCH_WORKSPACE_ID" || die "ORCH_WORKSPACE_ID is not a UUID"
state=$ORCH_DIR/STATE.md
[ -f "$state" ] || die "no $state"
if grep -qiE '^Keep old session: *yes' "$state"; then keep_old=1; fi
# Step 1 of the restart is a fresh STATE.md; refuse a stale one.
max=${STATE_MAX_AGE_MIN:-30}
[ -n "$(find "$state" -mmin "-$max" 2>/dev/null)" ] || die "STATE.md is older than $max min: rewrite it first (step 1)"
# New harness scripts get their bin/ link here (a non-link file of the same name is kept).
if [ -z "${HARNESS_DRY_RUN:-}" ]; then harness_link_scripts "$ORCH_DIR" --add || die "cannot add the bin/ links of new harness scripts to $ORCH_DIR/bin"; fi
# The address registry (modules/superset/bin/boss-of.sh) holds the old name until the successor records its own (template step),
# so a project that never ran `boss-of.sh set` has a row from its first restart on.
if [ -z "${HARNESS_DRY_RUN:-}" ]; then "$(dirname "$0")/boss-of.sh" set "$old" >/dev/null || die "cannot record $old in the address registry (modules/superset/bin/boss-of.sh)"; fi
tpl=${ORCH_SUCCESSOR_PROMPT:-$(harness_root)/modules/superset/templates/orchestrator-successor-prompt.md}
[ -f "$tpl" ] || die "no successor prompt template: $tpl"
# The close step is generated here, never read from the template: a template (a project copy included)
# with its own close command or without {CLOSE_STEP} is refused instead of closing at the wrong moment.
grep -q '^{CLOSE_STEP}$' "$tpl" || die "$tpl has no {CLOSE_STEP} line (modules/superset/templates/orchestrator-successor-prompt.md): migrate the copy"
# Checked on the joined text: a command wrapped over lines is still a command.
prompt=$(grep -v '^<!--' "$tpl" | tr '\n' ' ')
# Without the set step the registry keeps the old name after the close, and every send to it fails (harness 0.35.0).
printf '%s' "$prompt" | grep -Eq 'boss-of\.sh[[:space:]]+set' \
  || die "$tpl has no boss-of.sh set step (modules/superset/templates/orchestrator-successor-prompt.md): migrate the copy"
! printf '%s' "$prompt" | grep -Eq 'terminals[[:space:]]+close' || die "$tpl holds a close command: use the {CLOSE_STEP} line"
# The successor records itself as the wake target (wake.sh target) before any close, so a lost
# create response below never leaves wakes pointing at a closed terminal.
target_step="After the steps above, run exactly, with no argument after target: $(printf %q "$ORCH_DIR/bin/wake.sh") target"
if [ -n "$keep_old" ]; then
  close_step="$target_step Your predecessor's terminal stays open: do not close it."
else
  close_step="$target_step Only when it prints OK, and unless STATE.md says \"Keep old session: yes\", close your predecessor's terminal with exactly: superset terminals close --local --workspace $ORCH_WORKSPACE_ID --terminal $term . If it fails, leave the predecessor open and fix the wake target first."
fi
# Quoted replacements: bash 5.2+ (patsub_replacement) would turn an unquoted & into the match.
prompt=${prompt//\{OLD_NAME\}/"$old"}; prompt=${prompt//\{STATE\}/"$state"}
prompt=${prompt//\{WORKSPACE\}/"$ORCH_WORKSPACE_ID"}; prompt=${prompt//\{CLOSE_STEP\}/"$close_step"}
prompt=${prompt//\{ORCH_DIR\}/"$ORCH_DIR"}
read -r -a extra <<<"${ORCH_CLAUDE_FLAGS:-}"
cmd=$(printf '%q ' claude --dangerously-skip-permissions ${extra[@]+"${extra[@]}"} --model "$ORCH_MODEL" --effort "$ORCH_EFFORT" "$prompt")
if [ -n "${HARNESS_DRY_RUN:-}" ]; then echo "DRY RUN: superset terminals create --local --workspace $ORCH_WORKSPACE_ID --command $cmd"; exit 0; fi
new=$(superset terminals create --local --workspace "$ORCH_WORKSPACE_ID" --command "$cmd" --json | jq -r '.terminalId // empty' || true)
is_uuid "$new" || die "terminals create returned no terminal id: check the workspace; a started successor records itself (wake.sh target) before it closes this terminal"
printf '%s\n' "$new" >"$ORCH_DIR/orch-terminal"
echo "OK: successor terminal $new (wake target)"
