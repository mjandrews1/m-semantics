# Master critical path — all projects (unified)

**Last updated:** 2026-10-11  
**Scope:** every open project and outstanding issue — M stack, YottaDB stack, tooling, **and Comdb2**.  
**Detail docs:**  
- M ports: `fst/docs/RSM-PORT-COMPLETION.md` *(frozen in fst)* · `~/jvmumps/CRITICAL_PATH.md` · **`~/jvmumps/docs/CATCHUP-2026-10.md`**  
- YottaDB: `~/ydb-py/CRITICAL_PATH.md` · `~/ydb-mesh/CRITICAL_PATH.md` · `~/ydb-infra`  
- **Comdb2:** `~/comdb2/CRITICAL_PATH.md`  
- fst Track F/R: `fst/docs/CRITICAL_PATH.md` *(frozen)*  
**Home of this file:** `m-semantics/docs/MASTER_CRITICAL_PATH.md`  
**≡ reprint copy:** `~/CRITICAL_PATH.md`

**Focus (2026-10-10/11):** JvMumps + mJVM primary · RSM only Oracle · Py/C3 peer-proof freeze · O'Kane/FreeM adjuncts only · Comdb2 optional infra.

## How to read this

One **priority-ordered** interleaved path. **Ticket** = GitHub issue when one exists; **(no ticket)** = real work without an issue. Status: **OPEN** · **IN FLIGHT** · **WAIT** · **FROZEN** · **BELAYED**.

---

## Project map (2026-10-11)

| Project | Role | Stream |
|---------|------|--------|
| **RSM** | M oracle (U01) | P1 ports |
| **PyMumps / C3Mumps / JvMumps** | full-M peer ports | P1 (done at 131/8/0) |
| **mJVM** | JVM-native M (charter) | P2 (done at 131/8/0 native) |
| **ydb-py / ydb-mesh / ydb-infra** | YottaDB data plane + hosts | **P3 active** |
| **okane-mumps** | ISO benchmark (no upstream patches) | P4 |
| **fst** | search product — **FROZEN 2026-10-09** (reference only) | P5 frozen |
| **m-lsp / m-semantics** | tooling + Dafny spec + **shared path/coverage docs** | P6 |
| **comdb2** | Bloomberg clustered RDBMS on U01+U02 | P7 done |
| **freem** | FreeM ISO/feature/perf (U01+U02) | compare done · upstream #5/#6 |

---

## Critical path (order of attack)

```
  P0    ydb-mesh#12  BM25 PTERM rebuild (TRANS2BIG)     ← blocking ranked search
  P0b   ydb-mesh#13  ship/verify M DS libs (tools/)     ← local, parallel with P0
  P1    ydb-infra#1  close JDK host ticket              ← hygiene
  P2    ydb-infra#11 U02 replica keep/doc/teardown      ← ops
  P3    pymumps#3    W3 DO/GOTO/XECUTE freeze note      ← scope lock
  P4    jvmumps#24   same note for peer freeze (or dup)
  P5    rsm#31       coverage matrix refresh            ← docs
  P6    m-semantics#12 path refresh (this file)         ← docs
  P7    okanes-mumps#3 Mac binary                       ← optional
  FROZEN fst#10
```

---

## P0 — YottaDB search index (ranked)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| **P0.1** | **BM25 PTERM rebuild** (tf + doclen + df + hyphen/phrase) | **ydb-mesh#12** | **OPEN** — `%YDB-E-TRANS2BIG`; shrink TP batch |
| P0.2 | PTERM v1 postings (empty tf) | — | ✅ 39,994,988 arts · 4.05B postings · 6.36M terms |
| P0.3 | Preprints medRxiv + bioRxiv 6 months | — | ✅ 11,634 + 38,818 |
| **P0.4** | **BM25 search QA** (`myasthenia gravis self-care` ranked) | **ydb-mesh#12** | after P0.1 |

## P0b — M data-structure libraries (all tested on U01)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| **P0b.1** | Document API (`tools/README.md`) | **ydb-mesh#13** | **OPEN** |
| P0b.2 | HMAP / HSTACK / HQUEUE / HHEAP / HPQUE smoke | ydb-mesh#13 | ✅ local U01 green |
| P0b.3 | Optional RSM oracle run | ydb-mesh#13 | OPEN |

## P1 — M-port completion (historical — **DONE**)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P1.1–P1.5 | Py/C3/Jv W7–W9 + J8–J11 + mJVM M0–M9 | — | ✅ |
| P1.6 | Coverage matrix | rsm#30 | ✅ closed 2026-10-09 |
| P1.7 | JvMumps J12–J17 | jvmumps#7–#12 | ✅ **131/8/0** |
| P1.8 | mJVM M10–M12 + native | jvmumps#13–#15 | ✅ **131/8/0 native** (`fc143c8`) |

## P2 — mJVM (**DONE at 131/8/0** — rows updated)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P2.2–P2.4 | M10–M12 | jvmumps#13–#15 | ✅ done 2026-10-10 (was OPEN in 2026-10-09 doc) |

## P3 — YottaDB data plane (**ACTIVE**)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P3.1–P3.6 | mesh/poly/infra milestones | — | ✅ |
| P3.4 | Full author-pass PubMed + MARC | ydb-mesh#4 | ✅ **CLOSED** 2026-10-10 |
| **P3.7** | **BM25 index rebuild** | **ydb-mesh#12** | **OPEN** |
| **P3.8** | **M DS libraries ship/docs** | **ydb-mesh#13** | **OPEN** |
| **P3.9** | **U02 replica decision** | **ydb-infra#11** | **OPEN** |
| **P3.10** | **Host JDK ticket close-out** | **ydb-infra#1** | **OPEN** (JDK 21+25 done; see comment) |

## P4 — O'Kane GPL Mumps (benchmark only)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P4.1–P4.3 | B-tree · ISO table · MISS class | okanes-mumps#1–#2 | ✅ |
| **P4.4** | **Mac binary unlinked (SyncClock)** | **okanes-mumps#3** | **OPEN** |

## P5 — fst — **FROZEN**

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P5.f | Freeze: reference only | fst#10 | **FROZEN** (parked) |

## P6 — tooling / docs

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P6.1–P6.2b | m-lsp DO/FOR/@ | m-lsp#1–#3 | ✅ |
| **P6.3** | **Coverage matrix refresh** (131/8/0 + native) | **rsm#31** | **OPEN** |
| **P6.4** | **Refresh this path + `~/CRITICAL_PATH.md`** | **m-semantics#12** | **OPEN** |

## P7 — Comdb2 / FreeM

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P7.1–P7.5 | Comdb2 U01+U02 cluster | — | ✅ |
| P8 | FreeM upstream | freem-ops#1 | ✅ closed · WAIT indefinitely #5/#6 |

---

## Scope lock (2026-10-10 strategy)

| | Role |
|--|------|
| **JvMumps + mJVM** | primary ports |
| **RSM** | only Oracle |
| **PyMumps / C3Mumps** | peer-proof **freeze** (corpus/regression only) |
| **O'Kane / FreeM** | adjuncts, never oracles |
| **Comdb2** | optional infra |
| **YottaDB** | storage plane (not an M stack) |

**W3 / DO-GOTO-XECUTE:** `pymumps#3` + `jvmumps#24` — confirm freeze; do not expand peer scopes.

---

## Issue index (open GitHub 2026-10-11)

| Repo | Open |
|------|------|
| `mjandrews1/ydb-mesh` | **#12** BM25 TRANS2BIG · **#13** M DS libs |
| `mjandrews1/ydb-infra` | **#1** host JDK (commented 2026-10-11) · **#11** U02 replica |
| `mjandrews1/jvmumps` | **#24** W3 freeze note |
| `mjandrews1/pymumps` | **#3** W3 freeze note |
| `mjandrews1/rsm` | **#31** coverage refresh |
| `mjandrews1/m-semantics` | **#12** path refresh |
| `mjandrews1/okanes-mumps` | **#3** Mac binary |
| `mjandrews1/fst` | **#10** parked |
| Others | 0 open |

**Closed recently:** ydb-mesh#4 author-pass · jvmumps#6 `$ORDER` hang · jvmumps#7–#15 · P0 audits.

---

## Next action (do this now)

**NOW:** **ydb-mesh#12** — fix `write_batch` size (50–100 / TP or split TPs), rerun `term_index build` on U01, then `bm25_search` smoke.  
**Parallel:** **ydb-mesh#13** docs for HMAP/HSTACK/HQUEUE/HHEAP/HPQUE.  
**Then:** close **ydb-infra#1** · decide **ydb-infra#11** · freeze notes **pymumps#3** / **jvmumps#24** · refresh matrix **rsm#31**.
