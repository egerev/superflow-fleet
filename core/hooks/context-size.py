#!/usr/bin/env python3
"""PostToolUse hook for every project: one line when the session context passes its handoff budget.

Context = input + cache_creation + cache_read tokens of the transcript's last main-chain assistant call.
Budget (orchestration.md, Sessions): ORCH_CONTEXT_LIMIT (250k) when the cwd is an orchestrator's
directory or the path in its active-cwd file; WORKER_CONTEXT_LIMIT (170k) when the cwd is inside the
WORKTREES_DIR of that project's config.sh; any other session stays silent. Orchestrator directories: $HARNESS_ORCH_GLOB
(default ~/*-orchestrator). config.sh is read as plain KEY=value lines, never executed.
Any error stays silent: the hook must never block or disturb a tool call.
settings.json: {"type":"command","command":"<harness-exec.sh> core/hooks/context-size.py","timeout":5}
"""
import glob
import json
import os
import re
import sys

WORKER_LIMIT = 170_000
ORCHESTRATOR_LIMIT = 250_000
TAIL_BYTES = 512 * 1024
ASSIGN = re.compile(r"^\s*(?:export\s+)?([A-Z_][A-Z0-9_]*)=(.*)$")


def last_context(path: str) -> int:
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        f.seek(max(0, size - TAIL_BYTES))
        lines = f.read().splitlines()
    for raw in reversed(lines):
        if b'"usage"' not in raw: continue
        try: rec = json.loads(raw)
        except ValueError: continue  # first line of the tail may be cut
        if rec.get("type") != "assistant" or rec.get("isSidechain"): continue
        u = (rec.get("message") or {}).get("usage") or {}
        total = sum(int(u.get(k) or 0) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
        if total: return total
    return 0


def read_config(orch: str) -> dict:
    """KEY=value lines of <orch>/config.sh; quotes stripped; $HOME, ~ and $ORCH_DIR expanded."""
    out = {}
    try:
        with open(os.path.join(orch, "config.sh"), encoding="utf-8") as f: lines = f.read().splitlines()
    except (OSError, ValueError): return out  # a bad config never hides another project's
    env = dict(os.environ, ORCH_DIR=orch)
    for line in lines:
        m = ASSIGN.match(line)
        if not m: continue
        val = m.group(2).split(" #")[0].strip().strip("'\"")
        val = re.sub(r"\$\{?(\w+)\}?", lambda v: env.get(v.group(1), v.group(0)), val)
        out[m.group(1)] = os.path.expanduser(val)
    return out


def as_int(cfg: dict, key: str, default: int) -> int:
    try: return int(cfg.get(key) or default)
    except ValueError: return default


def inside(path: str, root: str) -> bool:
    return path == root or path.startswith(root.rstrip(os.sep) + os.sep)


def limit_for(cwd: str) -> "int | None":
    """The cwd's budget, or None outside every project (that session stays silent)."""
    if not cwd: return None
    cwd = os.path.realpath(cwd)
    worker = None
    for orch in sorted(glob.glob(os.path.expanduser(os.environ.get("HARNESS_ORCH_GLOB") or "~/*-orchestrator"))):
        try:
            orch = os.path.realpath(orch)
            cfg = read_config(orch)
            homes = {orch}
            try:
                with open(os.path.join(orch, "active-cwd"), encoding="utf-8") as f: line = f.readline().strip()
                if line: homes.add(os.path.realpath(os.path.expanduser(line)))
            except (OSError, ValueError): pass
            if cwd in homes: return as_int(cfg, "ORCH_CONTEXT_LIMIT", ORCHESTRATOR_LIMIT)
            wt = cfg.get("WORKTREES_DIR")
            if worker is None and wt and inside(cwd, os.path.realpath(wt)): worker = as_int(cfg, "WORKER_CONTEXT_LIMIT", WORKER_LIMIT)
        except Exception: continue  # one project's error never silences another's
    return worker


def main() -> None:
    data = json.load(sys.stdin)
    path = data.get("transcript_path") or ""
    if not path or not os.path.isfile(path): return
    tokens = last_context(path)
    limit = int(os.environ.get("CONTEXT_SIZE_LIMIT") or 0) or limit_for(data.get("cwd") or "")  # env override: tests only
    if limit is None or tokens <= limit: return
    line = f"context {tokens // 1000} k: write the handoff at the next boundary"
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": line}}))


if __name__ == "__main__":
    try: main()
    except Exception: pass
