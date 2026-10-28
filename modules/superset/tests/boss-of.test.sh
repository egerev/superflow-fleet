#!/usr/bin/env bash
# Fixture test for modules/superset/bin/boss-of.sh and the registry write of modules/superset/bin/orchestrator-restart.sh (stub superset):
# set and read, a stale row (older rows, a row whose project's orch-name is newer), a missing row,
# a bad name, and the restart recording the old name. Run: bash modules/superset/tests/boss-of.test.sh
set -euo pipefail
bin=$(cd "$(dirname "$0")/.." && pwd)/bin
root=$(mktemp -d); trap 'rm -r "$root"' EXIT
tmp="$(cd "$root" && pwd -P)/with space"
z=00000000-0000-0000-0000  # UUIDs are built here: a literal one trips the export leak check
mkdir -p "$tmp/alpha" "$tmp/beta" "$tmp/stub"
for p in alpha beta; do
  printf 'PROJECT=%s\nORCH_WORKSPACE_ID=%s\nORCH_MODEL=opus\nORCH_EFFORT=medium\n' "$p" "$z-000000000001" >"$tmp/$p/config.sh"
  printf 'Orchestrator: x\n' >"$tmp/$p/STATE.md"
done
cat >"$tmp/stub/superset" <<'STUB'
#!/usr/bin/env bash
# terminals create: the old name must already be in orch-name and in the raw registry row (exit 9 otherwise).
printf '%s\n' "$*" >>"$CALLED"
[ "$(head -n 1 "$ORCH_NAME_FILE")" = "$WANT_OLD" ] || exit 9
awk -F'\t' -v p="$PROJ" -v n="$WANT_OLD" '$1 == p && $2 == n { f = 1 } END { exit !f }' "$REG" || exit 9
printf '{"terminalId":"%s"}\n' "$NEW_TERM"
STUB
chmod 755 "$tmp/stub/superset"
reg=$tmp/cfg/bosses.tsv
fail=0
run() { # name expected-exit project-or-empty args... ; output in $tmp/<name>.out
  local name=$1 want=$2 p=$3 got=0; shift 3
  if [ -n "$p" ]; then
    env -u SUPERSET_WORKSPACE_ID -u SUPERSET_TERMINAL_ID HARNESS_BOSSES="$reg" HARNESS_CONFIG="$tmp/$p/config.sh" NEW_TERM=$z-000000000003 \
      CALLED="$tmp/called" REG="$reg" ORCH_NAME_FILE="$tmp/$p/orch-name" PROJ="$p" WANT_OLD="${WANT_OLD:-}" \
      PATH="$tmp/stub:$PATH" bash "$@" >"$tmp/$name.out" 2>&1 || got=$?
  else
    env -u HARNESS_CONFIG HARNESS_BOSSES="$reg" bash "$@" >"$tmp/$name.out" 2>&1 || got=$?
  fi
  if [ "$got" = "$want" ]; then echo "ok   $name"
  else echo "FAIL $name: exit $got, want $want"; sed 's/^/     /' "$tmp/$name.out"; fail=1; fi
}
has() { # file pattern
  if grep -qE "$2" "$1"; then echo "ok   $(basename "$1"): $2"
  else echo "FAIL $(basename "$1"): no line /$2/"; sed 's/^/     /' "$1"; fail=1; fi
}
rows() { awk -F'\t' -v p="$1" '("" $1) == ("" p)' "$reg" | wc -l | tr -d ' '; }

run missing-registry 1 '' "$bin/boss-of.sh" alpha
has "$tmp/missing-registry.out" 'no registry row for alpha'
run set-alpha 0 alpha "$bin/boss-of.sh" set alpha-boss-1
has "$tmp/alpha/orch-name" '^alpha-boss-1$'
run get-alpha 0 '' "$bin/boss-of.sh" alpha
has "$tmp/get-alpha.out" '^alpha-boss-1$'
run own-project 0 alpha "$bin/boss-of.sh"
has "$tmp/own-project.out" '^alpha-boss-1$'
run missing-row 1 '' "$bin/boss-of.sh" gamma
has "$tmp/missing-row.out" 'no registry row for gamma'

# Stale rows: a hand-appended older row and a duplicate are replaced by the next set; the other project's row stays.
run set-beta 0 beta "$bin/boss-of.sh" set beta-boss-1
printf 'alpha\talpha-boss-0\t%s\t2026-10-01T00:00Z\n' "$tmp/alpha" >>"$reg"
run set-alpha-2 0 alpha "$bin/boss-of.sh" set alpha-boss-2
if [ "$(rows alpha)" = 1 ] && [ "$(rows beta)" = 1 ]; then echo "ok   one row per project"; else echo "FAIL rows: $(cat "$reg")"; fail=1; fi
run get-alpha-2 0 '' "$bin/boss-of.sh" alpha
has "$tmp/get-alpha-2.out" '^alpha-boss-2$'
# A registry row older than the project's own orch-name (a set whose registry write was lost): orch-name wins.
printf 'beta-boss-2\n' >"$tmp/beta/orch-name"
run get-beta-stale 0 '' "$bin/boss-of.sh" beta
has "$tmp/get-beta-stale.out" '^beta-boss-2$'
# The last of two rows wins when no orch-name exists.
rm "$tmp/beta/orch-name"
printf 'beta\tbeta-boss-3\t%s\t2026-10-26T00:00Z\n' "$tmp/beta" >>"$reg"
run get-beta-last 0 '' "$bin/boss-of.sh" beta
has "$tmp/get-beta-last.out" '^beta-boss-3$'

run bad-name 1 alpha "$bin/boss-of.sh" set 'a b'
has "$tmp/bad-name.out" 'unexpected characters'
run bad-project 1 '' "$bin/boss-of.sh" '../x'
run set-no-config 1 '' "$bin/boss-of.sh" set alpha-boss-9
has "$tmp/alpha/orch-name" '^alpha-boss-2$'
if [ ! -e "$reg.lock" ]; then echo "ok   lock released"; else echo "FAIL lock left"; fail=1; fi

# orchestrator-restart.sh records the old name before it starts the successor; a dry run writes nothing.
mkdir -p "$tmp/alpha/bin"
before=$(cksum <"$reg")
HARNESS_DRY_RUN=1 run restart-dry 0 alpha "$bin/orchestrator-restart.sh" alpha-boss-dry "$z-000000000002"
has "$tmp/alpha/orch-name" '^alpha-boss-2$'
if [ "$(cksum <"$reg")" = "$before" ] && [ ! -e "$tmp/called" ]; then echo "ok   dry run: registry unchanged, no superset call"
else echo "FAIL dry run wrote the registry or called superset"; fail=1; fi
# The stub refuses unless orch-name and the raw row already hold the old name when the terminal is created.
WANT_OLD=alpha-boss-3 run restart 0 alpha "$bin/orchestrator-restart.sh" alpha-boss-3 "$z-000000000002"
has "$tmp/called" '^terminals create'
has "$tmp/alpha/orch-name" '^alpha-boss-3$'
run get-after-restart 0 '' "$bin/boss-of.sh" alpha
has "$tmp/get-after-restart.out" '^alpha-boss-3$'
has "$tmp/alpha/orch-terminal" "^$z-000000000003$"
# A successor template (a project copy) without the boss-of.sh set step is refused before any terminal is created.
rm "$tmp/called"
grep -v 'boss-of' "$bin/../templates/orchestrator-successor-prompt.md" >"$tmp/old-prompt.md"
printf 'ORCH_SUCCESSOR_PROMPT="%s"\n' "$tmp/old-prompt.md" >>"$tmp/alpha/config.sh"
run restart-old-template 1 alpha "$bin/orchestrator-restart.sh" alpha-boss-4 "$z-000000000002"
has "$tmp/restart-old-template.out" 'no boss-of.sh set step'
if [ ! -e "$tmp/called" ]; then echo "ok   old template: no superset call"; else echo "FAIL old template called superset"; fail=1; fi
# A copy that wraps the step over two lines is valid: the prompt is joined into one line.
sed 's/boss-of\.sh set /boss-of.sh\
set /' "$bin/../templates/orchestrator-successor-prompt.md" >"$tmp/old-prompt.md"
WANT_OLD=alpha-boss-5 run restart-wrapped-template 0 alpha "$bin/orchestrator-restart.sh" alpha-boss-5 "$z-000000000002"
has "$tmp/old-prompt.md" '^set <your session name>'

# Numeric-looking projects stay apart (awk compares such fields as numbers unless forced to strings).
for p in 01 1; do
  mkdir -p "$tmp/n$p"; printf 'PROJECT=%s\n' "$p" >"$tmp/n$p/config.sh"
  run "set-$p" 0 "n$p" "$bin/boss-of.sh" set "boss-$p"
done
run get-01 0 '' "$bin/boss-of.sh" 01
has "$tmp/get-01.out" '^boss-01$'
run get-1 0 '' "$bin/boss-of.sh" 1
has "$tmp/get-1.out" '^boss-1$'
if [ "$(rows 01)" = 1 ] && [ "$(rows 1)" = 1 ]; then echo "ok   numeric rows kept apart"; else echo "FAIL numeric rows: $(cat "$reg")"; fail=1; fi

# A failed orch-name write prints no OK and leaves the registry as it was.
before=$(cksum <"$reg")
mkdir "$tmp/beta/orch-name.tmp"
run set-write-fails 1 beta "$bin/boss-of.sh" set beta-boss-9
has "$tmp/set-write-fails.out" 'cannot write'
if ! grep -q '^OK' "$tmp/set-write-fails.out" && [ "$(cksum <"$reg")" = "$before" ]; then echo "ok   failed write: no OK, registry unchanged"
else echo "FAIL failed write reported OK or changed the registry"; fail=1; fi
rmdir "$tmp/beta/orch-name.tmp"
# A tab in the orchestrator directory would split the row: refused.
tabdir="$tmp/ta"$'\t'"b"; mkdir -p "$tabdir"; printf 'PROJECT=tabbed\n' >"$tabdir/config.sh"
if env -u SUPERSET_WORKSPACE_ID HARNESS_BOSSES="$reg" HARNESS_CONFIG="$tabdir/config.sh" bash "$bin/boss-of.sh" set t-1 >"$tmp/tab.out" 2>&1; then
  echo "FAIL tab dir accepted"; fail=1
else has "$tmp/tab.out" 'tab or newline'; fi

if [ "$fail" = 0 ]; then echo "all passed"; else echo "FAILED"; exit 1; fi
