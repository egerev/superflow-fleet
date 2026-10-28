#!/usr/bin/env bash
# Test for harness_link_scripts (core/lib/config.sh): lists missing bin/ links, adds them, keeps a project's own file.
# Run: bash core/tests/link-scripts.test.sh
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
mkdir "$tmp/bin"
# shellcheck source=core/lib/config.sh
. "$root/lib/config.sh"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: want '$2' got '$3'"; fail=1; fi; }
ln -s harness-exec.sh "$tmp/bin/wait-merge.sh"
touch "$tmp/bin/wake.sh"   # the project's own file, not a link
missing=$(harness_link_scripts "$tmp")
check "own file not listed" 0 "$(grep -cx wake.sh <<<"$missing" || true)"
check "linked script not listed" 0 "$(grep -cx wait-merge.sh <<<"$missing" || true)"
check "owner-page.sh listed" 1 "$(grep -cx owner-page.sh <<<"$missing" || true)"
check "launcher and creator never listed" 0 "$(grep -cE '^(harness-exec|new-orchestrator).sh$' <<<"$missing" || true)"
harness_link_scripts "$tmp" --add >/dev/null
check "nothing missing after add" "" "$(harness_link_scripts "$tmp")"
check "own file kept as a file" "file" "$([ -L "$tmp/bin/wake.sh" ] && echo link || echo file)"
check "new link target" harness-exec.sh "$(readlink "$tmp/bin/owner-page.sh")"
# new-orchestrator.sh links every harness bin/*.sh but the launcher and creator, and keeps a project's own file.
mkdir -p "$tmp/orch/bin"; touch "$tmp/orch/bin/wake.sh"
bash "$root/bin/new-orchestrator.sh" demo "$tmp/orch" >/dev/null
want=$(cd "$root/bin" && find . -name '*.sh' | sed 's|^\./||' | grep -vxE 'harness-exec.sh|new-orchestrator.sh|wake.sh' | sort)
got=$(cd "$tmp/orch/bin" && find . -type l | sed 's|^\./||' | sort)
# Every script next to the creator is linked (the export's creator may add enabled modules' links too).
check "new-orchestrator links every script" "" "$(comm -23 <(echo "$want") <(echo "$got"))"
check "new-orchestrator keeps own file" "file" "$([ -L "$tmp/orch/bin/wake.sh" ] && echo link || echo file)"
bash "$root/bin/new-orchestrator.sh" demo "$tmp/orch" >/dev/null
check "refresh keeps the same links" "$got" "$(cd "$tmp/orch/bin" && find . -type l | sed 's|^\./||' | sort)"
mkdir "$tmp/ro" "$tmp/ro/bin"; chmod 555 "$tmp/ro/bin"
rc=0; harness_link_scripts "$tmp/ro" --add >/dev/null 2>&1 || rc=$?
chmod 755 "$tmp/ro/bin"
if [ "$(id -u)" = 0 ]; then echo "skip unwritable bin/ (root)"; else check "link failure returns 1" 1 "$rc"; fi
exit "$fail"
