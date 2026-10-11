#!/usr/bin/env python3
"""fst#3 — build Gold A: graded MeSH tree proximity.

For each seed descriptor, list descriptors near it in the MeSH hierarchy,
graded:

    3  sibling   shares the immediate parent tree node
    2  parent/child   one tree number is a prefix of the other
    1  cousin     shares a grandparent but not a parent

This is TAXONOMIC relatedness. It is external to co-occurrence (which is
why it can judge PMI without circularity) but it is not associative
relatedness — a ranker can be penalised for good associative results.
That limitation is stated in docs/ranking-design.md §9.

Banned under C3: using tree proximity as a FEATURE. Here it is only GOLD.
"""
import argparse
import gzip
import json
import re
import sys
from collections import defaultdict


def parent_of(t):
    """Immediate parent tree number, or None for a top-level node."""
    return t.rsplit(".", 1)[0] if "." in t else None


def grandparent_of(t):
    p = parent_of(t)
    return parent_of(p) if p else None


def build_gold(trees, seed, pool):
    """Graded gold for `seed`, restricted to nodes in `pool`."""
    gold = {}
    s_trees = trees.get(seed, {}).get("trees", [])
    if not s_trees:
        return gold
    s_parents = set(filter(None, (parent_of(t) for t in s_trees)))
    s_grands = set(filter(None, (grandparent_of(t) for t in s_trees)))

    for u in pool:
        u_trees = trees.get(u, {}).get("trees", [])
        if not u_trees:
            continue
        best = 0
        for st in s_trees:
            for ut in u_trees:
                if ut == st:
                    continue
                # parent/child: one is a prefix of the other
                if ut.startswith(st + ".") or st.startswith(ut + "."):
                    best = max(best, 2)
                    continue
                up = parent_of(ut)
                # sibling: same immediate parent
                if up and up in s_parents:
                    best = max(best, 3)
                    continue
                ug = grandparent_of(ut)
                if ug and ug in s_grands:
                    best = max(best, 1)
        if best:
            gold[u] = best
    return gold


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--trees", required=True)
    ap.add_argument("--features", required=True, help="rank-features.json")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    trees = json.load(open(args.trees))
    feats = json.load(open(args.features))

    out = {"meta": feats["meta"], "gold": {}, "stats": {}}
    total = 0
    for seed, blob in feats["seeds"].items():
        pool = set(blob["cooc"].keys())
        g = build_gold(trees, seed, pool)
        if not g:
            continue
        out["gold"][seed] = g
        counts = defaultdict(int)
        for rel in g.values():
            counts[rel] += 1
        total += len(g)
        out["stats"][seed] = {
            "pool": len(pool),
            "gold": len(g),
            "by_grade": {str(k): v for k, v in sorted(counts.items())},
        }

    with open(args.out, "w") as f:
        json.dump(out, f)

    print("seeds with gold: %d" % len(out["gold"]))
    print("total gold pairs: %d" % total)
    if out["gold"]:
        sizes = sorted(s["gold"] for s in out["stats"].values())
        n = len(sizes)
        print("gold per seed: min=%d p50=%d max=%d" % (
            sizes[0], sizes[n // 2], sizes[-1]))
        pools = sorted(s["pool"] for s in out["stats"].values())
        print("pool per seed:  min=%d p50=%d max=%d" % (
            pools[0], pools[n // 2], pools[-1]))
        # Coverage: how much of the pool is gold at all.
        cov = [s["gold"] / s["pool"] if s["pool"] else 0
               for s in out["stats"].values()]
        cov.sort()
        print("gold/pool:      min=%.3f p50=%.3f max=%.3f" % (
            cov[0], cov[n // 2], cov[-1]))
    print("wrote", args.out)


if __name__ == "__main__":
    main()
