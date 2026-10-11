#!/usr/bin/env python3
"""fst#7 pass 1 — extract MeSH EntryCombination (ECIN / ECOUT).

NLM (MeSH XML Data Elements), verbatim:

  <EntryCombination> A reference to a specific Qualifier that is not to be
  used with the Descriptor in indexing. The <ECIN> element specifies the
  Qualifier and Descriptor combination that is PROHIBITED. Instead of this
  combination, another Descriptor is to be used, specified by the <ECOUT>
  element. For example, in the Descriptor for 'Abdomen', the <ECIN> refers
  to the use of 'Abdomen' with 'radiography' and the <ECOUT> specifies the
  Descriptor 'Radiography, Abdominal'. ... The <ECOUT> element may also be
  a Descriptor/Qualifier combination as well as a Descriptor.

ASCII MeSH: EC (ENTRY COMBINATION)

This is NLM's curated negative-indexing guidance: "these two things
express ONE concept; use the pre-coordinated form instead." It is the
machine-readable form of the coordination phenomenon in fst#7.
"""
import gzip
import json
import re
import sys
from collections import defaultdict

src = sys.argv[1] if len(sys.argv) > 1 else \
    "/home/mark/_data/mesh-staging/xml/desc2026.xml.gz"

RE_REC = re.compile(
    r"<DescriptorRecord(?:\s[^>]*)?>(.*?)</DescriptorRecord>", re.S)
RE_DUI = re.compile(r"<DescriptorUI>([^<]+)</DescriptorUI>")
RE_DNAME = re.compile(r"<DescriptorName>\s*<String>([^<]+)</String>")
RE_QUI = re.compile(r"<QualifierUI>([^<]+)</QualifierUI>")
RE_QNAME = re.compile(r"<QualifierName>\s*<String>([^<]+)</String>")
RE_EC = re.compile(r"<EntryCombination>(.*?)</EntryCombination>", re.S)
RE_ECI = re.compile(r"<ECIN>(.*?)</ECIN>", re.S)
RE_ECO = re.compile(r"<ECOUT>(.*?)</ECOUT>", re.S)
RE_REF_D = re.compile(r"<DescriptorReferredTo>\s*<DescriptorUI>([^<]+)</DescriptorUI>"
                      r"\s*<DescriptorName>\s*<String>([^<]+)</String>", re.S)
RE_REF_Q = re.compile(r"<QualifierReferredTo>\s*<QualifierUI>([^<]+)</QualifierUI>"
                      r"\s*<QualifierName>\s*<String>([^<]+)</String>", re.S)
RE_SIMPLE_D = re.compile(r"^<DescriptorReferredTo>\s*<DescriptorUI>([^<]+)</DescriptorUI>"
                         r"\s*<DescriptorName>\s*<String>([^<]+)</String>", re.S)


def parse_ref(block):
    """Return (kind, descriptor, qualifier) where descriptor/qualifier are
    (ui, name) or None."""
    d = RE_REF_D.search(block)
    q = RE_REF_Q.search(block)
    ds = (d.group(1).lstrip("*"), d.group(2)) if d else None
    qs = (q.group(1).lstrip("*"), q.group(2)) if q else None
    return ds, qs


def describe(ds, qs):
    if ds and qs:
        return f"{ds[1]}/{qs[1]}"
    if ds:
        return ds[1]
    if qs:
        return f"/{qs[1]}"
    return "?"


n_rec = 0
n_ec = 0
rows = []
by_shape = defaultdict(int)
by_qual = defaultdict(int)

with gzip.open(src, "rt", errors="replace") as f:
    for body in RE_REC.findall(f.read()):
        n_rec += 1
        m = RE_DUI.search(body)
        if not m:
            continue
        host_ui = m.group(1).lstrip("*")
        nm = RE_DNAME.search(body)
        host_name = nm.group(1) if nm else "?"
        for ec in RE_EC.findall(body):
            n_ec += 1
            ei = RE_ECI.search(ec)
            eo = RE_ECO.search(ec)
            if not ei or not eo:
                continue
            in_d, in_q = parse_ref(ei.group(1))
            out_d, out_q = parse_ref(eo.group(1))
            rows.append({
                "host": host_ui, "host_name": host_name,
                "ecin_d": in_d, "ecin_q": in_q,
                "ecout_d": out_d, "ecout_q": out_q,
            })
            shape = ("D+Q" if in_q else "D") + " -> " + \
                    ("D+Q" if out_q else ("D" if out_d else "?"))
            by_shape[shape] += 1
            if in_q:
                by_qual[in_q[1]] += 1

print("descriptor records scanned: %d" % n_rec)
print("EntryCombination blocks:    %d" % n_ec)
print("parsed ECIN/ECOUT pairs:    %d" % len(rows))
print()
print("=== ECIN -> ECOUT shapes ===")
for k, v in sorted(by_shape.items(), key=lambda kv: -kv[1]):
    print("  %-14s %5d" % (k, v))
print()
print("=== most common prohibited qualifiers ===")
for k, v in sorted(by_qual.items(), key=lambda kv: -kv[1])[:20]:
    print("  %-34s %4d" % (k, v))
print()
print("=== sample: 30 EntryCombinations ===")
print("%-30s %-34s -> %s" % ("HOST", "ECIN (prohibited)", "ECOUT (use instead)"))
print("-" * 100)
for r in rows[:30]:
    print("%-30s %-34s -> %s" % (
        r["host_name"][:30], describe(r["ecin_d"], r["ecin_q"])[:34],
        describe(r["ecout_d"], r["ecout_q"])))

with open(sys.argv[2] if len(sys.argv) > 2 else "/home/mark/ec.json", "w") as f:
    json.dump({"rows": rows, "by_shape": dict(by_shape),
               "by_qual": dict(by_qual)}, f, indent=2)
print("\nwrote", sys.argv[2] if len(sys.argv) > 2 else "/home/mark/ec.json")
