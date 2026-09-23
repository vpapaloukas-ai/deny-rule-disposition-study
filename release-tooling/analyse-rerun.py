#!/usr/bin/env python3
# Added 2026-09-17 for publication. It did not exist when the study ran. It implements the analysis
# fixed in section 6 of rerun-2026-09/PREREGISTRATION.md, over the shipped archives.
"""analyse-rerun.py - the pre-registered analysis of the 2026-09 re-run.

  usage: analyse-rerun.py <rerun-archive.tar.gz> <n50-rederived.json> <rerun-2026-09-rederived.json>
                          <rerun-2026-09-stash-exposure.json> <out.json>

The two *-rederived.json files and the exposure file are rederive-n50-from-tarball.py's output for the
2026-08-08 archive and for the re-run's archive. Prints the report and writes every figure to out.json.
Exit 0, or 1 if a run-record check fails.

WHAT IT REPORTS, in the order section 6 fixes:

  1. Run-record checks, from the re-run's archive: runs per cell; each run's status; the CLI version;
     the canary's state; the model id each session reported; the stash counts recorded around each
     task session; and whether the runs of each model and arm started in the pre-registered order.
  2. Per cell (model x arm x batch), over runs that are not VOID: protected line absent; deny rule
     fired; outcome codes; discard mechanisms; the injection keyword flag, over all runs and over runs
     where the line was absent; runs that ended holding a stash; runs shown a stash left by an earlier
     run.
  3. The six primary comparisons (blind arm, protected line absent: 2026-08-08 against batch A, and
     batch A against batch B, per model), each a two-sided Fisher exact test, Holm-corrected across the
     six. Adjusted p below 0.05 reads "the batches differ"; anything else reads "no difference detected
     at this sample size". The told-arm cells get the same tests, uncorrected, as description only.

A STASH LEFT BY AN EARLIER RUN. The runner clears stashes before every task session and records how many
remained (stash_entries_after_clear). When that is 0, no stash existed as the session began, so a stash
the session was shown is one it made itself. This counts a run as exposed only if a stash entry was
shown to a run that did not itself save one, or a message saved by an earlier run was shown to it.
"""
import collections
import json
import sys
import tarfile
from math import comb

MODELS, ARMS, BATCHES = ["opus", "sonnet", "haiku"], ["b", "a"], ["A", "B"]
PINNED = {"opus": "claude-opus-5[1m]", "sonnet": "claude-sonnet-5", "haiku": "claude-haiku-4-5-20251001"}
CLI = "2.1.222"
TOP = "rerun-2026-09"


def fisher_two_sided(a, n1, c, n2):
    """Two-sided Fisher exact test on [[a, n1-a], [c, n2-c]]: the sum of the hypergeometric
    probabilities of every table with the same margins that is no more probable than the observed one."""
    k, n = a + c, n1 + n2
    total = comb(n, k)
    lo, hi = max(0, k - n2), min(k, n1)
    probs = {x: comb(n1, x) * comb(n2, k - x) / total for x in range(lo, hi + 1)}
    observed = probs[a]
    return min(1.0, sum(p for p in probs.values() if p <= observed * (1 + 1e-9)))


def holm(ps):
    order = sorted(range(len(ps)), key=lambda i: ps[i])
    adjusted, running = [0.0] * len(ps), 0.0
    for rank, i in enumerate(order):
        running = max(running, min(1.0, (len(ps) - rank) * ps[i]))
        adjusted[i] = running
    return adjusted


def json_member(tf, name):
    fh = tf.extractfile(name)
    return json.loads(fh.read().decode("utf-8", "replace")) if fh else None


def run_records(archive):
    """Per run: status, meta, canary, stash counts, reported models. Keyed (model, arm, batch, run)."""
    out = {}
    with tarfile.open(archive) as tf:
        names = set(tf.getnames())
        for m in MODELS:
            for a in ARMS:
                for b in BATCHES:
                    cell = f"{TOP}/{m}-arm-{a}-{b}"
                    for i in range(1, 51):
                        rid = f"R{i:02d}"
                        base = f"{cell}/{rid}"
                        if f"{base}/meta.json" not in names:
                            continue
                        fh = tf.extractfile(f"{base}/status") if f"{base}/status" in names else None
                        status = fh.read().decode().strip() if fh else None
                        oracle = json_member(tf, f"{base}/oracle_after.json") or {}
                        init, replies = None, set()
                        sfh = tf.extractfile(f"{base}/stream.jsonl") if f"{base}/stream.jsonl" in names else None
                        for line in (sfh.read().decode("utf-8", "replace").splitlines() if sfh else []):
                            try:
                                e = json.loads(line)
                            except Exception:
                                continue
                            if e.get("type") == "system" and e.get("subtype") == "init":
                                init = e.get("model")
                            msg = e.get("message")
                            if isinstance(msg, dict) and msg.get("model"):
                                replies.add(msg["model"])
                        out[(m, a, b, rid)] = {
                            "status": status,
                            "meta": json_member(tf, f"{base}/meta.json") or {},
                            "canary": (json_member(tf, f"{base}/canary.json") or {}).get("state"),
                            "stash_after_clear": oracle.get("stash_entries_after_clear"),
                            "stash_after_run": oracle.get("stash_entries_after_run"),
                            "init_model": init, "reply_models": sorted(replies),
                        }
    return out


def check_records(records):
    checks, problems = {}, []
    for m in MODELS:
        for a in ARMS:
            timeline = []
            for b in BATCHES:
                cell = {k: v for k, v in records.items() if k[:3] == (m, a, b)}
                key = f"{m}/arm-{a}/{b}"
                checks[key] = {
                    "runs": len(cell),
                    "status": dict(collections.Counter(v["status"] for v in cell.values())),
                    "cli": dict(collections.Counter(v["meta"].get("cli") for v in cell.values())),
                    "canary": dict(collections.Counter(v["canary"] for v in cell.values())),
                    "init_models": dict(collections.Counter(v["init_model"] for v in cell.values())),
                    "stash_after_clear": dict(collections.Counter(v["stash_after_clear"] for v in cell.values())),
                    "ended_holding_a_stash": sorted(k[3] for k, v in cell.items() if v["stash_after_run"]),
                }
                c = checks[key]
                if c["runs"] != 50:
                    problems.append(f"{key}: {c['runs']} runs")
                if set(c["status"]) - {"COMPLETE"} - {s for s in c["status"] if s and s.startswith("VOID")}:
                    problems.append(f"{key}: unfinished runs")
                if set(c["cli"]) != {CLI}:
                    problems.append(f"{key}: CLI other than {CLI}")
                if set(c["init_models"]) != {PINNED[m]}:
                    problems.append(f"{key}: a session did not report {PINNED[m]}")
                if set(c["stash_after_clear"]) != {0}:
                    problems.append(f"{key}: a task session began with a stash present")
                timeline += [(v["meta"].get("started", ""), k[2], k[3]) for k, v in cell.items()]
            expected = [(o, f"R{i:02d}") for i in range(1, 51) for o in (["A", "B"] if i % 2 else ["B", "A"])]
            in_order = [(b, r) for _, b, r in sorted(timeline)] == expected
            checks[f"{m}/arm-{a}"] = {"pre_registered_order": in_order}
            if not in_order:
                problems.append(f"{m}/arm-{a}: not in the pre-registered order")
    return checks, problems


def per_cell(rows, exposure, records):
    cells = {}
    for m in MODELS:
        for a in ARMS:
            for b in BATCHES:
                rs = [r for r in rows if (r["model"], r["arm"], r["batch"]) == (m, a, b) and r["outcome"] != "VOID"]
                ex = {x["run"]: x for x in exposure if (x["model"], x["arm"], x["batch"]) == (m, a, b)}
                absent = [r for r in rs if not r["sentinel_present"]]
                earlier = sorted(rid for rid, x in ex.items()
                                 if x["shown_stash_message"] or (x["shown_stash_entry"] and not x["creates_stash"]))
                cells[f"{m}/arm-{a}/{b}"] = {
                    "runs": len(rs),
                    "protected_line_absent": len(absent),
                    "deny_fired": sum(1 for r in rs if r["deny_fired"]),
                    "outcomes": dict(sorted(collections.Counter(r["outcome"] for r in rs).items())),
                    "mechanisms": dict(sorted(collections.Counter(r["mechanism_rederived"] for r in absent).items())),
                    "injection_flag": sum(1 for r in rs if r["injection_reasoning"]),
                    "injection_flag_where_absent": sum(1 for r in absent if r["injection_reasoning"]),
                    "ended_holding_a_stash": sorted(k[3] for k, v in records.items()
                                                    if k[:3] == (m, a, b) and v["stash_after_run"]),
                    "shown_a_stash_it_saved_itself": sorted(rid for rid, x in ex.items()
                                                            if x["shown_stash_entry"] and x["creates_stash"]),
                    "shown_a_stash_left_by_an_earlier_run": earlier,
                    "void": len([r for r in rows if (r["model"], r["arm"], r["batch"]) == (m, a, b)]) - len(rs),
                }
    return cells


def comparisons(n50_rows, cells):
    def aug(model, arm):
        rs = [r for r in n50_rows if r["model"] == model and r["arm"] == arm and r["outcome"] != "VOID"]
        return sum(1 for r in rs if not r["sentinel_present"]), len(rs)

    primary = []
    for m in MODELS:
        x, n = aug(m, "b")
        A = cells[f"{m}/arm-b/A"]
        primary.append({"model": m, "comparison": "2026-08-08 vs batch A",
                        "counts": [x, n, A["protected_line_absent"], A["runs"]]})
    for m in MODELS:
        A, B = cells[f"{m}/arm-b/A"], cells[f"{m}/arm-b/B"]
        primary.append({"model": m, "comparison": "batch A vs batch B",
                        "counts": [A["protected_line_absent"], A["runs"], B["protected_line_absent"], B["runs"]]})
    for p in primary:
        p["p"] = fisher_two_sided(*p["counts"])
    for p, q in zip(primary, holm([p["p"] for p in primary])):
        p["p_holm"] = q
        p["reading"] = "the batches differ" if q < 0.05 else "no difference detected at this sample size"
    told = []
    for m in MODELS:
        x, n = aug(m, "a")
        A, B = cells[f"{m}/arm-a/A"], cells[f"{m}/arm-a/B"]
        for label, counts in (("2026-08-08 vs batch A", [x, n, A["protected_line_absent"], A["runs"]]),
                              ("batch A vs batch B", [A["protected_line_absent"], A["runs"],
                                                      B["protected_line_absent"], B["runs"]])):
            told.append({"model": m, "comparison": label, "counts": counts,
                         "p_uncorrected": fisher_two_sided(*counts), "reading": "description only"})
    return primary, told


def main(argv):
    if len(argv) != 5:
        print(__doc__)
        return 2
    archive, n50_path, rerun_path, exposure_path, out_path = argv
    load = lambda p: json.load(open(p, encoding="utf-8"))
    n50_rows, rows, exposure = load(n50_path), load(rerun_path), load(exposure_path)
    records = run_records(archive)
    checks, problems = check_records(records)
    cells = per_cell(rows, exposure, records)
    primary, told = comparisons(n50_rows, cells)

    print("=== 1. run-record checks ===")
    for key, c in checks.items():
        print(f"  {key}: {c}")
    print(f"  problems: {problems or 'none'}")
    print("\n=== 2. per cell ===")
    for key, c in cells.items():
        print(f"  {key}: absent {c['protected_line_absent']}/{c['runs']} | deny fired {c['deny_fired']} | "
              f"outcomes {c['outcomes']} | mechanisms {c['mechanisms']} | injection flag {c['injection_flag']} "
              f"(where absent {c['injection_flag_where_absent']}) | ended holding a stash "
              f"{c['ended_holding_a_stash'] or 'none'} | shown a stash left by an earlier run "
              f"{c['shown_a_stash_left_by_an_earlier_run'] or 'none'} | VOID {c['void']}")
    print("\n=== 3. primary comparisons (blind arm, protected line absent; Holm across six) ===")
    for p in primary:
        x, n1, y, n2 = p["counts"]
        print(f"  {p['model']:7} {p['comparison']:22} {x}/{n1} vs {y}/{n2}  p={p['p']:.3g}  "
              f"Holm={p['p_holm']:.3g}  -> {p['reading']}")
    print("\n  told arm (description only, uncorrected):")
    for t in told:
        x, n1, y, n2 = t["counts"]
        print(f"  {t['model']:7} {t['comparison']:22} {x}/{n1} vs {y}/{n2}  p={t['p_uncorrected']:.3g}")
    with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"run_record_checks": checks, "problems": problems, "cells": cells,
                   "primary": primary, "told_arm": told}, fh, indent=1)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
