#!/usr/bin/env python3
"""fst#9 item 7 -- is the facet rule sound, and is the judgement blocklist?

Two different questions:

  FACET blocks (DC != 1 in a subject walk)
    NLM defines DescriptorClass=1 as "topical Descriptor, used to identify
    the SUBJECT of an indexed document".  So DC != 1 is *defined* as
    not-subject.  Blocking it in a subject walk is sound BY CONSTRUCTION
    of that definition -- imported from NLM, not proved by us.

  JUDGEMENT blocks (DC == 1 nodes: Humans, Animals, M01.060 age groups,
    E05.318.372.500 study design, and the mixed-method UIs)
    These ARE topical by NLM's definition.  Suppressing them is a stated
    judgement, and it can remove a correct answer.

Decisive test: does the blocklist remove members of a gold standard?  If a
gold member is blocked, the filter has removed a correct answer and the
judgement blocklist is unsound for that gold.

Also reports: the subset property (suppression only removes), which is
trivially true and worth stating.
"""
import argparse
import importlib.util
import json
import os
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
    ap.add_argument("--gold", action="append", required=True,
                    help="gold json (repeatable)")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    trees = json.load(open(args.trees))
    F = json.load(open(args.features))

    def facet_blocked(ui):
        """DC != 1 for a subject walk -- the FACET half only."""
        t = trees.get(ui, {}).get("trees", [])
        return _hs.derive_dc(t) != 1

    def judgement_blocked(ui):
        """The DC=1 judgement half only (Humans, M01.060, ...)."""
        if facet_blocked(ui):
            return False
        # replicate the judgement branch of is_blocked, minus the facet rule
        if ui in _hs.JUDGEMENT_BLOCK_UIS:
            return True
        for t in trees.get(ui, {}).get("trees", []):
            for p in _hs.JUDGEMENT_BLOCK_TREES:
                if t == p or t.startswith(p + "."):
                    return True
        return False

    print("=" * 92)
    print("## Does the blocklist remove gold members?")
    print("=" * 92)

    totals = defaultdict(int)
    per_gold = {}
    for gpath in args.gold:
        gdoc = json.load(open(gpath))
        gold = gdoc["gold"]
        name = os.path.basename(gpath)
        facet_hits, judge_hits, kept = [], [], 0
        members = 0
        for s, g in gold.items():
            for u in g:
                members += 1
                if facet_blocked(u):
                    facet_hits.append((s, u))
                elif judgement_blocked(u):
                    judge_hits.append((s, u))
                else:
                    kept += 1
        per_gold[name] = {"members": members,
                          "blocked_by_facet": len(facet_hits),
                          "blocked_by_judgement": len(judge_hits),
                          "kept": kept,
                          "facet_examples": facet_hits[:12],
                          "judge_examples": judge_hits[:12]}
        totals["members"] += members
        totals["facet"] += len(facet_hits)
        totals["judge"] += len(judge_hits)
        totals["kept"] += kept

    for name, d in per_gold.items():
        print("\n### %s" % name)
        print("  gold members:            %d" % d["members"])
        print("  removed by FACET rule:   %d" % d["blocked_by_facet"])
        print("  removed by JUDGEMENT:    %d" % d["blocked_by_judgement"])
        print("  retained:                %d" % d["kept"])
        if d["facet_examples"]:
            print("  facet-removed examples:")
            for s, u in d["facet_examples"][:8]:
                nm = trees.get(u, {}).get("name", "?")
                print("    seed=%-11s u=%-12s %-32s DC=%d" % (
                    s, u, nm[:32], _hs.derive_dc(trees.get(u, {}).get("trees", []))))
        if d["judge_examples"]:
            print("  judgement-removed examples:")
            for s, u in d["judge_examples"][:8]:
                nm = trees.get(u, {}).get("name", "?")
                print("    seed=%-11s u=%-12s %-32s DC=1 (topical!)" % (
                    s, u, nm[:32]))

    print()
    print("=" * 92)
    print("## Verdict")
    print("=" * 92)
    print("  total gold members:          %d" % totals["members"])
    print("  removed by FACET (DC!=1):    %d" % totals["facet"])
    print("  removed by JUDGEMENT (DC=1): %d" % totals["judge"])
    print()
    if totals["facet"] == 0:
        print("  FACET rule:   SOUND on this gold -- it never removes a gold")
        print("                member. Expected: DC!=1 is *defined* as")
        print("                not-subject by NLM, so this is true by")
        print("                construction of the facet definition.")
    else:
        print("  FACET rule:   UNSOUND -- it removed %d gold members." % totals["facet"])
        print("                Either the gold is not subject-only, or the")
        print("                DescriptorClass derivation is wrong.")
    print()
    if totals["judge"] == 0:
        print("  JUDGEMENT:    no gold members removed on this gold. Does NOT")
        print("                establish soundness -- the judgement blocklist is")
        print("                a stated opinion (Adult/Aged are topical by NLM)")
        print("                and can remove correct answers in principle.")
    else:
        print("  JUDGEMENT:    UNSOUND, demonstrated. It removed %d gold members" % totals["judge"])
        print("                that NLM classifies as TOPICAL. These are correct")
        print("                answers the rule discards.")

    # ---- the subset property ---------------------------------------
    print()
    print("=" * 92)
    print("## Subset property (trivially true)")
    print("=" * 92)
    n = 0
    for seed, blob in F["seeds"].items():
        raw = set(blob["cooc"].keys())
        filt = {u for u in raw if not _hs.is_blocked(u, trees, "subject")}
        assert filt <= raw
        n += 1
    print("  for all %d seeds: suppressed set is a SUBSET of the raw set." % n)
    print("  A filter can only ever remove. Soundness is not this -- it is")
    print("  whether it removes anything it should not.")

    with open(args.out, "w") as f:
        json.dump({"totals": dict(totals), "per_gold": {
            k: {kk: vv for kk, vv in v.items()
                if kk not in ("facet_examples", "judge_examples")}
            for k, v in per_gold.items()},
            "facet_unsound": totals["facet"] > 0,
            "judgement_unsound": totals["judge"] > 0,
        }, f, indent=2)
    print("\nwrote", args.out)


if __name__ == "__main__":
    main()
