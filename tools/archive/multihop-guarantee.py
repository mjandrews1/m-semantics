#!/usr/bin/env python3
"""fst#9 item 10 -- is the multi-hop pruning guarantee vacuous?

fst#4's stated guarantee (paraphrased): pruning to K1 intermediates
RETAINS an oracle top-K node if that node has >= 2 distinct intermediates.

The true survival condition is:
    w survives  <=>  I(w) intersect S != {}
where I(w) = w's intermediate set and S = the kept K1.

So |I(w)| >= 2 does NOT imply survival -- both intermediates can be pruned.
This script checks, against the fst#4 feature dump:

  1.  the distribution of |I(w)| for KEPT vs LOST candidates
  2.  whether any LOST candidate had |I(w)| >= 2  (that would DISPROVE
      the stated condition, not merely show it unmet)
  3.  whether any KEPT candidate had |I(w)| == 1  (that would show the
      condition is not necessary either)
  4.  the empirical P(survive | |I(w)| = k) for k = 1, 2, 3+
"""
import argparse
import importlib.util
import json
import os
import statistics
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "hs", os.path.join(HERE, "hub-suppression.py"))
_hs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--features", required=True)
    ap.add_argument("--trees", required=True)
    ap.add_argument("--k1", type=int, default=12)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    F = json.load(open(args.features))
    trees = json.load(open(args.trees))
    deg = F["major_deg"]
    K1 = args.k1

    rows = []
    per_k_survived = defaultdict(lambda: [0, 0])   # k -> [survived, total]

    for seed in F["meta"]["panel_a"]:
        hop1 = F["hop1"][seed]
        sd = deg.get(seed, 1)
        all_inter = [u for u in hop1
                     if not _hs.is_blocked(u, trees) and hop1[u] >= 3]
        kept, _ = _hs.suppress(hop1, deg, sd, len(F["hop2"]), K1, trees)
        kept_set = set(kept)

        # every candidate w and the set of intermediates reaching it
        I = defaultdict(set)
        for u in all_inter:
            for w in F["hop2"].get(u, {}):
                if w != seed:
                    I[w].add(u)

        for w, inters in I.items():
            n_i = len(inters)
            survived = bool(inters & kept_set)
            rows.append({"seed": seed, "w": w, "n_inter": n_i,
                         "survived": survived,
                         "n_inter_kept": len(inters & kept_set)})

    # rebuild the tallies cleanly
    tally = defaultdict(lambda: {"surv": 0, "lost": 0})
    for r in rows:
        k = min(r["n_inter"], 5)
        tally[k]["surv" if r["survived"] else "lost"] += 1

    kept_rows = [r for r in rows if r["survived"]]
    lost_rows = [r for r in rows if not r["survived"]]

    def ms(vals):
        return statistics.fmean(vals) if vals else 0.0

    print("=" * 88)
    print("## |I(w)| distribution  (K1 = %d)" % K1)
    print("=" * 88)
    print("%-22s %8s %8s %8s %8s" % ("", "n", "mean|I|", "med|I|", "max|I|"))
    for lab, grp in (("KEPT (survived)", kept_rows),
                     ("LOST (pruned)", lost_rows)):
        ni = sorted(r["n_inter"] for r in grp)
        print("%-22s %8d %8.2f %8.1f %8d" % (
            lab, len(grp), ms(ni),
            statistics.median(ni) if ni else 0, ni[-1] if ni else 0))

    print()
    print("## Empirical P(survive | |I(w)| = k)")
    print("%-8s %8s %8s %10s" % ("|I|", "survived", "lost", "P(survive)"))
    for k in sorted(tally):
        t = tally[k]
        n = t["surv"] + t["lost"]
        print("%-8s %8d %8d %10.3f" % (
            (str(k) if k < 5 else "5+"), t["surv"], t["lost"], t["surv"] / n))

    lost_ge2 = [r for r in lost_rows if r["n_inter"] >= 2]
    kept_eq1 = [r for r in kept_rows if r["n_inter"] == 1]
    lost_eq1 = [r for r in lost_rows if r["n_inter"] == 1]

    print()
    print("=" * 88)
    print("## The stated guarantee")
    print("=" * 88)
    print('  claim:  "every node with >= 2 intermediates is retained"')
    print()
    print("  LOST nodes with |I| >= 2:   %d   <-- if >0 the claim is FALSE"
          % len(lost_ge2))
    print("  LOST nodes with |I| == 1:   %d" % len(lost_eq1))
    print("  KEPT nodes with |I| == 1:   %d   <-- if >0 the condition is not NECESSARY"
          % len(kept_eq1))
    print()
    if lost_ge2:
        print("  counterexamples to the claim (lost despite >=2 intermediates):")
        for r in lost_ge2[:12]:
            print("    seed=%-11s w=%-12s |I|=%d  kept-intermediates=%d"
                  % (r["seed"], r["w"], r["n_inter"], r["n_inter_kept"]))
    print()
    verdict = []
    if lost_ge2:
        verdict.append("SUFFICIENCY: FALSE -- nodes with >=2 intermediates are lost")
    else:
        verdict.append("SUFFICIENCY: not falsified on this sample")
    if kept_eq1:
        verdict.append("NECESSITY: FALSE -- nodes with 1 intermediate survive")
    else:
        verdict.append("NECESSITY: not falsified on this sample")
    if lost_eq1 and not lost_ge2:
        verdict.append("VACUITY: the claim never fires for the nodes we actually lose")
    for v in verdict:
        print("  " + v)

    with open(args.out, "w") as f:
        json.dump({
            "k1": K1,
            "n_candidates": len(rows),
            "kept": len(kept_rows), "lost": len(lost_rows),
            "mean_inter_kept": ms([r["n_inter"] for r in kept_rows]),
            "mean_inter_lost": ms([r["n_inter"] for r in lost_rows]),
            "lost_with_ge2_intermediates": len(lost_ge2),
            "kept_with_1_intermediate": len(kept_eq1),
            "lost_with_1_intermediate": len(lost_eq1),
            "p_survive_by_k": {str(k): (t["surv"] / (t["surv"] + t["lost"]))
                               for k, t in tally.items()},
            "verdict": verdict,
        }, f, indent=2)
    print("\nwrote", args.out)


if __name__ == "__main__":
    main()
