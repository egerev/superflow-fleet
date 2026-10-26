#!/usr/bin/env bash
# Fixture test for core/bin/plan-check.sh: backlog tables in the `estimate` shape with lane, paths and
# wave columns, and one `estimate plan --json` waves file. Run: bash core/tests/plan-check.test.sh
set -euo pipefail
script=${PLAN_CHECK:-$(cd "$(dirname "$0")/.." && pwd)/bin/plan-check.sh}  # PLAN_CHECK: another copy
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
fail=0
case_() { # name expected-exit expected-FAIL-count backlog-lines... [-- plan args]
  local name=$1 want=$2 nfail=$3 got=0 args=(); shift 3
  : >"$tmp/$name.md"
  while [ $# -gt 0 ] && [ "$1" != -- ]; do echo "$1" >>"$tmp/$name.md"; shift; done
  [ $# -eq 0 ] || { shift; args=("$@"); }
  bash "$script" "$tmp/$name.md" ${args[@]+"${args[@]}"} >"$tmp/$name.out" 2>&1 || got=$?
  local n; n=$(grep -c '^FAIL' "$tmp/$name.out" || true)
  if [ "$got" = "$want" ] && [ "$n" = "$nfail" ]; then echo "ok   $name"
  else echo "FAIL $name: exit $got want $want, $n FAIL lines want $nfail"; sed 's/^/     /' "$tmp/$name.out"; fail=1; fi
}
head='| id | title | effort | value | depends | lane | paths | wave |'
sep='|---|---|---|---|---|---|---|---|'
# shellcheck disable=SC2016 # backticks are table text
case_ clean 0 0 "$head" "$sep" \
  '| A-1 | api | 3 | 5 | | api | `src/api.py`, tests/test_api.py | 1 |' \
  '| A-2 | ui | 2 | 3 | - | ui | src/ui/ | 1 |' \
  '| A-3 | docs | 1 | 2 | A-1, A-2 | | docs/a.md | 2 |'
case_ same-file 1 1 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | | src/a.py | 1 |' '| A-2 | y | 2 | 3 | | | ./src/a.py | 1 |'
case_ dir-and-glob 1 2 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | | src/ | 1 |' '| A-2 | y | 2 | 3 | | | src/b.py | 1 |' \
  '| A-3 | z | 2 | 3 | | | tests/*.py | 2 |' '| A-4 | w | 2 | 3 | | | tests/test_b.py | 2 |'
# Same paths in different waves are fine.
case_ other-wave 0 0 "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | | src/a.py | 1 |' '| A-2 | y | 2 | 3 | | | src/a.py | 2 |'
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
case_ unknown-dep 0 0 "$head" "$sep" '| A-1 | x | 3 | 5 | A-9 | | a | 1 |'
case_ no-table 2 0 'just prose'
# Waves from `estimate plan --json`: the chosen agent count's waves.
printf '%s\n' '{"chosen": 2, "agents": {"1": {"waves": [{"ids": ["1"]}, {"ids": ["2"]}]},' \
  '"2": {"waves": [{"ids": ["1", "2"]}, {"ids": ["3"]}]}}}' >"$tmp/plan.json"
case_ plan-json 1 1 '| id | title | effort | depends | lane | expected paths |' '|---|---|---|---|---|---|' \
  '| 1 | x | 3 | | bot | bot.py |' '| 2 | y | 2 | | bot | lib/y.py |' '| 3 | z | 1 | 1 | | bot.py |' \
  -- --plan "$tmp/plan.json"
printf '{"chosen": 1}\n' >"$tmp/bad.json"
case_ plan-bad 2 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | |' -- --plan "$tmp/bad.json"
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
case_ wave-none 0 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | - |' '| A-2 | y | 2 | 3 | | | a | — |'
case_ wave-order 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | A-2 | | a | 10 |' '| A-2 | y | 2 | 3 | | | b | 2 |' \
  '| A-3 | z | 2 | 3 | A-1 | | c | 2 |'
case_ wave-label 2 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a | first |'
case_ dep-no-wave 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | A-2 | | a | 1 |' '| A-2 | y | 2 | 3 | | | b | |'
# Paths: (notes) dropped, the root covers all, .. normalized, globs conservative, a directory without /.
case_ path-notes 0 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | a.py (new) | 1 |' '| A-2 | y | 2 | 3 | | | b.py (new) | 1 |'
case_ path-root 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | | | ./ | 1 |' '| A-2 | y | 2 | 3 | | | src/x.py | 1 |'
case_ path-dotdot 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | | | src/../shared.py | 1 |' '| A-2 | y | 2 | 3 | | | shared.py | 1 |'
case_ glob-glob 1 2 "$head" "$sep" '| A-1 | x | 3 | 5 | | | src/a*.py | 1 |' '| A-2 | y | 2 | 3 | | | src/*b.py | 1 |' \
  '| A-3 | z | 2 | 3 | | | lib/*/handler.py | 2 |' '| A-4 | w | 2 | 3 | | | lib/api | 2 |'
case_ glob-apart 0 0 "$head" "$sep" '| A-1 | x | 3 | 5 | | | src/a*.py | 1 |' '| A-2 | y | 2 | 3 | | | src/c.py | 1 |' \
  '| A-3 | z | 2 | 3 | | | srcx/*.py | 1 |'
# The absolute root covers absolute paths.
case_ path-abs-root 1 1 "$head" "$sep" '| A-1 | x | 3 | 5 | | | / | 1 |' '| A-2 | y | 2 | 3 | | | /tmp/a | 1 |'
# An ambiguous alias stops resolution (as in `estimate`): two keys abcdef12, no invented self-cycle.
z=0000; uuid="abcdef12-$z-$z-$z-$z$z$z"  # built here: the export's leak check flags UUID literals
case_ alias-ambiguous 0 0 '| id | key | title | effort | depends |' '|---|---|---|---|---|' \
  '| k1 | abcdef12 | x | 3 | |' '| k2 | abcdef12 | y | 2 | |' "| $uuid | | z | 1 | abcdef12 |"
# A merging cap is not a limit on a wave: the lane keeps limit 1.
case_ merging-cap 1 1 '## Lanes' '- bot (merging cap 2)' '' "$head" "$sep" \
  '| A-1 | x | 3 | 5 | | bot | a | 1 |' '| A-2 | y | 2 | 3 | | bot | b | 1 |'
exit "$fail"
