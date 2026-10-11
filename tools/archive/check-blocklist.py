#!/usr/bin/env python3
"""Smoke-check: does the fst#2 blocklist catch the measured top-20 hubs?"""
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location("hs", "/home/mark/hub-suppression.py")
hs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hs)

trees = json.load(open("/home/mark/mesh-trees.json"))
base = json.load(open("/home/mark/hub-out/hub-baseline.json"))
hubs = next(b for b in base["edge_types"]
            if b["edge_type"] == "art->mesh")["top_hubs"]

ok = 0
for h in hubs:
    ui = h["id"].replace("mesh:", "")
    bl = hs.is_blocked(ui, trees)
    if bl:
        ok += 1
    name = (h.get("name") or "")[:36]
    print("%-5s %-12s %-36s %s" % ("BLOCK" if bl else "keep",
                                   ui, name, format(h["degree"], ",")))
print("\nblocked %d/%d of the measured top-20" % (ok, len(hubs)))
