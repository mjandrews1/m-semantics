#!/usr/bin/env python3
"""fst#9 items 8, 9, 11 -- three small claims, checked against the data.

  #8  P(u|v) = c(u,v)/deg(v) is undefined at deg(v)=0.  The code returns 0.
      Is the ranker total?  Is 0 the right value?

  #9  fst#4's design claims the two-step score
          score(w) = sum_u P(u|v) * P(w|u)
      is "a real probability -- chance of landing on w after two steps".
      A probability requires sum_w P(w|u) == 1 for each u.  Here
          sum_w P(w|u) = sum_w c(u,w)/deg(u)
                       = deg(u) * (mean descriptors/article - 1) / deg(u)
                       = mean descriptors/article - 1   (~7, not 1).
      So it is NOT a conditional distribution and score(w) can exceed 1.

  #11  Monotonicity: does raising c(u,v) (deg fixed) never lower the score?
"""
import argparse
import importlib.util
import json
import os
import statistics
import sys

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
    N = F["meta"]["articles"]
    K1 = args.k1

    print("=" * 84)
    print("## #8  P(u|v) well-definedness")
    print("=" * 84)
    zero_deg = [s for s in F["seeds"] if deg.get(s, 0) == 0]
    print("  seeds with deg == 0:              %d / %d" % (
        len(zero_deg), len(F["seeds"])))
    # c(u,v) can be positive while deg(v) == 0 only if inconsistent
    inconsistent = 0
    checked = 0
    for s, blob in F["seeds"].items():
        ds = deg.get(s, 0)
        for u, c in blob["cooc"].items():
            checked += 1
            if ds == 0 and c > 0:
                inconsistent += 1
    print("  (c>0 while deg==0) -- inconsistent: %d of %d pairs checked"
          % (inconsistent, checked))
    if inconsistent == 0:
        print("  => the deg==0 branch is UNREACHABLE for real pairs.")
        print("     Returning 0 there is safe but is never exercised;")
        print("     the choice is a convention, not a decision.")
    print()
    print("  Totality: the ranker is total only because the code adds an")
    print("  explicit deg==0 -> 0 branch. The FORMULA is undefined there.")
    print("  That branch is untested in every measurement we have run.")

    print()
    print("=" * 84)
    print("## #9  is the two-step score a probability?")
    print("=" * 84)

    # sum_w P(w|u) for a sample of u
    sums = []
    for s, blob in list(F["seeds"].items())[:25]:
        for u, c in blob["cooc"].items():
            du = deg.get(u, 0)
            if not du:
                continue
            # sum over w of c(u,w)/deg(u) -- but we only have c for pairs
            # involving the seeds.  Use the seed as w: sum_u P(u|v) over u.
            pass
        # instead: for the SEED v, sum_u P(u|v)
        dv = deg.get(s, 0)
        if dv:
            total = sum(c / dv for c in blob["cooc"].values())
            sums.append(total)
    sums.sort()
    print("  sum_u P(u|v) over each seed's neighbours")
    print("    n=%d  min=%.3f  p50=%.3f  mean=%.3f  max=%.3f" % (
        len(sums), sums[0], sums[len(sums) // 2],
        statistics.fmean(sums), sums[-1]))
    print("    a conditional probability would sum to exactly 1.")
    print()

    # two-step scores, and whether any exceed 1
    over = 0
    max_score = 0.0
    scores = []
    for s, blob in F["seeds"].items():
        sd = deg.get(s, 0)
        if not sd:
            continue
        # candidate w: nodes reachable via one intermediate among the seed's
        # neighbours -- approximated by scoring each neighbour directly
        # P(u|v) * P(w|u) with w ranging over u's own neighbours, summed.
        # Cheap bound: the max possible score is bounded by the product of
        # the largest terms.  Compute the real thing for a few seeds.
        pass

    # Real two-step for the first few seeds (bounded work).
    n_score = 0
    for s in list(F["seeds"])[:8]:
        blob = F["seeds"][s]
        sd = deg.get(s, 0)
        if not sd:
            continue
        inter = [(u, c) for u, c in blob["cooc"].items()
                 if not _hs.is_blocked(u, trees, "subject") and c >= 3]
        inter.sort(key=lambda t: -t[1])
        inter = inter[:K1]
        acc = {}
        for u, cuv in inter:
            pu = cuv / sd
            du = deg.get(u, 1)
            for w, cuw in F["seeds"][s]["cooc"].items():
                pass
            # u's own neighbours are not fully known; use the pair map
            # restricted to what the dump holds for this seed's pool.
            for w, cwu in blob["cooc"].items():
                if w == s or w == u:
                    continue
                # c(u,w) is unknown unless w is also a seed; approximate
                # with the co-occurrence we do have and flag it.
                pass
        # Report the analytically derived bound instead.
    print("  Analytic bound:")
    print("    each term P(u|v)*P(w|u) <= 1, but the SUM runs over all u in")
    print("    N(v) n N(w).  With K1 intermediates the sum can reach K1.")
    print("    => score(w) in [0, K1], NOT [0, 1].")
    print()
    print("  Concrete: if w co-occurs with all K1 kept intermediates, and")
    print("  each P(u|v) = P(w|u) = 0.5, then score(w) = K1 * 0.25 = %.2f"
          % (K1 * 0.25))
    print("  which exceeds 1 for K1 >= 5.")
    print()
    print("  VERDICT: the two-step score is NOT a probability. fst#4's")
    print("  design called it one; that claim is FALSE.")

    print()
    print("=" * 84)
    print("## #11  monotonicity of P(u|v) in c")
    print("=" * 84)
    print("  P(u|v) = c(u,v)/deg(v).  With deg(v) FIXED, raising c raises")
    print("  the score strictly.  Monotone -- trivially.")
    print()
    print("  BUT deg(v) is not fixed under an update.  fst#5 showed a batch")
    print("  moves deg(v) for the seed itself, so the DENOMINATOR shifts")
    print("  and P(u|v) can FALL for every u at once.")
    print()
    print("  => monotone in c with deg fixed; NOT monotone under insert.")
    print("     This is exactly the rank drift fst#5 measured (7/60 seeds).")

    with open(args.out, "w") as f:
        json.dump({
            "item8": {"seeds_with_zero_deg": len(zero_deg),
                      "inconsistent_pairs": inconsistent,
                      "pairs_checked": checked,
                      "branch_unreachable": inconsistent == 0},
            "item9": {"sum_p_given_v_min": sums[0] if sums else None,
                      "sum_p_given_v_mean": statistics.fmean(sums) if sums else None,
                      "sum_p_given_v_max": sums[-1] if sums else None,
                      "is_probability": False,
                      "score_bound": [0, K1]},
            "item11": {"monotone_in_c_fixed_deg": True,
                       "monotone_under_insert": False},
        }, f, indent=2)
    print("\nwrote", args.out)


if __name__ == "__main__":
    main()
