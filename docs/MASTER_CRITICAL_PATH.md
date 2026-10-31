# Master critical path — all projects (unified)

**Last updated:** 2026-10-31 (m-ils web milestone + mjvm #40 collation session) · **Home:** `m-semantics/docs/MASTER_CRITICAL_PATH.md` · **≡** `~/CRITICAL_PATH.md`

## ★ LATEST WORK QUEUE — 2026-10-31 ← HERE ★

1. **#40 $O/$Q M collation — DONE 2026-10-31** (mjvm 5135b54: MCollation, canonical-numeric-first; ORACLE COLLATE byte-identical to GT.M; issue closed)
2. **#33 store consolidation — DONE 2026-10-31** (mjvm a93e081: -v makes TieredStore volumes; h2/mapdb/sqlite +warn; memory/tiered/cdb2 kept)
3. **Comdb2 `ilsdb` cluster — IN PROGRESS**: U02 master COHERENT, U01 replica COHERENT (on a 512-sector loop device — U01's NVMe is 4Kn and comdb2's 512B O_DIRECT reads EINVAL there, root-caused); U04 recopy pending (copycomdb2 needs comdb2ar_rmt). Also done today: U02 disk 100%→46% (stale backup copies removed after U04's second copy verified byte-identical; LV grown 850→928G), NOPASSWD sudo on all 4 hosts, disk-watch loop ceb6ad87 every 6h
4. **Perf: parser-climb share** — mJVM fixture ingest 21s vs GT.M 6.3s; ~45% is ExprEval precedence climb; needs AST cache or --class emitter fixes (Bank_<LABEL> helpers, increment signature) — OPEN, schedule deliberately
5. **#18 + MFrontend family (#4,#13,#16-#19,#21,#22,#24,#25,#35) — USER's P1b surface** — do not touch MFrontend.java from agents
6. **Rationalize/harmonize/optimize active projects + the jobs that run them** — NEW 2026-10-31 (owner request, not started): audit all cron loops / launchd jobs / CI runners / services; dedupe; document owner+cadence per job
7. **Fleet + WIP dashboard** — NEW 2026-10-31 (owner request, not started): dashboard of how things work + WIP status, refreshed at regular (batch) intervals — not real-time; EXCEPT genuinely live services (GTMHTTP U01:8181, ILSWEB U01:8282, mJVM web Mac:8282) which can be probed live. Owner understands hard-realtime vs colloquial "real time"; our jobs are batch/soak. Design: cron-regenerated static page from soak logs, loop list, fuzz ledger, disk watch, comdb2 coherence, CI status, live-UI probes

m-ils state: Phase 0 fixture (138,966 nodes byte-identical dual-engine) + Phase 1 CRUD stress (2,000 ops, state byte-identical) + web UI live on both engines (GT.M U01:8282, mJVM Mac:8282) — repo mjandrews1/m-ils @ e9de5a3. tsx DEPRECATED 2026-10-31 (archived + banner).
**Detail docs:** JavaM `jvmumps/CRITICAL_PATH.md` · `jvmumps/docs/ROADMAP-0.5.0.md` · mjvm `mjvm/docs/` · inventory `m-semantics/docs/MASTER-INVENTORY.md`

**Name lock:** **MeshGraph** = product · **`ydb-mesh`** = code · **JavaM** = `mjandrews1/JavaM` (JvMumps) — **FROZEN oracle**; parser/lexer (and REPL) moved to mjvm, one codebase, one dev path going forward · **mjvm** = `mjandrews1/mjvm` (JIT engine) · **tsx** = Comdb2 time-series.

**Focus (end of 2026-10-28):** mjvm v2.2.2 shipped (P1b comma work in flight) · fleet hardened (key-only SSH, UFW everywhere, public 22 closed, edge containerized + fenced) · MeshGraph RESUMED + **post-resume heal DONE 2026-10-28** (retention semantics verified — NO phantom kill; dead PTERM guard fixed; 142,763 docs indexed; dangling cleared; WAND pruning live; updatefile retention live; first post-resume backup run) · **ydb-mesh repo reactivated** (PR #49: ops files + registry package + live tree) · Dafny corpus 547 verified · **JavaM REPL (#35/#36) verified DONE** — CI smoke restored to mjvm (c8ada1a) · **P8 M ecosystem survey cloned** (`~/m-ecosystem/`, 34 artifacts incl. GT.M V7.2-001) · **P9 GT.M instance RUNNING on U01:8181** · c3fst deprecated · **2026-10-29:** MeshGraph services restored + update/author timers re-armed; dangling=0 verified; still_missing=78,463 root-caused (benign); GTMHTTP back on 8181 with @reboot persistence; mjvm bench/micro landed (#5, #9, #10, #11 closed; #12/#13 filed); **U01 journaling RE-ENABLED 2026-10-29 00:26 UTC** (writer-quiesced after DAILY_DONE; verified by write-through) — P0c DONE; P5e monthly MARC timer armed; P8 mumps 1.71 tarball captured; P9 inventory documented ($ZCHSET=M, gtmcrypt plugin; GTMHTTP serial responder can wedge — restart is the remedy) · remaining: portal rotation (user), U02 backup second copy (user), mjvm comma backlog (P1b) + #4/#13 (MFrontend, coordinate with P1b), YDBTest cross-engine run (scoped), MCP registry publish (external accounts).

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
| **tsx / comdb2** | time-series + SQL plane | **DEPRECATED 2026-10-31** | FROZEN |
| **RSM** | archived → `U02:coldstore/mac-rsm-2026-10-26/` | FROZEN | FROZEN |

---

## Critical path (end of 2026-10-28)

```
  P0a Portal password rotation               (user)
  P0b U02 meshgraph-backup second copy       (DONE 2026-10-29 — byte-exact, see row)
  P0c U01 YDB journaling re-enable           (DONE 2026-10-29 — enabled while quiesced)

  P1a mjvm compiler coverage 36.4% → 60%      (peephole + error paths first)
  P1b mjvm VistA class-4: comma 17,057 (28.3%)  ← largest remaining backlog class
  P1c mjvm engine-gap items (mjvm#4–#10)       (micro-benchmark findings; #4 correctness first)
  P1d Conformance campaign (sprint to 11-30)   (oracle/differential vs GT.M; defects #13,#15-19,#4)
  P1d Conformance campaign (sprint to 11-30)   (oracle/differential vs GT.M; defects #13,#15-19,#4; charter: mjvm/docs/CONFORMANCE-CAMPAIGN.md)
  P2b ~~JavaM rename + VistA full run~~    (DONE — #27/#34 closed on GitHub; path was stale)

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
| U02 `meshgraph-backup` second copy | **DONE 2026-10-29 23:40 UTC** | The completing rsync (started ~02:40 UTC Wed, `--inplace` from U02's post-heal backup) finished with its last writes 2026-10-28 22:12 UTC — the monitoring cron's later "in flight" reports were pgrep false positives (the pattern matched the monitor's own ssh command line; the log's `Host key verification failed` lines were from post-completion restart attempts, not the completing run). Verified byte-exact against U02: `yottadb.dat` 237,585,666,048 bytes and directory `du -sb` 240,233,879,552 on both sides; renamed to `/backup/meshgraph-backup` on U04 (56% of 443G root). **Follow-ups:** (1) future re-syncs will fail until U04's `known_hosts` gains U02's host key — fix before the next weekly refresh; (2) monitoring greps must use self-match-proof patterns (`grep [r]sync` / `pgrep -x rsync`) |
| U01 YDB journaling re-enable | **DONE 2026-10-29** | Enabled while writer-quiesced (immediately after the daily run's DAILY_DONE 00:16 UTC): `mupip set -journal=ENABLE,FILE=~/.yottadb/r2.06_x86_64/g/yottadb.mjl -region DEFAULT` — before-images on, old Oct-10 journal auto-rotated to `yottadb.mjl_2026302002536`. Verified by write-through (`^JOURNALTEST` probe: journal 68K→78K) and `dse` header showing `Journal State ON`. The post-heal backup on U02 was verified first (2026-10-28 BACKUP OK) |

## P1 — mjvm (primary dev)

| Work | Status | Note |
|------|--------|------|
| GAUNTLET 134/134 · corpus 139/139 · CoreUnitTest 135/135 | **DONE** | Verified on Mac + u04 CI (GAUNTLET green post-gate-tuning) |
| Silent-recovery audits (rounds 1+2) | **DONE — v2.2.2** | 7 sites fixed, 45 regression tests, all suites green |
| Compiler coverage | **MEASURED, TARGET OPEN** | 36.4% lines (total project 79%). 60% compiler target: peephole + error paths first |
| **VistA swallowed-syntax backlog** | **IN FLIGHT — classes 1-2 DONE, class 4 (comma) next** | Baseline 21,452 routines (63.2%) → **14,430 (42.5%)** after classes 1-2. Remaining: comma **17,057 (28.3%)** → postcond 16,204 (26.9%) → @ 4,168 → dotted 2,483 → $ 1,182 → SET 1,180 → tail 9,070. Detail: `mjvm/docs/VISTA-SYNTAX-BACKLOG.md` |
| CI fix (untracked jars + gates) | **DONE** | archunit + jmh-core jars tracked; GAUNTLET env-overridable gates; green on u04 |
| **Engine-gap micro-benchmark findings** | **OPEN — mjvm#4, #12–#14 (#5, #6, #8, #9, #10, #11 DONE)** |
| **P1d Conformance campaign (2026-10-29 → 2026-11-30)** | **OPEN — on track; charter: `mjvm/docs/CONFORMANCE-CAMPAIGN.md`** | Day-1 results: ORACLE gate LIVE in GAUNTLET CI on u04 (60 cases, 4-bucket tripwire: 32 pass / 11 upstream / 16 known-bug — 0 unexplained); fuzzer LIVE (410 programs, 100% auto-classified); **#15 FIXED** (subscripted globals, regression-locked); **10 open bugs** — #4, #13, #16-#19, #21-#24, ALL MFrontend (= the P1b convergence surface), incl. two silent-output bugs found by the fuzzer: #22 (2-arg W fails to compile; mid-file degrades to silent RET-truncation) and #24 (multi-arg W DROPS its final non-literal argument); 7 upstream classes documented (WRITE line-break, $ETRAP, ELSE, div-zero, $STACK — pymumps byte-verified). π workstream D: digit-exact at 30/1k/10k vs Python, 100k+1M chain launched (~4-7 days, 6h-cron verifies + reports the millionth digit). Origin: the π program (Machin, verified digit-exact to 1000 digits vs Python) exposed **seven defects in one session**, five silent-wrong-answer class; new filings mjvm#17 (comma-IF parse error), #18 (IF in dotted block corrupts block / double-exec), #19 (multi-command same-line FOR body) join #13/#15/#16/#4. Method: oracle/differential testing — GT.M V7.2-001 on U01 as oracle (the corpus and GAUNTLET gate line-mode; π proved routine-mode + loop-carried subscripted state is the under-tested surface). Workstreams: (A) fix inventory, silent-wrong-answer first, all MFrontend items converging with P1b classes; (B) ORACLE harness — snippet corpus, GT.M-generated expecteds, CI gate on u04; (C) grammar fuzzer over the construct matrix, nightly; (D) known-answer math suite (π 1M as soak test); (E) regression lock-in per fix. Exit (11-30): zero open silent-wrong-answer defects in the matrix, ORACLE ≥100 cases green in CI, π 1M done, π program runs unmodified | 2026-10-28 four-engine benchmark (GT.M V7.2-001 / YDB r2.06 / RSM V1.83.1 / mJVM IR; data + methodology: `~/m-ecosystem/SURVEY.md`). mJVM vs GT.M/YDB: ~15x on compute loops, 33x on `$PIECE`, 15x on local sets. **#5 DONE 2026-10-29:** portable harness `mjvm/bench/micro/` (22d8afa) — BENCH.m ($ZUT) + phases/ (wall-clock), run-mjvm.sh, run-u01.sh; GT.M/YDB parity re-confirmed on U01, mJVM IR reproduces survey numbers. **#11 FIXED 2026-10-29 (09139c4):** `--class` now compiles FOR loops — structured emission (labeled loops for back targets, escape-pulled blocks for forward targets, dead-code pre-scan, switch-dispatch fallback) + control-char escaping, `compileGlobalRef` literal-subscript fix, END_WRITE/WRITE_CHAR/WRITE_COL emission; new `JavaSourceEmitterRegression` 14/14; all suites green (MFrontend 53/53, GAUNTLET 137/137). **#9 DONE 2026-10-29 (93b7f3e):** steady-state `--class` = 1.0–2.0x over IR machine (parity all phases); one-shot javac ~0.4s/program; **decision: keep IR default for file runs, `--class` opt-in** — both engines bottleneck on `rt.evalExpr` in loop bodies, so the real wins are #6/#7/#8 (compile loop-body expressions). Remaining: **#4** silent no-op `W:cond` (correctness — fix first; adjacent to P1b disambiguation) · **#13 NEW 2026-10-29:** QUIT in argumentless FOR exits the routine, not the loop — root cause of the survey's AWALK/GWALK n/v (GT.M prints the walk count, mJVM prints nothing; `f s x=$O(...) q:x=""` idiom — VistA-dominant; **fix lives in MFrontend → coordinate with in-flight P1b**; corpus lacks a case) · **#12 NEW 2026-10-29:** emitter op coverage — new `MjvmClassScore` corpus gate through `--class` scores 93/46/0 (38 non-upstream misses: indirection @ 10, MERGE 5, $ETRAP/$ECODE/$ZTRAP 5, DO/XECUTE 8, arith guards 5, SET_EXTRACT/SET_PIECE 2, global KILL/$DATA 2, $X/$Y 1); scope expansion, pressing only if #6–#8 make `--class` a serious fast mode · **#6/#7/#8 DONE 2026-10-29 (3bd0ecb):** MRuntime hot paths — evalExpr single-token/left-to-right-arithmetic-chain/$P fast shapes, SubRef subscripted-name parse cache, single-lookup getVar. Per-call: bare var 37→17ns, chain 250→55ns, `$P(...)` 438→142ns, setVar("a(i)") 197→47ns. Phases (IR): PIECE 0.231→0.128s (29x→16x vs GT.M), ASET 0.045→0.032s (3.0x→2.1x), INTLOOP 0.159→0.129s (8.8x→7.2x). Two semantic finds regression-locked in new `MRuntimeFastPathRegression` (27 tests): the fast path sat outside evalExpr's $ETRAP try (undefined reads bypassed the trap — C115/C116); M arithmetic is strictly left-to-right (C30: 1+2*3=9). **#14 NEW (follow-up):** residual gap = IrMachine dispatch (~258ns/iter INTLOOP, ~30-40ns/op × 6 ops) — levers: empty preRead probe skip, dispatch guards, then re-measure `--class` before MExprJava loop-body work. **#10 DONE 2026-10-29 (b0c9474):** store matrix — memory (CLI default) 0.140s GSET / 0.658s GREAD / 0.304s GWALK; sqlite ≈240x on writes (per-op SQL); cdb2 needs the Comdb2 environment; memory is the only viable bench backend. Side findings: GT.M/YDB parity confirmed; RSM `$ORDER` walks are **quadratic** (local + global) — fine for its oracle role, disqualifying for big-data use. **P1d sweep 2026-10-29 evening — operator-polarity audit:** **#26 FIXED** (string relational family: `'[` crashed with trailing-input, `]]` mis-tokenized, numeric fast path bypassed string coercion), **#27 FIXED** (`--class` emitter's negate flag was dead — `'= '< '> `compiled to their POSITIVES, silent wrong answers in class mode), **#28 FIXED** (`']` implemented as not-contains but GT.M defines NOT-sorts-after; `]]` now GT.M numeric collation — pymumps has no `]`-family, GT.M sole arbiter). Found by static audit of every operator mapping + `tools/opmatrix.m` (13 ops x 20 operand-type pairs, three-way mJVM-native/mJVM-class/GT.M; only documented C24 + C16/rsm#11 upstream cells remain). **Workstream D:** e = sum 1/k! (same fixed-point bignum as π) digit-exact at 30/1k/10k/100k (100k in 34min), 1M soak running; PEMDAS-in-M recursive-descent parser 13/13 dual-engine; the 8 fundamental data structures in M (array/linked-list/stack/queue/hash/BST/min-heap/graph-BFS) all verdicts identical vs GT.M. **ORACLE harness 96 → 116 cases: pass=74 upstream=17 known-bugs=25, diverge=0 err=0 — the ≥100-case exit criterion is MET.** New filings: **#29** HALT does not stop, **#30** `K (V)` exclusive kill kills V, **#31** argumentless NEW is a no-op. **Parallel extension 2026-10-29 (late):** (1) **algebra suite** in M, workstream D: symdiff (symbolic polynomial differentiation — GOTO state-machine parse, exponent-keyed globals with negated keys so ascending `$O` = descending exponents; 8 checks incl. round-trip second derivatives), polyarith (add/multiply — product of keys KA,KB lands at KA+KB; binomial/difference-of-squares identities), roots (Euclid gcd, integer sqrt/cbrt via parenthesized Newton), sieve (Eratosthenes, π(10000)=1229), cfe (continued fraction of e — 19 terms, unimodularity |p_k q_{k−1} − p_{k−1} q_k| = 1 checked in-program; convergent 14665106/5394991). All 30 checks byte-identical mJVM vs GT.M; ORACLE harness now **121 cases, pass=79, diverge=0**. (2) **MRelOps.dfy** in the Dafny core (new CI step): operand classes at the type level (null / canonical number / non-canonical numeric string / non-numeric string), both arbiter rule-sets, the `]`-family with GT.M numeric collation, truth-table lemmas pinning the opmatrix cells, and the **C16/C24 divergence classes formalized** — `CanonAgree` is the verified safety statement for ExprEval's numeric fast path (both arbiters coincide on canonical numerics). 13 lemmas verified; all 10 modules green (560 total). **Best-of-both merge (PR follow-up):** the duplicate MRelOps draft from the colliding parallel session (branch mrelops-dfy) was folded in on top of the merged base — lex reflexivity/antisymmetry, collation no-self/antisymmetry, null-containment laws, '= (C24 from the negated side), and the remaining opmatrix GT.M cells (] numeric-lex cells, '] probes, ]] string-class cells, ']] probes, contains-null cells) — **23 results, 0 errors (Dafny 4.11)**. |

## P2 — JavaM / m-semantics

| Work | Ticket | Status |
|------|--------|--------|
| 1.0 gate (FileMan Tier A/B/C, 135/4/0) | JavaM#32 #25 #26 | **DONE** (2026-10-17) |
| v1.2.0 release | — | **DONE** |
| REPL both engines | JavaM#35 #36 | **DONE — closed at v0.9.0** (13ca164 + 210852e, jvmumps repo). Path was stale; verified live 2026-10-28: both shells (`jvmumps.Repl`, `mjvm.cli.Repl`) pass the scripted session against the mjvm build; the CI smoke lost in the mjvm split restored in `gauntlet.yml` (c8ada1a) |
| Rename leftovers (docs/CI badges) | JavaM#27 | **DONE — closed on GitHub; path was stale (verified 2026-10-29)** |
| VistA full run under JavaM + mJVM | JavaM#34 | **DONE — closed on GitHub; path was stale (verified 2026-10-29): 99.97% (33,942/33,951) on BOTH engines, 0 engine gaps, 7 DATA (truncated sources) + 2 DIALECT failures, 0.148ms/routine parse** |
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
| P5d | MCP registry listings (ydb-mesh#28) | **PUBLISH READY — restart + live `tools/list` smoke verified 2026-10-29** | Package tracked in `ydb-mesh/registry/` (PR #49): README (identity + tool schemas verified against source, client snippet, submission checklist), `official-registry.json`, `smithery.json`, `glama.json` (drafts; validate against live registry schemas at submission). Corrected vs. issue: `/mcp` is public read-only (no auth). Live smoke on U01 2026-10-29: `tools/list` on 100.72.84.8:8082 returns both tools (mesh_search, mesh_get). Registry submission (external accounts) is the only remaining step |
| P5e | MARC author pass | **DONE 2026-10-29** | Monthly systemd timer armed: `meshgraph-catplus.timer` (first Sunday 06:00 UTC, `Persistent=true`, `Nice=10`, User=mark) → `run_catplus.sh`; scheduled after the daily (03:00) and author (Sun 04:30) windows; first fire Sun 2026-11-01. First-fire validation pending |

### Restore + data-warning triage (2026-10-29)

- **Services/timers restored:** mesh-search/mesh-mcp/ydb-web-server/ydb-dashboard-ui restarted; update + author timers re-armed. The update timer's missed-schedule catch-up fired immediately (full-window run).
- **dangling=268 verified resolved:** `^PUBMEDSTAT("dangling")` = 0 (SCR-exclusion re-baseline holds; the 2026-10-27 `WARN dangling != 0` log line predates the P5a fix).
- **still_missing=78,463 root-caused — benign:** `daily-update.sh` builds the want list with `grep -oE '<PMID[^>]*>[0-9]+'` over all updatefile content, which also captures PMIDs inside *other* articles' `<CommentsCorrections>` and `<ReferenceList>` entries (verified: PMID 10025890 appears in pubmed26n1659.xml.gz only as a CommentOn reference). Those PMIDs have no `PubmedArticle` of their own in the window, so they can never load — hence "still missing". Optional improvement: scope extraction to MedlineCitation-level PMIDs (full XML parse instead of grep).
- **Efficiency note — FIXED 2026-10-29 (ydb-mesh PR #50, deployed to U01 before the 03:00 run):** new step 2b (`filter_want_missing.py`, read-only `^PUBMED` data() probe, 12s for 3.35M lookups) filters the want list to genuinely absent PMIDs — today 3,349,314 wanted → **45,849 missing**. The load now writes only new articles (was re-writing ~3.3M/day); `^PUBMEDSTAT` counters stay honest; still_missing becomes the small honest cited-only set; step 3 skips cleanly when nothing is missing (catch-up + completeness still run). Open follow-ups: re-baseline the already-inflated `^PUBMEDSTAT` counters (the retention KILL never decremented them either — decide semantics first), ydb-mesh#51 (U01 live tree is a plain copy, not a clone — deploy-drift risk).

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

GitHub (`language:MUMPS`, 3,542 repos, served to the 1,000-result cap) + GitLab + SourceForge surveyed; 26 repos content-verified as genuine M (GitHub's "M"/"MUMPS" tag also catches MATLAB/Mathematica `.m` files — verification sampled real source). **Clones in `~/m-ecosystem/`** (34 total: 18 GitHub + 8 GitLab + GT.M release tarball + manifest in `SURVEY.md`): union of top-10-by-stars / top-10-by-M-volume / top-10-by-recency. Excluded: VistA + FileMan (owned), RSM (owned oracle), forks, the Fortran sparse-solver "MUMPS" project. Highlights: FOIA-RPMS (232MB M), YDBTest, EWD, JADE, habitat (Lucasfilm remake), HL-GTM, MPM (M package manager), GT.M V7.2-001. Follow-ups: ~~SF `mumps` 1.71 tarball~~ **DONE 2026-10-29** — Cloudflare cooldown passed; `mumps-1.71-src.tar.gz` captured to `~/m-ecosystem/sourceforge/`; **YDBTest as cross-engine conformance target** (GT.M P9 vs YottaDB vs mjvm). The **four-engine micro-benchmark** (GT.M/YDB/RSM/mJVM) is recorded in `SURVEY.md`; mJVM follow-ups filed as **mjvm#4–#10** (P1c).

## P9 — GT.M instance on U01 (2026-10-28) — RUNNING

- **Engine:** GT.M V7.2-001 (FIS, 2026-08-18 release; YottaDB's FIS parent) — user-space install `~/gtm/V7.2-001` (no root needed; sudo timestamps had expired), instance `~/gtm-ecosystem` (`gtm.dat`, env `gtm-env.sh` — `gtm_*` vars fully disjoint from `ydb_*`).
- **Port plan:** YottaDB services = 8081/8082/9080/9187/9188; **GT.M services = 8181+**. Health endpoint `GTMHTTP.m` serves `{"engine":"GT.M V7.2-001","status":"ok"}` on **8181** (serial SOCKET responder, `$ET`-trapped; GT.M socket pattern from the survey's own M-Web-Server source).
- **Smoke:** globals/arithmetic/`$DATA` pass; endpoint 3/3. Distribution tarball archived in `~/m-ecosystem/sourceforge/`.
- **Follow-ups:** ~~persistence for the HTTP service~~ **DONE 2026-10-29** — GTMHTTP had died (the gld's `gtm.dat` segment is *relative*, resolved from CWD; always run from the instance dir) — restarted + `@reboot` user crontab on U01. ~~M-mode/UTF-8 dist selection~~ **DONE 2026-10-29** — instance stays `$ZCHSET=M` (comparison role; DB objects CHSET=M; dist ships full `utf8/` if ever needed). ~~plugin inventory~~ **DONE 2026-10-29** — gtmcrypt only (keygen/encrypt scripts). ~~GTMHTTP wedge~~ **FIXED 2026-10-30 (v4 event-driven rewrite):** the serial responder was replaced by a single-process event loop — WRITE /WAIT multiplexes the listener and all attached client sockets (verified 10/10 identical bodies under burst concurrency; stalled-client + parallel curl serves in 0s — the wedge is structurally impossible). GT.M 7.2 socket API findings recorded in SURVEY.md (no DETACH in USE/CLOSE; /WAIT(n) = n seconds but a spin on the wrong device; $KEY must be captured before device switches; socket id = $KEY piece 2; per-event USE (CHSET="M") required). v1 source kept as GTMHTTP.m.serial.bak. Remaining: YDBTest runs against it (with P8 — scoped: tcsh/Docker standalone engagement; repo already cloned at ~/m-ecosystem/github/YDBTest, Dockerfile path recommended, `gtmtest -help`; **blocker RESOLVED 2026-10-30: LXD instead of Docker** — container `ydbtest` on U03 (lxd-group access, no sudo needed; ~1.5G growing to ~3G; 55G host headroom, RAM is the constraint — single-stream runs). Setup complete: Ubuntu 24.04 + the Dockerfile dep subset; repo at /usr/library/gtm_test/T999 (T990 symlink); GT.M V7.2-001 dist at /Distrib/GTM/V7.2-001 with V999_R999/{dbg,inc} symlinks + a tools/gtm_env.csh GT.M shim (sets gtm_dist, ydb_dist); serverconf.txt with hostname + /var/log/syslog substituted; /usr/local/bin/tcsh shebang symlink; gtmtest/gtmtest1 users (group gtc); /testarea1-3. **First smoke COMPLETE: `tcsh com/gtmtest.csh -nomail -fg -env gtm_ipv4_only=1 -env force_gtm_test_com_individual=1 -env test_encryption=NON_ENCRYPT -env gt_cc_compiler=cc -stdout 2 -t r132` ran end-to-end** (subtests executed, diffs produced, exit FAILED — expected: YDBTest exercises YDB-only features; the failures ARE the cross-engine conformance data). Next: the engagement proper — full-suite runs + diff triage (YDB-isms vs GT.M behavior vs env gaps), single-stream due to U03 RAM). **First basic-suite triage 2026-10-30:** the `-t basic` run aborted at subtest 1 (testver.m) after 5 min — its version gate uses YDB-only `$zyrelease` (class a: YDB-only feature), and the pervasive failure mode is `YDB>` vs `GTM>` prompts baked into the reference outputs (class b: environment gap — GT.M-branded references or prompt normalization needed before any subtest can pass; the ~1,299 diff lines are mostly prompt mismatches, i.e. no GT.M-behavior findings yet).

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
| tsx / comdb2 | time-series plane, **DEPRECATED 2026-10-31** (tsx repo archived w/ banner) |
| fst / O'Kane / FreeM | frozen / adjunct |
| swiftm | spec validation, **PROPOSED** (after P1b) |
| m-semantics | spec + master docs home (PR-only main) |
