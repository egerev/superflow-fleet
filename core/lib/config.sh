# shellcheck shell=bash
# Sourced by the harness bin/ scripts: loads the project config (core/templates/config.sh, filled in,
# kept as <orchestrator dir>/config.sh) and offers small helpers. Never prints a value.
die() { echo "STOP: $*" >&2; exit 1; }

# Loads HARNESS_CONFIG (set by harness-exec.sh when run through an orchestrator's bin/ link).
# ORCH_DIR defaults to the config's directory before the config is read.
harness_load_config() {
  local cfg=${HARNESS_CONFIG:-}
  [ -n "$cfg" ] && [ -f "$cfg" ] \
    || die "no project config: run through <orchestrator dir>/bin/<script> or set HARNESS_CONFIG=<orchestrator dir>/config.sh"
  ORCH_DIR=$(cd "$(dirname "$cfg")" && pwd); export ORCH_DIR
  # shellcheck source=/dev/null
  . "$cfg"
}

# require VAR...: each named config value must be set and must not be a <placeholder>.
require() {
  local v
  for v in "$@"; do
    [ -n "${!v:-}" ] || die "config.sh: $v is empty"
    case "${!v}" in *'<'*'>'*) die "config.sh: $v is still a placeholder" ;; esac
  done
}

# is_uuid VALUE: Superset workspace and terminal IDs are UUIDs; anything else (a placeholder, a
# name) must never reach a `superset terminals close` command.
is_uuid() { [[ ${1:-} =~ ^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$ ]]; }

# Root of the harness tree the running script came from (this file is core/lib/config.sh).
harness_root() { cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd; }

# timeout_bin: GNU timeout (coreutils; gtimeout on macOS Homebrew), required for bounded jobs.
timeout_bin() {
  command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null \
    || die "no timeout command: install coreutils (brew install coreutils)"
}

# harness_scripts: names of the orchestrator-facing harness scripts (every bin/*.sh but the launcher and
# the creator), one per line. new-orchestrator.sh and harness_link_scripts link exactly these.
harness_scripts() {
  local root f s
  root=$(harness_root)
  for f in "$root"/bin/*.sh "$root"/core/bin/*.sh "$root"/modules/*/bin/*.sh; do
    [ -e "$f" ] || continue
    s=$(basename "$f")
    case $s in harness-exec.sh|new-orchestrator.sh) continue ;; esac
    echo "$s"
  done
}

# harness_link_scripts DIR [--add]: names of the harness scripts that have no link in DIR/bin (one per
# line). A project's own non-link file of the same name is left alone and not listed. With --add the
# missing links are created the way new-orchestrator.sh makes them (to harness-exec.sh) and each is
# printed as "linked <name>"; a link that cannot be made is reported on stderr and the status is 1.
harness_link_scripts() {
  local dir=$1 add=${2:-} s rc=0
  for s in $(harness_scripts); do
    [ ! -L "$dir/bin/$s" ] || continue
    [ ! -e "$dir/bin/$s" ] || continue
    if [ -z "$add" ]; then echo "$s"
    elif ln -sfn harness-exec.sh "$dir/bin/$s"; then echo "linked $s"
    else echo "cannot link $dir/bin/$s" >&2; rc=1; fi
  done
  return "$rc"
}
