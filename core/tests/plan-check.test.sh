#!/usr/bin/env bash
# Fixture test for core/bin/plan-check.sh: backlog tables in the `estimate` shape with lane, paths and
# wave columns, one `estimate plan --json` waves file, and `estimate` config.json lanes.
# Run: bash core/tests/plan-check.test.sh
set -euo pipefail
unset ESTIMATE_DIR
script=${PLAN_CHECK:-$(cd "$(dirname "$0")/.." && pwd)/bin/plan-check.sh}  # PLAN_CHECK: another copy
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
fail=0
case_() { # name expected-exit expected-FAIL-count backlog-lines... [-- plan args]; CASE_DIR: the backlog's dir, CASE_CWD
  local name=$1 want=$2 nfail=$3 got=0 args=() md=${CASE_DIR:-$tmp}/$1.md; shift 3
  : >"$md"
  while [ $# -gt 0 ] && [ "$1" != -- ]; do echo "$1" >>"$md"; shift; done
  [ $# -eq 0 ] || { shift; args=("$@"); }
  (cd "${CASE_CWD:-$tmp}" && bash "$script" "$md" ${args[@]+"${args[@]}"}) >"$tmp/$name.out" 2>&1 || got=$?
  local n; n=$(grep -c '^FAIL' "$tmp/$name.out" || true)
  local nc; nc=$(grep -c '^plan-check: NOT CHECKED' "$tmp/$name.out" || true)
  [ "$want" != 0 ] || [ "$nc" = 0 ] || got="$got (NOT CHECKED line)"  # exit 1 may also print it
  [ "$want" != 3 ] || [ "$nc" = 1 ] || got="$got (no NOT CHECKED line)"
  if [ "$got" = "$want" ] && [ "$n" = "$nfail" ]; then echo "ok   $name"
  else echo "FAIL $name: exit $got want $want, $n FAIL lines want $nfail"; sed 's/^/     /' "$tmp/$name.out"; fail=1; fi
}
head='| id | title | effort | value | depends | lane | paths | wave |'
sep='|---|---|---|---|---|---|---|---|'
# shellcheck disable=SC2016 # backticks are table text
case_ clean 0 0 "$head" "$sep" \
  '| A-1 | api | 3 | 5 | | api | `src/api.py`, tests/test_api.py | 1 |' \
  '| A-2 | ui | 2 | 3 | - | ui | src/ui/ | 1 |' \
  '| A-3 | docs | 1 | 2 | A-1, A-2 | - | docs/a.md | 2 |'
case_ same-file 1 1 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | | src/a.py | 1 |' '| A-2 | y | 2 | 3 | | | ./src/a.py | 1 |'
case_ dir-and-glob 1 2 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | | src/ | 1 |' '| A-2 | y | 2 | 3 | | | src/b.py | 1 |' \
  '| A-3 | z | 2 | 3 | | | tests/*.py | 2 |' '| A-4 | w | 2 | 3 | | | tests/test_b.py | 2 |'
# Same paths in different waves are fine.
case_ other-wave 0 0 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | - | src/a.py | 1 |' '| A-2 | y | 2 | 3 | | - | src/a.py | 2 |'
case_ lane-default-cap 1 1 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | migration | m/1.sql | 1 |' '| A-2 | y | 2 | 3 | | migration | m/2.sql | 1 |'
case_ lane-cap-2 0 0 '## Lanes' '- migration (cap 2): numbered files' '' "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | migration | m/1.sql | 1 |' '| A-2 | y | 2 | 3 | | migration | m/2.sql | 1 |'
case_ cycle 1 1 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | A-3 | | | |' '| A-2 | y | 2 | 3 | A-1 | | | |' '| A-3 | z | 2 | 3 | A-2 | | | |'
case_ self-cycle 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | A-1 | | | |'
case_ dep-same-wave 1 1 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | | a | 1 |' '| A-2 | y | 2 | 3 | A-1 | | b | 1 |'
case_ dep-later-wave 1 1 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | A-2 | | a | 1 |' '| A-2 | y | 2 | 3 | | | b | 2 |'
case_ unknown-dep 0 0 "$head" "$sep" '| A-1 | x | 3 | 5 | A-9 | - | a | 1 |'
case_ no-table 2 0 'just prose'
# Not checked (exit 3): no waves, or no lane or paths column; a cycle still exits 1.
case_ no-waves 3 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | api | a | |'
case_ no-paths-col 3 0 '| id | title | effort | lane | wave |' '|---|---|---|---|---|' '| A-1 | x | 3 | api | 1 |'
case_ no-lane-col 3 0 '| id | title | effort | paths | wave |' '|---|---|---|---|---|' '| A-1 | x | 3 | a | 1 |'
# A card in a wave with an empty lane cell (- is "no lane") or no paths; out of a wave it does not count.
case_ empty-lane-cell 3 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | 1 |' '| A-2 | y | 2 | 3 | | | | |'
case_ empty-paths-cell 3 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | api | a | 1 |' '| A-2 | y | 2 | 3 | | ui | - | 1 |'
case_ empty-cell-fail 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | 1 |' '| A-2 | y | 2 | 3 | | | a | 1 |'
# Waves from `estimate plan --json`: the chosen agent count's waves.
printf '%s\n' '{"chosen": 2, "agents": {"1": {"waves": [{"ids": ["1"]}, {"ids": ["2"]}]},' \
  '"2": {"waves": [{"ids": ["1", "2"]}, {"ids": ["3"]}]}}}' >"$tmp/plan.json"
case_ plan-json 1 1 '| id | title | effort | depends | lane | expected paths |' '|---|---|---|---|---|---|' \
  '| 1 | x | 3 | | bot | bot.py |' '| 2 | y | 2 | | bot | lib/y.py |' '| 3 | z | 1 | 1 | | bot.py |' \
  -- --plan "$tmp/plan.json"
printf '{"chosen": 1}\n' >"$tmp/bad.json"
case_ plan-bad 2 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | |' -- --plan "$tmp/bad.json"
# Empty waves in a plan check nothing: exit 3.
echo '{"chosen": 1, "agents": {"1": {"waves": [{"ids": []}]}}}' >"$tmp/empty-wave.json"
echo '{"chosen": 1, "agents": {"1": {"waves": []}}}' >"$tmp/no-wave.json"
case_ plan-empty-wave 3 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | api | a | |' -- --plan "$tmp/empty-wave.json"
case_ plan-no-wave 3 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | api | a | |' -- --plan "$tmp/no-wave.json"
case_ plan-no-file 2 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | |' -- --plan
# Ids and Depends as `estimate` reads them: a leading #, a range, a key, another case.
case_ hash-ids 1 1 "$head" "$sep" '| #1 | x | 3 | 5 | #2 | | | |' '| #2 | y | 2 | 3 | 1 | | | |'
case_ range-dep 1 1 "$head" "$sep" \
  '| 1 | x | 3 | 5 | 2-3 | | | |' '| 2 | y | 2 | 3 | 1 | | | |' '| 3 | z | 1 | 2 | | | | |'
case_ key-dep 1 1 '| id | key | title | effort | depends |' '|---|---|---|---|---|' \
  '| u1 | ACME-1 | x | 3 | acme-2 |' '| u2 | ACME-2 | y | 2 | ACME-1 |'
case_ row-ids 1 1 '| title | effort | depends | wave |' '|---|---|---|---|' '| x | 3 | | 1 |' '| y | 2 | 1 | 1 |'
# An overview table before the backlog (no effort column) is not the backlog.
case_ overview-first 1 1 '| id | title |' '|---|---|' '| 1 | overview |' '' "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | | a | 1 |' '| A-2 | y | 2 | 3 | | | a | 1 |'
# Waves: - is none (no wave), whole numbers in number order, any other label is a usage error.
case_ wave-none 3 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | - |' '| A-2 | y | 2 | 3 | | | a | — |'
case_ wave-order 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | A-2 | | a | 10 |' '| A-2 | y | 2 | 3 | | | b | 2 |' \
  '| A-3 | z | 2 | 3 | A-1 | | c | 2 |'
case_ wave-label 2 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | first |'
case_ dep-no-wave 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | A-2 | | a | 1 |' '| A-2 | y | 2 | 3 | | | b | |'
# Paths: (notes) dropped, the root covers all, .. normalized, globs conservative, a directory without /.
case_ path-notes 0 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | - | a.py (new) | 1 |' '| A-2 | y | 2 | 3 | | - | b.py (new) | 1 |'
case_ path-root 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | | | ./ | 1 |' '| A-2 | y | 2 | 3 | | | src/x.py | 1 |'
case_ path-dotdot 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | | | src/../shared.py | 1 |' '| A-2 | y | 2 | 3 | | | shared.py | 1 |'
case_ glob-glob 1 2 "$head" "$sep" '| A-1 | x | 3 | 5 | | | src/a*.py | 1 |' '| A-2 | y | 2 | 3 | | | src/*b.py | 1 |' \
  '| A-3 | z | 2 | 3 | | | lib/*/handler.py | 2 |' '| A-4 | w | 2 | 3 | | | lib/api | 2 |'
case_ glob-apart 0 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | - | src/a*.py | 1 |' '| A-2 | y | 2 | 3 | | - | src/c.py | 1 |' \
  '| A-3 | z | 2 | 3 | | - | srcx/*.py | 1 |'
# The absolute root covers absolute paths.
case_ path-abs-root 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | | | / | 1 |' '| A-2 | y | 2 | 3 | | | /tmp/a | 1 |'
# An ambiguous alias stops resolution (as in `estimate`): two keys abcdef12, no invented self-cycle.
z=0000; uuid="abcdef12-$z-$z-$z-$z$z$z"  # built here: the export's leak check flags UUID literals
case_ alias-ambiguous 3 0 '| id | key | title | effort | depends |' '|---|---|---|---|---|' \
  '| k1 | abcdef12 | x | 3 | |' '| k2 | abcdef12 | y | 2 | |' "| $uuid | | z | 1 | abcdef12 |"
# A merging cap is not a limit on a wave: the lane keeps limit 1.
case_ merging-cap 1 1 '## Lanes' '- bot (merging cap 2)' '' "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | bot | a | 1 |' '| A-2 | y | 2 | 3 | | bot | b | 1 |'
# Lane limits from the `estimate` config.json when the file has no `## Lanes` section: --config,
# $ESTIMATE_DIR/config.json, or the nearest .estimate/config.json above the backlog; the section wins.
m1='| A-1 | x | 3 | 5 | | migration | m/1.sql | 1 |' m2='| A-2 | y | 2 | 3 | | migration | m/2.sql | 1 |'
echo '{"lanes": {"migration": {"open": 2, "merging": 1}}}' >"$tmp/cfg-open.json"
echo '{"lanes": {"migration": 2}}' >"$tmp/cfg-int.json"
echo '{"lanes": {"migration": 0}}' >"$tmp/cfg-zero.json"
echo 'not json' >"$tmp/cfg-bad.json"
echo '{"lanes": ["migration"]}' >"$tmp/cfg-list.json"
echo '{"lanes": {"migration": {"merging": 2}}}' >"$tmp/cfg-merging.json"
echo '{"lanes": null}' >"$tmp/cfg-null.json"
echo '{"lanes": {"migration": 1}}' >"$tmp/cfg-one.json"
case_ config-open 0 0 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-open.json"
case_ config-int 0 0 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-int.json"
case_ config-zero-ignored 1 1 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-zero.json"
case_ config-section-wins 1 1 '## Lanes' '- api (cap 2)' '' "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-int.json"
case_ config-bad 2 0 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-bad.json"
case_ config-list 2 0 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-list.json"
for v in '[]' '""' false 0 '[1]'; do
  case $v in '[1]') echo "$v" ;; *) echo "{\"lanes\": $v}" ;; esac >"$tmp/cfg-falsey.json"
  case_ "config-falsey-$v" 2 0 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-falsey.json"
done
case_ config-null 1 1 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-null.json"
case_ config-merging-only 1 1 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-merging.json"
case_ config-missing 2 0 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/nofile.json"
mkdir -p "$tmp/proj/.estimate" "$tmp/env"
cp "$tmp/cfg-int.json" "$tmp/proj/.estimate/config.json"; cp "$tmp/cfg-int.json" "$tmp/env/config.json"
CASE_DIR=$tmp/proj/.estimate case_ config-walk-up 0 0 "$head" "$sep" "$m1" "$m2"
ESTIMATE_DIR=$tmp/env case_ config-env 0 0 "$head" "$sep" "$m1" "$m2"
# $ESTIMATE_DIR without a config.json: no lanes from the walk-up either (as `estimate` picks its data dir).
ESTIMATE_DIR=$tmp CASE_DIR=$tmp/proj/.estimate case_ config-env-empty 1 1 "$head" "$sep" "$m1" "$m2"
# --config wins over a config.json above the backlog; a backlog with none above it uses the one above the cwd.
CASE_DIR=$tmp/proj/.estimate case_ config-explicit-wins 1 1 "$head" "$sep" "$m1" "$m2" -- --config "$tmp/cfg-one.json"
mkdir -p "$tmp/plain" "$tmp/work/sub"; cp -R "$tmp/proj/.estimate" "$tmp/work/"
CASE_DIR=$tmp/plain CASE_CWD=$tmp/work/sub case_ config-cwd 0 0 "$head" "$sep" "$m1" "$m2"
exit "$fail"
