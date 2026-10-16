# Master critical path — all projects (unified)

**Last updated:** 2026-10-15 · **Home:** `m-semantics/docs/MASTER_CRITICAL_PATH.md` · **≡** `~/CRITICAL_PATH.md`  
**Detail docs:** JavaM `jvmumps/CRITICAL_PATH.md` · MeshGraph `ydb-mesh/CRITICAL_PATH.md` · tsx · ydb-infra · `jvmumps/docs/ROADMAP-0.5.0.md` · `jvmumps/docs/BENCH.md`

**Name lock:** **MeshGraph** = product · **`ydb-mesh`** = code · **JavaM** = `mjandrews1/JavaM` · **tsx** = Comdb2 time-series.

**Focus (2026-10-15):** JavaM **v0.5.0** perf close-out · MeshGraph post-BM25 · tsx P1–P2 · infra U03.

## How to read

Priority-ordered path. Status: **OPEN** · **IN FLIGHT** · **DONE** · **FROZEN**.

---

## Project map

| Project | Role | Stream |
|---------|------|--------|
| **RSM** | M oracle (U01) | never a port target |
| **JavaM** (JvMumps + mJVM) | full-M + JVM-native M · **131/8/0** | **P1** |
| **MeshGraph** (`ydb-mesh`) | YottaDB citation index (BM25 live) | **P2** |
| **tsx** | Comdb2 time-series (USGS/NOAA/pinksheet) | **P3** |
| **ydb-infra / utility-03** | hosts, Caddy, backup, U03 edge | **P4** |
| **m-semantics / m-lsp** | Dafny spec + docs | P5 |
| **PyMumps / C3Mumps** | peer-proof **freeze** | FROZEN |
| **fst** | frozen | FROZEN |
| **okane / freem** | adjunct / upstream WAIT | P6 |
| **comdb2** | SQL plane (U01+U02 cluster READY) | infra |

---

## Critical path (2026-10-15)

```
  P0  JavaM PR#127 / #126     Cdb2 LOCK + TSTART          ← merge
  P0b JavaM #122 #123         store audit close-out
  P1  JavaM v0.5.0            perf cycle → tag v0.5.0
  P2  MeshGraph #28 operator registry publish · remaining polish
  P3  tsx#4                   archive cdb2sql PATH (broken cron)
  P4  tsx #2 #3               replica+caps · terminal
  P5  ydb-infra #14–#23       utility-03 edge / backup / DNS
  P6  JavaM #32               FileMan Tier A (1.0 gate)
  P7  JavaM #25 #26           Dafny DO/GOTO + 8 misses
```

---

## P0 — JavaM v0.5.0 remainder

| Work | Ticket | Status |
|------|--------|--------|
| PerfMatrix / matrix / footprint / store-lock / findings | JavaM#97–#102 #31 #33 | **DONE** |
| Cdb2 LOCK + TSTART undo | JavaM#126 (PR #127) | **IN FLIGHT** |
| Concurrency + store matrix | JavaM#122 #123 | **OPEN** |
| Next tag v0.5.0 | — | after #122/#123/#126 |

## P1 — JavaM 1.0 track

| Work | Ticket | Status |
|------|--------|--------|
| FileMan Tier A no ENGINE GAP | JavaM#32 | **OPEN** (1.0 gate) |
| Dafny CALL_PC/JMP + 8 misses | JavaM#25 #26 | **OPEN** |
| REPL | JavaM#35 #36 | **OPEN** |
| VistA full run | JavaM#34 | **OPEN** |
| Rename hygiene | JavaM#27 | **OPEN** (docs refresh in this pass) |

## P2 — MeshGraph (post-BM25)

| Work | Ticket | Status |
|------|--------|--------|
| PTERM BM25 rebuild + catch-up + smoke | ydb-mesh#12 | **DONE** 2026-10-15 |
| M DS libs HMAP/HSTACK/… | ydb-mesh#13 | **DONE** |
| Author-pass PubMed + MARC | ydb-mesh#4 | **DONE** |
| `related_rev()` / out-edges | ydb-mesh#15 | **DONE** PR #35 |
| MeSH edge orientation | ydb-mesh#23 | **DONE** PR #35 |
| Portal search UX (top-k + titles) | ydb-mesh#24 | **DONE** PR #35 |
| Perf + limit probes | ydb-mesh#20 | **DONE** PR #36 |
| MCP registry | ydb-mesh#28 | **WAIT** submit kit ready (operator publish) |
| PubMed completeness / MCP v0 smoke | ydb-mesh#25–#27 | **VERIFIED** PR #38 (dangling=0) |

**No MeshGraph cron** — rebuilds were one-shots. Live: `mesh-search.service`, YDB web, dashboard.

## P3 — tsx scheduled jobs (U01)

| Job | Cron | Status |
|-----|------|--------|
| USGS acquire | `:43` hourly | **OK** |
| USGS load | `:50` hourly | **OK** |
| NOAA wx | `:20` hourly | **OK** |
| cap_check | `:17` hourly | **OK** (0.27/2 GB active) |
| **archive_cdb2** | `27 3 * * *` | **BROKEN** — `cdb2sql` PATH → **tsx#4** |
| Pink Sheet | 5th 04:15 | OK (monthly) |

| Work | Ticket | Status |
|------|--------|--------|
| archive PATH fix | tsx#4 | **OPEN** |
| P1 replica + caps | tsx#2 | **OPEN** |
| P2 terminal surface | tsx#3 | **OPEN** |

## P4 — infra / utility-03

| Work | Ticket | Status |
|------|--------|--------|
| utility-03 edge (Caddy, jump, git, TUI) | ydb-infra#14–#17 | **OPEN** |
| Backup / read node / provisioning | ydb-infra#19–#21 | **OPEN** |
| Move MeshGraph search + MCP to U03 | ydb-infra#22 | **OPEN** |
| Porkbun DNS + /mcp | ydb-infra#23 | **OPEN** |

## Done (historical — do not reopen)

- **P ports** Py/C3/JavaM + mJVM native **131/8/0**
- **ydb-mesh#12** BM25 · **#13** DS libs · **#4** author-pass
- **JavaM v0.4.0** (Cdb2 mesh, `$ORDER`, fleet smoke) 2026-10-15
- **Perf review** #97–#102 + BENCH/PERF-REVIEW/BENCH-BACKENDS
- **Comdb2** U01+U02 cluster READY · **ydb-infra#1** JDK · **rsm#30** coverage
- **m-semantics#12** path refresh (superseded by this 2026-10-15 pass)

## Scope lock

| Role | |
|------|--|
| JavaM + mJVM | primary |
| RSM | only oracle |
| Py/C3 | corpus freeze |
| MeshGraph / tsx | data products (not M oracles) |
| fst / O'Kane / FreeM | frozen / adjunct |
