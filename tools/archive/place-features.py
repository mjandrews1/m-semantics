#!/usr/bin/env python3
"""fst#8 — place-seeded feature dump.

The fst#3 dump was built from 60 SUBJECT seeds, so it contains no
place-to-place pairs and no degrees for Z* nodes. The place-facet walk
needs its own dump: every DC=4 node's neighbourhood, plus its degree.

Single corpus pass. Emits the same shape as rank-features.py so the
walk/eval code is shared.
"""
import argparse
import glob
import gzip
import importlib.util
import json
import os
import re
import sys
import time
from collections import defaultdict

RE_CITE_SPLIT = re.compile(r'(?=<MedlineCitation)')
RE_MAJOR = re.compile(
    r'<DescriptorName UI="(D\d+)" MajorTopicYN="Y">([^<]*)</DescriptorName>')
RE_MESH_ANY = re.compile(
    r'<DescriptorName UI="(D\d+)"[^>]*>([^<]*)</DescriptorName>')

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "hs", os.path.join(HERE, "hub-suppression.py"))
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--trees", required=True)
    ap.add_argument("--sample-every", type=int, default=20)
    ap.add_argument("--limit-files", type=int, default=0)
    ap.add_argument("--top", type=int, default=25,
                    help="how many Z* nodes to track (by degree)")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    trees = json.load(open(args.trees))
    is_place = {ui for ui, v in trees.items()
                if isinstance(v, dict) and hs.derive_dc(v.get("trees", [])) == 4}
    print(f"Z* place descriptors in MeSH: {len(is_place)}")

    files = sorted(glob.glob(args.input))
    if args.sample_every > 1:
        files = files[::args.sample_every]
    if args.limit_files:
        files = files[:args.limit_files]
    print(f"files: {len(files)}")

    # Pass 1: degrees of ALL major-topic nodes, so place nodes get a real
    # degree (the fst#3 dump had deg 0 for them).
    deg = defaultdict(int)
    name = {}
    place_deg = defaultdict(int)
    n_articles = 0
    # place -> neighbour -> cooccurrence count. Bounded: only tracked for
    # the top-N places once we know them, so this is a two-pass script.
    t0 = time.time()
    for i, path in enumerate(files, 1):
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            for chunk in RE_CITE_SPLIT.split(f.read()):
                if "MedlineCitation" not in chunk:
                    continue
                n_articles += 1
                # GENERAL form, not major-only: geography is essentially
                # never a MajorTopicYN=Y heading in PubMed (measured 2026-03-31:
                # 900,000 articles, 0 place nodes as major topics). NLM places
                # geography outside the subject facet, so it lands as a
                # secondary heading. A place walk must read the general form.
                for u, nm in RE_MESH_ANY.findall(chunk):
                    deg[u] += 1
                    name.setdefault(u, nm)
                    if u in is_place:
                        place_deg[u] += 1
        if i % 10 == 0 or i == len(files):
            print(f"  pass1 [{i}/{len(files)}] arts={n_articles} "
                  f"places_seen={len(place_deg)} {time.time()-t0:.0f}s",
                  flush=True)

    top_places = sorted(place_deg, key=lambda u: -place_deg[u])[:args.top]
    print(f"\ntop {len(top_places)} places by major-topic degree:")
    for u in top_places:
        print(f"   {u}  deg={place_deg[u]:<6d} {name.get(u,'?')}")

    # Pass 2: neighbourhoods of those places.
    track = set(top_places)
    nb = defaultdict(lambda: defaultdict(int))
    t1 = time.time()
    for i, path in enumerate(files, 1):
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            for chunk in RE_CITE_SPLIT.split(f.read()):
                if "MedlineCitation" not in chunk:
                    continue
                uis = [u for u, _ in RE_MESH_ANY.findall(chunk)]
                hit = track.intersection(uis)
                if not hit:
                    continue
                for p in hit:
                    for u in uis:
                        if u != p:
                            nb[p][u] += 1
        if i % 10 == 0 or i == len(files):
            print(f"  pass2 [{i}/{len(files)}] {time.time()-t1:.0f}s", flush=True)

    out = {
        "meta": {"files": len(files), "articles": n_articles,
                 "place_seeds": top_places, "kind": "place-walk"},
        "major_deg": dict(deg),
        "seed_names": name,
        "seeds": {p: {"cooc": dict(nb.get(p, {})),
                      "both_major": {}, "title_hits": {}}
                  for p in top_places},
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(out, f)
    print(f"\nwrote {args.out} ({os.path.getsize(args.out)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
