#!/usr/bin/env python3
"""fst#3 — evaluate ranking candidates against Gold A.

Success criterion (docs/ranking-design.md §10):

    beats PMI  <=>  d_nDCG@10(Gold A) > 0 with bootstrap 95% CI excluding 0
                    AND d_nDCG@10 >= 0 on topical seeds
                    AND d_nDCG@10 > eps_method on method-hub seeds
                    AND no banned feature used
                    AND cost reported next to every score

Feature ban (C3): gold is thesaurus-derived, so features must be
corpus-derived only. Every ranker below obeys this.
"""
import argparse
import importlib.util
import json
import math
import os
import random
import statistics
import sys
import time

# Reuse fst#2's blocklist verbatim — suppression must be IDENTICAL to the
# shipped algorithm, not reimplemented here, or the comparison is not
# "which ranker is better" but "which ranker best survives hubs".
_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "hub_suppression", os.path.join(_HERE, "hub-suppression.py"))
_hs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hs)
is_blocked = _hs.is_blocked
MIN_COOCCUR = 3

# Seed strata from the fst#2 hand-check. Method hubs have no topical
# content; topical seeds are the class PMI already gets right.
METHOD_HUBS = {
    "D012106",   # Research
    "D000465",   # Algorithms
    "D008954",   # Models, Biological
    "D008962",   # Models, Theoretical
    "D000375",   # Aging
    "D012984",   # Software
    "D003142",   # Communication
    "D006761",   # Hospitals
    "D001291",   # Attitude of Health Personnel
    "D007722",   # Health Knowledge, Attitudes, Practice
}


# --------------------------------------------------------------------------
# rankers — every one is corpus-derived only (C3)
# --------------------------------------------------------------------------

def rank_pmi(f, seed):
    """Baseline: PMI(u;v) = log2[ c * N / (deg(u)*deg(v)) ]."""
    n, sd = f["n_articles"], f["deg_seed"]
    out = {}
    for u, c in f["cooc"].items():
        du = f["deg"].get(u, 1)
        if du and sd and c:
            out[u] = math.log2((c * n) / float(du * sd))
    return out


def rank_npmi(f, seed):
    """Normalised PMI: PMI / -log2 P(u,v). Bounded to [-1, 1]."""
    n, sd = f["n_articles"], f["deg_seed"]
    out = {}
    for u, c in f["cooc"].items():
        du = f["deg"].get(u, 1)
        if not (du and sd and c):
            continue
        pxy = c / float(n)
        if pxy <= 0:
            continue
        pmi = math.log2(pxy / ((du / float(n)) * (sd / float(n))))
        denom = -math.log2(pxy)
        out[u] = (pmi / denom) if denom > 0 else 0.0
    return out


def rank_pmi2(f, seed):
    """PMI weighted by evidence: PMI * log2(c). Rewards strong AND frequent."""
    n, sd = f["n_articles"], f["deg_seed"]
    out = {}
    for u, c in f["cooc"].items():
        du = f["deg"].get(u, 1)
        if not (du and sd and c):
            continue
        pmi = math.log2((c * n) / float(du * sd))
        out[u] = pmi * math.log2(1 + c)
    return out


def rank_cond(f, seed):
    """P(u|v) = c(u,v)/deg(v). Asymmetric."""
    sd = f["deg_seed"]
    out = {}
    if sd:
        for u, c in f["cooc"].items():
            out[u] = c / float(sd)
    return out


def rank_both_major(f, seed):
    """Co-occurrence counting only articles where BOTH are major topics.

    A corpus-derived 'strength' signal: both-major co-occurrence is a
    tighter relation than any-mention co-occurrence. PMI treats them
    identically, which is exactly its blindness.
    """
    n, sd = f["n_articles"], f["deg_seed"]
    out = {}
    for u, c in f["cooc"].items():
        du = f["deg"].get(u, 1)
        bm = f["both_major"].get(u, 0)
        if not (du and sd and bm):
            continue
        out[u] = math.log2((bm * n) / float(du * sd))
    return out


def rank_text(f, seed):
    """Text signal: seed name in the article title of co-occurring articles.

    PMI never reads the paper. Two candidates with identical c(u,v) are
    indistinguishable to PMI, but one may co-occur on articles that are
    literally *about* the seed (title match) while the other is a methods
    footnote. This is the challenger.
    """
    n, sd = f["n_articles"], f["deg_seed"]
    out = {}
    for u, c in f["cooc"].items():
        du = f["deg"].get(u, 1)
        th = f["title_hits"].get(u, 0)
        if not (du and sd and c):
            continue
        pmi = math.log2((c * n) / float(du * sd))
        # Title hits are rare and decisive: add a bonus proportional to
        # the share of co-occurring articles whose title names the seed.
        share = th / float(c) if c else 0.0
        out[u] = pmi * (1.0 + 4.0 * share)
    return out


def rank_degree_anti(f, seed):
    """ANTI-baseline: the broken fst#2 keep-order (rarest first).

    Expected to score badly. Included so the evaluation has a floor that
    is known-bad rather than just 'random'.
    """
    out = {}
    for u in f["cooc"]:
        out[u] = -float(f["deg"].get(u, 1))
    return out


def rank_random(f, seed):
    rng = random.Random(20260930)
    return {u: rng.random() for u in f["cooc"]}


RANKERS = [
    ("PMI", rank_pmi, "baseline"),
    ("NPMI", rank_npmi, "candidate"),
    ("PMI2", rank_pmi2, "candidate"),
    ("P(u|v)", rank_cond, "candidate"),
    ("BothMajor-PMI", rank_both_major, "candidate"),
    ("Text-PMI", rank_text, "challenger"),
    ("RarestFirst", rank_degree_anti, "anti-baseline"),
    ("Random", rank_random, "sanity"),
]


# --------------------------------------------------------------------------
# metrics
# --------------------------------------------------------------------------

def ndcg_at_k(ranked, gold, k=10):
    dcg = 0.0
    for i, u in enumerate(ranked[:k]):
        rel = gold.get(u, 0)
        if rel:
            dcg += (2 ** rel - 1) / math.log2(i + 2)
    ideal = sorted(gold.values(), reverse=True)[:k]
    idcg = sum((2 ** r - 1) / math.log2(i + 2)
               for i, r in enumerate(ideal))
    return (dcg / idcg) if idcg > 0 else 0.0


def precision_at_k(ranked, gold, k=10):
    return sum(1 for u in ranked[:k] if u in gold) / float(k)


def mrr(ranked, gold):
    for i, u in enumerate(ranked, 1):
        if u in gold:
            return 1.0 / i
    return 0.0


def mean_rel(ranked, gold, k=10):
    vals = [gold.get(u, 0) for u in ranked[:k]]
    return sum(vals) / float(len(vals)) if vals else 0.0


def bootstrap_ci(deltas, n=2000, alpha=0.05, seed=20260930):
    """Percentile bootstrap CI of the mean delta."""
    if not deltas:
        return (0.0, 0.0)
    rng = random.Random(seed)
    means = []
    n_d = len(deltas)
    for _ in range(n):
        s = [deltas[rng.randrange(n_d)] for _ in range(n_d)]
        means.append(sum(s) / n_d)
    means.sort()
    lo = means[int((alpha / 2) * n)]
    hi = means[int((1 - alpha / 2) * n)]
    return (lo, hi)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--features", required=True)
    ap.add_argument("--gold", required=True)
    ap.add_argument("--trees", required=True)
    ap.add_argument("--k", type=int, default=10)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    feats = json.load(open(args.features))
    gold_doc = json.load(open(args.gold))
    gold_all = gold_doc["gold"]
    global _trees
    _trees = json.load(open(args.trees))

    n_articles = feats["meta"]["articles"]
    major_deg = feats["major_deg"]
    results = {}

    print(f"articles={n_articles:,}  seeds with gold={len(gold_all)}  "
          f"k={args.k}\n", flush=True)

    for name, fn, kind in RANKERS:
        t0 = time.time()
        per_seed = {}
        times = []
        for seed, gold in gold_all.items():
            f = {
                "n_articles": n_articles,
                "deg_seed": major_deg.get(seed, 1),
                "deg": major_deg,
                "cooc": feats["seeds"][seed]["cooc"],
                "both_major": feats["seeds"][seed]["both_major"],
                "title_hits": feats["seeds"][seed]["title_hits"],
            }
            ts = time.time()
            scores = fn(f, seed)
            times.append(time.time() - ts)
            # fst#2 suppression FIRST: blocklist + min-cooccur. Without
            # this the evaluation ranks a raw pool full of hubs and
            # measures hub handling instead of ranking quality.
            scores = {u: sc for u, sc in scores.items()
                      if not is_blocked(u, _trees)
                      and f["cooc"].get(u, 0) >= MIN_COOCCUR}
            ranked = sorted(scores, key=lambda u: (-scores[u], u))
            per_seed[seed] = {
                "ndcg": ndcg_at_k(ranked, gold, args.k),
                "p10": precision_at_k(ranked, gold, args.k),
                "mrr": mrr(ranked, gold),
                "mean_rel": mean_rel(ranked, gold, args.k),
                "top": ranked[:args.k],
            }
        el = time.time() - t0
        results[name] = {"kind": kind, "per_seed": per_seed,
                         "score_s": el, "per_seed_ms":
                         1000.0 * (sum(times) / max(1, len(times)))}
        print(f"  {name:<16} {kind:<13} done in {el:.1f}s "
              f"({results[name]['per_seed_ms']:.2f} ms/seed)", flush=True)

    # ---- aggregate -------------------------------------------------
    def agg(name, stratum=None):
        ps = results[name]["per_seed"]
        vals = []
        for s, r in ps.items():
            if stratum == "method" and s not in METHOD_HUBS:
                continue
            if stratum == "topical" and s in METHOD_HUBS:
                continue
            vals.append(r["ndcg"])
        return vals

    summary = {}
    for name, _, kind in RANKERS:
        vals = agg(name)
        summary[name] = {
            "kind": kind,
            "ndcg_mean": statistics.fmean(vals) if vals else 0.0,
            "ndcg_p50": statistics.median(vals) if vals else 0.0,
            "n": len(vals),
            "method": statistics.fmean(agg(name, "method"))
                     if agg(name, "method") else 0.0,
            "topical": statistics.fmean(agg(name, "topical"))
                      if agg(name, "topical") else 0.0,
            "p10": statistics.fmean(
                [r["p10"] for r in results[name]["per_seed"].values()])
                   if results[name]["per_seed"] else 0.0,
            "mrr": statistics.fmean(
                [r["mrr"] for r in results[name]["per_seed"].values()])
                   if results[name]["per_seed"] else 0.0,
            "score_s": results[name]["score_s"],
            "per_seed_ms": results[name]["per_seed_ms"],
        }

    # ---- success test vs PMI ---------------------------------------
    base = summary["PMI"]["ndcg_mean"]
    tests = {}
    for name, _, kind in RANKERS:
        if name == "PMI":
            continue
        deltas = [results[name]["per_seed"][s]["ndcg"]
                  - results["PMI"]["per_seed"][s]["ndcg"]
                  for s in gold_all]
        lo, hi = bootstrap_ci(deltas)
        d_method = [results[name]["per_seed"][s]["ndcg"]
                    - results["PMI"]["per_seed"][s]["ndcg"]
                    for s in gold_all if s in METHOD_HUBS]
        d_topical = [results[name]["per_seed"][s]["ndcg"]
                     - results["PMI"]["per_seed"][s]["ndcg"]
                     for s in gold_all if s not in METHOD_HUBS]
        tests[name] = {
            "delta_mean": statistics.fmean(deltas) if deltas else 0.0,
            "ci95": [lo, hi],
            "delta_method": statistics.fmean(d_method) if d_method else 0.0,
            "delta_topical": statistics.fmean(d_topical) if d_topical else 0.0,
            "ci_excludes_0": (lo > 0) or (hi < 0),
            "beats_overall": lo > 0,
            "no_regress_topical": (statistics.fmean(d_topical)
                                   if d_topical else 0.0) >= -1e-9,
        }

    out = {"meta": feats["meta"], "k": args.k,
           "summary": summary, "tests_vs_pmi": tests,
           "per_ranker": {n: results[n]["per_seed"] for n in results}}

    with open(args.out, "w") as f:
        json.dump(out, f, indent=2)

    # ---- report ----------------------------------------------------
    print("\n## Ranking summary (nDCG@%d, Gold A = MeSH tree proximity)\n"
          % args.k)
    print("%-16s %-13s %8s %8s %8s %8s %10s %8s" % (
        "ranker", "kind", "nDCG", "method", "topical", "P@10", "ms/seed", "MRR"))
    print("-" * 96)
    for name, _, kind in RANKERS:
        s = summary[name]
        print("%-16s %-13s %8.4f %8.4f %8.4f %8.3f %10.3f %8.3f" % (
            name, kind, s["ndcg_mean"], s["method"], s["topical"],
            s["p10"], s["per_seed_ms"], s["mrr"]))

    print("\n## Success test vs PMI\n")
    print("%-16s %10s %22s %10s %10s  %s" % (
        "ranker", "d_nDCG", "bootstrap 95% CI", "method", "topical", "verdict"))
    print("-" * 100)
    for name, _, kind in RANKERS:
        if name == "PMI":
            continue
        t = tests[name]
        verdict = "BEATS" if (t["beats_overall"] and t["no_regress_topical"]) \
                  else ("no-regress-only" if t["no_regress_topical"]
                        and t["delta_mean"] > 0 else "no")
        print("%-16s %+10.4f [%+8.4f,%+8.4f] %+10.4f %+10.4f  %s" % (
            name, t["delta_mean"], t["ci95"][0], t["ci95"][1],
            t["delta_method"], t["delta_topical"], verdict))
    print("\nwrote", args.out)


if __name__ == "__main__":
    main()
