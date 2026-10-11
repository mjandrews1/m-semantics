#!/usr/bin/env python3
"""fst#4 — M4 reformulated at the answer level.

The original M4 ranked intermediates (paths) and asked whether discarded
paths were low-value. It FAILED (kept rank 6.5 vs discarded 6.1) while
recall was 0.95 — so the wrong object was being measured.

The real question: of the oracle's full 2-hop candidate set, where do the
nodes pruning LOSES rank? If lost nodes rank low, pruning discards
low-value *answers*, which is what justifies it.

Also measures the proposed mechanism: graph redundancy. Many intermediates
reach the same candidate, so discarding intermediates does not discard
candidates.
"""
import argparse
import importlib.util
import json
import math
import os
import statistics
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "hub_suppression", os.path.join(_HERE, "hub-suppression.py"))
_hs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hs)
is_blocked = _hs.is_blocked
MIN_COOCCUR = 3


def two_step(seed, intermediates, hop2, deg):
    sd = deg.get(seed, 1)
    scores, paths = {}, {}
    for u in intermediates:
        hop1 = hop2["_hop1"]
        pu = hop1.get(u, 0) / float(sd)
        if not pu:
            continue
        nbrs = hop2.get(u, {})
        du = deg.get(u, 1)
        if not du:
            continue
        for w, c_uw in nbrs.items():
            if w == seed:
                continue
            scores[w] = scores.get(w, 0.0) + pu * (c_uw / float(du))
            paths.setdefault(w, []).append(u)
    return scores, paths


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

    rows = []
    for seed in F["meta"]["panel_a"]:
        hop1 = F["hop1"][seed]
        sd = deg.get(seed, 1)
        all_inter = [u for u in hop1
                     if not is_blocked(u, trees) and hop1[u] >= MIN_COOCCUR]
        kept, _ = _hs.suppress(hop1, deg, sd, len(F["hop2"]), args.k1, trees)

        ctx = {"_hop1": hop1}
        for u in all_inter:
            ctx[u] = F["hop2"].get(u, {})
        oracle_scores, oracle_paths = two_step(seed, all_inter, ctx, deg)

        ctx2 = {"_hop1": hop1}
        for u in kept:
            ctx2[u] = F["hop2"].get(u, {})
        pruned_scores, pruned_paths = two_step(seed, kept, ctx2, deg)

        # Rank every oracle candidate.
        order = sorted(oracle_scores, key=lambda w: (-oracle_scores[w], w))
        rank_of = {w: i + 1 for i, w in enumerate(order)}
        lost = [w for w in oracle_scores if w not in pruned_scores]
        kept_w = [w for w in oracle_scores if w in pruned_scores]

        # M4-answer: mean oracle-rank of LOST candidates vs KEPT candidates.
        lost_ranks = [rank_of[w] for w in lost]
        kept_ranks = [rank_of[w] for w in kept_w]

        # Redundancy: how many distinct intermediates reach each candidate.
        red_all = statistics.fmean(
            [len(set(v)) for v in oracle_paths.values()]) if oracle_paths else 0
        red_lost = statistics.fmean(
            [len(set(oracle_paths[w])) for w in lost]) if lost else 0

        rows.append({
            "seed": seed, "name": F["seed_names"].get(seed, ""),
            "candidates": len(oracle_scores),
            "lost": len(lost),
            "lost_share": len(lost) / float(len(oracle_scores)) if oracle_scores else 0,
            "m4_answer_kept_rank": statistics.fmean(kept_ranks) if kept_ranks else 0,
            "m4_answer_lost_rank": statistics.fmean(lost_ranks) if lost_ranks else 0,
            "m4_answer_max_lost_rank": max(lost_ranks) if lost_ranks else 0,
            "redundancy_all": red_all,
            "redundancy_lost": red_lost,
        })

    m4_kept = statistics.fmean([r["m4_answer_kept_rank"] for r in rows])
    m4_lost = statistics.fmean([r["m4_answer_lost_rank"] for r in rows])
    red_all = statistics.fmean([r["redundancy_all"] for r in rows])
    red_lost = statistics.fmean([r["redundancy_lost"] for r in rows])
    mean_lost_share = statistics.fmean([r["lost_share"] for r in rows])

    out = {"panel_a": rows,
           "summary": {"m4_answer_kept_rank": m4_kept,
                       "m4_answer_lost_rank": m4_lost,
                       "m4_pass": m4_lost > m4_kept,
                       "redundancy_all": red_all,
                       "redundancy_lost": red_lost,
                       "mean_lost_share": mean_lost_share}}
    with open(args.out, "w") as f:
        json.dump(out, f, indent=2)

    print("## M4 reformulated at the ANSWER level\n")
    print("%-12s %-28s %6s %6s %8s %10s %10s %8s %8s" % (
        "seed", "name", "cands", "lost", "lost%", "kept-rank", "lost-rank",
        "red-all", "red-lost"))
    print("-" * 106)
    for r in rows:
        print("%-12s %-28s %6d %6d %7.1f%% %10.1f %10.1f %8.2f %8.2f" % (
            r["seed"], (r["name"] or "")[:28], r["candidates"], r["lost"],
            100 * r["lost_share"], r["m4_answer_kept_rank"],
            r["m4_answer_lost_rank"], r["redundancy_all"],
            r["redundancy_lost"]))
    print("\n  mean kept-rank = %.1f   mean lost-rank = %.1f   (higher = worse)"
          % (m4_kept, m4_lost))
    print("  M4-answer: %s" % ("PASS (lost answers rank worse)"
                               if m4_lost > m4_kept else "FAIL"))
    print("\n## Proposed mechanism: graph redundancy\n")
    print("  mean intermediates reaching a candidate  all  = %.2f" % red_all)
    print("  mean intermediates reaching a LOST cand.      = %.2f" % red_lost)
    print("  mean share of candidates lost            = %.1f%%"
          % (100 * mean_lost_share))
    print("\n  -> candidates are reached by %.1f intermediates on average, "
          "so" % red_all)
    print("     discarding %d of %d intermediates loses only %.1f%% of "
          "candidates."
          % (args.k1, len(rows and [1]), 100 * mean_lost_share))
    print("\nwrote", args.out)


if __name__ == "__main__":
    main()
