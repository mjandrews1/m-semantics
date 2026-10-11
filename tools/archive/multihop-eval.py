#!/usr/bin/env python3
"""fst#4 — evaluate hub-pruned 2-hop against the exhaustive 2-hop oracle.

Success criterion (docs/multihop-design.md §8):

    succeeds  <=>  recall@10(pruned vs oracle) >= 0.80        [M1]
                   AND nDCG@10(pruned vs oracle) >= 0.80      [M2]
                   AND work <= 1e6 edge visits <= 500ms        [M3]
                   AND work scaling exponent alpha < 2         [M3]
                   AND mean-oracle-rank(discarded) >
                       mean-oracle-rank(kept)                  [M4]

Scoring for BOTH arms is the two-step random walk (design §3):

    score(w) = sum_{u in N(v) n N(w)} P(u|v) * P(w|u)

Not P(w|v) — that is 0 for every true distance-2 node.
"""
import argparse
import importlib.util
import json
import math
import os
import statistics
import sys
import time

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "hub_suppression", os.path.join(_HERE, "hub-suppression.py"))
_hs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hs)
is_blocked = _hs.is_blocked
MIN_COOCCUR = 3


def two_step_scores(seed, intermediates, hop2, deg, n_articles):
    """score(w) = sum_u P(u|seed) * P(w|u) over the allowed intermediates.

    Returns (scores, edge_visits). edge_visits counts every (u,w) pair
    examined — the work unit for M3.
    """
    sd = deg.get(seed, 1)
    scores = {}
    visits = 0
    for u in intermediates:
        c_uv = hop2.get("_c_uv", {}).get((seed, u), None)
        # c(u,seed) is the 1-hop count, passed separately by the caller.
        pu = hop2["_pu"].get(u, 0.0)
        if not pu:
            continue
        nbrs = hop2.get(u, {})
        du = deg.get(u, 1)
        if not du:
            continue
        for w, c_uw in nbrs.items():
            if w == seed:
                continue
            visits += 1
            scores[w] = scores.get(w, 0.0) + pu * (c_uw / float(du))
    return scores, visits


def ndcg_at_k(ranked, gold_scores, k):
    """gold_scores: w -> ideal score. nDCG of the ranked list vs the ideal."""
    dcg = 0.0
    for i, w in enumerate(ranked[:k]):
        g = gold_scores.get(w, 0.0)
        if g > 0:
            dcg += g / math.log2(i + 2)
    ideal = sorted(gold_scores.values(), reverse=True)[:k]
    idcg = sum(g / math.log2(i + 2) for i, g in enumerate(ideal))
    return (dcg / idcg) if idcg > 0 else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--features", required=True)
    ap.add_argument("--trees", required=True)
    ap.add_argument("--k", type=int, default=10)
    ap.add_argument("--k1", type=int, default=12,
                    help="fst#2 budget for the intermediate set")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    F = json.load(open(args.features))
    trees = json.load(open(args.trees))
    deg = F["major_deg"]
    names = F["seed_names"]
    panel_a = F["meta"]["panel_a"]
    panel_b = F["meta"]["panel_b"]
    K = args.k

    print(f"panel A seeds: {len(panel_a)}   panel B: {len(panel_b)}   "
          f"K={K}  K1={args.k1}\n")

    # ---------------- Panel A: correctness + M4 ----------------------
    rows = []
    for seed in panel_a:
        hop1 = F["hop1"][seed]
        sd = deg.get(seed, 1)

        # ---- ORACLE: every non-blocked 1-hop neighbour is an
        # intermediate. No degree filtering, no budget.
        all_inter = [u for u in hop1
                     if not is_blocked(u, trees)
                     and hop1[u] >= MIN_COOCCUR]
        hop2_ctx = {"_pu": {u: hop1[u] / float(sd) for u in all_inter}}
        for u in all_inter:
            hop2_ctx[u] = F["hop2"].get(u, {})

        t0 = time.time()
        oracle_scores, oracle_visits = two_step_scores(
            seed, all_inter, hop2_ctx, deg, len(F["hop2"]))
        oracle_wall = time.time() - t0
        oracle_ranked = sorted(oracle_scores,
                               key=lambda w: (-oracle_scores[w], w))
        oracle_top = oracle_ranked[:K]

        # ---- PRUNED: fst#2 suppression on the intermediates.
        # Same rule as the shipped algorithm: blocklist + min-cooccur +
        # K1 budget by the fst#3 keep-order.
        kept, _st = _hs.suppress(hop1, deg, sd, len(F["hop2"]), args.k1, trees)
        pruned_inter = kept
        hop2p = {"_pu": {u: hop1[u] / float(sd) for u in pruned_inter}}
        for u in pruned_inter:
            hop2p[u] = F["hop2"].get(u, {})

        t0 = time.time()
        pruned_scores, pruned_visits = two_step_scores(
            seed, pruned_inter, hop2p, deg, len(F["hop2"]))
        pruned_wall = time.time() - t0
        pruned_ranked = sorted(pruned_scores,
                               key=lambda w: (-pruned_scores[w], w))
        pruned_top = pruned_ranked[:K]

        # M1/M2: against the oracle's own ranking.
        gold_scores = {w: oracle_scores[w] for w in oracle_top}
        recall = (len(set(pruned_top) & set(oracle_top))
                  / float(len(oracle_top))) if oracle_top else 1.0
        ndcg = ndcg_at_k(pruned_ranked, gold_scores, K)

        # M4: mean oracle-rank of the paths kept vs discarded.
        # A "path" is an intermediate u. Rank intermediates by their
        # contribution to the oracle (P(u|seed) * sum_w P(w|u)).
        contrib = {}
        for u in all_inter:
            pu = hop1[u] / float(sd)
            du = deg.get(u, 1)
            nbrs = F["hop2"].get(u, {})
            contrib[u] = pu * sum(c / float(du) for c in nbrs.values())
        order = sorted(contrib, key=lambda u: -contrib[u])
        rank_of = {u: i + 1 for i, u in enumerate(order)}
        kept_ranks = [rank_of[u] for u in pruned_inter if u in rank_of]
        disc_ranks = [rank_of[u] for u in all_inter
                      if u not in set(pruned_inter) and u in rank_of]

        rows.append({
            "seed": seed, "name": names.get(seed, ""),
            "deg": sd, "hop1": len(hop1),
            "oracle_inter": len(all_inter), "pruned_inter": len(pruned_inter),
            "oracle_2hop": len(oracle_scores), "pruned_2hop": len(pruned_scores),
            "recall": recall, "ndcg": ndcg,
            "oracle_visits": oracle_visits, "pruned_visits": pruned_visits,
            "oracle_ms": 1000 * oracle_wall, "pruned_ms": 1000 * pruned_wall,
            "m4_kept_mean_rank": statistics.fmean(kept_ranks) if kept_ranks else 0,
            "m4_disc_mean_rank": statistics.fmean(disc_ranks) if disc_ranks else 0,
        })

    # ---------------- Panel B: cost + scaling ------------------------
    cost_rows = []
    for seed in panel_b:
        hop1 = F["hop1"][seed]
        sd = deg.get(seed, 1)
        all_inter = [u for u in hop1
                     if not is_blocked(u, trees) and hop1[u] >= MIN_COOCCUR]
        # Naive 2-hop visits = sum_u deg(u) over ALL intermediates.
        naive_visits = sum(len(F["hop2"].get(u, {})) for u in hop1)
        kept, _ = _hs.suppress(hop1, deg, sd, len(F["hop2"]), args.k1, trees)
        pruned_visits = sum(len(F["hop2"].get(u, {})) for u in kept)
        cost_rows.append({
            "seed": seed, "name": names.get(seed, ""), "deg": sd,
            "hop1": len(hop1), "naive_visits": naive_visits,
            "pruned_visits": pruned_visits,
            "ratio": (naive_visits / pruned_visits) if pruned_visits else 0,
        })

    # Scaling exponent: fit log(work) = alpha*log(deg) + c over panel A+B.
    xs, ys = [], []
    for r in rows + cost_rows:
        if r["deg"] > 0 and r.get("naive_visits", r.get("oracle_visits", 0)) > 0:
            w = r.get("naive_visits") or r.get("oracle_visits")
            xs.append(math.log(r["deg"]))
            ys.append(math.log(w))
    alpha_naive = 0.0
    if len(xs) >= 2:
        mx, my = statistics.fmean(xs), statistics.fmean(ys)
        num = sum((a - mx) * (b - my) for a, b in zip(xs, ys))
        den = sum((a - mx) ** 2 for a in xs)
        alpha_naive = num / den if den else 0.0

    xs2, ys2 = [], []
    for r in rows + cost_rows:
        w = r.get("pruned_visits", 0)
        if r["deg"] > 0 and w > 0:
            xs2.append(math.log(r["deg"]))
            ys2.append(math.log(w))
    alpha_pruned = 0.0
    if len(xs2) >= 2:
        mx, my = statistics.fmean(xs2), statistics.fmean(ys2)
        num = sum((a - mx) * (b - my) for a, b in zip(xs2, ys2))
        den = sum((a - mx) ** 2 for a in xs2)
        alpha_pruned = num / den if den else 0.0

    # ---------------- verdict ---------------------------------------
    mean_recall = statistics.fmean([r["recall"] for r in rows]) if rows else 0
    mean_ndcg = statistics.fmean([r["ndcg"] for r in rows]) if rows else 0
    max_pruned_visits = max([r["pruned_visits"] for r in rows] +
                            [r["pruned_visits"] for r in cost_rows] or [0])
    max_pruned_ms = max([r["pruned_ms"] for r in rows] or [0])
    m4_kept = statistics.fmean([r["m4_kept_mean_rank"] for r in rows]) if rows else 0
    m4_disc = statistics.fmean([r["m4_disc_mean_rank"] for r in rows]) if rows else 0

    checks = {
        "M1_recall_ge_0.80": mean_recall >= 0.80,
        "M2_ndcg_ge_0.80": mean_ndcg >= 0.80,
        "M3_work_le_1e6": max_pruned_visits <= 1_000_000,
        "M3_time_le_500ms": max_pruned_ms <= 500,
        "M3_alpha_lt_2": alpha_pruned < 2.0,
        "M4_discarded_rank_worse": m4_disc > m4_kept,
    }

    out = {
        "meta": {"k": K, "k1": args.k1,
                 "articles": F["meta"]["articles"]},
        "panel_a": rows, "panel_b": cost_rows,
        "scaling": {"alpha_naive": alpha_naive, "alpha_pruned": alpha_pruned},
        "summary": {
            "mean_recall": mean_recall, "mean_ndcg": mean_ndcg,
            "max_pruned_visits": max_pruned_visits,
            "max_pruned_ms": max_pruned_ms,
            "m4_kept_mean_rank": m4_kept, "m4_disc_mean_rank": m4_disc,
        },
        "checks": checks,
    }
    with open(args.out, "w") as f:
        json.dump(out, f, indent=2)

    # ---------------- report ----------------------------------------
    print("## Panel A — correctness (exhaustive 2-hop oracle)\n")
    print("%-12s %-28s %6s %5s %7s %7s %8s %8s %10s %10s" % (
        "seed", "name", "deg", "hop1", "inter", "2-hop", "recall", "nDCG",
        "visits", "ms"))
    print("-" * 118)
    for r in rows:
        print("%-12s %-28s %6d %5d %7d %7d %8.3f %8.3f %10d %10.1f" % (
            r["seed"], (r["name"] or "")[:28], r["deg"], r["hop1"],
            r["oracle_inter"], r["oracle_2hop"], r["recall"], r["ndcg"],
            r["pruned_visits"], r["pruned_ms"]))
    print("\n  mean recall@%d = %.4f   mean nDCG@%d = %.4f" % (
        K, mean_recall, K, mean_ndcg))
    print("  M4: mean oracle-rank  kept=%.1f  discarded=%.1f  "
          "(higher = worse)" % (m4_kept, m4_disc))

    print("\n## Panel B — cost (largest hubs)\n")
    print("%-12s %-28s %8s %10s %12s %12s %8s" % (
        "seed", "name", "deg", "hop1", "naive", "pruned", "ratio"))
    print("-" * 92)
    for r in cost_rows:
        print("%-12s %-28s %8d %10d %12d %12d %7.1fx" % (
            r["seed"], (r["name"] or "")[:28], r["deg"], r["hop1"],
            r["naive_visits"], r["pruned_visits"], r["ratio"]))

    print("\n## Scaling  (fit log(work) = alpha * log(deg))\n")
    print("  naive   alpha = %.3f" % alpha_naive)
    print("  pruned  alpha = %.3f   (need < 2)" % alpha_pruned)

    print("\n## Verdict\n")
    for k, v in checks.items():
        print("  %-28s %s" % (k, "PASS" if v else "FAIL"))
    print("\n  overall: %s" % ("PASS" if all(checks.values()) else "FAIL"))
    print("\nwrote", args.out)


if __name__ == "__main__":
    main()
