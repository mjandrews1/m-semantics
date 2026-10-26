# Master critical path — all projects (unified)

**Last updated:** 2026-10-26 · **Home:** `m-semantics/docs/MASTER_CRITICAL_PATH.md` · **≡** `~/CRITICAL_PATH.md`
**Detail docs:** JavaM `jvmumps/CRITICAL_PATH.md` · `jvmumps/docs/ROADMAP-0.5.0.md` · mjvm `mjvm/docs/` · inventory `m-semantics/docs/MASTER-INVENTORY.md`

**Name lock:** **MeshGraph** = product · **`ydb-mesh`** = code · **JavaM** = `mjandrews1/JavaM` (JvMumps) · **mjvm** = `mjandrews1/mjvm` (JIT engine, now a separate repo) · **tsx** = Comdb2 time-series.

**Focus (2026-10-26):** mjvm v2.2.0 hardening close-out · JavaM REPL · fleet consolidation DONE · **YottaDB family PAUSED** (MeshGraph, tsx, comdb2) · U04 unprovisioned.

## How to read

Priority-ordered path. Status: **OPEN** · **IN FLIGHT** · **DONE** · **FROZEN** · **PAUSED**.

---

## Project map (post-cleanup 2026-10-26)

| Project | Role | State | Stream |
|---------|------|-------|--------|
| **mjvm** | M → JVM JIT engine (v2.2.0, GAUNTLET 134/134) | active, Mac-only tree | **P1** |
| **JavaM** (JvMumps) | full-M oracle + LineEngine (v1.2.0, 1.0 gate achieved) | active | **P1** |
| **m-semantics** | Dafny spec (464 lemmas) + master docs | active | P2 |
| **m-lsp** | language server | active, clean | P3 |
| **mformatter** | M formatter | idle, 1 untracked script | P3 |
| **tieredstore-rs** | Rust TieredStore prototype (published 2026-10-26) | active | P4 |
| **pymumps** | peer corpus host (restored on Mac) | active | P5 |
| **fileman** | frozen VistA corpus | frozen | FROZEN |
| **MeshGraph / ydb-mesh** | YottaDB citation index | **PAUSED** | FROZEN |
| **tsx / comdb2** | time-series + SQL plane | **PAUSED** | FROZEN |
| **RSM** | archived → `U02:coldstore/mac-rsm-2026-10-26/` | FROZEN | FROZEN |

---

## Critical path (2026-10-26)

```
  P0a Portal password rotation          (user, outstanding since 2026-10-26)
  P0b U01 YottaDB journal trim          (overdue — backup_then_prune WARN 2026-10-17)
  P0c U04 role decision                (unprovisioned MacMini 1TB)
  P1a mjvm hardening close-out         (compiler coverage, silent-recovery audit, README units)
  P1b mjvm v2.2.0 release tag          (CHANGELOG done, no git tag yet)
  P2a JavaM REPL                       (#35/#36 — both engines)
  P2b JavaM rename hygiene + VistA     (#27, #34)
  P3  tieredstore-rs                    (README, CI, spec sync)
  P4  Infra: backup redundancy + U03 mirror health + monitoring
  P5  Paused-family resume checklist   (documented below, do not act)
```

---

## P0 — Immediate (infra hygiene)

| Work | Status | Note |
|------|--------|------|
| Rotate portal credential (`home.flamingyak.com`) | **OPEN** (user) | Scrubbed from skill files 2026-10-26; rotation itself outstanding |
| U01 journal trim | **OPEN** | `backup_then_prune.log` 2026-10-17: `WARN rotated journals exceed keep (3) — run journal trim` · `CAP CHECK fail=1`. Keep current `yottadb.mjl` + 2 newest; `ls yottadb.mjl_* \| sort \| head -n -2 \| xargs rm -f` |
| U04 role decision | **OPEN** (user) | 1TB MacMini. Candidates: second copy of U02's 222G `meshgraph-backup` (single-copy risk) · PubMed coldstore continuation if YDB resumes (PIPELINE-PAUSED option 3) · CI runner |
| jvmumps working tree | **OPEN** | `BankScaleBench.java` modified, uncommitted — commit or discard |

## P1 — mjvm (primary dev)

| Work | Status | Note |
|------|--------|------|
| GAUNTLET 134/134 · regression 30/30 · corpus 139/139 | **DONE** | Verified 2026-10-26, all suites on Mac |
| Version unified 2.2.0 (CLI/dist/CHANGELOG) | **DONE** | c3f36cf, pushed |
| Compiler coverage: 36% → target 60% | **OPEN** | Compiler is where all 10 v2.2.0 bugs lived; peephole + error-recovery paths first |
| Silent-recovery audit | **OPEN** | `DEPTH30` returns empty IR silently (MFrontend); historical error-handler replaced bad lines with RET. Convert to hard errors |
| README perf-number consistency | **OPEN** | Units differ across tables (10,155K vs 13.5M vs 83.6M txn/ms); pick one benchmark format |
| Tag `v2.2.0` + release | **OPEN** | Use RELEASE-CHECKLIST.md |

## P2 — JavaM / m-semantics

| Work | Ticket | Status |
|------|--------|--------|
| 1.0 gate (FileMan Tier A/B/C, 135/4/0) | JavaM#32 #25 #26 | **DONE** (2026-10-17) |
| v1.2.0 release | — | **DONE** |
| REPL both engines | JavaM#35 #36 | **OPEN** ← next attack |
| Rename leftovers (docs/CI badges) | JavaM#27 | **OPEN** |
| VistA full run under JavaM + mJVM | JavaM#34 | **OPEN** (last: 99.97%) |
| Dafny deepening (464 verified) | m-semantics | **DONE** this cycle · m-semantics pushes are PR-only (branch policy) |

## P3 — m-lsp / mformatter

| Work | Status | Note |
|------|--------|------|
| m-lsp | **CLEAN** at c9ba9dd | No open work identified |
| mformatter | **OPEN** | `run_mformatter.sh` untracked — commit or archive; ISO-8859-1 fix landed |

## P4 — tieredstore-rs (new repo)

| Work | Status | Note |
|------|--------|------|
| Published github.com/mjandrews1/tieredstore-rs | **DONE** | 2 commits, mirrored on U03 |
| README | **OPEN** | Repo has no README (only module docs) |
| CI (GitHub Actions: cargo test) | **OPEN** | No CI today; property tests must run in the cloud |
| Spec sync with `TieredStore.dfy` | **OPEN** | Keep property tests tracking the Dafny spec |

## P5 — Infrastructure

| Work | Status | Note |
|------|--------|------|
| Fleet consolidation (archives → U02, dedup, mirrors) | **DONE** | 2026-10-26, all checksums verified — see MASTER-INVENTORY |
| U03 mirror sync bug (frozen snapshots) | **DONE** | All 11 mirrors now carry `+refs/heads/*:refs/heads/*`; verified live |
| U03 mirror health visibility | **OPEN** | `update_git_mirrors.sh` is silent on success — add a timestamped log line or last-success marker so staleness is detectable |
| U02 `meshgraph-backup` (222G) single copy | **OPEN** | Top data risk. Second copy → U04 when provisioned |
| U01 journal rotation while paused | **OPEN** | Optional weekly cron for the manual trim (runbook procedure) |
| Monitoring / alerting | **OPEN** | None fleet-wide. Minimum: nightly disk/mirror/report ping (U03 cron could host it) |
| GitHub App connector | **NOTE** | Lacks repo-create + PR perms; use `gh` CLI on Mac (authed, works) |

## P6 — Paused family: resume checklist (do NOT act while paused)

The YottaDB family is paused by owner decision (2026-10-26). State preserved and verified:

- **U01 live DB**: YottaDB database (live `yottadb.dat` ~237G of U01's 243G usage) + 799M `~/db` tsx blobs; last journal write Oct 10; `~/_data` pipeline state + markers intact.
- **U02 backup**: `coldstore/meshgraph-backup/yottadb.dat` 237G, Oct 16 vintage — **verified newer than last write**.
- **Resume path**: (1) provision U04 as coldstore continuation (PIPELINE-PAUSED option 3), (2) restore from U02 backup, (3) resume author-chain/PubMed catch-up, (4) tsx: rebuild comdb2 from upstream (source trees deleted in cleanup — data intact).
- **Do not**: reboot U01 mid-load, start a second YDB writer, or prune U01 `~/db` / `~/_data` while paused.

---

## Done (historical — do not reopen)

- **2026-10-26 fleet cleanup** — all 5 phases + follow-ups (PRs #47 #48); YDB backup currency proven; mirrors fixed fleet-wide
- **mjvm v2.2.0** correctness hardening — 10 bugs, 30 regression tests, Dafny 335→464
- **JavaM v0.4.0 / v0.5.0 / v1.2.0** · perf review #97–#102 · concurrency audits #119–#123 · Cdb2 LOCK/TSTART #126
- **MeshGraph** BM25 rebuild + author-pass + related_rev (pre-pause, all green)
- **P ports** Py/C3/JavaM + mJVM native — corpus freeze
- **U03 commissioned** (mirrors + DNS) 2026-10; LXC containers deleted 2026-10-26 (unused, verified empty)

## Scope lock

| Role | |
|------|--|
| mjvm + JavaM | primary development |
| RSM | oracle only (archived) |
| Py/C3 | corpus freeze |
| MeshGraph / tsx / comdb2 | data products, **PAUSED** |
| fst / O'Kane / FreeM | frozen / adjunct |
| m-semantics | spec + master docs home (PR-only main) |
