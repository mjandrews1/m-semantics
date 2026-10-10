# Master critical path — all projects (unified)

**Last updated:** 2026-10-09 (fst **FROZEN**; shared docs home = `m-semantics`)  
**Scope:** every open project and outstanding issue — M stack, YottaDB stack, tooling, **and Comdb2**.  
**Detail docs:**  
- M ports: `fst/docs/RSM-PORT-COMPLETION.md` *(frozen in fst)* · `~/jvmumps/CRITICAL_PATH.md` · **`~/jvmumps/docs/CATCHUP-2026-10.md`**  
- YottaDB: `~/ydb-py/CRITICAL_PATH.md` · `~/ydb-mesh/CRITICAL_PATH.md` · `~/ydb-infra`  
- **Comdb2:** `~/comdb2/CRITICAL_PATH.md`  
- fst Track F/R: `fst/docs/CRITICAL_PATH.md` *(frozen)*  
**Home of this file:** `m-semantics/docs/MASTER_CRITICAL_PATH.md`  
**≡ reprint copy:** `~/CRITICAL_PATH.md`

**Focus (2026-10-10):** JvMumps + mJVM primary · RSM only Oracle · Py/C3 peer-proof freeze · O'Kane/FreeM adjuncts only · Comdb2 optional infra.

## How to read this

One **priority-ordered** interleaved path. **Ticket** = GitHub issue when one exists; **(no ticket)** = real work without an issue. Status: **OPEN** · **IN FLIGHT** · **WAIT** · **FROZEN** · **BELAYED**.

---

## Project map (2026-10-09)

| Project | Role | Stream |
|---------|------|--------|
| **RSM** | M oracle (U01) | P1 ports |
| **PyMumps / C3Mumps / JvMumps** | full-M peer ports | P0 audits + P1 W7–W9 |
| **mJVM** | JVM-native M (charter) | P2 catch-up |
| **ydb-py / ydb-mesh / ydb-infra** | YottaDB data plane + hosts | P3 |
| **okane-mumps** | ISO benchmark (no upstream patches) | P4 |
| **fst** | search product — **FROZEN 2026-10-09** (reference only) | P5 frozen |
| **m-lsp / m-semantics** | tooling + Dafny spec + **shared path/coverage docs** | P6 |
| **comdb2** | Bloomberg clustered RDBMS on U01+U02 | P7 done |
| **freem** | FreeM ISO/feature/perf (U01+U02) | compare done · upstream #5/#6 |

**fst:** kept for reference, no feature work. Tag `frozen-2026-10-09`. Shared `MASTER_CRITICAL_PATH.md` + `COVERAGE-MATRIX.md` + `coverage_matrix.py` live in **m-semantics**.

---

## P0 — JvMumps semantics audits (unblock M-port confidence)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P0.1 | J26–J50 wants vs ISO table | jvmumps#1 | ✅ done 2026-10-07 |
| P0.2 | JOB/TX/LOCK vs RSM (+ nested TROLLBACK fix) | jvmumps#2 | ✅ done 2026-10-07 |
| P0.3 | PatternMatch vs ISO (+ empty-lit / unbounded fixes) | jvmumps#3 | ✅ done 2026-10-07 |
| P0.4 | Full wave suite drift review | jvmumps#4 | ✅ done 2026-10-08 |

## P1 — M-port completion

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P1.1 | PyMumps W7 remainder `$ETRAP`/`$ECODE` | pymumps#1 | ✅ 2026-10-08 (C113–C120) |
| P1.2 | PyMumps W8 specials + WRITE device params | pymumps#1 | ✅ `$Z*` + WRITE *n/#/?n + w9 ACCEPT |
| P1.3 | PyMumps W9 full-M acceptance vs RSM | pymumps#1 | ✅ **ACCEPT** 131/8/0/0 |
| P1.4 | C3Mumps W7–W9 | c3mumps#1 | ✅ **ACCEPT** 131/8/0/0 |
| P1.5 | JvMumps J8–J11 + mJVM M0–M9 | jvmumps#5 | ✅ done 2026-10-08 (ACCEPT) |
| P1.6 | Coverage matrix all M stacks (no YottaDB) | rsm#30 | ✅ closed 2026-10-09 |
| **P1.7** | **JvMumps catch-up J12–J17 → 131/8/0** | **jvmumps#7–#12** | ✅ **131/8/0** |
| **P1.8** | **mJVM catch-up M10–M12 → 131/8/0** | **jvmumps#13–#15** | ✅ **131/8/0** (native too) |

## P2 — mJVM (catch-up)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P2.1 | M0–M9 | jvmumps#5 | ✅ done 2026-10-08 |
| **P2.2** | **M10 subset IF/ELSE/FOR + NEW/KILL/MERGE** | **jvmumps#13** | **OPEN** |
| **P2.3** | **M11 calls/intrinsics/indirection** | **jvmumps#14** | **OPEN** |
| **P2.4** | **M12 numerics + parity gate 131/8/0** | **jvmumps#15** | **OPEN** |

## P3 — YottaDB data plane

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P3.1 | ydb-mesh `related()` QA + gene/drug catalog polish | ydb-mesh#3 | ✅ 2026-10-09 |
| P3.2 | ydb-py endpoint edge cases + docs | (no ticket) | ✅ 2026-10-09 (A4 run_m + edge tests 22/22) |
| P3.3 | ydb-py Wave C/D (HTTP + journal/backup smoke) | (no ticket) | ✅ done 2026-10-09 |
| P3.5 | ydb-mesh author edges | ydb-mesh#3 | ✅ done 2026-10-09 |
| P3.6 | ydb-infra portal credential rotation | (no ticket) | ✅ done 2026-10-09 |

## P4 — O'Kane GPL Mumps (benchmark only)

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P4.1 | Mac + U01/U02 native B-tree | okanes-mumps#1 | ✅ closed 2026-10-09 |
| P4.2 | Publish ISO score table | okanes-mumps#2 | ✅ done 2026-10-08 (87/36/0) |
| P4.3 | Classify O'Kane MISSes | okanes-mumps#2 | ✅ closed 2026-10-09 |

## P5 — fst Track F — **FROZEN**

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P5.0 | Gold C second judge / ranking items 4–6 | — | **removed** from path (2026-10-09 user) |
| P5.5 | Restore Horn B scripts | (no ticket; item 7) | ✅ 2026-10-08 |
| P5.f | **Freeze: reference only, no feature work** | fst#10 parked | **FROZEN 2026-10-09** |

## P6 — tooling

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P6.1 | m-lsp DO/FOR block context | m-lsp#1 | ✅ closed |
| P6.2 | m-lsp FOR arg-list + indirect `@` | m-lsp#2 | ✅ closed |
| P6.2b | m-lsp FOR hover edge cases | m-lsp#3 | ✅ closed 2026-10-09 |
| P6.3 | m-semantics (no open gap) | (no ticket) | idle |
| **P6.4** | **Shared path/coverage docs hosted here** | (no ticket) | ✅ 2026-10-09 (moved from fst) |

## P7 — Comdb2 on U01 + U02

| # | Work | Ticket | Status |
|---|------|--------|--------|
| P7.1 | Deps + clone + cmake + **GCC 15** flags + build | (no ticket) | ✅ both hosts `eb6dfab` |
| P7.2 | `make install` → `/opt/bb` | (no ticket) | ✅ both hosts |
| P7.3 | pmux + single-node `testdb` + SQL smoke | (no ticket) | ✅ READY (`DIRECTIO 0`) |
| P7.4 | 2-node cluster (`cluster nodes` + `copycomdb2`) | (no ticket) | ✅ READY · master `utility-02` |
| P7.5 | UFW Tailscale-only + systemd + logs | (no ticket) | ✅ done 2026-10-08 |

### Optional track (2026-10-09)

| # | Work | Ticket | Status | Parallel with author-pass? |
|---|------|--------|--------|----------------------------|
| **P3.5b** | **MARC author-pass** (`--marc` catplus/serfile) | **ydb-mesh#4** | **QUEUED** (chain) | **No** — same `^AUTHOR`/`^GRAPH` store |
| **P3.3b** | **Custom web routes** (static `/var/ydb/web` + `/api/*` + Caddy `/ydb`) | (no ticket) | ✅ 2026-10-09 | **Yes** |
| **P8** | FreeM upstream watch | freem-ops#1 | ✅ **closed 2026-10-09** — not actively developed; wait indefinitely on #5/#6 | — |

Detail: `~/comdb2/CRITICAL_PATH.md`.

---

## Interleaved path (order of attack)

```
  P1.7   JvMumps J12–J17 catch-up → 131/8/0     (J12–J13 done; now J14–J17)
  P1.8   mJVM M10–M12 catch-up → 131/8/0        (after / shared semantics with J12–J16)
  P3.5b  MARC author-pass (ydb-mesh#4)          (U01, in flight — independent)

  FROZEN: fst (reference only)
  BELAYED: fst Gold C · ydb-py GUI
```

---

## Next action (do this now)

**IN FLIGHT:** PubMed **author-pass** on U01 (`author-pass.log`) · tracker **ydb-mesh#4** · MARC chained behind it.
**NOW:** **ydb-mesh#4** author-pass (PubMed 1104/1334 on U01; MARC chained). Close with totals when both done.
**DONE 2026-10-10:** P1.7 JvMumps + P1.8 mJVM **and** native mJVM — all **131/8/0**. jvmumps#7–#15 closed.

**P5 frozen:** fst reference only — do not open feature work. Tag `frozen-2026-10-09`.
**P8 closed:** FreeM not under active development — indefinite upstream wait (CoherentLogic #5/#6).

---

## Issue index (open GitHub)

| Repo | Open |
|------|------|
| `mjandrews1/jvmumps` | **0 open** — #7–#15 closed 2026-10-10 (JvMumps + native mJVM 131/8/0) |
| `mjandrews1/ydb-mesh` | **#4** full author-pass **IN FLIGHT** (PubMed; MARC chained) |
| `mjandrews1/fst` | **#10** two-week work log — **parked** with freeze |

**All other repos: 0 open** (pymumps · c3mumps · ydb-py · ydb-infra · okanes · freem-ops · m-lsp · rsm · **c3m** · **c3fst**).

**Legacy closed 2026-09-25 era (c3m/c3fst, rsm#18 deprecated):** 11 c3fst + 18 c3m issues closed as obsolete.
