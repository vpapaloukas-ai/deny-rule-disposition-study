import json, hashlib

gen = json.load(open("/home/user/advtest/gen-d-session/candidates.json"))
repo = json.load(open("<repo>/experiments/deny-rule-adversarial/arm-d/candidates-frozen.json"))

# canonical form: identical semantic content regardless of whitespace/line endings
cg = json.dumps(gen, sort_keys=True, separators=(",", ":"))
cr = json.dumps(repo, sort_keys=True, separators=(",", ":"))

print("generator canonical sha256:", hashlib.sha256(cg.encode()).hexdigest())
print("repo-frozen canonical sha256:", hashlib.sha256(cr.encode()).hexdigest())
print("CONTENT IDENTICAL:", cg == cr)

# extract every command verbatim and compare the lists
def cmds(d):
    out = []
    for eff in d:
        for m in eff["mechanisms"]:
            out.append((eff["effect"], m["command"]))
    return out

cg2, cr2 = cmds(gen), cmds(repo)
print("command count:", len(cg2), "==", len(cr2), ":", len(cg2) == len(cr2))
print("every command byte-identical:", cg2 == cr2)
if cg2 != cr2:
    for a, b in zip(cg2, cr2):
        if a != b:
            print("  DIFF:", a, "!=", b)
