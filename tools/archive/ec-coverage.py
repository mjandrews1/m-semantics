#!/usr/bin/env python3
"""fst#7 pass 2 -- what does EntryCombination cover, and what does it not?

Question: EC is all D+Q. The NLM example of coordination in 'Use of MeSH
in Indexing' is D+D -- 'jejunal enteritis may be expressed by the use of
Jejunal Diseases + Enteritis'. Is there any machine-readable record of
that half?

Scan desc2026 for Annotation 'coordinate' instructions, and profile the
EntryCombination set.
"""
import gzip
import json
import re
import sys
from collections import Counter, defaultdict

src = sys.argv[1] if len(sys.argv) > 1 else \
    "/home/mark/_data/mesh-staging/xml/desc2026.xml.gz"

RE_REC = re.compile(
    r"<DescriptorRecord(?:\s[^>]*)?>(.*?)</DescriptorRecord>", re.S)
RE_DUI = re.compile(r"<DescriptorUI>([^<]+)</DescriptorUI>")
RE_DNAME = re.compile(r"<DescriptorName>\s*<String>([^<]+)</String>")
RE_ANN = re.compile(r"<Annotation>(.*?)</Annotation>", re.S)
RE_CONSIDER = re.compile(r"<ConsiderAlso>(.*?)</ConsiderAlso>", re.S)
RE_EC = re.compile(r"<EntryCombination>(.*?)</EntryCombination>", re.S)
RE_REF_D = re.compile(r"<DescriptorReferredTo>\s*<DescriptorUI>([^<]+)</DescriptorUI>"
                      r"\s*<DescriptorName>\s*<String>([^<]+)</String>", re.S)
RE_REF_Q = re.compile(r"<QualifierReferredTo>\s*<QualifierUI>([^<]+)</QualifierUI>"
                      r"\s*<QualifierName>\s*<String>([^<]+)</String>", re.S)

COORD_PAT = re.compile(
    r"coordinat(?:e|ed|ing|ion)", re.I)

n_ann = 0
n_coord_ann = 0
coord_samples = []
n_consider = 0
consider_samples = []
hosts = Counter()
ec_targets = defaultdict(set)
n_ec = 0

with gzip.open(src, "rt", errors="replace") as f:
    for body in RE_REC.findall(f.read()):
        m = RE_DUI.search(body)
        if not m:
            continue
        host = m.group(1).lstrip("*")
        nm = RE_DNAME.search(body)
        host_name = nm.group(1) if nm else "?"

        for ann in RE_ANN.findall(body):
            n_ann += 1
            text = " ".join(ann.split())
            if COORD_PAT.search(text):
                n_coord_ann += 1
                if len(coord_samples) < 25:
                    coord_samples.append((host_name, text[:190]))

        for c in RE_CONSIDER.findall(body):
            n_consider += 1
            if len(consider_samples) < 15:
                consider_samples.append((host_name, " ".join(c.split())[:120]))

        for ec in RE_EC.findall(body):
            n_ec += 1
            hosts[host_name] += 1
            ds = RE_REF_D.findall(ec)
            qs = RE_REF_Q.findall(ec)
            for d_ui, d_nm in ds:
                ec_targets[d_nm].add(host_name)

print("descriptor records:      31110")
print("Annotation elements:     %d" % n_ann)
print("  mentioning 'coordinat':%d" % n_coord_ann)
print("ConsiderAlso elements:   %d" % n_consider)
print("EntryCombination blocks: %d" % n_ec)
print()
print("=== Annotation instructions mentioning coordination ===")
for nm, t in coord_samples[:20]:
    print("  %-28s %s" % (nm[:28], t))
print()
print("=== ConsiderAlso samples (free-text 'related roots') ===")
for nm, t in consider_samples[:12]:
    print("  %-28s %s" % (nm[:28], t))
print()
print("=== hosts with the most EntryCombinations ===")
for nm, c in hosts.most_common(12):
    print("  %-34s %d" % (nm[:34], c))
print()
print("=== many-to-one collapses (one ECOUT target from several hosts) ===")
multi = sorted(((t, sorted(h)) for t, h in ec_targets.items() if len(h) > 1),
               key=lambda kv: -len(kv[1]))
print("  targets fed by >1 host: %d" % len(multi))
for t, hs in multi[:12]:
    print("  %-34s <= %s" % (t[:34], ", ".join(h[:22] for h in hs[:4])))
