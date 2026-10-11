#!/usr/bin/env python3
"""fst#6 regression check: subject-walk results before vs after facet scoping.

Compares the kept sets from the shipped fst#2/fst#3 suppression against the
new facet-aware one on the same feature dump.
"""
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "hs", os.path.join(HERE, "hub-suppression.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)

FEATS = sys.argv[1]
TREES = sys.argv[2]
# gold is optional -- used to report nDCG-ish overlap if present
GOLD = sys.argv[3] if len(sys.argv) > 3 else None

F = json.load(open(FEATS))
trees = json.load(open(TREES))
deg = F["major_deg"]

# Rebuild the OLD blocklist verbatim (fst#2 shipped state) for comparison.
OLD_TREES = ["M01.060", "E05.318.372.500", "Z01"]
OLD_UIS = {"D006801", "D000818", "D005260", "D008297", "D014481",
           "D013997", "D016896", "D012307", "D000367", "D015203", "D011795"}


def old_blocked(ui):
    if ui in OLD_UIS:
        return True
    for t in trees.get(ui, {}).get("trees", []):
        for p in OLD_TREES:
            if t == p or t.startswith(p + "."):
                return True
    return False


gold = json.load(open(GOLD))["gold"] if GOLD else {}

rows = []
for seed, blob in F["seeds"].items():
    cooc = blob["cooc"]
    sd = deg.get(seed, 1)
    # old: manual filter + fst#2 suppress semantics (K=12, min_cooc=3)
    cand_old = [u for u in cooc
                if not old_blocked(u) and cooc[u] >= 3]
    scored = []
    import math
    n = F["meta"]["articles"]
    for u in cand_old:
        du = deg.get(u, 1)
        if du and sd:
            scored.append((-math.log2((cooc[u] * n) / float(du * sd)),
                           -cooc[u], u))
    scored.sort()
    old_kept = sorted(u for _, _, u in scored[:12])

    new_kept, st = hs.suppress(cooc, deg, sd, F["meta"]["articles"],
                               12, trees, 3, walk="subject")

    inter = set(old_kept) & set(new_kept)
    union = set(old_kept) | set(new_kept)
    j = len(inter) / len(union) if union else 1.0

    g = gold.get(seed, {})
    old_hits = sum(1 for u in old_kept if u in g)
    new_hits = sum(1 for u in new_kept if u in g)
    rows.append({"seed": seed, "name": F["seed_names"].get(seed, ""),
                 "old": len(old_kept), "new": len(new_kept),
                 "jaccard": j, "old_hits": old_hits, "new_hits": new_hits,
                 "blocked_new": st["blocked"]})

rows.sort(key=lambda r: r["jaccard"])
print("%-12s %-30s %5s %5s %8s %7s %7s" % (
    "seed", "name", "old", "new", "jaccard", "gold-o", "gold-n"))
print("-" * 88)
for r in rows[:15]:
    print("%-12s %-30s %5d %5d %8.3f %7d %7d" % (
        r["seed"], (r["name"] or "")[:30], r["old"], r["new"],
        r["jaccard"], r["old_hits"], r["new_hits"]))

js = sorted(r["jaccard"] for r in rows)
n = len(js)
print("\nseeds: %d" % n)
print("Jaccard old vs new kept sets: min=%.3f p50=%.3f max=%.3f mean=%.3f"
      % (js[0], js[n // 2], js[-1], sum(js) / n))
tot_o = sum(r["old_hits"] for r in rows)
tot_n = sum(r["new_hits"] for r in rows)
print("gold hits: old=%d  new=%d  delta=%+d" % (tot_o, tot_n, tot_n - tot_o))
print("mean blocked by facet rule: %.1f per seed"
      % (sum(r["blocked_new"] for r in rows) / n))
print("\nverdict: %s" % (
    "PASS - no regression" if tot_n >= tot_o else "CHECK - gold hits dropped"))
