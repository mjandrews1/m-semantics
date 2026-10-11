#!/usr/bin/env python3
"""fst#3 — dump ranking features once, so rankers can be evaluated offline.

Emits, per seed: the full co-occurring candidate pool with counts, plus
the corpus-derived signals a ranker is allowed to use under
docs/ranking-design.md C3 (no thesaurus features — gold is thesaurus-derived).

Signals (all corpus-derived):
    c(u,v)      co-occurrence count
    deg(u)      major-topic degree of the candidate
    deg(v)      major-topic degree of the seed
    both_major  count of co-occurring articles where BOTH are major topics
    title_hits  count of co-occurring articles whose title contains the
                seed's name (a text signal PMI cannot see)
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
RE_PPMID = re.compile(r'<PMID[^>]*>(\d+)</PMID>')
RE_MAJOR = re.compile(
    r'<DescriptorName UI="(D\d+)" MajorTopicYN="Y">([^<]*)</DescriptorName>')
RE_MESH_ANY = re.compile(
    r'<DescriptorName UI="(D\d+)"[^>]*>([^<]*)</DescriptorName>')
RE_TITLE = re.compile(r'<ArticleTitle>(.*?)</ArticleTitle>', re.S)


class FeatureScan(object):
    def __init__(self, seeds, seed_names):
        self.seeds = set(seeds)
        self.seed_names = seed_names          # ui -> display name
        self.seed_lower = {ui: nm.lower()
                           for ui, nm in seed_names.items() if nm}
        self.major_deg = defaultdict(int)
        self.all_deg = defaultdict(int)
        self.cooc = defaultdict(lambda: defaultdict(int))
        self.both_major = defaultdict(lambda: defaultdict(int))
        self.title_hits = defaultdict(lambda: defaultdict(int))
        self.n_articles = 0

    def feed(self, chunk):
        self.n_articles += 1
        m = RE_PPMID.search(chunk)
        majors = RE_MAJOR.findall(chunk)
        alls = RE_MESH_ANY.findall(chunk)
        maj_uis = [u for u, _ in majors]
        all_uis = [u for u, _ in alls]
        for ui, _ in majors:
            self.major_deg[ui] += 1
        for ui, _ in alls:
            self.all_deg[ui] += 1

        hit = self.seeds.intersection(maj_uis)
        if not hit:
            return

        tm = RE_TITLE.search(chunk)
        title = tm.group(1).lower() if tm else ""
        major_set = set(maj_uis)

        for s in hit:
            sname = self.seed_lower.get(s, "")
            s_major = s in major_set
            for u in all_uis:
                if u == s:
                    continue
                self.cooc[s][u] += 1
                if s_major and u in major_set:
                    self.both_major[s][u] += 1
                if sname and sname in title:
                    self.title_hits[s][u] += 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--seeds-from", required=True,
                    help="hub-suppression.json from fst#2")
    ap.add_argument("--sample-every", type=int, default=20)
    ap.add_argument("--limit-files", type=int, default=0)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    prior = json.load(open(args.seeds_from))
    seeds = [r["seed"] for r in prior["per_seed"]]
    seed_names = {r["seed"]: r["name"] for r in prior["per_seed"]}
    print(f"seeds: {len(seeds)}", flush=True)

    files = sorted(glob.glob(args.input))
    if args.sample_every > 1:
        files = files[::args.sample_every]
    if args.limit_files:
        files = files[:args.limit_files]
    print(f"files: {len(files)}", flush=True)

    scan = FeatureScan(seeds, seed_names)
    t0 = time.time()
    for i, path in enumerate(files, 1):
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            for chunk in RE_CITE_SPLIT.split(f.read()):
                if "MedlineCitation" in chunk:
                    scan.feed(chunk)
        if i % 10 == 0 or i == len(files):
            print(f"  [{i}/{len(files)}] articles={scan.n_articles} "
                  f"{time.time()-t0:.0f}s", flush=True)

    out = {
        "meta": {"files": len(files), "articles": scan.n_articles,
                 "seeds": len(seeds), "elapsed_s": round(time.time() - t0, 1)},
        "major_deg": dict(scan.major_deg),
        "all_deg": dict(scan.all_deg),
        "seed_names": seed_names,
        "seeds": {},
    }
    for s in seeds:
        out["seeds"][s] = {
            "cooc": dict(scan.cooc.get(s, {})),
            "both_major": dict(scan.both_major.get(s, {})),
            "title_hits": dict(scan.title_hits.get(s, {})),
        }

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(out, f)
    print(f"wrote {args.out} ({os.path.getsize(args.out)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
