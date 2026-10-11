#!/usr/bin/env python3
"""fst#7 x fst#3 -- does P(u|v)'s win survive with coordination pairs removed?

A coordination pair is ONE concept expressed by two descriptors (fst#7:
EntryCombination 1000x D+Q, Annotation 1784x D+D). Ranking such a pair as
"a related topic" is a category error -- it is a PART of the topic.

Three conditions against the same gold and the same feature dump:

  BASE     normal evaluation
  POOL     coordination pairs removed from the candidate pool
  GOLD     coordination pairs removed from the gold set

Plus: for each ranker, how much of its top-K is coordination at all.
"""
import argparse
import importlib.util
import json
import math
import os
import statistics
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "hs", os.path.join(HERE, "hub-suppression.py"))
_hs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hs)

_spec2 = importlib.util.spec_from_file_location(
    "re", os.path.join(HERE, "rank-eval.py"))
_re = importlib.util.module_from_spec(_spec2)
_spec2.loader.exec_module(_re)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--features", required=True)
    ap.add_argument("--gold", required=True)
    ap.add_argument("--trees", required=True)
    ap.add_argument("--coord", required=True)
    ap.add_argument("--k", type=int, default=10)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    F = json.load(open(args.features))
    gold_doc = json.load(open(args.gold))
    gold_all = gold_doc["gold"]
    trees = json.load(open(args.trees))
    coord = json.load(open(args.coord))

    # Coordination pairs as an UNORDERED set of (a,b) UI pairs.
    coord_pairs = set()
    for p in coord["pairs"]:
        if p["kind"] != "COORD":
            continue
        a, b = p["host"], p["target"]
        if a != b:
            coord_pairs.add(frozenset((a, b)))
    print(f"coordination pairs (COORD, unordered): {len(coord_pairs)}")
    noc = sum(1 for p in coord["pairs"] if p["kind"] == "NOCOORD")
    print(f"negative coordination pairs (NOCOORD): {noc}")

    def is_coord(a, b):
        return frozenset((a, b)) in coord_pairs

    n_articles = F["meta"]["articles"]
    major_deg = F["major_deg"]
    K = args.k

    # gold restricted to non-coordination members
    gold_nocoord = {}
    gold_removed = 0
    for s, g in gold_all.items():
        keep = {u: v for u, v in g.items() if not is_coord(s, u)}
        gold_removed += len(g) - len(keep)
        if keep:
            gold_nocoord[s] = keep
    print(f"gold members removed as coordination: {gold_removed} "
          f"({len(gold_all)} seeds -> {len(gold_nocoord)})")

    def run(gold_set, drop_coord_from_pool):
        """Return {ranker: {seed: {...}}} and coordination share of top-K."""
        res = {}
        coord_share = defaultdict(list)
        for name, fn, kind in _re.RANKERS:
            per_seed = {}
            for seed, gold in gold_set.items():
                f = {"n_articles": n_articles,
                     "deg_seed": major_deg.get(seed, 1),
                     "deg": major_deg,
                     "cooc": F["seeds"][seed]["cooc"],
                     "both_major": F["seeds"][seed]["both_major"],
                     "title_hits": F["seeds"][seed]["title_hits"]}
                scores = fn(f, seed)
                if drop_coord_from_pool:
                    scores = {u: sc for u, sc in scores.items()
                              if not is_coord(seed, u)
                              and not _hs.is_blocked(u, trees, "subject")
                              and f["cooc"].get(u, 0) >= 3}
                else:
                    scores = {u: sc for u, sc in scores.items()
                              if not _hs.is_blocked(u, trees, "subject")
                              and f["cooc"].get(u, 0) >= 3}
                ranked = sorted(scores, key=lambda u: (-scores[u], u))
                top = ranked[:K]
                coord_share[name].append(
                    sum(1 for u in top if is_coord(seed, u)))
                gold_scores = {w: gold[w] for w in
                               [x for x in gold if x in scores]}
                per_seed[seed] = {
                    "ndcg": _re.ndcg_at_k(ranked, gold_scores, K),
                    "p10": _re.precision_at_k(ranked, gold, K),
                    "mrr": _re.mrr(ranked, gold),
                    "top": top,
                }
            res[name] = {"kind": kind, "per_seed": per_seed}
        return res, coord_share

    print("\nrunning BASE ...", flush=True)
    base, cs_base = run(gold_all, False)
    print("running POOL (coordination excluded from candidates) ...", flush=True)
    pool, cs_pool = run(gold_all, True)
    print("running GOLD (coordination excluded from gold) ...", flush=True)
    gold_r, cs_gold = run(gold_nocoord, False)

    def mean_ndcg(res, name):
        v = [r["ndcg"] for r in res[name]["per_seed"].values()]
        return statistics.fmean(v) if v else 0.0

    def deltas(res, name):
        out = []
        for s in gold_all:
            if s not in res[name]["per_seed"]:
                continue
            if s not in base["PMI"]["per_seed"]:
                continue
            out.append(res[name]["per_seed"][s]["ndcg"]
                       - base["PMI"]["per_seed"][s]["ndcg"])
        return out

    print("\n" + "=" * 104)
    print("## nDCG@%d by condition" % K)
    print("=" * 104)
    print("%-16s %-13s %10s %10s %10s %12s" % (
        "ranker", "kind", "BASE", "POOL", "GOLD", "top-K coord"))
    print("-" * 104)
    for name, _, kind in _re.RANKERS:
        print("%-16s %-13s %10.4f %10.4f %10.4f %11.2f/%d" % (
            name, kind,
            mean_ndcg(base, name), mean_ndcg(pool, name),
            mean_ndcg(gold_r, name),
            statistics.fmean(cs_base[name]) if cs_base[name] else 0.0, K))

    print("\n" + "=" * 104)
    print("## Does the win survive?  (vs PMI, bootstrap 95%% CI)")
    print("=" * 104)
    print("%-16s %10s %-22s %10s %-22s %10s %-22s" % (
        "ranker", "d_BASE", "CI", "d_POOL", "CI", "d_GOLD", "CI"))
    print("-" * 104)
    verdicts = {}
    for name, _, kind in _re.RANKERS:
        if name == "PMI":
            continue
        row = []
        surv = True
        for cond, res in (("BASE", base), ("POOL", pool), ("GOLD", gold_r)):
            d = deltas(res, name)
            m = statistics.fmean(d) if d else 0.0
            lo, hi = _re.bootstrap_ci(d)
            excl = lo > 0
            if not excl:
                surv = False
            row.append((m, lo, hi, excl))
        verdicts[name] = surv
        print("%-16s %+10.4f [%+7.4f,%+7.4f] %s %+10.4f [%+7.4f,%+7.4f] %s "
              "%+10.4f [%+7.4f,%+7.4f] %s" % (
                  name,
                  row[0][0], row[0][1], row[0][2], "ok" if row[0][3] else "--",
                  row[1][0], row[1][1], row[1][2], "ok" if row[1][3] else "--",
                  row[2][0], row[2][1], row[2][2], "ok" if row[2][3] else "--"))

    print("\n## Verdict: win survives all three conditions?\n")
    for name, _, kind in _re.RANKERS:
        if name == "PMI":
            continue
        print("  %-16s %s" % (name, "YES" if verdicts[name]
                              else "NO - CI includes 0 in some condition"))
    print("\nwrote", args.out)

    with open(args.out, "w") as f:
        json.dump({"coord_pairs": len(coord_pairs),
                   "gold_removed": gold_removed,
                   "ndcg": {c: {n: mean_ndcg(r, n) for n in r}
                            for c, r in (("BASE", base), ("POOL", pool),
                                         ("GOLD", gold_r))},
                   "coord_share_topk": {
                       n: statistics.fmean(v) if v else 0.0
                       for n, v in cs_base.items()},
                   "survives_all": verdicts}, f, indent=2)


if __name__ == "__main__":
    main()
