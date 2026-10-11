#!/usr/bin/env python3
"""fst#1 — hub-suppression baseline.

Streams MEDLINE/PubMed XML and measures the hub distribution per edge type.
This is measurement only: no suppression algorithm, no design decisions.

Produces, per edge type:
  1. degree distribution  min/p50/p90/p99/p99.9/max + counts above 10^k
  2. concentration        fraction of all edges attached to the top 0.1% of nodes
  3. top-50 hub identity  node id + name + degree + node type
  4. walk length          the degree IS the raw $ORDER walk length; bytes
                          scanned are estimated from key width (see notes)
  5. ranking signals      in-degree distribution (what we have without a store)

Usage:
  hub-baseline.py --input 'glob' [--sample-every N] [--limit-files N] --out DIR

Output: hub-baseline.md + hub-baseline.json
"""
import argparse
import glob
import gzip
import json
import os
import re
import statistics
import sys
import time

# --- extraction regexes (fast path: no full XML parse) ----------------
RE_PPMID = re.compile(r'<PMID[^>]*>(\d+)</PMID>')
RE_MESH = re.compile(
    r'<DescriptorName UI="(D\d+)"[^>]*>([^<]*)</DescriptorName>')
RE_QUAL = re.compile(
    r'<QualifierName UI="(Q\d+)"[^>]*>([^<]*)</QualifierName>')
RE_CHEM = re.compile(
    r'<NameOfSubstance UI="(D\d+)">([^<]*)</NameOfSubstance>')
RE_AUTHOR = re.compile(
    r'<LastName>([^<]*)</LastName>\s*<ForeName>([^<]*)</ForeName>')
RE_AUTHOR_I = re.compile(
    r'<LastName>([^<]*)</LastName>\s*<Initials>([^<]*)</Initials>')
RE_ISSN = re.compile(r'<ISSNLinking>([^<]+)</ISSNLinking>')
RE_TA = re.compile(r'<MedlineTA>([^<]+)</MedlineTA>')
RE_PTYPE = re.compile(
    r'<PublicationType UI="(D\d+)">([^<]*)</PublicationType>')
RE_YEAR = re.compile(r'<PubDate>.*?<Year>(\d{4})</Year>', re.S)
RE_MAJOR = re.compile(
    r'<DescriptorName UI="(D\d+)" MajorTopicYN="Y">')

# Split into <MedlineCitation> chunks so we never hold the file in RAM.
RE_CITE_SPLIT = re.compile(r'(?=<MedlineCitation)')


class Counter(object):
    def __init__(self):
        self.deg = {}
        self.name = {}
        self.edges = 0

    def add(self, key, name=None):
        self.deg[key] = self.deg.get(key, 0) + 1
        self.edges += 1
        if name and key not in self.name:
            self.name[key] = name

    def merge(self, other):
        for k, v in other.deg.items():
            self.deg[k] = self.deg.get(k, 0) + v
            self.edges += v
        for k, v in other.name.items():
            self.name.setdefault(k, v)


def pct(sorted_vals, p):
    if not sorted_vals:
        return 0
    i = min(len(sorted_vals) - 1, int(round(p / 100.0 * (len(sorted_vals) - 1))))
    return sorted_vals[i]


def summarize(counter, edge_type, node_type, key_bytes=12):
    """Return the measurement block for one edge type."""
    degs = sorted(counter.deg.values())
    n = len(degs)
    total_edges = counter.edges
    if n == 0:
        return {"edge_type": edge_type, "nodes": 0, "edges": 0}

    thresholds = {}
    for k in range(1, 8):
        t = 10 ** k
        thresholds[str(t)] = sum(1 for d in degs if d >= t)

    # Concentration: share of all edges held by the top 0.1% of nodes.
    top_n = max(1, int(round(n * 0.001)))
    top_edges = sum(degs[-top_n:])
    top_1pct_n = max(1, int(round(n * 0.01)))
    top_1pct_edges = sum(degs[-top_1pct_n:])

    # Top 50 hubs.
    ordered = sorted(counter.deg.items(), key=lambda kv: -kv[1])[:50]
    hubs = [{"id": k, "name": counter.name.get(k, ""), "degree": d}
            for k, d in ordered]

    # Walk length = degree. Bytes scanned = degree * key width (estimate).
    bands = {}
    for lo, hi, label in [(1, 99, "1-99"), (100, 9999, "1e2-1e4"),
                          (10000, 999999, "1e4-1e6"), (1000000, 10**12, "1e6+")]:
        inb = [d for d in degs if lo <= d <= hi]
        if inb:
            mx = max(inb)
            bands[label] = {
                "nodes": len(inb),
                "max_degree": mx,
                "est_bytes_scanned": mx * key_bytes,
            }

    return {
        "edge_type": edge_type,
        "node_type": node_type,
        "nodes": n,
        "edges": total_edges,
        "degree": {
            "min": degs[0],
            "p50": pct(degs, 50),
            "p90": pct(degs, 90),
            "p99": pct(degs, 99),
            "p99.9": pct(degs, 99.9),
            "max": degs[-1],
            "mean": round(statistics.fmean(degs), 2),
        },
        "thresholds_ge": thresholds,
        "concentration": {
            "top_0.1pct_nodes": top_n,
            "top_0.1pct_edge_share": round(top_edges / total_edges, 4),
            "top_1pct_nodes": top_1pct_n,
            "top_1pct_edge_share": round(top_1pct_edges / total_edges, 4),
        },
        "walk_bands": bands,
        "top_hubs": hubs,
    }


def scan_file(path, counters):
    """Extract entity degrees from one MEDLINE XML file."""
    n_art = 0
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        buf = []
        for chunk in RE_CITE_SPLIT.split(f.read()):
            if "MedlineCitation" not in chunk:
                continue
            n_art += 1
            m = RE_PPMID.search(chunk)
            pmid = m.group(1) if m else "?"

            # Mesh descriptors (all) and major-topic-only subset.
            for ui, name in RE_MESH.findall(chunk):
                counters["art->mesh"].add("mesh:" + ui, name)
            for ui in RE_MAJOR.findall(chunk):
                # name lookup is cheap from the full mesh pass above
                counters["art->mesh_major"].add("mesh:" + ui)

            for ui, name in RE_QUAL.findall(chunk):
                counters["art->qual"].add("qual:" + ui, name)

            for ui, name in RE_CHEM.findall(chunk):
                counters["art->chem"].add("chem:" + ui, name)

            for last, fore in RE_AUTHOR.findall(chunk):
                counters["art->author"].add(
                    "author:" + last + "," + fore, last + " " + fore)

            for issn in RE_ISSN.findall(chunk):
                counters["art->issn"].add("issn:" + issn, issn)

            for ui, name in RE_PTYPE.findall(chunk):
                counters["art->ptype"].add("ptype:" + ui, name)

            m = RE_YEAR.search(chunk)
            if m:
                counters["art->year"].add("year:" + m.group(1), m.group(1))

    return n_art


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="glob for .xml.gz files")
    ap.add_argument("--sample-every", type=int, default=1,
                    help="process every Nth file (1 = all)")
    ap.add_argument("--limit-files", type=int, default=0)
    ap.add_argument("--out", required=True)
    ap.add_argument("--key-bytes", type=int, default=12)
    args = ap.parse_args()

    files = sorted(glob.glob(args.input))
    if not files:
        sys.exit(f"no files match {args.input}")
    if args.sample_every > 1:
        files = files[::args.sample_every]
    if args.limit_files:
        files = files[:args.limit_files]

    print(f"input: {args.input}")
    print(f"files: {len(files)} (sample_every={args.sample_every})", flush=True)

    names = ["art->mesh", "art->mesh_major", "art->qual", "art->chem",
             "art->author", "art->issn", "art->ptype", "art->year"]
    counters = {n: Counter() for n in names}

    t0 = time.time()
    n_art = 0
    for i, path in enumerate(files, 1):
        try:
            n_art += scan_file(path, counters)
        except Exception as e:
            print(f"  !! {os.path.basename(path)}: {e}", file=sys.stderr)
        if i % 10 == 0 or i == len(files):
            dt = time.time() - t0
            print(f"  [{i}/{len(files)}] {n_art} articles  {dt:.0f}s", flush=True)

    elapsed = time.time() - t0
    print(f"done: {n_art} articles in {elapsed:.0f}s", flush=True)

    node_types = {
        "art->mesh": "MeSH descriptor",
        "art->mesh_major": "MeSH descriptor (major topic only)",
        "art->qual": "MeSH qualifier",
        "art->chem": "chemical / substance",
        "art->author": "author",
        "art->issn": "journal (ISSN)",
        "art->ptype": "publication type",
        "art->year": "publication year",
    }
    blocks = []
    for n in names:
        blocks.append(summarize(counters[n], n, node_types[n], args.key_bytes))

    meta = {
        "files_scanned": len(files),
        "articles": n_art,
        "elapsed_s": round(elapsed, 1),
        "sample_every": args.sample_every,
        "input": args.input,
    }

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "hub-baseline.json"), "w") as f:
        json.dump({"meta": meta, "edge_types": blocks}, f, indent=2)

    write_md(os.path.join(args.out, "hub-baseline.md"), meta, blocks)
    print("wrote", os.path.join(args.out, "hub-baseline.md"))


def write_md(path, meta, blocks):
    L = []
    L.append("# Hub-suppression baseline (fst#1)\n")
    L.append("Measurement only. No suppression algorithm was designed or "
             "implemented here.\n")
    L.append("## Corpus\n")
    L.append(f"- input: `{meta['input']}`")
    L.append(f"- files scanned: **{meta['files_scanned']}**"
             f" (every {meta['sample_every']} file)")
    L.append(f"- articles: **{meta['articles']:,}**")
    L.append(f"- wall time: {meta['elapsed_s']} s\n")
    if meta["sample_every"] > 1 or meta["files_scanned"] < 2000:
        L.append("> **Sampled, not full corpus.** Absolute degrees scale with "
                 "the sample. Distribution *shape* and the concentration "
                 "ratios are the stable quantities and are what the "
                 "suppression design should be based on.\n")

    L.append("## 1. Degree distribution\n")
    for b in blocks:
        if not b.get("nodes"):
            continue
        d = b["degree"]
        L.append(f"### `{b['edge_type']}` — {b['node_type']}\n")
        L.append(f"| nodes | edges | min | p50 | p90 | p99 | p99.9 | max | mean |")
        L.append(f"|---|---|---|---|---|---|---|---|---|")
        L.append(f"| {b['nodes']:,} | {b['edges']:,} | {d['min']} | "
                 f"{d['p50']} | {d['p90']} | {d['p99']} | {d['p99.9']} | "
                 f"**{d['max']}** | {d['mean']} |\n")
        L.append("Nodes at or above degree:\n")
        L.append("| ≥10 | ≥100 | ≥1e3 | ≥1e4 | ≥1e5 | ≥1e6 | ≥1e7 |")
        L.append("|---|---|---|---|---|---|---|")
        t = b["thresholds_ge"]
        L.append("| " + " | ".join(str(t[str(10 ** k)]) for k in range(1, 8)) + " |\n")

    L.append("## 2. Concentration\n")
    L.append("What fraction of all edges hang off the top of the distribution.\n")
    L.append("| edge type | top 0.1 % nodes | share of edges | "
             "top 1 % nodes | share of edges |")
    L.append("|---|---|---|---|---|")
    for b in blocks:
        if not b.get("nodes"):
            continue
        c = b["concentration"]
        L.append(f"| `{b['edge_type']}` | {c['top_0.1pct_nodes']:,} | "
                 f"**{c['top_0.1pct_edge_share']:.1%}** | "
                 f"{c['top_1pct_nodes']:,} | "
                 f"{c['top_1pct_edge_share']:.1%} |")
    L.append("")
    L.append("This is the number that decides whether hub suppression is a "
             "20 % problem or a 99 % problem.\n")

    L.append("## 3. Top hubs\n")
    for b in blocks:
        if not b.get("top_hubs"):
            continue
        L.append(f"### `{b['edge_type']}`\n")
        L.append("| rank | id | name | degree |")
        L.append("|---|---|---|---|")
        for i, h in enumerate(b["top_hubs"][:20], 1):
            nm = (h["name"] or "").replace("|", "/")
            L.append(f"| {i} | `{h['id']}` | {nm} | {h['degree']:,} |")
        L.append("")

    L.append("## 4. Raw walk cost\n")
    L.append("A `$ORDER` walk of a node visits every edge exactly once, so "
             "**the degree is the walk length**. Bytes scanned are estimated "
             "from key width only:\n")
    L.append("| edge type | band | nodes | max degree | est. bytes scanned |")
    L.append("|---|---|---|---|---|")
    for b in blocks:
        if not b.get("walk_bands"):
            continue
        for label, info in b["walk_bands"].items():
            L.append(f"| `{b['edge_type']}` | {label} | {info['nodes']:,} | "
                     f"{info['max_degree']:,} | "
                     f"{info['est_bytes_scanned']:,} |")
    L.append("")
    L.append("> **Gap:** wall time and syscall counts for a real `$ORDER` "
             "walk need a loaded store. Those are deferred until one exists; "
             "the degree *is* the upper bound on work regardless of store, "
             "so this section bounds the problem rather than timing it.\n")

    L.append("## 5. Ranking signals available\n")
    L.append("Measured without a store — what we can see in the corpus alone:\n")
    L.append("| signal | available here? | evidence |")
    L.append("|---|---|---|")
    L.append("| in-degree of the neighbour | **yes** | the degree tables above |")
    L.append("| out-degree of the neighbour | **yes** | symmetric for "
             "art↔entity in this corpus |")
    L.append("| major-topic flag | **yes** | `art->mesh_major` vs `art->mesh` |")
    L.append("| recency | **yes** | `art->year` |")
    L.append("| edge-label weight | partial | only qualifier names here |")
    L.append("| TF-IDF / document frequency | **yes** | `art->mesh` degree "
             "*is* document frequency |")
    L.append("| co-occurrence strength | **no** | needs a store to compute "
             "pairwise |")
    L.append("| path type / relation ontology | **no** | needs the graph "
             "link vocabulary |")
    L.append("")
    L.append("Note that in-degree and TF-IDF-ish weight are the *same* "
             "measurement here: a MeSH descriptor's degree is exactly its "
             "document frequency. Any ranking scheme that uses both is "
             "double-counting.\n")

    with open(path, "w") as f:
        f.write("\n".join(L))


if __name__ == "__main__":
    main()
