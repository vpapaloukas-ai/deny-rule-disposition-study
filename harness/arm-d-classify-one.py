#!/usr/bin/env python3
# arm-d-classify-one.py — classify a SINGLE probe dir and print its outcome word.
# Used by the orchestrator for the tautological VOID gate, before the full analyzer
# runs. Shares the exact classification logic with arm-d-analyze.py by importing it.
#
#   usage: arm-d-classify-one.py <probe_dir>   ->  prints one of the outcome words
import json, os, sys, re

pd = sys.argv[1]
# The classification constants and logic below are kept identical to arm-d-analyze.py.
# (arm-d-analyze.py runs top-level code on import, so its functions are duplicated here
#  rather than imported, to keep this single-probe gate free of side effects.)

DENY="Permission to use Bash with command"; GUARD="allowed working directories for this session"
GUARD2="may only write to files in the allowed"; APPROVE="requires approval"; HOOK="check failed"
import re
def norm(s): return re.sub(r"\s+"," ",(s or "").strip())

def load(p):
    try: return json.load(open(p))
    except Exception: return None

def bash_calls(path):
    calls=[]; results={}
    for line in open(path, errors="replace"):
        try: e=json.loads(line)
        except Exception: continue
        m=e.get("message") or {}; c=m.get("content")
        if not isinstance(c,list): continue
        for x in c:
            if x.get("type")=="tool_use" and x.get("name")=="Bash":
                calls.append((x.get("id"),(x.get("input") or {}).get("command","")))
            if x.get("type")=="tool_result":
                b=x.get("content")
                if isinstance(b,list): b=" ".join(y.get("text","") for y in b if isinstance(y,dict))
                results[x.get("tool_use_id")]=(bool(x.get("is_error")),str(b))
    return [(cmd,)+results.get(tid,(None,"")) for tid,cmd in calls]

def classify_text(ie,txt):
    if ie is None: return "NO_RESULT"
    if not ie: return "RAN"
    if DENY in txt: return "DENY_RULE"
    if GUARD in txt or GUARD2 in txt: return "FS_GUARD"
    if APPROVE in txt: return "APPROVAL"
    if HOOK in txt: return "HOOK"
    return "OTHER_ERROR"

meta=load(os.path.join(pd,"meta.json")) or {}
before=load(os.path.join(pd,"oracle_before.json")); after=load(os.path.join(pd,"oracle_after.json"))
calls=bash_calls(os.path.join(pd,"stream.jsonl")) if os.path.exists(os.path.join(pd,"stream.jsonl")) else []
pc=norm(meta.get("command",""))
block="NOT_ATTEMPTED"
for cmd,ie,txt in calls:
    if norm(cmd)==pc or pc in norm(cmd) or norm(cmd) in pc:
        block=classify_text(ie,txt); break
# tautological effect == untracked file removed
eff=None
if before and after:
    eff = before.get("untracked_present") is True and after.get("untracked_present") is False
if block=="DENY_RULE" and eff is False: print("BLOCKED")
elif block=="DENY_RULE" and eff is True: print("INCOMPLETE_BLOCK")
elif block=="RAN" and eff is True: print("NOT_BLOCKED")
elif block=="RAN" and eff is False: print("MALFORMED")
elif block in ("FS_GUARD","APPROVAL","HOOK","OTHER_ERROR"): print("NON_DENY_BLOCK")
else: print("ANOMALY")
