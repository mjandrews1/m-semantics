#!/usr/bin/env python3
"""Extract MeSH descriptor -> tree-number list from desc2026.xml.gz.

Used by the fst#2 blocklist: suppression is by tree CATEGORY, not by
hand-picked UI, so it survives annual MeSH releases.
"""
import gzip
import json
import re
import sys

src = sys.argv[1] if len(sys.argv) > 1 else \
    "/home/mark/_data/mesh-staging/xml/desc2026.xml.gz"
out = sys.argv[2] if len(sys.argv) > 2 else "/home/mark/mesh-trees.json"

# Record-per-descriptor: UI, Name, then every TreeNumber under it.
rec = re.compile(
    r"<DescriptorRecord(?:\s[^>]*)?>(.*?)</DescriptorRecord>", re.S)
ui_p = re.compile(r"<DescriptorUI>(D\d+)</DescriptorUI>")
name_p = re.compile(r"<DescriptorName>\s*<String>([^<]+)</String>")
tree_p = re.compile(r"<TreeNumber>([A-Z]\d+(?:\.\d+)*)</TreeNumber>")

m = {}
with gzip.open(src, "rt", errors="replace") as f:
    for body in rec.findall(f.read()):
        ui = ui_p.search(body)
        if not ui:
            continue
        nm = name_p.search(body)
        trees = tree_p.findall(body)
        m[ui.group(1)] = {
            "name": nm.group(1) if nm else "",
            "trees": trees,
        }

with open(out, "w") as f:
    json.dump(m, f)
print("descriptors:", len(m), "->", out)
# Show the categories the blocklist cares about.
for prefix, label in [
    ("N01.224", "Age Groups"),
    ("N01.224.600", "Persons"),
    ("V01", "Publication Characteristics"),
    ("V04", "Study Characteristics"),
    ("M01.526", "Anthropology/Education/Sociology"),
    ("H01.158", "Natural Science Disciplines"),
]:
    n = sum(1 for v in m.values() if any(t.startswith(prefix) for t in v["trees"]))
    print(f"  {prefix:16s} {label:42s} {n} descriptors")
