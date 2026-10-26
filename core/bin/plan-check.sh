#!/usr/bin/env bash
# Wave check (tiden.md, Planning an ask, P5; orchestration.md, Lanes): before a wave is dispatched,
# fail on Depends cycles, on a card that depends on a card of its own wave, a later wave or no wave,
# and inside one wave on path overlap or a lane over its limit.
# Input: the backlog file `estimate` reads: its first Markdown table with title and effort columns,
#   | id | title | effort | value | depends | lane | paths | wave |
# read as `estimate` reads it (header aliases id/#, effort/sp/e, depends/depends on/deps, key; an id
# without its leading # or, with no id, the row number; Depends `3, 5`, `3-6`, ids, keys, any case).
# Extra columns: paths (also "expected paths"), wave. Fill lane, paths and depends from the card's
# `Lane:`, `Expected paths:` and `Depends on:`.
# Paths: comma- or space-separated; backticks and (notes) dropped; normalized (`./`, `..`). A path
# covers everything under it (`.` covers all); a glob (* ? [) is taken to cover everything that
# starts with its text before the first wildcard (conservative: such pairs fail, split or reorder).
# Lane limits: the open cap of a `## Lanes` section in the same file (`- migration (cap 2)`, the line
# `estimate` reads; a merging cap is not a limit here); a lane not listed has limit 1, stricter than
# `estimate`, since a wave is dispatched at once. A card without a lane or paths skips that check.
# Waves: the wave column (whole numbers; empty or - for none), or --plan FILE, the output of
# `estimate plan --json [--agents n]` (the waves of its chosen agent count). Without waves only cycles
# are checked. Cards `estimate` runs one after another in a capped lane of one wave still count
# against the limit: move one to another wave.
# Usage: plan-check.sh <backlog.md> [--plan FILE]
# Exit: 0 clean, 1 findings (one FAIL line each), 2 usage or an unreadable file or table.
set -euo pipefail
usage() { echo "usage: plan-check.sh <backlog.md> [--plan FILE]" >&2; exit 2; }
[ $# -ge 1 ] || usage
backlog=$1; shift
plan=''
while [ $# -gt 0 ]; do
  case "$1" in
    --plan) [ $# -ge 2 ] && [ -n "$2" ] || usage; plan=$2; shift ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
  shift
done
[ -f "$backlog" ] || { echo "no backlog file: $backlog" >&2; exit 2; }
[ -z "$plan" ] || [ -f "$plan" ] || { echo "no plan file: $plan" >&2; exit 2; }
exec python3 -I - "$backlog" "$plan" <<'PY'
import json, posixpath, re, sys

backlog, plan = sys.argv[1], sys.argv[2]
COLS = {'id': ('id', '#'), 'title': ('title', 'item', 'task'), 'sp': ('effort', 'sp', 'e'), 'key': ('key',),
        'depends': ('depends', 'depends on', 'deps'), 'lane': ('lane',), 'paths': ('paths', 'expected paths'),
        'wave': ('wave',)}
LANE = re.compile(r'^\s*[-*]\s*`?([^\s`(:]+)`?\s*[(:]\s*(?:(open|merging)\s+)?cap\s*(\d+)', re.I)
UUID = r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
NONE = ('', '-', '–', '—')


def usage(msg):
    print(f'plan-check: {msg}', file=sys.stderr)
    sys.exit(2)


def read(path):
    try:
        with open(path, encoding='utf-8') as f: return f.read()
    except (OSError, UnicodeDecodeError) as err: usage(f'{path}: {err}')


def cells(line):
    parts = re.split(r'(?<!\\)\|', line.strip())
    if parts and parts[0] == '': parts = parts[1:]
    if parts and parts[-1] == '': parts = parts[:-1]
    return [p.strip() for p in parts]


def depends(cell):
    """As `estimate` reads Depends: `3, 5` or `3-6` (a numeric range); `-` or empty is none."""
    out = []
    for part in re.split(r'[,\s]+', cell.strip()):
        part = part.strip().strip('`').lstrip('#')
        if part in NONE: continue
        m = re.fullmatch(r'(\d+)\s*[-–]\s*(\d+)', part)
        if m and int(m.group(1)) <= int(m.group(2)): out += [str(n) for n in range(int(m.group(1)), int(m.group(2)) + 1)]
        else: out.append(part)
    return out


def paths(cell):
    out = []
    for p in re.split(r'[,\s]+', re.sub(r'\([^)]*\)', ' ', cell)):
        p = p.strip().strip('`')
        if p in NONE: continue
        out.append(posixpath.normpath(p))
    return out


lines = read(backlog).splitlines()
cols, start = None, None
for n, line in enumerate(lines):
    if not line.strip().startswith('|'): continue
    names = [c.lower() for c in cells(line)]
    found = {k: next((i for i, c in enumerate(names) if c in al), None) for k, al in COLS.items()}
    if found['sp'] is not None and found['title'] is not None:
        cols, start = found, n
        break
if cols is None: usage(f'{backlog}: no backlog table (a header with title and effort columns)')
cards, order, row = {}, [], 0
for line in lines[start + 1:]:
    if not line.strip().startswith('|'): break
    c = cells(line)
    if all(re.fullmatch(r':?-+:?', x) for x in c if x): continue
    row += 1
    get = lambda k: c[cols[k]] if cols[k] is not None and cols[k] < len(c) else ''
    cid = get('id').strip('`').lstrip('#') or str(row)
    if cid in cards: usage(f'{backlog}: id {cid} twice')
    wave = get('wave').strip()
    if wave in NONE: wave = None
    elif not re.fullmatch(r'\d+', wave): usage(f'{backlog}: card {cid}: wave must be a whole number, not {wave!r}')
    cards[cid] = {'key': get('key').strip('`'), 'depends': depends(get('depends')),
                  'lane': get('lane').strip('` ') or None, 'paths': paths(get('paths')), 'wave': wave}
    order.append(cid)
caps, inside = {}, False
for line in lines:
    if m := re.match(r'^\s*#{1,6}\s+(.*?)\s*$', line):
        inside = m.group(1).lower().startswith('lanes'); continue
    if inside and (m := LANE.match(line)) and (m.group(2) or 'open').lower() == 'open' and int(m.group(3)) >= 1:
        caps[m.group(1)] = int(m.group(3))


def resolve(ref):
    """As `estimate` resolves a Depends ref: the id, else the key, else either in another case, else a
    UUID prefix of 8 or more characters. The first step that matches decides: one card resolves, two
    or more leave the ref unchanged (unknown, taken as done)."""
    if ref in cards: return ref
    low = ref.lower()
    for found in ({i for i in cards if cards[i]['key'] == ref},
                  {i for i in cards if i.lower() == low or cards[i]['key'].lower() == low},
                  {i for i in cards if re.fullmatch(UUID, i.lower()) and i.lower().startswith(low)} if len(ref) >= 8 else set()):
        if found: return next(iter(found)) if len(found) == 1 else ref
    return ref


fails = []
for cid in order:
    cards[cid]['depends'] = list(dict.fromkeys(resolve(d) for d in cards[cid]['depends']))
    for d in cards[cid]['depends']:
        if d not in cards: print(f'plan-check: {cid} depends on {d}, which is not in the table (taken as done)', file=sys.stderr)

# Depends cycles: depth-first search over the cards in the table.
state, stack = {}, []
sys.setrecursionlimit(max(1000, 4 * len(cards) + 100))
def visit(v):
    state[v] = 1; stack.append(v)
    for d in cards[v]['depends']:
        if d not in cards: continue
        if state.get(d) == 1: fails.append(f'FAIL cycle: {" -> ".join(stack[stack.index(d):] + [d])}')
        elif d not in state: visit(d)
    stack.pop(); state[v] = 2
for cid in order:
    if cid not in state: visit(cid)

# Waves: the plan's chosen agent count, else the wave column in number order.
if plan:
    try:
        p = json.loads(read(plan))
        waves = [[str(x) for x in w['ids']] for w in p['agents'][str(p['chosen'])]['waves']]
    except (ValueError, KeyError, TypeError) as err: usage(f'{plan}: not `estimate plan --json` output ({err!r})')
    for w in waves:
        for x in w:
            if x not in cards: usage(f'{plan}: wave card {x} is not in {backlog}')
    labels = [str(n + 1) for n in range(len(waves))]
else:
    labels = sorted({cards[c]['wave'] for c in order if cards[c]['wave']}, key=int)
    waves = [[c for c in order if cards[c]['wave'] == lb] for lb in labels]
wave_of = {x: n for n, w in enumerate(waves) for x in w}
if not waves: print('plan-check: no waves (no wave column and no --plan): cycles only', file=sys.stderr)


def overlap(a, b):
    """Two normalized paths touch: one is, or is under, the other; `.` touches all. A glob touches what
    shares its text before the first wildcard (conservative)."""
    if '.' in (a, b): return True
    under = lambda x, d: x == d or x.startswith(d.rstrip('/') + '/')  # `/` covers every absolute path
    ga, gb = re.search(r'[*?[]', a), re.search(r'[*?[]', b)
    if not ga and not gb: return under(a, b) or under(b, a)
    la, lb = a[:ga.start()] if ga else a, b[:gb.start()] if gb else b
    if ga and gb: return la.startswith(lb) or lb.startswith(la)
    lit, plain = (la, b) if ga else (lb, a)
    return plain.startswith(lit) or under(lit, plain)


for n, w in enumerate(waves):
    for x in w:
        for d in cards[x]['depends']:
            if d not in cards: continue
            if d not in wave_of: fails.append(f'FAIL wave {labels[n]}: {x} depends on {d}, which is in no wave')
            elif wave_of[d] >= n:
                where = 'the same wave' if wave_of[d] == n else f'later wave {labels[wave_of[d]]}'
                fails.append(f'FAIL wave {labels[n]}: {x} depends on {d} in {where}')
    for i, x in enumerate(w):
        for y in w[i + 1:]:
            hit = sorted({p if p == q else f'{p} ~ {q}' for p in cards[x]['paths'] for q in cards[y]['paths'] if overlap(p, q)})
            if hit: fails.append(f'FAIL wave {labels[n]}: path overlap of {x} and {y}: {", ".join(hit)}')
    lanes = {}
    for x in w:
        if cards[x]['lane']: lanes.setdefault(cards[x]['lane'], []).append(x)
    for lane, xs in lanes.items():
        cap = caps.get(lane, 1)
        if len(xs) > cap: fails.append(f'FAIL wave {labels[n]}: lane {lane} over its limit {cap}: {", ".join(xs)}')

for f in fails: print(f)
print(f'plan-check: {len(cards)} cards, {len(waves)} waves ({len(wave_of)} cards in a wave), {len(fails)} findings')
sys.exit(1 if fails else 0)
PY
