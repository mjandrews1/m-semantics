#!/usr/bin/env python3
"""fst#8 — the place-facet walk.

Semantics (design):
    Given a place p, return the things that relate to it across domains.

    Two result kinds:
      A. RELATED PLACES   (DC=4 neighbours)  -- evaluated against RT gold
      B. SUBJECTS OF p    (DC=1 hanging off p) -- the cross-domain answer

The walk is the INVERSE of the subject walk. In a subject walk, place is a
non-discriminating bridge. In a place walk, place is the PIVOT and subject
headings are what hang off it.

Evaluation discipline (same as fst#3): gold must be external to
co-occurrence. For (A) that is SeeRelatedDescriptor among Z* nodes. For
(B) there is no such gold in MeSH -- see the honesty note in the report.

No suppression filter is applied to the ANSWERS here: a place walk is
*supposed* to return other facets. Suppression governs traversal, and in
this walk the traversal is place->subject, i.e. leaving the facet.
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
spec = importlib.util.spec_from_file_location(
    "hs", os.path.join(HERE, "hub-suppression.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--features", required=True)
    ap.add_argument("--trees", required=True)
    ap.add_argument("--mesh-index", required=True,
                    help="gold-build.py output (rt links)")
    ap.add_argument("--k", type=int, default=10)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    F = json.load(open(args.features))
    trees = json.load(open(args.trees))
    ni = json.load(open(args.mesh_index))
    rt = ni["rt"]
    deg = F["major_deg"]
    names = F["seed_names"]
    # names for nodes that are not seeds
    for ui, v in trees.items():
        if isinstance(v, dict) and v.get("name"):
            names.setdefault(ui, v["name"])
    N = F["meta"]["articles"]
    K = args.k

    # ---- find place seeds (DC=4) in the feature dump ---------------
    place_seeds = []
    for s, blob in F["seeds"].items():
        if hs.derive_dc(trees.get(s, {}).get("trees", [])) == 4:
            place_seeds.append(s)
    print(f"place seeds (DC=4) in feature dump: {len(place_seeds)}")
    if not place_seeds:
        print("\n  NOTE: the fst#3 feature dump was built from the 60 seeds "
              "chosen for subject ranking, and none of them are DC=4.\n"
              "  Building the place walk requires place seeds. Falling back "
              "to the Z* nodes present in the general corpus.")
        # Use every DC=4 node that appears as a co-occurring candidate.
        cand = set()
        for blob in F["seeds"].values():
            cand.update(blob["cooc"].keys())
        place_seeds = [u for u in cand
                       if hs.derive_dc(trees.get(u, {}).get("trees", [])) == 4]
        place_seeds = sorted(place_seeds, key=lambda u: -deg.get(u, 0))[:20]
        print(f"  picked top-{len(place_seeds)} Z* nodes by degree")

    # ---- the walk -------------------------------------------------
    results = []
    for p in place_seeds:
        cooc = {}
        for blob in F["seeds"].values():
            if p in blob["cooc"]:
                # this seed co-occurs with p; but we want p's own
                # neighbourhood, which the dump only has if p was a seed.
                pass
        # p's own neighbourhood:
        own = F["seeds"].get(p, {}).get("cooc", {})
        if not own:
            # recover from reverse co-occurrence over the dumped seeds
            for s, blob in F["seeds"].items():
                if p in blob["cooc"]:
                    own[s] = blob["cooc"][p]
        if not own:
            continue

        # (A) related places -- DC=4 among the neighbourhood
        # (B) subjects -- DC=1 among the neighbourhood
        places, subjects = [], []
        for u, c in own.items():
            dc = hs.derive_dc(trees.get(u, {}).get("trees", []))
            du = deg.get(u, 1)
            sd = deg.get(p, 1)
            if not (du and sd and c):
                continue
            score = math.log2((c * N) / float(du * sd))   # PMI
            if dc == 4:
                places.append((u, c, score))
            elif dc == 1:
                subjects.append((u, c, score))

        places.sort(key=lambda x: -x[2])
        subjects.sort(key=lambda x: -x[2])

        # RT gold for (A)
        rt_targets = set(rt.get(p, []))
        for u in list(rt_targets):
            rt_targets |= set(rt.get(u, []))
        gold_places = {u for u, _, _ in places if u in rt_targets}

        results.append({
            "place": p, "name": names.get(p, "?"),
            "deg": deg.get(p, 0),
            "n_places": len(places), "n_subjects": len(subjects),
            "top_places": places[:K],
            "top_subjects": subjects[:K],
            "rt_gold_in_pool": len(gold_places),
            "rt_hits_at_k": sum(1 for u, _, _ in places[:K] if u in rt_targets),
        })

    if not results:
        print("no place nodes had neighbourhood data; nothing to report")
        sys.exit(0)

    # ---- report ---------------------------------------------------
    print("\n## Place-facet walk\n")
    print("%-12s %-26s %7s %7s %8s %8s %8s" % (
        "place", "name", "deg", "nbrs", "places", "subjects", "RT@k"))
    print("-" * 88)
    for r in results:
        print("%-12s %-26s %7d %7d %8d %8d %8d" % (
            r["place"], (r["name"] or "")[:26], r["deg"],
            r["n_places"] + r["n_subjects"],
            r["n_places"], r["n_subjects"], r["rt_hits_at_k"]))

    print("\n### A. Related places (DC=4) -- evaluated against SeeRelated\n")
    for r in results[:6]:
        print(f"{r['name']} ({r['place']}), deg {r['deg']}, "
              f"RT gold in pool: {r['rt_gold_in_pool']}, "
              f"hits@{K}: {r['rt_hits_at_k']}")
        for u, c, sc in r["top_places"][:6]:
            mark = " RT" if u in set(rt.get(r["place"], [])) else "   "
            print(f"{mark}   {u:12s} {names.get(u,'?')[:38]:38s} "
                  f"c={c:<5d} pmi={sc:.2f}")
        print()

    print(f"### B. Subjects hanging off the place (DC=1) -- the "
          f"cross-domain answer\n")
    for r in results[:6]:
        print(f"{r['name']} ({r['place']}) -> subjects:")
        for u, c, sc in r["top_subjects"][:8]:
            print(f"      {u:12s} {names.get(u,'?')[:38]:38s} "
                  f"c={c:<5d} pmi={sc:.2f}")
        print()

    tot_rt = sum(r["rt_hits_at_k"] for r in results)
    tot_gold = sum(r["rt_gold_in_pool"] for r in results)
    print(f"## Verdict (A only)\n")
    print(f"  place nodes walked:      {len(results)}")
    print(f"  RT gold members in pool: {tot_gold}")
    print(f"  RT gold in top-{K}:       {tot_rt}")
    if tot_gold:
        print(f"  recall@{K} vs SeeRelated: {tot_rt/tot_gold:.3f}")
    else:
        print("  recall@K: n/a -- no RT gold fell in any place's pool")
    print(f"""
## Honesty note on (B)

There is NO gold external to co-occurrence for 'what subjects relate to
this place'. MeSH ships:
  - SeeRelatedDescriptor (RT)   -- descriptor<->descriptor, not facet-crossing
  - tree proximity              -- taxonomic, and place/subject sit in
                                    different top-level sections (Z vs A-L)

Neither judges whether 'asthma' is a correct subject for 'California'.
Doing so needs sources we have not loaded -- environmental, epidemiological,
socioeconomic series -- which is exactly the cross-domain join this walk
exists to serve.

So (B) is reported as a DEMONSTRATION, not as a scored result. That is the
honest status, and it is the gap fst#8's evaluation criteria require be
stated rather than papered over.
""")

    with open(args.out, "w") as f:
        json.dump({"results": results,
                   "k": K,
                   "rt_recall_at_k": (tot_rt / tot_gold) if tot_gold else None},
                  f, indent=2)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
