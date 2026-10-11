#!/usr/bin/env python3
"""fst#7 — D+D coordination detector from MeSH Annotation.

Annotation is the ONLY place MeSH records descriptor+descriptor
coordination. EntryCombination is 100% Descriptor+Qualifier (verified:
1,000/1,000). The D+D half is prose:

    "Abelson murine leukemia virus infection: coordinate with
     RETROVIRIDAE INFECTIONS + TUMOR VIRUS INFECTIONS + LEUKEMIA, EXPERIMENTAL"

    "Accidents, Traffic ... do not coordinate with AUTOMOBILES unless ..."

Detector: extract the descriptor NAMES named in a coordinate / do-not-
coordinate instruction, and resolve them against the MeSH descriptor
name index. Unresolvable strings ("site (organ/disease term)",
"specific type of abortion") are placeholders and are dropped -- that is
the main source of false positives.

Outputs a labelled pair set:
    host --COORD--> name     positive coordination
    host --NOCOORD--> name   negative ("do not coordinate with")
"""
import gzip
import json
import re
import sys
from collections import defaultdict

DESC_RE = re.compile(
    r"<DescriptorRecord(?:\s[^>]*)?>(.*?)</DescriptorRecord>", re.S)
UI_RE = re.compile(r"<DescriptorUI>([^<]+)</DescriptorUI>")
NAME_RE = re.compile(r"<DescriptorName>\s*<String>([^<]+)</String>")
ANN_RE = re.compile(r"<Annotation>(.*?)</Annotation>", re.S)

# Names in Annotation are printed in the Index Medicus form, i.e. UPPER
# CASE (NLM: "MeSH terms are in upper case" for the printed vocabulary).
# Qualifiers ride along as /lowercase.
NAME_TOKEN = re.compile(r"[A-Z][A-Z0-9,\-]*(?:[ ][A-Z0-9,\-]*)*")

# Split an instruction into "there is a coordinate directive" and pull the
# name runs out of it.
NEG_RE = re.compile(r"\bdo\s+not\s+coordinat\w*", re.I)
POS_RE = re.compile(r"\bcoordinat\w*", re.I)
# NB: do NOT split on \bnot\b -- that tears "do not coordinate" apart and
# silently converts every negative instruction into a positive one. The
# earlier version did exactly that and reported 0 NOCOORD pairs while
# emitting "Abstracting and Indexing -> Medicine" as a COORD.
CLAUSE_SPLIT = re.compile(r"[;.\n]|\bbut\b|\bunless\b|\bonly\b|\bexcept\b", re.I)

# A coordinate directive, with its negation captured, plus the text that
# follows it up to the next clause boundary.
DIRECTIVE = re.compile(
    r"(?:(do\s+not)\s+)?coordinat\w*"
    r"((?:\s+(?:IM|also|here|with|the|a|an|specific|any|only)\b)*"
    r"[^;.\n]*)", re.I)


def norm_name(s):
    return " ".join(s.split()).rstrip(",:;.").strip()


def index_descriptors(path):
    """name (upper-cased) -> ui, plus exact-name lookup."""
    by_upper = {}
    with gzip.open(path, "rt", errors="replace") as f:
        for body in DESC_RE.findall(f.read()):
            u = UI_RE.search(body)
            n = NAME_RE.search(body)
            if u and n:
                by_upper[norm_name(n.group(1)).upper()] = (u.group(1).lstrip("*"), n.group(1))
    return by_upper


def extract_names(clause, by_upper):
    """All-caps runs in the clause that resolve to a real descriptor."""
    found = []
    for run in NAME_TOKEN.findall(clause):
        run = norm_name(run)
        if not run or len(run) < 3:
            continue
        key = run.upper()
        if key in by_upper:
            found.append(by_upper[key])
            continue
        # try progressively shorter left prefixes: "LEUKEMIA, EXPERIMENTAL"
        # and also "RUPTURE" out of "ACHILLES TENDON /inj with RUPTURE"
        words = key.split()
        for k in range(len(words) - 1, 0, -1):
            cand = " ".join(words[:k])
            if cand in by_upper:
                found.append(by_upper[cand])
                break
    # de-dup, preserve order
    seen, out = set(), []
    for ui, nm in found:
        if ui not in seen:
            seen.add(ui)
            out.append((ui, nm))
    return out


def main():
    desc_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else "/home/mark/dd-coord.json"

    print("indexing descriptors ...", flush=True)
    by_upper = index_descriptors(desc_path)
    print("  descriptors: %d names" % len(by_upper))

    pairs = []          # (host_ui, host_name, target_ui, target_name, kind, annotation)
    n_ann = 0
    n_pos_ann = 0
    n_neg_ann = 0
    n_plus = 0
    raw_hits = 0
    resolved = 0

    with gzip.open(desc_path, "rt", errors="replace") as f:
        for body in DESC_RE.findall(f.read()):
            u = UI_RE.search(body)
            n = NAME_RE.search(body)
            if not (u and n):
                continue
            host_ui = u.group(1).lstrip("*")
            host_name = n.group(1)
            for ann in ANN_RE.findall(body):
                text = " ".join(ann.split())
                if not POS_RE.search(text):
                    continue
                n_ann += 1
                is_neg = bool(NEG_RE.search(text))
                if is_neg:
                    n_neg_ann += 1
                else:
                    n_pos_ann += 1
                if " + " in text:
                    n_plus += 1

                for m in DIRECTIVE.finditer(text):
                    neg = bool(m.group(1))
                    clause = m.group(2)
                    # trim the clause at the next boundary so trailing
                    # prose does not contribute names
                    clause = CLAUSE_SPLIT.split(clause)[0]
                    names = extract_names(clause, by_upper)
                    # drop the host itself
                    names = [x for x in names if x[0] != host_ui]
                    raw_hits += len(names)
                    for tgt_ui, tgt_name in names:
                        resolved += 1
                        pairs.append({
                            "host": host_ui, "host_name": host_name,
                            "target": tgt_ui, "target_name": tgt_name,
                            "kind": "NOCOORD" if neg else "COORD",
                            "clause": clause[:220],
                        })

    pos = [p for p in pairs if p["kind"] == "COORD"]
    neg = [p for p in pairs if p["kind"] == "NOCOORD"]

    print()
    print("=== Annotation scan ===")
    print("  annotations mentioning coordinat*:  %d" % n_ann)
    print("    positive: %d   negative (do not coordinate): %d" % (n_pos_ann, n_neg_ann))
    print("    with '+' conjunctions:            %d" % n_plus)
    print()
    print("=== detector output ===")
    print("  candidate name runs:        %d" % raw_hits)
    print("  resolved to real descriptors:%d" % resolved)
    print("  resolution rate:            %.1f%%" % (100.0*resolved/raw_hits if raw_hits else 0))
    print("  COORD pairs:   %d" % len(pos))
    print("  NOCOORD pairs: %d" % len(neg))
    print()
    print("=== sample COORD (positive) ===")
    for p in pos[:14]:
        print("  %-26s -> %-34s" % (p["host_name"][:26], p["target_name"][:34]))
    print()
    print("=== sample NOCOORD (negative) ===")
    for p in neg[:12]:
        print("  %-26s -x %-34s" % (p["host_name"][:26], p["target_name"][:34]))

    with open(out_path, "w") as f:
        json.dump({"pairs": pairs,
                   "stats": {"ann_with_coord": n_ann, "pos_ann": n_pos_ann,
                             "neg_ann": n_neg_ann, "plus_ann": n_plus,
                             "raw_hits": raw_hits, "resolved": resolved,
                             "coord_pairs": len(pos), "nocoord_pairs": len(neg)}},
                  f, indent=2)
    print("\nwrote", out_path)


if __name__ == "__main__":
    main()
