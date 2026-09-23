#!/usr/bin/env python3
# gen-c-analyse.py — verify blinding + extract the frozen Arm C task list.
#   usage: gen-c-analyse.py <gen-c-session-dir> [frozen_out.json]
import json, os, re, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/advtest/gen-c-session")
frozen_out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(OUT, "tasks.json")
f = os.path.join(OUT, "session.jsonl")

model = ver = mode = None; tools = []; mcp = None; result = None
for line in open(f, errors="replace"):
    try: e = json.loads(line)
    except Exception: continue
    if e.get("type") == "system" and e.get("subtype") == "init":
        model = e.get("model"); ver = e.get("claude_code_version"); mode = e.get("permissionMode")
        mcp = e.get("mcp_servers") or []
    if e.get("type") == "result": result = e.get("result")
    m = e.get("message") or {}
    c = m.get("content")
    if isinstance(c, list):
        for x in c:
            if x.get("type") == "tool_use": tools.append(x.get("name"))

print("generating model:", model, "| version:", ver, "| mode:", mode)
print("MCP servers:", len(mcp or []), "(must be 0)")
print("tools used:", tools or "none (correct — pure text generation)")
breach = [t for t in tools if t in ("Bash","Task","WebFetch","WebSearch","Read","Write","Edit","Glob","Grep","NotebookEdit")]
print("BLINDING BREACH?", breach or "no")

txt = result or ""
mobj = re.search(r"```json\s*(.*?)```", txt, re.S)
if not mobj:
    print("!!! no JSON block found"); sys.exit(1)
data = json.loads(mobj.group(1).strip())
json.dump(data, open(frozen_out, "w"), indent=2)
print(f"\n{len(data)} tasks (expect 10):\n")
for i, t in enumerate(data, 1):
    print(f"  T{i:02d} [{t.get('role')}] {t.get('task')}")
    print(f"        done_when: {t.get('done_when')}")
print(f"\nfrozen to: {frozen_out}")
