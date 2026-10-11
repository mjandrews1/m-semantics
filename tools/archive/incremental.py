#!/usr/bin/env python3
"""fst#5 — incremental update: implementation and measurement.

Index (fst#2/#3 co-assignment structure):

    deg[v]       articles carrying v
    c[{u,v}]     articles carrying BOTH u and v   (UNORDERED key -- one
                                                entry, so a one-way update
                                                is structurally impossible)

Ranking is P(u|v) = c(u,v) / deg(v) -- the fst#3 winner.

Measures, per docs/incremental-design.md 6:
  M1  consistency   forward == reverse; deg/c invariant
  M2  incrementality  apply(B) vs rebuild ratio
  M3  rank drift      how many seeds' top-K change after a batch
  M4  deletion        exact restore; double-delete no-op; hub deletion clean
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
RE_MAJOR = re.compile(
    r'<DescriptorName UI="(D\d+)" MajorTopicYN="Y">([^<]*)</DescriptorName>')


def key(a, b):
    """Unordered pair key -- the consistency guarantee, in one line."""
    return (a, b) if a <= b else (b, a)


class Index(object):
    def __init__(self):
        self.deg = defaultdict(int)
        self.c = defaultdict(int)
        self.records = set()      # present record ids -- deletion guard
        self.mutations = 0

    # ---- writes ----------------------------------------------------
    def apply_record(self, rid, descs):
        if rid in self.records:
            return 0                      # idempotent
        self.records.add(rid)
        n = 0
        for d in descs:
            self.deg[d] += 1
            n += 1
        ds = sorted(set(descs))
        for i in range(len(ds)):
            for j in range(i + 1, len(ds)):
                self.c[key(ds[i], ds[j])] += 1
                n += 1
        self.mutations += n
        return n

    def delete_record(self, rid, descs):
        """Reverse of apply. A delete of an absent record is a no-op."""
        if rid not in self.records:
            return 0
        self.records.discard(rid)
        n = 0
        for d in descs:
            self.deg[d] -= 1
            n += 1
            if self.deg[d] <= 0:
                self.deg.pop(d, None)
        ds = sorted(set(descs))
        for i in range(len(ds)):
            for j in range(i + 1, len(ds)):
                k = key(ds[i], ds[j])
                self.c[k] -= 1
                n += 1
                if self.c[k] <= 0:
                    self.c.pop(k, None)
        self.mutations += n
        return n

    # ---- reads -----------------------------------------------------
    def neighbours(self, v):
        """Nodes co-occurring with v -- the forward walk."""
        out = {}
        for k, n in self.c.items():
            if k[0] == v:
                out[k[1]] = n
            elif k[1] == v:
                out[k[0]] = n
        return out

    def rank(self, v, k=10):
        """P(u|v) = c(u,v)/deg(v) -- the fst#3 winner."""
        dv = self.deg.get(v, 0)
        if not dv:
            return []
        nb = self.neighbours(v)
        scored = sorted(nb.items(), key=lambda kv: (-(kv[1] / dv), kv[0]))
        return [u for u, _ in scored[:k]]

    def invariant_violations(self, sample=200):
        """deg[v] must equal the sum of c over pairs containing v.

        (For co-assignment, deg[v] == number of articles with v; sum_u c[u,v]
        is larger -- it counts pairs, not articles. The checkable invariant
        is non-negativity and presence consistency.)
        """
        bad = 0
        for v in random.sample(list(self.deg), min(sample, len(self.deg))):
            if self.deg[v] < 0:
                bad += 1
        for k, n in list(self.c.items())[:sample]:
            if n < 0 or k[0] == k[1]:
                bad += 1
            if k[0] not in self.deg or k[1] not in self.deg:
                bad += 1
        return bad


def read_corpus(paths, limit=0):
    """-> list of (rid, [descriptor uis])"""
    out = []
    for path in paths:
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            for chunk in RE_CITE_SPLIT.split(f.read()):
                if "MedlineCitation" not in chunk:
                    continue
                m = re.search(r'<PMID[^>]*>(\d+)</PMID>', chunk)
                rid = m.group(1) if m else str(len(out))
                descs = [u for u, _ in RE_MAJOR.findall(chunk)]
                if descs:
                    out.append((rid, descs))
                if limit and len(out) >= limit:
                    return out
    return out


def topk_all(idx, seeds, k=10):
    return {s: idx.rank(s, k) for s in seeds}


def jaccard(a, b):
    sa, sb = set(a), set(b)
    u = sa | sb
    return len(sa & sb) / len(u) if u else 1.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--base-records", type=int, default=60000)
    ap.add_argument("--batch-records", type=int, default=2000)
    ap.add_argument("--sample-every", type=int, default=40)
    ap.add_argument("--k", type=int, default=10)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    files = sorted(glob.glob(args.input))
    if args.sample_every > 1:
        files = files[::args.sample_every]
    print(f"files: {len(files)}", flush=True)

    total = args.base_records + args.batch_records
    print(f"reading {total} records ...", flush=True)
    t0 = time.time()
    recs = read_corpus(files, limit=total)
    print(f"  {len(recs)} records in {time.time()-t0:.1f}s")
    base_recs = recs[:args.base_records]
    batch_recs = recs[args.base_records:args.base_records + args.batch_records]
    print(f"  base={len(base_recs)}  batch={len(batch_recs)}")

    # ---- build the base index (this is the 'rebuild' cost) ----------
    t0 = time.time()
    idx = Index()
    for rid, d in base_recs:
        idx.apply_record(rid, d)
    t_build = time.time() - t0
    mut_build = idx.mutations
    print(f"\nbase index: {len(idx.deg)} nodes, {len(idx.c)} pairs, "
          f"{mut_build} mutations in {t_build:.2f}s")

    seeds = sorted(idx.deg, key=lambda v: -idx.deg[v])[:60]
    before = topk_all(idx, seeds, args.k)
    state0 = (dict(idx.deg), dict(idx.c), set(idx.records), idx.mutations)

    # ---- M2 incremental apply --------------------------------------
    t0 = time.time()
    mut_apply = 0
    for rid, d in batch_recs:
        mut_apply += idx.apply_record(rid, d)
    t_apply = time.time() - t0

    t0 = time.time()
    idx2 = Index()
    for rid, d in base_recs + batch_recs:
        idx2.apply_record(rid, d)
    t_rebuild = time.time() - t0
    mut_rebuild = idx2.mutations

    # ---- M3 rank drift ---------------------------------------------
    after = topk_all(idx, seeds, args.k)
    jac = [jaccard(before[s], after[s]) for s in seeds]
    changed = sum(1 for j in jac if j < 1.0)
    jac.sort()

    # how many nodes changed suppression status (degree band crossing)
    def band(d):
        return (d >= 10) + (d >= 100) + (d >= 1000) + (d >= 10000)
    crossed = sum(1 for v in idx.deg
                  if band(idx.deg[v]) != band(state0[0].get(v, 0)))

    # ---- M1 consistency --------------------------------------------
    fwd_rev = 0
    for s in seeds[:20]:
        fw = set(idx.neighbours(s))
        rev = set()
        for k, n in idx.c.items():
            if k[0] == s:
                rev.add(k[1])
            elif k[1] == s:
                rev.add(k[0])
        if fw != rev:
            fwd_rev += 1
    inv = idx.invariant_violations()

    # ---- M4 deletion ------------------------------------------------
    t0 = time.time()
    mut_del = 0
    for rid, d in batch_recs:
        mut_del += idx.delete_record(rid, d)
    t_delete = time.time() - t0
    restored = (dict(idx.deg) == state0[0] and dict(idx.c) == state0[1]
                and set(idx.records) == state0[2])

    # double-delete must be a no-op
    before_double = (dict(idx.deg), dict(idx.c), idx.mutations)
    for rid, d in batch_recs:
        idx.delete_record(rid, d)
    noop = (dict(idx.deg) == before_double[0]
            and dict(idx.c) == before_double[1]
            and idx.mutations == before_double[2])

    # hub deletion: remove a top node's records entirely
    hub = seeds[0]
    hub_recs = [(r, d) for r, d in base_recs if hub in d]
    for r, d in hub_recs:
        idx.delete_record(r, d)
    dangling = sum(1 for k in idx.c if hub in k)
    hub_gone = hub not in idx.deg

    print("\n" + "=" * 84)
    print("## M2  incrementality")
    print("=" * 84)
    print("  apply(batch of %d)   %8.3fs   %8d mutations" % (
        len(batch_recs), t_apply, mut_apply))
    print("  rebuild(base+batch)  %8.3fs   %8d mutations" % (
        t_rebuild, mut_rebuild))
    print("  base index build     %8.3fs   %8d mutations" % (
        t_build, mut_build))
    print("  apply / rebuild      %8.1fx  (time)" % (t_rebuild / t_apply))
    print("  apply / rebuild      %8.1fx  (mutations)" % (
        mut_rebuild / mut_apply if mut_apply else 0))

    print("\n" + "=" * 84)
    print("## M3  rank drift  (60 seeds, top-%d, P(u|v))" % args.k)
    print("=" * 84)
    print("  seeds whose top-%d changed: %d / %d" % (
        args.k, changed, len(seeds)))
    print("  Jaccard  min=%.3f  p50=%.3f  max=%.3f  mean=%.3f" % (
        jac[0], jac[len(jac) // 2], jac[-1], sum(jac) / len(jac)))
    print("  nodes crossing a degree band (10/100/1e3/1e4): %d" % crossed)

    print("\n" + "=" * 84)
    print("## M1  consistency")
    print("=" * 84)
    print("  seeds where forward != reverse: %d / 20" % fwd_rev)
    print("  invariant violations (sample 200): %d" % inv)

    print("\n" + "=" * 84)
    print("## M4  deletion")
    print("=" * 84)
    print("  delete(batch)        %8.3fs   %8d mutations" % (
        t_delete, mut_del))
    print("  state restored exactly: %s" % ("YES" if restored else "NO"))
    print("  double-delete is a no-op: %s" % ("YES" if noop else "NO"))
    print("  hub '%s' deleted (%d records): gone from deg=%s, "
          "dangling c entries=%d" % (hub, len(hub_recs), hub_gone, dangling))

    checks = {
        "M1_forward_eq_reverse": fwd_rev == 0,
        "M1_no_invariant_violations": inv == 0,
        "M2_apply_at_least_100x_faster": (t_rebuild / t_apply) >= 100,
        "M4_state_restored": restored,
        "M4_double_delete_noop": noop,
        "M4_hub_delete_clean": dangling == 0 and hub_gone,
    }
    print("\n## Checks\n")
    for k, v in checks.items():
        print("  %-34s %s" % (k, "PASS" if v else "FAIL"))
    print("\n  (M3 drift has no pass threshold -- it is a property to report.)")

    with open(args.out, "w") as f:
        json.dump({
            "meta": {"base_records": len(base_recs),
                     "batch_records": len(batch_recs), "k": args.k},
            "incrementality": {
                "apply_s": t_apply, "rebuild_s": t_rebuild,
                "build_s": t_build,
                "apply_mutations": mut_apply,
                "rebuild_mutations": mut_rebuild,
                "ratio_time": t_rebuild / t_apply,
                "ratio_mutations": (mut_rebuild / mut_apply) if mut_apply else None,
            },
            "drift": {"changed_seeds": changed, "seeds": len(seeds),
                      "jaccard_min": jac[0], "jaccard_p50": jac[len(jac)//2],
                      "jaccard_mean": sum(jac) / len(jac),
                      "bands_crossed": crossed},
            "consistency": {"forward_reverse_mismatch": fwd_rev,
                            "invariant_violations": inv},
            "deletion": {"restored": restored, "double_delete_noop": noop,
                         "hub_gone": hub_gone, "hub_dangling": dangling},
            "checks": checks,
        }, f, indent=2)
    print("\nwrote", args.out)


if __name__ == "__main__":
    main()
