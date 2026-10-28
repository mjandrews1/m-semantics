# Master critical path — all projects (unified)

**Last updated:** 2026-10-28 (post-resume heal session) · **Home:** `m-semantics/docs/MASTER_CRITICAL_PATH.md` · **≡** `~/CRITICAL_PATH.md`
**Detail docs:** JavaM `jvmumps/CRITICAL_PATH.md` · `jvmumps/docs/ROADMAP-0.5.0.md` · mjvm `mjvm/docs/` · inventory `m-semantics/docs/MASTER-INVENTORY.md`

**Name lock:** **MeshGraph** = product · **`ydb-mesh`** = code · **JavaM** = `mjandrews1/JavaM` (JvMumps) — **FROZEN oracle**; parser/lexer (and REPL) moved to mjvm, one codebase, one dev path going forward · **mjvm** = `mjandrews1/mjvm` (JIT engine) · **tsx** = Comdb2 time-series.

**Focus (end of 2026-10-28):** mjvm v2.2.2 shipped (P1b comma work in flight) · fleet hardened (key-only SSH, UFW everywhere, public 22 closed, edge containerized + fenced) · MeshGraph RESUMED + **post-resume heal DONE 2026-10-28** (retention semantics verified — NO phantom kill; dead PTERM guard fixed; 142,763 docs indexed; dangling cleared; WAND pruning live; updatefile retention live; first post-resume backup run) · **ydb-mesh repo reactivated** (PR #49: ops files + registry package + live tree) · Dafny corpus 547 verified · **JavaM REPL (#35/#36) verified DONE** — CI smoke restored to mjvm (c8ada1a) · **P8 M ecosystem survey cloned** (`~/m-ecosystem/`, 34 artifacts incl. GT.M V7.2-001) · **P9 GT.M instance RUNNING on U01:8181** · c3fst deprecated · remaining: portal rotation (user), U02 backup second copy (user), U01 journaling re-enable, mjvm comma backlog.

## How to read

Priority-ordered path. Status: **OPEN** · **IN FLIGHT** · **DONE** · **FROZEN** · **PAUSED**.

---

## Project map (end of 2026-10-28)

| Project | Role | State | Stream |
|---------|------|-------|--------|
| **mjvm** | M → JVM JIT engine (v2.2.2, GAUNTLET 134/134, CI green on u04) | active, Mac-only tree | **P1** |
| **JavaM** (JvMumps) | full-M oracle (v1.2.0, 1.0 gate) — **FROZEN**; parser/lexer + REPL live in mjvm; one codebase, one dev path | frozen, local reference | P2 |
| **m-semantics** | Dafny spec (**547 lemmas**: 464 M-sem + 25 GraphStore + 42 BM25 + 16 Scan) + master docs | active | P2 |
| **MeshGraph / ydb-mesh** | YottaDB citation index (44.4M corpus, 42.5M indexed docs, 7.0B postings; repo **ACTIVE — unarchived + upstreamed 2026-10-28**, PR #49) | **ACTIVE — resumed 2026-10-27, post-resume heal 2026-10-28** | **P5** |
| **m-lsp** | language server | active, clean | P3 |
| **mformatter** | M formatter | idle | P3 |
| **swiftm** (proposed) | spec-first M in Swift — validates Dafny proofs against an independent implementation; native Apple Silicon; actor-based JOB/LOCK | **PROPOSED** — after P1/P2 stabilize | **P7** |
| **tieredstore-rs** | Rust TieredStore prototype (published, CI green on u04) | active | P4 |
| **pymumps** | peer corpus host (restored on Mac) | active | P5 |
| **fileman** | frozen VistA corpus | frozen | FROZEN |
| **tsx / comdb2** | time-series + SQL plane | **PAUSED** | FROZEN |
| **RSM** | archived → `U02:coldstore/mac-rsm-2026-10-26/` | FROZEN | FROZEN |

---

## Critical path (end of 2026-10-28)

```
  P0a Portal password rotation               (user)
  P0b U02 meshgraph-backup second copy       (user decision: U04 LV? 5th host? accept risk?)
  P0c U01 YDB journaling re-enable           (OFF since Oct 10; post-resume writes unjournaled)

  P1a mjvm compiler coverage 36.4% → 60%      (peephole + error paths first)
  P1b mjvm VistA class-4: comma 17,057 (28.3%)  ← largest remaining backlog class
  P1c mjvm engine-gap items (mjvm#4–#10)       (micro-benchmark findings; #4 correctness first)
  P2b JavaM rename hygiene + VistA full run   (#27, #34)

  P5d MeshGraph: MCP registry listings        (ydb-mesh#28 — prep done, publish after restart)
  P5e MeshGraph: MARC author pass timer      (catline/serline pass is manual)
  P7  swiftm: spec-first M in Swift            (after P1b lands; validates Dafny)
  P8  M ecosystem survey — follow-ups          (SF mumps release; YDBTest cross-engine runs)
  P9  GT.M instance (U01)                      (running on 8181; persistence + hardening)
```

---

## P0 — Immediate

| Work | Status | Note |
|------|--------|------|
| Rotate portal credential (`home.flamingyak.com`) | **OPEN** (user) | Scrubbed from skill files 2026-10-26; rotation itself outstanding |
| U02 `meshgraph-backup` second copy | **OPEN** (user) | Top data risk. U04 has 828G free VG; decision pending |
| U01 YDB journaling re-enable | **OPEN** | `Journal State: OFF` since Oct 10 (pre-freeze; never re-enabled at resume) — every post-resume write (incl. the 2026-10-27/28 catch-up + heal) went straight to the .dat. Enable after the post-heal backup is verified on U02, ideally while quiesced |

## P1 — mjvm (primary dev)

| Work | Status | Note |
|------|--------|------|
| GAUNTLET 134/134 · corpus 139/139 · CoreUnitTest 135/135 | **DONE** | Verified on Mac + u04 CI (GAUNTLET green post-gate-tuning) |
| Silent-recovery audits (rounds 1+2) | **DONE — v2.2.2** | 7 sites fixed, 45 regression tests, all suites green |
| Compiler coverage | **MEASURED, TARGET OPEN** | 36.4% lines (total project 79%). 60% compiler target: peephole + error paths first |
| **VistA swallowed-syntax backlog** | **IN FLIGHT — classes 1-2 DONE, class 4 (comma) next** | Baseline 21,452 routines (63.2%) → **14,430 (42.5%)** after classes 1-2. Remaining: comma **17,057 (28.3%)** → postcond 16,204 (26.9%) → @ 4,168 → dotted 2,483 → $ 1,182 → SET 1,180 → tail 9,070. Detail: `mjvm/docs/VISTA-SYNTAX-BACKLOG.md` |
| CI fix (untracked jars + gates) | **DONE** | archunit + jmh-core jars tracked; GAUNTLET env-overridable gates; green on u04 |
| **Engine-gap micro-benchmark findings** | **OPEN — mjvm#4–#10** | 2026-10-28 four-engine benchmark (GT.M V7.2-001 / YDB r2.06 / RSM V1.83.1 / mJVM IR; data + methodology: `~/m-ecosystem/SURVEY.md`). mJVM vs GT.M/YDB: ~15x on compute loops, 33x on `$PIECE`, 15x on local sets. Filed: **#4** silent no-op `W:cond` (correctness — fix first; adjacent to P1b disambiguation) · **#5** portable harness in `bench/` (land before optimizing) · **#6** IR hot-loop audit (570ns/iter) · **#7** dense-numeric locals fast path · **#8** `$PIECE` hot path · **#9** `--jit` measurement + default decision · **#10** store-backend matrix. Side findings: GT.M/YDB parity confirmed; RSM `$ORDER` walks are **quadratic** (local + global) — fine for its oracle role, disqualifying for big-data use |

## P2 — JavaM / m-semantics

| Work | Ticket | Status |
|------|--------|--------|
| 1.0 gate (FileMan Tier A/B/C, 135/4/0) | JavaM#32 #25 #26 | **DONE** (2026-10-17) |
| v1.2.0 release | — | **DONE** |
| REPL both engines | JavaM#35 #36 | **DONE — closed at v0.9.0** (13ca164 + 210852e, jvmumps repo). Path was stale; verified live 2026-10-28: both shells (`jvmumps.Repl`, `mjvm.cli.Repl`) pass the scripted session against the mjvm build; the CI smoke lost in the mjvm split restored in `gauntlet.yml` (c8ada1a) |
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

### Post-resume heal (2026-10-28) — P5a/P5b/P5c/P5f DONE

**The headline finding: the 32.8M "phantom" PTERM entries are the retention design, not the historical bug — the planned phantom kill was cancelled.** A retention pass on 2026-10-17 (`tools/archive_mesh.py`, RETENTION.md) exported 33,458,179 `^PUBMED` articles below PMID 35,000,000 (389.5M nodes) to `U02:coldstore/meshgraph/pubmed-2026-10-17.csv.gz` (12.4G + a titles-only 1.2G export, manifest.json) and KILLed them from the live DB to shrink it. The PTERM index deliberately still covers the full corpus. Live store after the heal: **8,489,142 articles** (7,429,111 with abstracts); index: **42,514,186 docs / 7.0B postings**. Search over old literature returns PMIDs with empty titles by design (articles restorable from the coldstore export).

| # | Item | Status | Result |
|---|---|---|---|
| P5a | Post-heal phantom cleanup | **DONE — scope revised** | NO phantom kill (they are the corpus). Real findings fixed instead: (1) the daily-update PTERM catch-up guard was **dead** — `yottadb.data("PUBMED", …)` without the `^` caret silently returns 0, so every run reported "nothing loaded-but-unindexed" (only the caret form resolves in ydbpython); fixed + verified. (2) **142,763 docs were loaded-but-unindexed** (all title-bearing, newest PMIDs) — indexed via `term_index build`; `^PTERMSTAT docs 42,371,423 → 42,514,186`. (3) The 268 "dangling" refs are **4 MeSH SCR UIs** (C+9 digits — supplementary concepts, absent from the desc2026-only `^MESH` by design); loader now excludes SCR from the dangling counter, stat re-baselined to 0, probe prints `COMPLETENESS OK` |
| P5b | First post-resume backup | **DONE 2026-10-28** | Quiescent-copy run after the heal; size-verified swap on U02, previous kept as `.old` (numbers in inventory §9f) |
| P5c | BM25 WAND pruning | **DONE** | `bm25_search_wand` in `term_index.py` implements `PrunedScanYieldsTopK` (per-term `Idf·(k1+1)` saturated bounds; `bm25_search` delegates, old scan kept as parity oracle via `--scan`). A/B parity 6/6 exact (max diff 2.8e-14, float order only). Latency: multi-term queries **13–33s → 0.2–3.5s**. Two A/B-caught bugs fixed: int-subscript seeks silently swallowed as list-exhaustion; advance-to-pivot must be an inclusive `nextGE` ($ORDER is exclusive) or docs lose contributions. Phrase df capped at 20001 (parity with the scan path) + cached in new `^PTERMPHRASEDF` |
| P5f | Updatefile retention | **DONE** | `daily-update.sh` step 6: after a fully successful run, delete `pubmed*.xml.gz` + `.md5` older than `MESH_RETENTION_DAYS` (default 14, `0`/garbage disables). Safety: every abort path exits before it, so deleted files are provably consumed. Unit-tested; current 363-file/20G set first prunes ~Nov 11 |
| P5d | MCP registry listings (ydb-mesh#28) | **PREP DONE 2026-10-28 — publish pending** | Package tracked in `ydb-mesh/registry/` (PR #49): README (identity + tool schemas verified against source, client snippet, submission checklist), `official-registry.json`, `smithery.json`, `glama.json` (drafts; validate against live registry schemas at submission). Corrected vs. issue: `/mcp` is public read-only (no auth). Prep documented on #28. Publish after service restart + live `tools/list` smoke |
| P5e | MARC author pass | **OPEN** | catline/serline pass is manual; consider a monthly timer |

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

## P8 — M ecosystem survey (2026-10-28) — v1 DONE, follow-ups open

GitHub (`language:MUMPS`, 3,542 repos, served to the 1,000-result cap) + GitLab + SourceForge surveyed; 26 repos content-verified as genuine M (GitHub's "M"/"MUMPS" tag also catches MATLAB/Mathematica `.m` files — verification sampled real source). **Clones in `~/m-ecosystem/`** (34 total: 18 GitHub + 8 GitLab + GT.M release tarball + manifest in `SURVEY.md`): union of top-10-by-stars / top-10-by-M-volume / top-10-by-recency. Excluded: VistA + FileMan (owned), RSM (owned oracle), forks, the Fortran sparse-solver "MUMPS" project. Highlights: FOIA-RPMS (232MB M), YDBTest, EWD, JADE, habitat (Lucasfilm remake), HL-GTM, MPM (M package manager), GT.M V7.2-001. Follow-ups: SF `mumps` 1.71 tarball (Cloudflare cooldown; V1.64 source captured via the `Duraznos/rubella` mirror); **YDBTest as cross-engine conformance target** (GT.M P9 vs YottaDB vs mjvm). The **four-engine micro-benchmark** (GT.M/YDB/RSM/mJVM) is recorded in `SURVEY.md`; mJVM follow-ups filed as **mjvm#4–#10** (P1c).

## P9 — GT.M instance on U01 (2026-10-28) — RUNNING

- **Engine:** GT.M V7.2-001 (FIS, 2026-08-18 release; YottaDB's FIS parent) — user-space install `~/gtm/V7.2-001` (no root needed; sudo timestamps had expired), instance `~/gtm-ecosystem` (`gtm.dat`, env `gtm-env.sh` — `gtm_*` vars fully disjoint from `ydb_*`).
- **Port plan:** YottaDB services = 8081/8082/9080/9187/9188; **GT.M services = 8181+**. Health endpoint `GTMHTTP.m` serves `{"engine":"GT.M V7.2-001","status":"ok"}` on **8181** (serial SOCKET responder, `$ET`-trapped; GT.M socket pattern from the survey's own M-Web-Server source).
- **Smoke:** globals/arithmetic/`$DATA` pass; endpoint 3/3. Distribution tarball archived in `~/m-ecosystem/sourceforge/`.
- **Follow-ups:** persistence for the HTTP service (systemd unit needs root — or `--user` + linger; currently nohup), full M-mode/UTF-8 dist selection, `$ZINT`/plugin inventory, YDBTest runs against it (with P8).

---

## Done (historical — do not reopen)

- **2026-10-26 fleet cleanup** — all 5 phases + follow-ups (PRs #47 #48)
- **2026-10-27 U04 commissioned** — fleet CI runner; mjvm CI red-streak (untracked jars) found + fixed
- **2026-10-27 fleet posture hardened** — key-only SSH, UFW, Caddy+fail2ban edge-only, public 22 closed
- **2026-10-27 edge containerized** — LXD container `edge`, fenced, snapshots, DMZ-equivalent containment
- **2026-10-27 MeshGraph resumed** — services, edge, daily/weekly timers, backup timer, Dafny proofs (GraphStore + BM25 + Scan)
- **2026-10-27 Dafny corpus 464 → 547** — GraphStore.dfy, BM25.dfy, Scan.dfy (PRs #67 #69 #70)
- **2026-10-28 MeshGraph post-resume heal** — retention semantics verified (NO phantom kill), dead PTERM guard fixed (caret bug), 142,763 docs indexed, dangling = SCR-by-design cleared, WAND pruning live (13–33s → 0.2–3.5s), updatefile retention live, first post-resume backup to U02
- **2026-10-28 JavaM REPL (#35/#36) verified DONE** — closed at v0.9.0; scripted CI smoke restored to mjvm `gauntlet.yml` (c8ada1a) after being lost in the repo split
- **2026-10-28 P8 M ecosystem survey** — GitHub/GitLab/SourceForge; 34 artifacts cloned to `~/m-ecosystem/` (SURVEY.md); content-verified genuine-M selections (stars/M-volume/recency), VistA/FileMan/RSM excluded
- **2026-10-28 P9 GT.M V7.2-001 instance** — user-space install on U01, disjoint `gtm_*` env, HTTP health endpoint on 8181 (port plan: GT.M 8181+, YottaDB 8081/8082/9080/9187/9188)
- **2026-10-28 four-engine micro-benchmark** — GT.M/YDB parity; RSM `$ORDER` quadratic; mJVM IR ~15x compute gap; findings filed as mjvm#4–#10; recorded in `~/m-ecosystem/SURVEY.md`
- **mjvm v2.2.0 / v2.2.1 / v2.2.2** correctness hardening — 17 bugs total, 45+ regression tests
- **JavaM v0.4.0 / v0.5.0 / v1.2.0** · perf review · concurrency audits · Cdb2 LOCK/TSTART
- **MeshGraph** BM25 rebuild + author-pass + related_rev (pre-pause, all green)
- **P ports** Py/C3/JavaM + mJVM native — corpus freeze
- **U03 commissioned** (mirrors + DNS) 2026-10

## Scope lock

| Role | |
|------|--|
| mjvm | **sole development path** (JavaM frozen; parser/lexer + REPL live in mjvm) |
| JavaM | frozen full-M oracle (v1.2.0) — reference only |
| MeshGraph | data product, **ACTIVE** |
| RSM | oracle only (archived) |
| Py/C3 | corpus freeze |
| tsx / comdb2 | time-series plane, **PAUSED** |
| fst / O'Kane / FreeM | frozen / adjunct |
| swiftm | spec validation, **PROPOSED** (after P1b) |
| m-semantics | spec + master docs home (PR-only main) |
