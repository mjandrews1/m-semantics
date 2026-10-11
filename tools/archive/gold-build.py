#!/usr/bin/env python3
"""fst#3 gold-standard fix (T41) — build both corrected golds.

Two defects in the original Gold A (MeSH tree proximity), both now
verified against NLM documentation:

  1. SCRs (D0000... supplementary concept records) have NO tree position.
     NLM: "SCRs are not organised in a tree hierarchy. Instead each SCR is
     linked to one or more Descriptors by the Heading Mapped To (HM) field."
     Tree-based gold therefore scored SCRs 0.0 structurally -- which is
     exactly why P(u|v) scored 0.0000 on SARS-CoV-2 / COVID-19 Vaccines.

  2. Tree proximity is BT/NT (hierarchical). The associative relation is
     SeeRelatedDescriptor (NLM "see related" / See Also / ASCII FX),
     5,934 descriptors / 9,213 links. That is the relation the product
     question actually asks about.

This script emits:
  gold-tree-rtfix.json   tree proximity, with SCRs resolved SCR -> HM -> Descriptor
  gold-rt.json           SeeRelatedDescriptor (associative) gold
  mesh-index.json        DescriptorClass + trees + names + HM map (reusable)
"""
import argparse
import gzip
import json
import os
import re
import sys
from collections import defaultdict

RE_DESC_REC = re.compile(
    r"<DescriptorRecord(?:\s[^>]*)?>(.*?)</DescriptorRecord>", re.S)
RE_SUPP_REC = re.compile(
    r"<SupplementalRecord(?:\s[^>]*)?>(.*?)</SupplementalRecord>", re.S)
# NB: SCR UIs are <SupplementalRecordUI>, NOT <SupplementalUI>. Using the
# wrong element name silently falls through to the first <DescriptorUI>
# inside HeadingMappedTo and keys the HM map on the TARGET instead of the
# SCR -- so resolution appears to work while mapping nothing.
RE_DESC_UI = re.compile(r"<DescriptorUI>([^<]+)</DescriptorUI>")
RE_SCR_UI = re.compile(r"<SupplementalRecordUI>([^<]+)</SupplementalRecordUI>")
RE_NAME = re.compile(r"<(?:Descriptor|Concept)Name>\s*<String>([^<]+)</String>")
RE_TREE = re.compile(r"<TreeNumber>([A-Z]\d+(?:\.\d+)*)</TreeNumber>")
RE_SEE_RELATED = re.compile(
    r"<SeeRelatedDescriptor>\s*<DescriptorReferredTo>\s*"
    r"<DescriptorUI>([^<]+)</DescriptorUI>", re.S)
RE_HM = re.compile(
    r"<HeadingMappedTo>\s*<DescriptorReferredTo>\s*"
    r"<DescriptorUI>([^<]+)</DescriptorUI>", re.S)
RE_SCR_CLASS = re.compile(r'SCRClass\s*=\s*"(\d)"')


def norm(ui):
    """MeSH occasionally prefixes UIs with '*' in HM contexts."""
    return ui.lstrip("*")


def build_index(desc_path, supp_path):
    """Descriptor index + SCR -> HeadingMappedTo map."""
    desc = {}
    rt_links = defaultdict(set)
    with gzip.open(desc_path, "rt", errors="replace") as f:
        for body in RE_DESC_REC.findall(f.read()):
            m = RE_DESC_UI.search(body)
            if not m:
                continue
            ui = norm(m.group(1))
            nm = RE_NAME.search(body)
            trees = RE_TREE.findall(body)
            desc[ui] = {
                "name": nm.group(1) if nm else "",
                "trees": trees,
                "dc": derive_dc(trees),
            }
            for tgt in RE_SEE_RELATED.findall(body):
                rt_links[ui].add(norm(tgt))

    scr_hm = {}
    scr_name = {}
    scr_class = {}
    n_scr = 0
    if supp_path and os.path.exists(supp_path):
        with gzip.open(supp_path, "rt", errors="replace") as f:
            for body in RE_SUPP_REC.findall(f.read()):
                m = RE_SCR_UI.search(body)
                if not m:
                    continue
                n_scr += 1
                ui = norm(m.group(1))
                nm = RE_NAME.search(body)
                if nm:
                    scr_name[ui] = nm.group(1)
                c = RE_SCR_CLASS.search(body)
                if c:
                    scr_class[ui] = int(c.group(1))
                targets = [norm(t) for t in RE_HM.findall(body)]
                if targets:
                    scr_hm[ui] = targets

    return desc, dict(rt_links), scr_hm, scr_name, scr_class, n_scr


def derive_dc(trees):
    """MeSH DescriptorClass, derived as NLM documents it.

    NLM (Record Types): Class 1 topical (tree, not V/Z); Class 2
    Publication Characteristics (V tree); Class 3 Check Tags (no tree);
    Class 4 Geographics (Z tree). The attribute is omitted from the
    distributed desc2026.xml.gz, but the definition is stated in terms of
    the tree, so it is derivable.
    """
    if not trees:
        return 3          # Check Tag
    first = trees[0]
    if first.startswith("V"):
        return 2          # Publication Characteristics
    if first.startswith("Z"):
        return 4          # Geographic
    return 1              # Topical


def parent_of(t):
    return t.rsplit(".", 1)[0] if "." in t else None


def grandparent_of(t):
    p = parent_of(t)
    return parent_of(p) if p else None


def tree_grade(seed_trees, cand_trees):
    """3 sibling / 2 parent-child / 1 cousin / 0 not near."""
    if not seed_trees or not cand_trees:
        return 0
    best = 0
    s_parents = set(filter(None, (parent_of(t) for t in seed_trees)))
    s_grands = set(filter(None, (grandparent_of(t) for t in seed_trees)))
    for st in seed_trees:
        for ut in cand_trees:
            if ut == st:
                continue
            if ut.startswith(st + ".") or st.startswith(ut + "."):
                best = max(best, 2)
                continue
            up = parent_of(ut)
            if up and up in s_parents:
                best = max(best, 3)
                continue
            ug = grandparent_of(ut)
            if ug and ug in s_grands:
                best = max(best, 1)
    return best


def resolve_to_descriptors(ui, desc, scr_hm, depth=2):
    """SCR -> HeadingMappedTo -> Descriptor, recursively bounded.

    Returns the set of Descriptor UIs this node can stand in for.
    A Descriptor resolves to itself. An SCR resolves to its HM targets
    (which may themselves be SCRs in rare cases).
    """
    if ui in desc:
        return {ui}
    out = set()
    stack = [(ui, 0)]
    seen = set()
    while stack:
        cur, d = stack.pop()
        if cur in seen or d > depth:
            continue
        seen.add(cur)
        if cur in desc:
            out.add(cur)
            continue
        for t in scr_hm.get(cur, []):
            stack.append((t, d + 1))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--desc", required=True)
    ap.add_argument("--supp", required=True)
    ap.add_argument("--features", required=True, help="rank-features.json")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    print("building MeSH index (descriptors + SCRs)...", flush=True)
    desc, rt, scr_hm, scr_name, scr_class, n_scr = build_index(
        args.desc, args.supp)
    print(f"  descriptors: {len(desc):,}   SCR->HM entries: {len(scr_hm):,} "
          f"(of {n_scr:,} SCRs)", flush=True)
    rt_total = sum(len(v) for v in rt.values())
    print(f"  SeeRelated links: {rt_total:,} over {len(rt):,} descriptors",
          flush=True)

    # How many corpus nodes are SCRs?
    F = json.load(open(args.features))
    corpus_nodes = set(F["major_deg"])
    scr_in_corpus = {u for u in corpus_nodes if u.startswith("D0000")}
    resolved = sum(1 for u in scr_in_corpus if resolve_to_descriptors(
        u, desc, scr_hm))
    print(f"\ncorpus nodes: {len(corpus_nodes):,}   SCR-shaped (D0000*): "
          f"{len(scr_in_corpus):,}   resolvable via HM: {resolved:,}",
          flush=True)

    # ---- build the two golds ---------------------------------------
    gold_tree = {}
    gold_rt = {}
    stats = {"tree": {}, "rt": {}}

    for seed, blob in F["seeds"].items():
        pool = set(blob["cooc"].keys())

        # (a) tree proximity WITH SCR resolution
        seed_desc = resolve_to_descriptors(seed, desc, scr_hm)
        if not seed_desc:
            continue
        g = {}
        for u in pool:
            u_desc = resolve_to_descriptors(u, desc, scr_hm)
            if not u_desc:
                continue
            best = 0
            for sd in seed_desc:
                for ud in u_desc:
                    best = max(best, tree_grade(
                        desc[sd]["trees"], desc[ud]["trees"]))
            if best:
                g[u] = best
        if g:
            gold_tree[seed] = g
            by = defaultdict(int)
            for v in g.values():
                by[v] += 1
            stats["tree"][seed] = {"pool": len(pool), "gold": len(g),
                                   "by_grade": {str(k): v
                                                for k, v in sorted(by.items())}}

        # (b) RT gold (SeeRelatedDescriptor), resolved through HM
        rt_targets = set()
        for sd in seed_desc:
            for t in rt.get(sd, []):
                # a target may be a descriptor or need resolution
                rt_targets |= resolve_to_descriptors(t, desc, scr_hm)
        # also: if the seed is an SCR, its HM targets' RT links
        g2 = {}
        for u in pool:
            u_desc = resolve_to_descriptors(u, desc, scr_hm)
            if not u_desc:
                continue
            if u_desc & rt_targets:
                g2[u] = 2          # RT = associative, single grade
            else:
                # reciprocal: seed in u's RT
                for ud in u_desc:
                    for t in rt.get(ud, []):
                        if t in seed_desc:
                            g2[u] = 2
                            break
        if g2:
            gold_rt[seed] = g2
            stats["rt"][seed] = {"pool": len(pool), "gold": len(g2)}

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "mesh-index.json"), "w") as f:
        json.dump({"desc": desc, "rt": {k: sorted(v) for k, v in rt.items()},
                   "scr_hm": scr_hm,
                   "scr_name": scr_name, "scr_class": scr_class}, f)
    with open(os.path.join(args.out, "gold-tree-hm.json"), "w") as f:
        json.dump({"gold": gold_tree, "stats": stats["tree"]}, f)
    with open(os.path.join(args.out, "gold-rt.json"), "w") as f:
        json.dump({"gold": gold_rt, "stats": stats["rt"]}, f)

    def summarise(label, gold, st):
        n = len(gold)
        tot = sum(len(v) for v in gold.values())
        print(f"\n### {label}")
        print(f"  seeds with gold: {n}    total gold pairs: {tot:,}")
        if st:
            gsz = sorted(s["gold"] for s in st.values())
            psz = sorted(s["pool"] for s in st.values())
            m = len(gsz)
            print(f"  gold/seed:  min={gsz[0]} p50={gsz[m//2]} max={gsz[-1]}")
            print(f"  pool/seed:  min={psz[0]} p50={psz[m//2]} max={psz[-1]}")
            cov = sorted(s["gold"] / s["pool"] if s["pool"] else 0
                         for s in st.values())
            print(f"  gold/pool:  min={cov[0]:.3f} p50={cov[m//2]:.3f} "
                  f"max={cov[-1]:.3f}")

    print()
    summarise("Gold TREE with SCR->HM resolution", gold_tree, stats["tree"])
    summarise("Gold RT (SeeRelatedDescriptor)", gold_rt, stats["rt"])
    print("\nwrote", args.out)


if __name__ == "__main__":
    main()
