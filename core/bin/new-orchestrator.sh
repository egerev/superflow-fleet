#!/usr/bin/env bash
# Create (or complete) an orchestrator directory for a project from the harness templates.
# Usage: [HARNESS_MODULES="superset tiden"] harness-exec.sh core/bin/new-orchestrator.sh <project> [directory]   (default ~/<project>-orchestrator)
# Never overwrites a project file: an existing file is kept and reported. bin/ is harness-owned:
# its launcher copy and links are refreshed on every run. Next steps: README, New project.
set -euo pipefail
# shellcheck source=core/lib/config.sh
. "$(dirname "$0")/../lib/config.sh"
root=$(harness_root)
project=${1:-}
[[ $project =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "usage: new-orchestrator.sh <project: lowercase, digits, dashes> [directory]"
dir=${2:-$HOME/$project-orchestrator}
title=$(tr '[:lower:]' '[:upper:]' <<<"${project:0:1}")${project:1}
mkdir -p "$dir"/{bin,briefs,handoffs,research,archive,inbox}
dir=$(cd "$dir" && pwd)
modules=${HARNESS_MODULES:-superset}   # modules whose scripts get a link in bin/
[[ $modules =~ ^[a-z0-9\ -]*$ ]] || die "HARNESS_MODULES: lowercase names separated by spaces"

# put <template> <target>: copy with the project name filled in, unless the target exists.
# Returns 1 for a kept file; a failed copy stops the run (errexit is off inside `put || true`).
put() {
  local src dst=$dir/$2 m
  src=$root/core/templates/$1
  for m in $modules; do [ -f "$root/modules/$m/templates/$1" ] && src=$root/modules/$m/templates/$1; done
  if [ -e "$dst" ]; then echo "kept     $dst"; return 1; fi
  sed -e "s/<Project>/$title/g" -e "s/<PROJECT>/$title/g" -e "s/<project>/$project/g" "$src" >"$dst" \
    || die "cannot write $dst"
  echo "created  $dst"
}
put config.sh config.sh || true
put STATE.md STATE.md || true
put DECISIONS.md DECISIONS.md || true
put orchestrator-facts.md orchestrator-facts.md || true
put handoff.md handoffs/TEMPLATE.md || true
# Fill the orchestrator directory into the common brief only when this run created it.
if put worker-brief-common.md briefs/common.md; then
  esc=$(printf '%s' "$dir" | sed 's/[&|\\]/\\&/g')
  sed -i.bak "s|<orchestrator dir>|$esc|g" "$dir/briefs/common.md" || die "cannot fill $dir/briefs/common.md"
  rm -f "$dir/briefs/common.md.bak"
fi

# bin/: the launcher and one link per harness script (a link name picks bin/<name>).
cp "$root/core/bin/harness-exec.sh" "$dir/bin/harness-exec.sh"; chmod 755 "$dir/bin/harness-exec.sh"
scripts=""
bindirs=("$root/core/bin")
for m in $modules; do bindirs+=("$root/modules/$m/bin"); done
for d in "${bindirs[@]}"; do
  [ -d "$d" ] || continue
  for f in "$d"/*.sh; do
    s=$(basename "$f"); case $s in harness-exec.sh|new-orchestrator.sh) continue ;; esac
    scripts="$scripts $s"
  done
done
for s in $scripts; do
  # A project's own script of the same name stays until the project removes it.
  if [ -e "$dir/bin/$s" ] && [ ! -L "$dir/bin/$s" ]; then echo "kept     $dir/bin/$s (not a harness link)"; continue; fi
  ln -sfn harness-exec.sh "$dir/bin/$s"
done
echo "bin      $dir/bin (launcher and links refreshed)"
cat <<EOF

Next (README, New project):
  1. Fill $dir/config.sh, briefs/common.md (Project facts), orchestrator-facts.md, DECISIONS.md D1.
  2. Write the orchestrator worktree path:  printf '%s\n' <worktree path> > $dir/active-cwd
EOF
[ ! -e "$dir/bin/orchestrator-check.sh" ] || echo "  3. Check:  $dir/bin/orchestrator-check.sh"
