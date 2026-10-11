#!/usr/bin/env python3
"""fst#4 — dump 2-hop expansion features.

1-hop data already exists in rank-features.json (fst#3). This script
answers the second-hop question: for every node that is a 1-hop neighbour
of a chosen seed, what are ITS neighbours?

That is everything needed to compute both the exhaustive 2-hop oracle and
the pruned 2-hop offline.

Panel A (correctness): seeds whose 1-hop is small enough that 2-hop is
genuinely exhaustive. Panel B (cost): the largest hubs.
"""
import argparse
import glob
import gzip
import json
import os
import re
import sys
import time
from collections import defaultdict

RE_CITE_SPLIT = re.compile(r'(?=<MedlineCitation)')
RE_MAJOR = re.compile(
    r'<DescriptorName UI="(D\d+)" MajorTopicYN="Y">([^<]*)</DescriptorName>')


def pick_panels(feats, n_small=12, n_large=3):
    """Panel A: small 1-hop. Panel B: largest by degree."""
    cooc = feats["seeds"]
    sizes = sorted(((s, len(b["cooc"])) for s, b in cooc.items()),
                   key=lambda kv: kv[1])
    # Panel A: 20 <= 1-hop <= 300, spanning the range.
    small = [s for s, n in sizes if 20 <= n <= 300]
    if len(small) > n_small:
        step = max(1, len(small) // n_small)
        small = small[::step][:n_small]
    # Panel B: largest by major-topic degree.
    deg = feats["major_deg"]
    large = sorted(feats["seed_names"], key=lambda s: -deg.get(s, 0))[:n_large]
    return small, large


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--features", required=True)
    ap.add_argument("--sample-every", type=int, default=20)
    ap.add_argument("--limit-files", type=int, default=0)
    ap.add_argument("--n-small", type=int, default=12)
    ap.add_argument("--n-large", type=int, default=3)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    feats = json.load(open(args.features))
    panel_a, panel_b = pick_panels(feats, args.n_small, args.n_large)
    seeds = list(dict.fromkeys(panel_a + panel_b))
    print(f"panel A (correctness): {len(panel_a)} seeds")
    print(f"panel B (cost):        {len(panel_b)} seeds")
    print(f"total seeds:           {len(seeds)}")

    # Every node one hop from any seed becomes an expansion target.
    targets = set()
    for s in seeds:
        targets.update(feats["seeds"][s]["cooc"].keys())
    print(f"2-hop expansion targets: {len(targets)}", flush=True)

    files = sorted(glob.glob(args.input))
    if args.sample_every > 1:
        files = files[::args.sample_every]
    if args.limit_files:
        files = files[:args.limit_files]

    hop2 = defaultdict(lambda: defaultdict(int))
    n_articles = 0
    t0 = time.time()
    for i, path in enumerate(files, 1):
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            for chunk in RE_CITE_SPLIT.split(f.read()):
                if "MedlineCitation" not in chunk:
                    continue
                n_articles += 1
                uis = [u for u, _ in RE_MAJOR.findall(chunk)]
                hit = targets.intersection(uis)
                if not hit:
                    continue
                for t in hit:
                    for u in uis:
                        if u != t:
                            hop2[t][u] += 1
        if i % 10 == 0 or i == len(files):
            print(f"  [{i}/{len(files)}] articles={n_articles} "
                  f"targets_hit={len(hop2)} {time.time()-t0:.0f}s", flush=True)

    out = {
        "meta": {"files": len(files), "articles": n_articles,
                 "seeds": seeds, "panel_a": panel_a, "panel_b": panel_b,
                 "targets": len(targets), "elapsed_s": round(time.time()-t0, 1)},
        "major_deg": feats["major_deg"],
        "seed_names": feats["seed_names"],
        "hop1": {s: feats["seeds"][s]["cooc"] for s in seeds},
        "hop2": {t: dict(v) for t, v in hop2.items()},
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(out, f)
    print(f"wrote {args.out} ({os.path.getsize(args.out)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
