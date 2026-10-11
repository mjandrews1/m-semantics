#!/usr/bin/env python3
"""fst#7 — hand-check sheet for the D+D detector.

Prints each sampled pair next to the SOURCE CLAUSE it came from, so a human
can judge whether the extraction is correct without re-reading desc2026.
"""
import json
import random
import sys

d = json.load(open(sys.argv[1]))
pairs = d["pairs"]
n = int(sys.argv[2]) if len(sys.argv) > 2 else 25
seed = int(sys.argv[3]) if len(sys.argv) > 3 else 20260331

pos = [p for p in pairs if p["kind"] == "COORD"]
neg = [p for p in pairs if p["kind"] == "NOCOORD"]
rng = random.Random(seed)

# de-dup on (host,target,kind) so we judge distinct claims
seen, uniq_pos, uniq_neg = set(), [], []
for p in pos:
    k = (p["host"], p["target"], p["kind"])
    if k in seen: continue
    seen.add(k); uniq_pos.append(p)
for p in neg:
    k = (p["host"], p["target"], p["kind"])
    if k in seen: continue
    seen.add(k); uniq_neg.append(p)

print("distinct COORD pairs:   %d  (from %d raw, %d duplicate)"
      % (len(uniq_pos), len(pos), len(pos)-len(uniq_pos)))
print("distinct NOCOORD pairs: %d  (from %d raw, %d duplicate)"
      % (len(uniq_neg), len(neg), len(neg)-len(uniq_neg)))
print()

for label, pool, mark in (("COORD", uniq_pos, "->"),
                          ("NOCOORD", uniq_neg, "-x")):
    samp = rng.sample(pool, min(n, len(pool)))
    print("=" * 100)
    print("### %s sample (%d of %d distinct)  -- judge: is '%s' correctly extracted?"
          % (label, len(samp), len(pool), mark))
    print("=" * 100)
    for i, p in enumerate(samp, 1):
        print("%2d. %-28s %s %-32s" % (i, p["host_name"][:28], mark,
                                       p["target_name"][:32]))
        print("    clause: %s" % p["clause"].strip()[:170])
        print()
