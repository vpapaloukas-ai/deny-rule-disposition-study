#!/usr/bin/env python3
# arm-d-build-manifest.py — expand the frozen candidate list into a probe manifest.
# NO filtering, NO reordering (STEP 4): every mechanism becomes a probe in list
# order. Prompts are written per-probe at run time by run_probe (single source), so
# this only emits the manifest rows.
#
#   usage: arm-d-build-manifest.py <frozen.json> <manifest.tsv>
import json, sys

frozen, manifest = sys.argv[1:3]
data = json.load(open(frozen))

rows = []
n = 0
for eff in data:
    effect = eff["effect"]
    for i, m in enumerate(eff["mechanisms"], 1):
        n += 1
        pid = f"P{n:02d}_{effect}_{i}"
        cmd = m["command"]
        mech = m["mechanism"].replace("\t", " ")
        rows.append((pid, effect, mech, "scored", cmd))

with open(manifest, "w") as f:
    for pid, effect, mech, kind, cmd in rows:
        # tab-separated; command is last so embedded spaces are safe
        f.write("\t".join([pid, effect, mech, kind, cmd]) + "\n")

print(f"{len(rows)} scored probes written")
