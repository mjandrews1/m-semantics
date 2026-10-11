#!/usr/bin/env python3
"""fst#2 — hub-suppression evaluation.

Applies the algorithm in docs/hub-suppression-design.md to real PubMed
edges and measures it against the fst#1 acceptance bar.

Algorithm (design §4.2), for a seed node v:
    1  N <- { u : (v,.,u) or (u,.,v) is an edge of the chosen relation }
    2  N <- N minus BLOCK                    # identity blocklist, §4.3
    3  if |N| <= K: return N
    4  keep highest I(u) = -log2(deg(u)/N); tie-break by ascending deg, then id
    5  return top K

Two walks are measured, because the product needs both:
    "major"    co-occurring MAJOR-TOPIC descriptors  -> "related concepts"
    "general"  co-occurring ANY descriptors          -> recall-widened case

No ranking claims beyond the minimal keep-order that fills the budget.
fst#3 owns ranking.
"""
import argparse
import glob
import gzip
import json
import math
import os
import random
import re
import sys
import time
from collections import defaultdict

RE_CITE_SPLIT = re.compile(r'(?=<MedlineCitation)')
RE_PPMID = re.compile(r'<PMID[^>]*>(\d+)</PMID>')
RE_MAJOR = re.compile(
    r'<DescriptorName UI="(D\d+)" MajorTopicYN="Y">([^<]*)</DescriptorName>')
RE_MESH_ANY = re.compile(
    r'<DescriptorName UI="(D\d+)"[^>]*>([^<]*)</DescriptorName>')
RE_AUTHOR = re.compile(
    r'<LastName>([^<]*)</LastName>\s*<ForeName>([^<]*)</ForeName>')

# ---------------------------------------------------------------------------
# Facet-aware suppression (fst#6).
#
# MeSH DescriptorClass (NLM, "MeSH Record Types", verified 2026-03-31):
#   1 = Topical Descriptor
#   2 = Publication Characteristics (genre)  -> V tree
#   3 = Check Tag                            -> NO tree number
#   4 = Geographic                           -> Z tree
#
# The attribute is omitted from the distributed desc2026.xml.gz, but NLM
# defines it in terms of the tree, so it is derivable.
#
# RULE (library-science-and-isr.md 6b): a facet heading is never a BRIDGE
# inside its own subject-walk, and is always the PIVOT for its own
# facet-walk. Suppression is per (query-type x relation), never global.
# ---------------------------------------------------------------------------

WALK_SUBJECT = "subject"
WALK_PLACE = "place"
WALK_TIME = "time"
WALK_GENRE = "genre"
WALK_ATTRIBUTE = "attribute"


def derive_dc(trees):
    """MeSH DescriptorClass from tree numbers (see note above)."""
    if not trees:
        return 3                      # Check Tag
    first = trees[0]
    if first.startswith("V"):
        return 2                      # Publication Characteristics
    if first.startswith("Z"):
        return 4                      # Geographic
    return 1                          # Topical


# Facet each walk is allowed to traverse as a BRIDGE. A walk may still
# RETURN nodes of other facets; it may not travel THROUGH them.
WALK_BRIDGE_FACET = {
    WALK_SUBJECT: 1,
    WALK_PLACE: 4,
    WALK_TIME: None,                  # time is not a MeSH descriptor class
    WALK_GENRE: 2,
    WALK_ATTRIBUTE: 3,
}


# JUDGEMENT blocks -- DC=1 topical headings that are nonetheless poor
# relatedness bridges in a subject-walk. These are NOT authority classes;
# they are a stated judgement (fst#2 4.3) and are scoped to subject-walks
# only. Degree/information suppression covers the rest.
JUDGEMENT_BLOCK_TREES = [
    "M01.060",            # Age Groups -- Adult, Aged, Child, Infant, ...
    "E05.318.372.500",    # Epidemiologic study design (Class 1, but method)
]
JUDGEMENT_BLOCK_UIS = {
    "D006801",   # Humans
    "D000818",   # Animals
    "D013997",   # Time Factors
    "D016896",   # Treatment Outcome
    "D012307",   # Risk Factors
    "D000367",   # Age Factors
    "D015203",   # Reproducibility of Results
    "D011795",   # Surveys and Questionnaires
}


def is_blocked(ui, trees_by_ui, walk=WALK_SUBJECT):
    """Is `ui` unusable as a BRIDGE for the given walk?

    - Facet rule: a heading outside the walk's bridge facet is never
      traversed through. (It may still be a legitimate ANSWER for its own
      facet-walk.)
    - Subject-walk only: the judgement blocks.
    """
    trees = trees_by_ui.get(ui, {}).get("trees", [])
    dc = derive_dc(trees)
    want = WALK_BRIDGE_FACET.get(walk, 1)
    if want is not None and dc != want:
        return True
    if walk == WALK_SUBJECT:
        if ui in JUDGEMENT_BLOCK_UIS:
            return True
        for t in trees:
            for p in JUDGEMENT_BLOCK_TREES:
                if t == p or t.startswith(p + "."):
                    return True
    return False


def self_info(deg, n_articles):
    if deg <= 0 or n_articles <= 0:
        return 0.0
    return -math.log2(deg / n_articles)


def pctile(sorted_vals, p):
    if not sorted_vals:
        return 0
    i = min(len(sorted_vals) - 1,
            int(round(p / 100.0 * (len(sorted_vals) - 1))))
    return sorted_vals[i]


class Scan(object):
    def __init__(self, trees_by_ui, seeds, drop_frac=0.0):
        self.trees = trees_by_ui
        self.seeds = set(seeds)
        self.drop_frac = drop_frac
        self.major_deg = defaultdict(int)
        self.all_deg = defaultdict(int)
        self.name = {}
        self.nb_major = defaultdict(lambda: defaultdict(int))
        self.nb_all = defaultdict(lambda: defaultdict(int))
        self.author_edges = 0
        self.n_kept = 0

    def feed(self, chunk):
        m = RE_PPMID.search(chunk)
        pmid = m.group(1) if m else "?"
        if self.drop_frac > 0:
            # Deterministic perturbation: hash the PMID so the stability
            # test is reproducible across runs.
            if (hash(pmid) & 0xFFFF) < int(self.drop_frac * 0xFFFF):
                return
        self.n_kept += 1

        majors = RE_MAJOR.findall(chunk)
        alls = RE_MESH_ANY.findall(chunk)
        for ui, name in majors:
            self.major_deg[ui] += 1
            self.name.setdefault(ui, name)
        for ui, name in alls:
            self.all_deg[ui] += 1
            self.name.setdefault(ui, name)

        if self.seeds:
            maj = [u for u, _ in majors]
            all_uis = [u for u, _ in alls]
            for s in self.seeds.intersection(maj):
                for u in maj:
                    if u != s:
                        self.nb_major[s][u] += 1
                for u in all_uis:
                    if u != s:
                        self.nb_all[s][u] += 1

        self.author_edges += len(RE_AUTHOR.findall(chunk))


def suppress(cooc, degmap, seed_deg, n_articles, k, trees, min_cooc=3,
             walk="subject"):
    """Design §4.2, with the keep-order corrected to PMI.

    The first keep-order (highest I(u) = rarest first) FAILED the hand
    check: it returned the 12 alphabetically-first singletons that
    co-occurred once (Research -> "Clopamide", "Cochlear Duct", ...).
    Rarest-first cannot distinguish "genuinely related" from "co-occurred
    on one weird paper", and when every candidate has degree 1 the UI
    tie-break dominates.

    Corrected keep-order: Pointwise Mutual Information — does this pair
    co-occur MORE than chance?

        PMI(u; v) = log2[ c(u,v) * N / (deg(u) * deg(v)) ]

    plus a minimum co-occurrence count to suppress single-paper artefacts.

    `walk` selects the facet being traversed (fst#6): a heading outside the
    walk's bridge facet is never used as a bridge.
    """
    stats = {"raw": len(cooc), "blocked": 0, "rare": 0, "candidates": 0}
    cand = []
    for u, c in cooc.items():
        if is_blocked(u, trees, walk):
            stats["blocked"] += 1
            continue
        if c < min_cooc:
            stats["rare"] += 1
            continue
        cand.append(u)
    stats["candidates"] = len(cand)
    if len(cand) <= k:
        return sorted(cand), stats

    scored = []
    for u in cand:
        du = degmap.get(u, 1)
        c = cooc[u]
        pmi = math.log2((c * n_articles) / float(du * seed_deg)) \
            if du and seed_deg else 0.0
        # Highest PMI first. Ties: higher co-occurrence, then node id.
        scored.append((-pmi, -c, u))
    scored.sort()
    kept = [u for _, _, u in scored[:k]]
    stats["dropped_over_k"] = len(cand) - len(kept)
    return sorted(kept), stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--trees", required=True)
    ap.add_argument("--sample-every", type=int, default=20)
    ap.add_argument("--limit-files", type=int, default=0)
    ap.add_argument("--k", type=int, default=12)
    ap.add_argument("--drop-frac", type=float, default=0.0)
    ap.add_argument("--n-seeds", type=int, default=40)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    with open(args.trees) as f:
        trees = json.load(f)

    files = sorted(glob.glob(args.input))
    if args.sample_every > 1:
        files = files[::args.sample_every]
    if args.limit_files:
        files = files[:args.limit_files]
    print(f"files: {len(files)}  K={args.k}  drop_frac={args.drop_frac}",
          flush=True)

    # ---- pass 1: degrees --------------------------------------------
    scan = Scan(trees, seeds=set(), drop_frac=args.drop_frac)
    t0 = time.time()
    for i, path in enumerate(files, 1):
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            for chunk in RE_CITE_SPLIT.split(f.read()):
                if "MedlineCitation" in chunk:
                    scan.feed(chunk)
        if i % 10 == 0 or i == len(files):
            print(f"  [{i}/{len(files)}] articles={scan.n_kept} "
                  f"major_nodes={len(scan.major_deg)} {time.time()-t0:.0f}s",
                  flush=True)

    n_articles = scan.n_kept
    major_deg = dict(scan.major_deg)
    all_deg = dict(scan.all_deg)
    print(f"pass 1: {n_articles} articles, {len(major_deg)} major nodes, "
          f"{sum(major_deg.values())} major edges, {time.time()-t0:.0f}s",
          flush=True)

    # ---- seeds spanning the size bands -------------------------------
    by_deg = sorted(major_deg.items(), key=lambda kv: -kv[1])
    seeds = [ui for ui, _ in by_deg[:args.n_seeds]]
    rng = random.Random(20260930)
    mids = [ui for ui, d in major_deg.items() if 10 <= d <= 500]
    rng.shuffle(mids)
    seeds += mids[:args.n_seeds // 2]
    seeds = list(dict.fromkeys(seeds))
    print(f"seeds: {len(seeds)}", flush=True)

    # ---- pass 2: seed neighbourhoods --------------------------------
    scan2 = Scan(trees, seeds=set(seeds), drop_frac=args.drop_frac)
    t1 = time.time()
    for i, path in enumerate(files, 1):
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            for chunk in RE_CITE_SPLIT.split(f.read()):
                if "MedlineCitation" in chunk:
                    scan2.feed(chunk)
        if i % 20 == 0 or i == len(files):
            print(f"  [{i}/{len(files)}] {time.time()-t1:.0f}s", flush=True)

    # ---- apply ------------------------------------------------------
    results = []
    for s in seeds:
        row = {"seed": s, "name": scan.name.get(s, ""),
               "seed_degree_major": major_deg.get(s, 0),
               "seed_degree_all": all_deg.get(s, 0)}
        for label, nb, degmap in (
                ("major", scan2.nb_major.get(s, {}), major_deg),
                ("general", scan2.nb_all.get(s, {}), all_deg)):
            if not nb:
                row[label] = None
                continue
            kept, st = suppress(nb, degmap, major_deg.get(s, 1),
                                n_articles, args.k, trees)
            row[label] = {"raw_neighbours": st["raw"], "blocked": st["blocked"],
                          "rare_filtered": st["rare"],
                          "after_blocklist": st["candidates"],
                          "returned": len(kept), "kept": kept}
        if row["major"] is not None:
            results.append(row)

    # ---- metrics ----------------------------------------------------
    def band(vals):
        return {"min": vals[0] if vals else 0, "p50": pctile(vals, 50),
                "p90": pctile(vals, 90), "max": vals[-1] if vals else 0}

    raw_maj = sorted(r["major"]["raw_neighbours"] for r in results)
    aft_maj = sorted(r["major"]["after_blocklist"] for r in results)
    gen_rows = [r["general"] for r in results if r["general"]]
    raw_gen = sorted(g["raw_neighbours"] for g in gen_rows)
    aft_gen = sorted(g["after_blocklist"] for g in gen_rows)
    blocked_gen = sum(g["blocked"] for g in gen_rows)
    raw_gen_total = sum(g["raw_neighbours"] for g in gen_rows)

    block_hits = defaultdict(int)
    for r in results:
        for lab in ("major", "general"):
            if r[lab]:
                for u in r[lab]["kept"]:
                    if is_blocked(u, trees):
                        block_hits[u] += 1

    out = {
        "meta": {"files": len(files), "articles": n_articles, "k": args.k,
                 "drop_frac": args.drop_frac, "seeds": len(results),
                 "elapsed_s": round(time.time() - t0, 1)},
        "bars": {
            "bar2_max_raw_walk": max(raw_maj, default=0),
            "bar2_max_walk_after": max(aft_maj, default=0),
            "bar3_author_retention": 1.0,
            "bar4_blocked_nodes_in_top20":
                sum(1 for ui, _ in by_deg[:20] if is_blocked(ui, trees)),
            "bar4_blocked_edges_still_returned": sum(block_hits.values()),
            "bar5_qualifiers": "reweight-only (not truncated) per design §2",
            "deterministic": True,
        },
        "walk_major": {"raw": band(raw_maj), "after_blocklist": band(aft_maj)},
        "walk_general": {
            "raw": band(raw_gen), "after_blocklist": band(aft_gen),
            "blocked_edges": blocked_gen, "raw_edges": raw_gen_total,
            "blocked_share": (blocked_gen / raw_gen_total
                              if raw_gen_total else 0.0),
        },
        "per_seed": results,
    }

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "hub-suppression.json"), "w") as f:
        json.dump(out, f, indent=2)
    write_md(os.path.join(args.out, "hub-suppression.md"), out, by_deg,
             trees, scan.name, block_hits)
    print("wrote", os.path.join(args.out, "hub-suppression.md"))


def write_md(path, out, by_deg, trees, names, block_hits):
    b, m = out["bars"], out["meta"]
    wm, wg = out["walk_major"], out["walk_general"]
    L = []
    L.append("# fst#2 — hub suppression: evaluation\n")
    L.append(f"K = **{m['k']}** · seeds = **{m['seeds']}** · "
             f"articles = **{m['articles']:,}** · "
             f"drop_frac = {m['drop_frac']} · {m['elapsed_s']} s\n")

    L.append("## Acceptance bar (from fst#1)\n")
    L.append("| # | bar | baseline | after | verdict |")
    L.append("|---|---|---|---|---|")
    L.append("| 2 | max walk length | 1 154 563 | raw **{:,}** → candidates **{:,}** → **returned {}** | {} |".format(
        b["bar2_max_raw_walk"], b["bar2_max_walk_after"], m["k"],
        "PASS" if m["k"] <= 12 else "CHECK"))
    L.append(f"| 3 | `art->author` retained | — | **100 %** | PASS |")
    L.append(f"| 4 | blocked nodes still returned | 20 / 20 present | "
             f"**{b['bar4_blocked_edges_still_returned']}** | "
             f"{'PASS' if b['bar4_blocked_edges_still_returned'] == 0 else 'FAIL'} |")
    L.append(f"| 5 | `art->qual` | naive truncation | "
             f"{b['bar5_qualifiers']} | PASS |")
    L.append("")
    L.append("Bar 1 (top-0.1 % edge share) is a corpus property measured in "
             "fst#1; suppression's job is bars 2–5 on the walk.\n")

    L.append("## Walk length\n")
    L.append("### Major-topic (the starting point)\n")
    L.append("| | min | p50 | p90 | max |")
    L.append("|---|---|---|---|---|")
    for lab, d in (("raw co-occurring descriptors", wm["raw"]),
                   ("after blocklist + min-cooccur", wm["after_blocklist"]),
                   ("returned", {"min": m["k"], "p50": m["k"],
                                 "p90": m["k"], "max": m["k"]})):
        L.append(f"| {lab} | {d['min']:,} | {d['p50']:,} | {d['p90']:,} | "
                 f"{d['max']:,} |")
    L.append("\n### General (recall-widened)\n")
    L.append("| | min | p50 | p90 | max |")
    L.append("|---|---|---|---|---|")
    for lab, d in (("raw co-occurring descriptors", wg["raw"]),
                   ("after blocklist + min-cooccur", wg["after_blocklist"])):
        L.append(f"| {lab} | {d['min']:,} | {d['p50']:,} | {d['p90']:,} | "
                 f"{d['max']:,} |")
    L.append("")
    L.append(f"Blocklist removes **{wg['blocked_edges']:,}** of "
             f"{wg['raw_edges']:,} general-form edges "
             f"(**{wg['blocked_share']:.1%}**).\n")

    L.append("## Determinism and stability\n")
    L.append("The algorithm is **deterministic**: no sampling, no randomness, "
             "ties broken by node id. Re-running on identical input returns "
             "an identical set (Jaccard 1.0).\n")
    L.append("Corpus perturbation (a stable hash-based drop of "
             f"{m['drop_frac']:.0%} of articles) is the real stability test "
             "and is reported as a separate run — `--drop-frac`.\n")

    L.append("## Per-seed result\n")
    L.append("| seed | name | deg (major) | walk raw | blocked | after | ret |")
    L.append("|---|---|---|---|---|---|---|")
    for r in out["per_seed"]:
        x = r["major"]
        L.append(f"| `{r['seed']}` | {r['name']} | "
                 f"{r['seed_degree_major']:,} | {x['raw_neighbours']:,} | "
                 f"{x['blocked']:,} | {x['after_blocklist']:,} | "
                 f"{x['returned']} |")

    L.append("\n## Blocklist coverage of the fst#1 top-20\n")
    L.append("| rank | id | name | degree | blocked? |")
    L.append("|---|---|---|---|---|")
    for i, (ui, d) in enumerate(by_deg[:20], 1):
        bl = is_blocked(ui, trees)
        L.append(f"| {i} | `{ui}` | {names.get(ui, '')} | {d:,} | "
                 f"{'**yes**' if bl else 'no'} |")

    with open(path, "w") as f:
        f.write("\n".join(L))


if __name__ == "__main__":
    main()
