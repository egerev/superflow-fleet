#!/usr/bin/env bash
# One Tiden CLI version for every project (tiden.md, Tiden CLI version). The pin is the
# TIDEN_CLI_VERSION= and TIDEN_CLI_SHA256_<platform>= lines of tiden.md; a project's CI reads them
# from its pinned copy docs/harness/modules/tiden/tiden.md, never a number of its own.
# check [<project dir>...]: compares the pin with the release's checksums.txt (every platform in
#   PLATFORMS must have a line), the newest release (`tiden upgrade check`), the local binary and
#   each project's CI on its origin/main (fetched first): a workflow that reads the pinned copy (the
#   tiden.md step: `s/^TIDEN_CLI_VERSION=//p` and docs/harness/modules/tiden/tiden.md in one file) against that
#   copy's version and checksums; a release URL or TIDEN_CLI_VERSION value written in a workflow is
#   a RULE line; any other Tiden download in a workflow a WARN (not verified). Without arguments
#   the projects are a checkout under WORKTREES_DIR of every ~/*-orchestrator/config.sh.
# smoke <tiden binary> [<product id>]: the reads consumers parse (estimate.py: product list, spec
#   list with pagination; orchestrators: spec get) with that binary, in an empty directory, and the
#   JSON fields they read. Run it with the new binary before the pin moves. Three or four
#   authenticated reads (about $0.21 each).
# Output: one line each, OK / LAG / RULE / BAD / WARN (smoke: OK / FAIL). Exit: 0 all OK (WARN
#   allowed), 1 a LAG, RULE, BAD or FAIL line, 2 usage or no readable pin.
# Test hooks: TIDEN_PIN_FILE (pin file instead of tiden.md at HARNESS_REV), TIDEN_BIN,
#   TIDEN_RELEASE_BASE (release download URL prefix), TIDEN_ORCH_GLOB.
set -euo pipefail
PLATFORMS="linux_amd64 darwin_arm64"   # CI runners, the local machine; a new one gets a pin line first
usage() { echo "usage: tiden-version.sh check [<project dir>...] | smoke <tiden binary> [<product id>]" >&2; exit 2; }
[ $# -ge 1 ] || usage
cmd=$1; shift
bin=${TIDEN_BIN:-tiden}
rc=0
say() { echo "$*"; case $1 in LAG|RULE|BAD|FAIL) rc=1 ;; esac; }
tmo=$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)
bounded() { if [ -n "$tmo" ]; then "$tmo" "$@"; else shift; "$@"; fi; }   # bounded <seconds> cmd...

if [ "$cmd" = smoke ]; then
  [ $# -ge 1 ] && [ $# -le 2 ] || usage
  sb=$1; pid=${2:-}
  case $sb in */*) ;; *) sb=$(command -v "$sb") || { echo "no tiden binary: $1" >&2; exit 2; } ;; esac
  [ -x "$sb" ] && [ -f "$sb" ] || { echo "no tiden binary: $1" >&2; exit 2; }
  sb=$(cd "$(dirname "$sb")" && pwd)/$(basename "$sb")   # absolute: the reads run in another directory
  work=$(mktemp -d); trap 'rm -r "$work"' EXIT
  cd "$work"   # tiden writes .tiden/config.json into the current repository on first use
  if out=$(bounded 60 "$sb" product list --format json 2>&1) \
     && jq -e '(.products // .) | type == "array" and length > 0
               and all(.[]; has("id") and has("name") and has("code"))' >/dev/null 2>&1 <<<"$out"; then
    say OK "smoke: product list --format json (id, name, code)"
    [ -n "$pid" ] || pid=$(jq -r '(.products // .)[0].id' <<<"$out")
  else
    say FAIL "smoke: product list --format json: no products array with id, name, code: ${out:0:200}"
  fi
  page='(.pagination | type == "object" and (.nextPageToken | type == "string") and (.totalCount | type == "number"))
        and (.requirements | type == "array"
             and all(.[]; has("id") and has("title") and has("status") and has("content") and has("seqNum")
                          and has("productId")))'
  list=(spec list --format json --include-sources --page-size 50 --product-id "$pid")
  sid=''
  if [ -z "$pid" ]; then say FAIL "smoke: spec list not run (no product id)"
  elif out=$(bounded 300 "$sb" "${list[@]}" 2>&1) \
     && jq -e "$page"' and (.requirements | length > 0 and (length < 2 or any(.[]; has("parentId"))))' >/dev/null 2>&1 <<<"$out"; then
    say OK "smoke: spec list --format json --include-sources --page-size (requirements: id, title, status, content, seqNum, productId, parentId; pagination: nextPageToken, totalCount)"
    sid=$(jq -r '.requirements[0].id' <<<"$out")
    token=$(jq -r '.pagination.nextPageToken' <<<"$out")
    if [ -n "$token" ]; then
      if out=$(bounded 300 "$sb" "${list[@]}" --page-token "$token" 2>&1) && jq -e "$page" >/dev/null 2>&1 <<<"$out"; then
        say OK "smoke: spec list --page-token (second page)"
      else say FAIL "smoke: spec list --page-token: ${out:0:200}"; fi
    fi
  else
    say FAIL "smoke: spec list --format json --include-sources: missing requirements, pagination or a field: ${out:0:200}"
  fi
  if [ -n "$sid" ]; then
    if out=$(bounded 60 "$sb" spec get "$sid" --format json 2>&1) \
       && jq -e 'has("id") and has("title") and has("status") and has("content")' >/dev/null 2>&1 <<<"$out"; then
      say OK "smoke: spec get --format json (id, title, status, content)"
    else say FAIL "smoke: spec get --format json: ${out:0:200}"; fi
  fi
  exit "$rc"
fi
[ "$cmd" = check ] || usage

# The pin: tiden.md of the harness commit this script runs from (harness-exec sets HARNESS_REV).
if [ -n "${TIDEN_PIN_FILE:-}" ]; then pin_text=$(cat "$TIDEN_PIN_FILE")
else
  h=${HARNESS_DIR:-$HOME/agent-harness}
  pin_text=$(git -C "$h" show "${HARNESS_REV:-origin/main}:modules/tiden/tiden.md") || { echo "no tiden.md in $h" >&2; exit 2; }
fi
pin_of() { sed -n "s/^$1=//p" <<<"$2" | head -n 1; }
pin=$(pin_of TIDEN_CLI_VERSION "$pin_text")
[[ $pin =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "no TIDEN_CLI_VERSION=<x.y.z> line in the pin" >&2; exit 2; }
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]; }  # $1 > $2

# 1. The pinned checksums: one per platform, equal to the release's checksums.txt.
base=${TIDEN_RELEASE_BASE:-https://github.com/qase-tms/homebrew-tap/releases/download}
rel=$(bounded 60 curl --fail --silent --show-error --location "$base/v$pin/checksums.txt" 2>&1) \
  || { say WARN "pin $pin: cannot read the release checksums.txt: ${rel:0:200}"; rel=''; }
for plat in $PLATFORMS; do
  sum=$(pin_of "TIDEN_CLI_SHA256_$plat" "$pin_text")
  if [ -z "$sum" ]; then say BAD "pin $pin: no TIDEN_CLI_SHA256_$plat= line"; continue; fi
  [ -n "$rel" ] || continue
  want=$(awk -v f="tiden_${plat}.tar.gz" '$2 == f { print $1 }' <<<"$rel")
  if [ -n "$want" ] && [ "$want" = "$sum" ]; then say OK "pin $pin $plat checksum matches the release"
  else say BAD "pin $pin $plat checksum ${sum:0:12} differs from the release (${want:-no tiden_${plat}.tar.gz})"; fi
done

# 2. The newest release (tiden upgrade check always exits 0; read its JSON).
if up=$(bounded 60 "$bin" upgrade check --format json 2>/dev/null) && latest=$(jq -er '.latest' <<<"$up" 2>/dev/null); then
  latest=${latest#v}
  if newer "$latest" "$pin"; then say LAG "pin $pin: release $latest is out (smoke it, then bump the pin)"
  else say OK "pin $pin is the newest release"; fi
else say WARN "tiden upgrade check gave no .latest"; fi

# 3. The local binary.
if have=$("$bin" --version 2>/dev/null) && [[ $have =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
  have=${BASH_REMATCH[1]}
  if [ "$have" = "$pin" ]; then say OK "local $bin $have"
  else say LAG "local $bin $have, pin $pin (tiden upgrade --binary-only --version v$pin)"; fi
else say WARN "local $bin: no version"; fi

# 4. Each project's CI on origin/main.
dirs=("$@")
if [ $# -eq 0 ]; then
  for cfg in ${TIDEN_ORCH_GLOB:-$HOME/*-orchestrator/config.sh}; do
    [ -f "$cfg" ] || continue
    wt=$(ORCH_DIR=$(dirname "$cfg") bash -c '. "$1" >/dev/null 2>&1; printf %s "${WORKTREES_DIR:-}"' _ "$cfg") || continue
    found=''
    while IFS= read -r g; do   # the root or a worktree up to four levels down (branch names with slashes)
      d=$(dirname "$g")
      git -C "$d" rev-parse --verify -q origin/main >/dev/null 2>&1 && { found=$d; break; }
    done < <([ -n "$wt" ] && [ -d "$wt" ] && find "$wt" -maxdepth 5 -name .git -prune 2>/dev/null | sort)
    if [ -n "$found" ]; then dirs+=("$found")
    else say WARN "$(dirname "$cfg"): no checkout with origin/main under WORKTREES_DIR '${wt}'"; fi
  done
fi
[ ${#dirs[@]} -gt 0 ] || { say WARN "no project checkouts found"; exit "$rc"; }
num='v?[0-9]+\.[0-9]+\.[0-9]+'
for d in "${dirs[@]}"; do
  p=$(basename "$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's#/\.git$##')" 2>/dev/null || echo "$d")
  bounded 60 git -C "$d" fetch -q origin main 2>/dev/null || say WARN "$p: fetch failed, origin/main may be old"
  git -C "$d" rev-parse --verify -q origin/main >/dev/null || { say WARN "$p: no origin/main in $d"; continue; }
  gg() { git -C "$d" grep -I "$@" origin/main -- .github 2>/dev/null || true; }
  hard=$(gg -n -o -E "homebrew-tap/releases/download/$num/tiden_|TIDEN_CLI_VERSION[[:space:]]*[:=][[:space:]]*[\"']?$num")
  reads=$(comm -12 <(gg -l -F 's/^TIDEN_CLI_VERSION=//p' | sort) <(gg -l -F 'docs/harness/modules/tiden/tiden.md' | sort))
  other=$(gg -l -i -E 'homebrew-tap|tiden_(linux|darwin)_|tiden\.tar\.gz|(brew|go) install[^#]*tiden|tiden[^ ]*/install\.sh')
  while IFS= read -r line; do
    [[ $line =~ ^origin/main:([^:]+:[0-9]+):.*[^0-9.]([0-9]+\.[0-9]+\.[0-9]+) ]] || continue
    loc=${BASH_REMATCH[1]}; v=${BASH_REMATCH[2]}
    say RULE "$p: $loc names Tiden $v itself; read TIDEN_CLI_VERSION from docs/harness/modules/tiden/tiden.md"
    [ "$v" = "$pin" ] || say LAG "$p: CI $v at $loc, pin $pin"
  done <<<"$hard"
  while IFS= read -r f; do   # a Tiden download in a file that neither reads the copy nor names a version we parse
    [ -n "$f" ] || continue
    f=${f#origin/main:}
    grep -qxF "origin/main:$f" <<<"$reads" || grep -q "^origin/main:$f:" <<<"$hard" \
      || say WARN "$p: $f downloads Tiden in a way this check does not read; verify it by hand"
  done <<<"$other"
  if [ -n "$reads" ]; then
    copy=$(git -C "$d" show origin/main:docs/harness/modules/tiden/tiden.md 2>/dev/null || true)
    cpin=$(pin_of TIDEN_CLI_VERSION "$copy")
    if [ -z "$cpin" ]; then say LAG "$p: CI reads docs/harness/modules/tiden/tiden.md, which has no pin (refresh the pinned copy)"
    elif [ "$cpin" != "$pin" ]; then say LAG "$p: CI reads the pinned copy, $cpin, pin $pin (refresh docs/harness)"
    else
      bad=''
      for plat in $PLATFORMS; do
        [ "$(pin_of "TIDEN_CLI_SHA256_$plat" "$copy")" = "$(pin_of "TIDEN_CLI_SHA256_$plat" "$pin_text")" ] || bad="$bad $plat"
      done
      if [ -n "$bad" ]; then say BAD "$p: pinned copy $cpin checksums differ from the pin:$bad (copy it verbatim)"
      else say OK "$p: CI reads the pinned copy, $cpin"; fi
    fi
  elif [ -z "$hard" ] && [ -z "$other" ]; then say OK "$p: no Tiden install in CI (tiden on PATH: the local binary)"
  fi
done
exit "$rc"
