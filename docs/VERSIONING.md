# Versioning — MeshGraph · JavaM · mJVM

**Scope:** public-facing libraries and products in this M-stack.  
**Style:** [Semantic Versioning 2.0.0](https://semver.org) — `MAJOR.MINOR.PATCH[-prerelease]`.  
**Tags:** `vMAJOR.MINOR.PATCH` on the GitHub repo (e.g. `v0.9.0`, `v1.0.0-rc.1`).

| Product | Code / repo | What we version |
|---------|-------------|-----------------|
| **JavaM** | `mjandrews1/JavaM` | JvMumps full-M engine, corpus runner, smoke, `tests/conformance.json` contract |
| **mJVM** | same repo (`mjvm.*` + `build/`) | JVM-native compiler/runtime/CLI |
| **MeshGraph** | `mjandrews1/ydb-mesh` | YottaDB biomedical citation index/API (`^GRAPH`, `^PUBMED`, `^PTERM`, …) |

Internal checkouts may keep old directory names (`~/jvmumps`); **git remote and docs use JavaM**.

---

## 1. When a version number changes

| Change | Bump |
|--------|------|
| Docs, CI, branding, comments only | **PATCH** or no release |
| Bugfix, no contract change (hang, false positive, perf without semantics) | **PATCH** |
| Additive: new optional flag, new API function, new backend **behind the same contract** | **MINOR** |
| New language capability that old callers can ignore (new `$Z*`, extra corpus cases) | **MINOR** |
| **Breaking:** M semantics, corpus **expected** values, global schema, CLI required flags, Dafny lemma names that clients use | **MAJOR** |
| Anything else that would surprise a pinned consumer | **MAJOR** |

### Project-specific rules

1. **Corpus expecteds are contract.** Changing a case `expected` without citing **ISO/IEC 11756** or a live **RSM** rule is forbidden; if the change is real, it is a **MAJOR** (or a clearly documented MINOR if purely additive cases).
2. **Dafny (`m-semantics`) is the sole proof tool.** Public lemma/API renames that ports implement = **MAJOR**. Internal lemmas = PATCH/MINOR.
3. **MeshGraph globals:** adding a node type or subscript is **MINOR**; renaming/removing a documented global or edge `rel` is **MAJOR**.
4. **Engine vs LineInterp:** native score is the release gate; debug interpreters must not change `MATCH`/`ERR` for a tag without a changelog entry.
5. **Prerelease** (`-rc.1`) allowed for “all tests green but FileMan/limits incomplete.”

### Gates before **any** tag

- [ ] Required CI green (`smoke` / `test` / `dafny` as applicable)
- [ ] `tools/ci-block-probe.sh` prints **ALL PASS**
- [ ] `docs/RELEASE-CHECKLIST.md` followed
- [ ] Changelog section for the tag (below)

---

## 2. Shippable product (measurable)

“Shippable” means **gates green**, not “feature complete.” `0.x` may ship with known gaps listed in the release notes.

### Shared

| Criterion | Measure |
|-----------|---------|
| Reproducible build | Documented toolchain (JDK `--release 21`, Python 3.12+, YottaDB r2.06) |
| CI | Workflow + **required** status check on `main` |
| Release probe | `ci-block-probe.sh` ALL PASS |
| Hygiene | No secrets; LICENSE + attribution current |
| Honesty | Known misses/limits named in notes |

### JavaM (`MAJOR.MINOR.PATCH`)

| Gate | 0.x shippable | **1.0.0** |
|------|---------------|-----------|
| Corpus | MATCH=**131** MISS=**8** ERR=**0** (or better) | same, miss list documented |
| Native mJVM path | `MjvmNativeScore` same numbers | same |
| `make smoke` | J0–J12 + FmJv green | green |
| **FileMan Tier A** | optional | **no ENGINE GAP** required |
| Multi-host | Linux + Mac `--release 21` | required |

### mJVM

| Gate | 0.x | **1.0.0** |
|------|-----|-----------|
| Native parity | 131/8/0 | 131/8/0 |
| CLI | `mjvm` scores corpus | drop-in story documented |
| FileMan | optional | Tier A without ENGINE GAP |
| Perf baseline | optional table | recorded for the tag (`MjvmBench` / JMH) |

### MeshGraph

| Gate | 0.x | **1.0.0** |
|------|-----|-----------|
| Load counts | `^PUBMEDSTAT` / edge totals published | stable schema |
| PTERM | build completes; search returns ranked PMIDs | BM25 + phrases trusted |
| Graph API | `related()` (+ `related_rev` when shipped) | both documented |
| Safety | no destructive tests on production globals | enforced |
| User docs | index ≠ evidence; **not medical advice** | on portal + README |

---

## 3. Changelog template

```markdown
## [0.9.0] — YYYY-MM-DD
### Added
### Changed
### Fixed
### Contract
- corpus: … (ISO/RSM cite)
- Dafny: …
### Known gaps
- …
```

---

## 4. What we do *not* version this way

- Host-only ops (Caddy, UFW) — note in `ydb-infra` commits  
- Frozen **fst** — tag `frozen-2026-10-09` only  
- Research writeups under `docs/research/` — dated filenames, not SemVer  

---

## 5. Current intent (2026-10-11)

| Product | Next tag |
|---------|----------|
| JavaM | **v0.9.0** after path/rename docs; **v1.0.0** after FileMan Tier A |
| mJVM | **v0.9.0** with JavaM; **v1.0.0** with FileMan + CLI |
| MeshGraph | **v0.2.0** after ydb-mesh#12 BM25; **v1.0.0** after #12 + related_rev |

Regenerate **`~/CRITICAL_PATH.md`** from `docs/MASTER_CRITICAL_PATH.md` on release.
