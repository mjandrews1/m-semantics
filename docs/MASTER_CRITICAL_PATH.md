# Master critical path — all projects (unified)

**Last updated:** 2026-10-27 (end of session) · **Home:** `m-semantics/docs/MASTER_CRITICAL_PATH.md` · **≡** `~/CRITICAL_PATH.md`
**Detail docs:** JavaM `jvmumps/CRITICAL_PATH.md` · `jvmumps/docs/ROADMAP-0.5.0.md` · mjvm `mjvm/docs/` · inventory `m-semantics/docs/MASTER-INVENTORY.md`

**Name lock:** **MeshGraph** = product · **`ydb-mesh`** = code · **JavaM** = `mjandrews1/JavaM` (JvMumps) · **mjvm** = `mjandrews1/mjvm` (JIT engine, now a separate repo) · **tsx** = Comdb2 time-series.

**Focus (end of 2026-10-27):** mjvm v2.2.2 shipped · U04 commissioned (CI runner, all 4 repos green on self-hosted) · fleet hardened (key-only SSH, UFW everywhere, public 22 closed, edge containerized + fenced on U03) · **MeshGraph RESUMED** (services + edge + daily updates + backup timers live) · **Dafny corpus 547 verified** (GraphStore + BM25 + Scan) · **swiftm (spec-first M in Swift) PROPOSED** as P7 · c3fst deprecated · remaining: portal rotation (user), U02 backup second copy, mjvm class-4 comma backlog.

## How to read

Priority-ordered path. Status: **OPEN** · **IN FLIGHT** · **DONE** · **FROZEN** · **PAUSED**.

---

## Project map (end of 2026-10-27)

| Project | Role | State | Stream |
|---------|------|-------|--------|
| **mjvm** | M → JVM JIT engine (v2.2.2, GAUNTLET 134/134, CI green on u04) | active, Mac-only tree | **P1** |
| **JavaM** (JvMumps) | full-M oracle + LineEngine (v1.2.0, 1.0 gate; repo ARCHIVED) | active-local | **P2** |
| **m-semantics** | Dafny spec (**547 lemmas**: 464 M-sem + 25 GraphStore + 42 BM25 + 16 Scan) + master docs | active | P2 |
| **MeshGraph / ydb-mesh** | YottaDB citation index (41.2M articles, 2.8B postings; repo ARCHIVED) | **ACTIVE — resumed 2026-10-27** | **P5** |
| **m-lsp** | language server | active, clean | P3 |
| **mformatter** | M formatter | idle | P3 |
| **swiftm** (proposed) | spec-first M in Swift — validates Dafny proofs against an independent implementation; native Apple Silicon; actor-based JOB/LOCK | **PROPOSED** — after P1/P2 stabilize | **P7** |
| **tieredstore-rs** | Rust TieredStore prototype (published, CI green on u04) | active | P4 |
| **pymumps** | peer corpus host (restored on Mac) | active | P5 |
| **fileman** | frozen VistA corpus | frozen | FROZEN |
| **tsx / comdb2** | time-series + SQL plane | **PAUSED** | FROZEN |
| **RSM** | archived → `U02:coldstore/mac-rsm-2026-10-26/` | FROZEN | FROZEN |

---

## Critical path (end of 2026-10-27)

```
  P0a Portal password rotation               (user)
  P0b U02 meshgraph-backup second copy       (user decision: U04 LV? 5th host? accept risk?)

  P1a mjvm compiler coverage 36.4% → 60%      (peephole + error paths first)
  P1b mjvm VistA class-3: postcond 9,896  ← next after comma; now the dominant class
  P2a JavaM REPL                             (#35/#36 — both engines)
  P2b JavaM rename hygiene + VistA full run   (#27, #34)

  P5a MeshGraph: post-heal phantom cleanup     (check catch-up result → clean PTERM)
  P5b MeshGraph: first post-resume backup      (quiescent-copy after heal verified)
  P5c MeshGraph: BM25 WAND pruning            (gated by proven PrunedScanYieldsTopK)
  P5d MeshGraph: MCP registry listings        (ydb-mesh#28 — Smithery + official)
  P5e MeshGraph: MARC author pass + updatefile retention (small)
  P7  swiftm: spec-first M in Swift            (after P1b lands; validates Dafny)
```

---

## P0 — Immediate (user)

| Work | Status | Note |
|------|--------|------|
| Rotate portal credential (`home.flamingyak.com`) | **OPEN** (user) | Scrubbed from skill files 2026-10-26; rotation itself outstanding |
| U02 `meshgraph-backup` (222G) second copy | **OPEN** (user) | Top data risk. U04 has 828G free VG; decision pending |

## P1 — mjvm (primary dev)

| Work | Status | Note |
|------|--------|------|
| GAUNTLET 134/134 · corpus 139/139 · CoreUnitTest 135/135 | **DONE** | Verified on Mac + u04 CI (GAUNTLET green post-gate-tuning) |
| Silent-recovery audits (rounds 1+2) | **DONE — v2.2.2** | 7 sites fixed, 45 regression tests, all suites green |
| Compiler coverage | **MEASURED, TARGET OPEN** | 36.4% lines (total project 79%). 60% compiler target: peephole + error paths first |
| **VistA swallowed-syntax backlog** | **IN FLIGHT — classes 1-2-4 DONE, class 3 (postcond) next** | Baseline 21,452 routines (63.2%) → 14,430 (42.5%) after class 2 → **9,498 (28.0%)** after class 4. Comma class: 17,057 → 760 (**−96%**). Remaining: **postcond ~9,896 (next)** → @ ~5,649 → comma residue 760 → dotted ~2,483 → $ ~1,182 → SET ~1,180 → tail. Detail: `mjvm/docs/VISTA-SYNTAX-BACKLOG.md` |
| CI fix (untracked jars + gates) | **DONE** | archunit + jmh-core jars tracked; GAUNTLET env-overridable gates; green on u04 |

## P2 — JavaM / m-semantics

| Work | Ticket | Status |
|------|--------|--------|
| 1.0 gate (FileMan Tier A/B/C, 135/4/0) | JavaM#32 #25 #26 | **DONE** (2026-10-17) |
| v1.2.0 release | — | **DONE** |
| REPL both engines | JavaM#35 #36 | **OPEN** ← next attack |
| Rename leftovers (docs/CI badges) | JavaM#27 | **OPEN** |
| VistA full run under JavaM + mJVM | JavaM#34 | **OPEN** (last: 99.97%) |
| Dafny corpus: **547 verified** | m-semantics | **DONE this cycle** (M-semantics 464 + GraphStore 25 + BM25 42 + Scan 16) |

### Dafny proof files (all 0 errors, Dafny 4.11, CI-verified)

| File | Lemmas | Content |
|---|---|---|
| MSemantics.dfy + MPattern.dfy + MControl.dfy | 464 | M-language semantics (numeric scan, pattern match, control flow) |
| **GraphStore.dfy** | 25 | MeshGraph edge invariants: paired relation datatype (orientation unrepresentable), `^GRAPH`/`^GRAPHREV` two-record model, count agreement, no-dangling, index integrity (`indexed ⇒ stored`) with phantom witness + repair lemma |
| **BM25.dfy** | 42 | BM25 arithmetic (nonneg, saturation `≤ Idf·(k1+1)`, tf-monotone, length-norm, b=0 flatness), exact top-k scan, **WAND pruning soundness** (`PrunedScanYieldsTopK`), valid upper bounds (`SaturatedSumIsValidBound`) |
| **Scan.dfy** | 16 | Capped substring-walk semantics: results are prefix of full match set, truncated iff limit exceeded, untruncated = complete |
| TieredStore.dfy | existing | WAL/crash safety/eviction (unchanged this cycle) |

## P3 — m-lsp / mformatter

| Work | Status | Note |
|------|--------|------|
| m-lsp | **CLEAN** at 5aa377d | Self-hosted CI on u04 (PR #16) |
| mformatter | **DONE** | `run_mformatter.sh` committed + pushed (b04cc88) |

## P4 — tieredstore-rs

All items **DONE** (published, README, CI green on u04, initial spec sync). Keep tracking `TieredStore.dfy` as the spec evolves.

## P5 — MeshGraph (resumed 2026-10-27)

### Resume record

- **DB up on U01**: 222G `yottadb.dat` opened cleanly; corpus 41.2M articles / 2.8B postings. First catch-up run launched and completed 2026-10-27 (~1.2M update-era PMIDs loaded + indexed).
- **Services (U01, systemd)**: `mesh-search` (:8081 BM25), `mesh-mcp` (:8082 JSON-RPC, new unit), `ydb-web-server` (:9080), `ydb-dashboard-metrics`/`ydb-dashboard-ui` (:9188/9187). All bind U01's tailscale IP via drop-ins.
- **Public edge (U03 container `edge`)**: `/search*` → 8081, `/mcp*` → 8082, `/dashboard*` → 9188, `/ydb*` → 9080 on `home.flamingyak.com`; `mcp.flamingyak.com` vhost → 8082. Portal basicauth on `/ /ydb /ydb/*`; search/MCP/dashboard public. Fence + ufw scoped allows: container → `100.72.84.8:{8081,8082,9188,9080}` only.
- **Scheduled updates (U01)**: daily 03:00 (fetch updatefiles → load missing → BM25/PTERM catch-up → completeness probe); Sun 04:30 (author pass over updatefiles). Scripts local-only (repo archived). Fail-loud guards: zero-PMID extraction ABORT, load-fail ABORT before indexing (phantom guard).
- **Backup**: Sat 02:00 — quiescent-copy (refuses if writer active or journal growing); rsync to U02 via `.inprogress` + atomic rename; size-verify; previous kept as `.old`.
- **Dashboard**: metrics service fixed (CWD drop-in); HTML name-matching extended for `ydb_`-prefixed gauges; wrapper extended (load 1/5/15, disk %/free/total); `/dashboard` canonicalized to trailing slash at the edge. 17/22 cards fill.
- **c3fst**: entirely deprecated (mdbx purged, unit disabled, plan void).

### Open MeshGraph items

| # | Item | Priority | Effort |
|---|---|---|---|
| P5a | **Post-heal phantom cleanup** — check the catch-up run's `still_missing` count; if PTERM entries remain for PMIDs absent from `^PUBMED`, kill them + re-baseline `^PUBMEDSTAT` | high | < 1 hour |
| P5b | **First post-resume backup** — the U02 backup is stale (writers resumed today). Run `meshgraph-backup.service` after P5a. | high | overnight (quiescent-copy) |
| P5c | **BM25 WAND pruning** — implement `PrunedScanYieldsTopK` in `term_index.py` using per-term `Idf·(k1+1)` upper bounds. Proven sound; should bring 10-40s queries to interactive. | medium | session |
| P5d | **MCP registry listings** (ydb-mesh#28) — Smithery + official MCP registry; URL + manifest already documented | medium | < 1 hour |
| P5e | **MARC author pass** — catline/serline pass is manual; consider a monthly timer | low | small |
| P5f | **Updatefile retention** — daily update re-scans full-year 363-file set; consider deleting consumed files > N days old | low | small |

## P6 — Infrastructure (all DONE this cycle)

| Work | Status |
|------|--------|
| U04 commissioned (CI runner, all 4 repos green) | **DONE** |
| Key-only SSH fleet-wide, public 22 closed | **DONE** |
| UFW on all 4 hosts | **DONE** |
| Edge containerized + fenced on U03 (DMZ-equivalent containment) | **DONE** |
| Central logging (all 4 hosts + edge container → U03) | **DONE** |
| Logrotate (collector + caddy access log) | **DONE** |
| Mirror sync + health visibility | **DONE** |
| Logrotate on U03 `/var/log/remote` | **DONE** |

---

## P7 — swiftm: spec-first M in Swift (PROPOSED)

**Rationale:** a greenfield implementation of M in Swift for macOS, written to the ISO standard (11756) with the m-semantics Dafny proofs (547 lemmas) as the executable specification. Not a replacement for mjvm or JavaM — a **specification validation tool**.

### What it teaches

| Question | How swiftm answers it |
|---|---|
| Are the Dafny proofs complete? | Two independent implementations (JVM + Swift) against the same spec — any divergence is a proof gap or implementation bug |
| What does ISO M actually require? | Spec-first implementation exposes gaps the VistA-recovery approach can't see (dot-level semantics, SET evaluation order, postconditional universality, $ETRAP/JOB interaction) |
| What's the conforming core vs. VistA accretion? | Implement just enough to pass the 139-test corpus; measure the delta to full VistA conformance |
| Can M's concurrency be provable? | Swift actors for JOB/LOCK — compile-time data-race safety instead of runtime testing |
| How fast is native code? | GAUNTLET on Apple Silicon — a JVM vs. AOT performance comparison point |

### Architecture sketch

- **Swift Package Manager**: separate modules for parser, IR, runtime, storage
- **`enum MValue`** with associated values — the type system forces enumerating all value forms
- **Actor model** for JOB + LOCK — M's multi-process semantics map naturally to Swift's isolation guarantees
- **Swift protocols with associated types** for the global store — more expressive than Java's `StoreApi` interface
- **Value semantics** for globals — Swift's copy-on-write structs apply `GraphStore.dfy` invariants naturally
- **AOT compilation** — no JVM warm-up; relevant for M's traditional quick-script role

### Scope guard (what NOT to do)

- **Do NOT** implement the full VistA syntax surface (21k swallowed-line cases) — that's mjvm's job
- **Do NOT** replace JavaM as the conformance oracle
- **Do NOT** add server deployment — macOS-only; the fleet is Linux
- **Do NOT** start before P1b (comma) lands — the Dafny spec needs to cover the comma semantics first

### Prerequisites (before starting)

1. **P1b (VistA class-4 comma) lands** — the comma semantics need to be in the Dafny proofs
2. **A `MCommand.dfy`** — the command dispatch semantics (D/G/K/W multi-arg loops, postconditionals) formalized
3. **A "minimal conforming M" test definition** — which of the 139 corpus tests are ISO-required vs. vendor-specific

### Open question

Whether to write swiftm against the **Dafny proofs directly** (extract the spec as Swift protocol contracts) or against the **ISO standard document** (with Dafny as the cross-check). The former is more rigorous; the latter is more independent. Recommend: start with ISO, validate with Dafny — the divergence is the interesting part.

---

## Done (historical — do not reopen)

- **2026-10-26 fleet cleanup** — all 5 phases + follow-ups (PRs #47 #48)
- **2026-10-27 U04 commissioned** — fleet CI runner; mjvm CI red-streak (untracked jars) found + fixed
- **2026-10-27 fleet posture hardened** — key-only SSH, UFW, Caddy+fail2ban edge-only, public 22 closed
- **2026-10-27 edge containerized** — LXD container `edge`, fenced, snapshots, DMZ-equivalent containment
- **2026-10-27 MeshGraph resumed** — services, edge, daily/weekly timers, backup timer, Dafny proofs (GraphStore + BM25 + Scan)
- **2026-10-27 Dafny corpus 464 → 547** — GraphStore.dfy, BM25.dfy, Scan.dfy (PRs #67 #69 #70)
- **mjvm v2.2.0 / v2.2.1 / v2.2.2** correctness hardening — 17 bugs total, 45+ regression tests
- **JavaM v0.4.0 / v0.5.0 / v1.2.0** · perf review · concurrency audits · Cdb2 LOCK/TSTART
- **MeshGraph** BM25 rebuild + author-pass + related_rev (pre-pause, all green)
- **P ports** Py/C3/JavaM + mJVM native — corpus freeze
- **U03 commissioned** (mirrors + DNS) 2026-10

## Scope lock

| Role | |
|------|--|
| mjvm + JavaM | primary development |
| MeshGraph | data product, **ACTIVE** |
| RSM | oracle only (archived) |
| Py/C3 | corpus freeze |
| tsx / comdb2 | time-series plane, **PAUSED** |
| fst / O'Kane / FreeM | frozen / adjunct |
| swiftm | spec validation, **PROPOSED** (after P1b) |
| m-semantics | spec + master docs home (PR-only main) |
