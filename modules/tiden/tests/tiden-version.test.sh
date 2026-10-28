#!/usr/bin/env bash
# Fixture test for modules/tiden/bin/tiden-version.sh: a stub `tiden`, a file:// release and project repositories
# (hard-coded versions, the pinned-copy step, a copy off the pin, an unknown install). Run: bash modules/tiden/tests/tiden-version.test.sh
# shellcheck disable=SC2016  # workflow texts are literal
set -euo pipefail
script=$(cd "$(dirname "$0")/.." && pwd)/bin/tiden-version.sh
tmp=$(mktemp -d); trap 'rm -r "$tmp"' EXIT
sum=d42fca58f868dc22be1aa01187105a1c442b4a32c88e9c47ac2f051ef05fb286
mac=4829fd814f1b322cf72a850418e86dac010ed5c24875f24bc8002a976fa8c6d5
printf 'TIDEN_CLI_VERSION=0.41.0\nTIDEN_CLI_SHA256_linux_amd64=%s\nTIDEN_CLI_SHA256_darwin_arm64=%s\n' "$sum" "$mac" >"$tmp/pin"
mkdir -p "$tmp/rel/v0.41.0" "$tmp/bin"
printf '%s  tiden_linux_amd64.tar.gz\n%s  tiden_darwin_arm64.tar.gz\n' "$sum" "$mac" >"$tmp/rel/v0.41.0/checksums.txt"
cat >"$tmp/bin/tiden" <<'STUB'
#!/usr/bin/env bash
# --version, upgrade check, product list, spec list (two pages with a token), spec get in the shapes
# CLI 0.41.0 prints (read 10-26).
case "$*" in
  --version) echo "tiden version $LOCAL" ;;
  'upgrade check --format json') printf '{"current":"%s","latest":"v%s","updateAvailable":true}\n' "$LOCAL" "$LATEST" ;;
  'product list --format json') echo "$PRODUCTS" ;;
  'spec list '*'--page-token '*) echo "${SPECS2:-$SPECS}" ;;
  'spec list '*) echo "$SPECS" ;;
  'spec get '*) echo "${GET:-}" ;;
  *) exit 9 ;;
esac
STUB
chmod 755 "$tmp/bin/tiden"
repo() { # dir workflow-text [pinned-copy-text]
  local o=$tmp/$1.git w=$tmp/$1
  mkdir -p "$w"; git init -q --bare -b main "$o"; git init -q -b main "$w"; mkdir -p "$w/.github/workflows"
  printf '%s\n' "$2" >"$w/.github/workflows/ci.yml"
  [ -z "${3:-}" ] || { local c=$w/docs/harness/modules/tiden/tiden.md; mkdir -p "$(dirname "$c")"; printf '%s\n' "$3" >"$c"; }
  git -C "$w" add -A; git -C "$w" -c user.name=t -c user.email=t@t commit -q -m init
  git -C "$w" remote add origin "$o"; git -C "$w" push -q origin main
}
step='run: ver=$(sed -n "s/^TIDEN_CLI_VERSION=//p" docs/harness/modules/tiden/tiden.md); curl -o t "https://github.com/qase-tms/homebrew-tap/releases/download/v$ver/tiden_linux_amd64.tar.gz"'
repo hard 'run: curl -L https://github.com/qase-tms/homebrew-tap/releases/download/v0.36.0/tiden_linux_amd64.tar.gz'
repo var '  TIDEN_CLI_VERSION: v0.41.0'
repo shell 'run: TIDEN_CLI_VERSION=v0.36.0; curl "https://github.com/qase-tms/homebrew-tap/releases/download/$TIDEN_CLI_VERSION/tiden_linux_amd64.tar.gz"'
repo good "$step" "$(cat "$tmp/pin")"
repo old "$step" 'TIDEN_CLI_VERSION=0.40.0'
repo badcopy "$step" "$(sed 's/^TIDEN_CLI_SHA256_linux_amd64=d/TIDEN_CLI_SHA256_linux_amd64=e/' "$tmp/pin")"
repo brew 'run: brew install qase-tms/tap/tiden   # comment naming docs/harness/modules/tiden/tiden.md'
repo none 'run: echo no tiden here'
repo wt/fix/deep/one 'run: echo nested worktree'
printf 'WORKTREES_DIR="%s/wt"\n' "$tmp" >"$tmp/config.sh"
fail=0
run() { # name expected-exit args... ; output in $tmp/<name>.out
  local name=$1 want=$2 got=0; shift 2
  PATH="$tmp/bin:$PATH" TIDEN_PIN_FILE="$tmp/pin" TIDEN_RELEASE_BASE="file://$tmp/rel" TIDEN_ORCH_GLOB=${GLOB:-"$tmp/none/*"} \
    LOCAL=${LOCAL:-0.41.0} LATEST=${LATEST:-0.41.0} PRODUCTS=${PRODUCTS:-} SPECS=${SPECS:-} SPECS2=${SPECS2:-} GET=${GET:-} \
    bash "$script" "$@" >"$tmp/$name.out" 2>&1 || got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"
  else echo "FAIL $name: exit $got, want $want"; sed 's/^/     /' "$tmp/$name.out"; fail=1; fi
}
has() { # name pattern
  if grep -qE "$2" "$tmp/$1.out"; then echo "ok   $1: $2"
  else echo "FAIL $1: no line /$2/"; sed 's/^/     /' "$tmp/$1.out"; fail=1; fi
}
hasnt() { # name pattern
  if grep -qE "$2" "$tmp/$1.out"; then echo "FAIL $1: unexpected /$2/"; sed 's/^/     /' "$tmp/$1.out"; fail=1
  else echo "ok   $1: no $2"; fi
}
run clean 0 check "$tmp/good" "$tmp/none"
has clean '^OK pin 0.41.0 linux_amd64 checksum matches'
has clean '^OK pin 0.41.0 darwin_arm64 checksum matches'
has clean '^OK good: CI reads the pinned copy, 0.41.0'
hasnt clean '^WARN good'
has clean '^OK none: no Tiden install in CI'
LATEST=0.42.0 LOCAL=0.40.0 run lags 1 check "$tmp/hard" "$tmp/var" "$tmp/shell" "$tmp/old" "$tmp/badcopy" "$tmp/brew"
has lags '^LAG pin 0.41.0: release 0.42.0 is out'
has lags '^LAG local tiden 0.40.0, pin 0.41.0'
has lags '^RULE hard: \.github/workflows/ci.yml:1 names Tiden 0.36.0'
has lags '^LAG hard: CI 0.36.0'
has lags '^RULE var: .github/workflows/ci.yml:1 names Tiden 0.41.0'
hasnt lags '^LAG var'
has lags '^RULE shell: .github/workflows/ci.yml:1 names Tiden 0.36.0'
has lags '^LAG shell: CI 0.36.0'
has lags '^LAG old: CI reads the pinned copy, 0.40.0, pin 0.41.0'
has lags '^BAD badcopy: pinned copy 0.41.0 checksums differ from the pin: linux_amd64'
has lags '^WARN brew: .github/workflows/ci.yml downloads Tiden'
hasnt lags '^OK brew'
GLOB="$tmp/config.sh" run discover 0 check
has discover '^OK one: no Tiden install in CI'
sed 's/^TIDEN_CLI_SHA256_linux_amd64=d/TIDEN_CLI_SHA256_linux_amd64=e/' "$tmp/pin" >"$tmp/pin2"; mv "$tmp/pin2" "$tmp/pin"
run badsum 1 check "$tmp/none"
has badsum '^BAD pin 0.41.0 linux_amd64 checksum'
grep -v darwin_arm64 "$tmp/pin" >"$tmp/pin2"; mv "$tmp/pin2" "$tmp/pin"
run noplat 1 check "$tmp/none"
has noplat '^BAD pin 0.41.0: no TIDEN_CLI_SHA256_darwin_arm64= line'
printf 'no pin here\n' >"$tmp/pin"
run nopin 2 check
products='{"products":[{"id":"p1","name":"P","code":"PC"}],"pagination":{}}'
specs='{"requirements":[{"id":"a","title":"t","status":"Backlog","content":"","seqNum":1,"productId":"p1"},{"id":"b","title":"u","status":"Backlog","content":null,"seqNum":2,"productId":"p1","parentId":"a"}],"pagination":{"nextPageToken":"","totalCount":2}}'
get='{"id":"a","title":"t","status":"Backlog","content":""}'
PRODUCTS=$products SPECS=$specs GET=$get run smoke 0 smoke "$tmp/bin/tiden"
has smoke '^OK smoke: spec list'
has smoke '^OK smoke: spec get'
hasnt smoke 'page-token'
(cd "$tmp" && PRODUCTS=$products SPECS=$specs GET=$get run smoke-relative 0 smoke bin/tiden)
PRODUCTS=$products SPECS=${specs/\"nextPageToken\":\"\"/\"nextPageToken\":\"t2\"} GET=$get run smoke-pages 0 smoke "$tmp/bin/tiden"
has smoke-pages '^OK smoke: spec list --page-token'
PRODUCTS=$products SPECS=${specs/\"nextPageToken\":\"\"/\"nextPageToken\":\"t2\"} SPECS2='{"requirements":[]}' GET=$get \
  run smoke-page2-break 1 smoke "$tmp/bin/tiden"
PRODUCTS=$products SPECS=${specs/,\"totalCount\":2/} GET=$get run smoke-no-total 1 smoke "$tmp/bin/tiden"
PRODUCTS=$products SPECS='{"specs":[]}' run smoke-break 1 smoke "$tmp/bin/tiden"
has smoke-break '^FAIL smoke: spec list'
PRODUCTS=$products SPECS=$specs GET='{"id":"a"}' run smoke-get-break 1 smoke "$tmp/bin/tiden"
run usage 2 frob
exit "$fail"
