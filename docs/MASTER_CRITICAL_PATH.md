# Master critical path — all projects (unified)

**Last updated:** 2026-10-27 · **Home:** `m-semantics/docs/MASTER_CRITICAL_PATH.md` · **≡** `~/CRITICAL_PATH.md`
**Detail docs:** JavaM `jvmumps/CRITICAL_PATH.md` · `jvmumps/docs/ROADMAP-0.5.0.md` · mjvm `mjvm/docs/` · inventory `m-semantics/docs/MASTER-INVENTORY.md`

**Name lock:** **MeshGraph** = product · **`ydb-mesh`** = code · **JavaM** = `mjandrews1/JavaM` (JvMumps) · **mjvm** = `mjandrews1/mjvm` (JIT engine, now a separate repo) · **tsx** = Comdb2 time-series.

**Focus (2026-10-27):** mjvm **v2.2.2** shipped · **U04 commissioned as fleet CI runner** (all 4 repos green on self-hosted CI) · **fleet posture hardened + edge containerized on U03** (fenced, key-only SSH, public 22 closed) · **MeshGraph RESUMED** — services up, public via the edge, scheduled updates + backup timers live, c3fst deprecated · remaining: portal rotation, U02 backup second copy.

## How to read

Priority-ordered path. Status: **OPEN** · **IN FLIGHT** · **DONE** · **FROZEN** · **PAUSED**.

---

## Project map (post-cleanup 2026-10-26)

| Project | Role | State | Stream |
|---------|------|-------|--------|
| **mjvm** | M → JVM JIT engine (v2.2.1, GAUNTLET 134/134) | active, Mac-only tree | **P1** |
| **JavaM** (JvMumps) | full-M oracle + LineEngine (v1.2.0, 1.0 gate achieved; repo ARCHIVED) | active-local | **P2** |
| **m-semantics** | Dafny spec (464 lemmas) + master docs | active | P2 |
| **m-lsp** | language server | active, clean | P3 |
| **mformatter** | M formatter | idle | P3 |
| **tieredstore-rs** | Rust TieredStore prototype (published, CI green) | active | P4 |
| **pymumps** | peer corpus host (restored on Mac) | active | P5 |
| **fileman** | frozen VistA corpus | frozen | FROZEN |
| **MeshGraph / ydb-mesh** | YottaDB citation index (41.2M articles, 2.8B postings) | **ACTIVE — resumed 2026-10-27** | P5 |
| **tsx / comdb2** | time-series + SQL plane | **PAUSED** | FROZEN |
| **RSM** | archived → `U02:coldstore/mac-rsm-2026-10-26/` | FROZEN | FROZEN |

---

## Critical path (2026-10-26, post-P0–P5)

```
  P0a Portal password rotation          (user — only remaining P0 item)
  P1a mjvm compiler coverage 36.4% → 60% (peephole + error paths first)
  P2a JavaM REPL                       (#35/#36 — both engines)
  P2b JavaM rename hygiene + VistA     (#27, #34)
  P4  Infra: U02 backup second copy    (U04 now provisioned — 828G free VG)
  P5  MeshGraph follow-ups             (MARC author pass, MCP registry listings — see P6 section)
```

---

## P0 — Immediate (infra hygiene)

| Work | Status | Note |
|------|--------|------|
| Rotate portal credential (`home.flamingyak.com`) | **OPEN** (user) | Scrubbed from skill files 2026-10-26; rotation itself outstanding |
| U01 journal trim | **RESOLVED (no-op)** | Oct 17 WARN was stale — zero rotated `yottadb.mjl_*` remain; rotation cannot recur while the DB is quiescent. No cron added (dead weight while paused) |
| U04 role decision + commissioning | **DONE — CI runner (2026-10-27)** | Late-2014 **Mac mini** hardware running Ubuntu 26.04 LTS — **i5-4278U, 2C/4T, 7.1G RAM, 1TB spinning HDD**. Hostname `utility-04`; Tailscale **100.79.52.105** (authed 2026-10-27); LAN fallback `192.168.0.32`. 4 per-repo GitHub Actions runners (`u04-mjvm/-m-lsp/-m-semantics/-tieredstore-rs`) online as systemd services; rsyslog → U03 verified; all 4 CI workflows flipped to `self-hosted` (m-lsp PR #16, m-semantics PR #55, both merged) |
| U03 sshd hardening + fleet posture | **DONE (2026-10-27)** | U03 (public edge): `PasswordAuthentication no` via `/etc/ssh/sshd_config.d/40-disable-password.conf` — OpenSSH is first-match-wins, so `40-` beats cloud-init's `50-`; same fix on U04. U01/U02 already key-only (`99-harden.conf`). UFW active on all 4 hosts: default deny in / allow out, `allow in on tailscale0`, LAN 22 fallback; U03 additionally allows public 80/443 only. **Public 22 closed (2026-10-27 evening)** — SSH is now tailnet + LAN-only fleet-wide; external check confirms port 22 times out while 443 serves. Caddy + fail2ban run **only on U03 (edge)** — disabled on U01 (stale pre-Oct-20 edge config) and U02 (vestigial). U04 remote-log dir on U03 fixed to `syslog:adm 755`. Fleet `mark` password is standard — keep in the password manager, never in skill files |
| jvmumps working tree | **DONE** | `BankScaleBench --cache` flag committed (954dff2) — **local-only**: JavaM repo is ARCHIVED on GitHub (read-only), so the commit cannot be pushed. Frozen-oracle policy applies |

## P1 — mjvm (primary dev)

| Work | Status | Note |
|------|--------|------|
| GAUNTLET 134/134 · corpus 139/139 · CoreUnitTest 135/135 | **DONE** | Verified 2026-10-26, all suites on Mac |
| Silent-recovery audit | **DONE — v2.2.1** | Found THREE silent depth returns (compile, compileInto, **compileForSpec** — the last silently dropped a 16th nested inline FOR's whole body, a real pre-existing bug). All now throw MError; swallowed lines logged + recorded in new `lastSwallowedErrors()` ledger; compileDepth balanced via try/finally (leaked on every compile error before). 2 new regression tests (32/32). Released as **v2.2.1** (v2.2.0 was already tagged Oct 25) |
| Compiler coverage | **MEASURED, TARGET OPEN** | 36.4% lines (total project 79%, runtime 62.3% — the old "19%" CHANGELOG figure predates CoreUnitTest). 60% compiler target remains open work: peephole + error paths first |
| Silent-recovery audit round 2 | **DONE — v2.2.2** | Four more sites fixed (unknown-command skip → throw; WRITE-sub swallow → propagate; `$GET`/`$DATA` catches narrowed to the undefined case). 32/32 regression, GAUNTLET 134/134, corpus 139/139 |
| README perf-number consistency | **DONE** | Contradicting "13.5M txn/ms" removed; BankFull table is now the single source |
| **VistA swallowed-syntax backlog** | **IN FLIGHT — classes 1-2 DONE, class 4 next** | Ledger protocol working: baseline 21,452 routines (63.2%) with swallowed lines / 223,453 entries; after class 1 (dotted stage 1, mjvm `bc23951` `9727848` — mid-line argless-D merger, space-dot levels, syn-body RET; plus a pre-existing compileInto patch-offset bug that made `F … D` + block silently no-op at runtime) and class 2 (SET targets, `d376761` — `S (A,B)=` lists evaluated once, quote-aware subscripts): **14,430 routines (42.5%), 60,225 entries (−73%)**. Remaining board: comma 17,057 (28.3%) → postcond 16,204 (26.9%) → @ 4,168 → dotted no-D heads 2,483 → $ 1,182 → SET residue 1,180 → tail 9,070. All suites green per class (regression 45/45, GAUNTLET 134/134, J0Smoke 139/139, CoreUnitTest 135/135). Detail + per-class numbers: `mjvm/docs/VISTA-SYNTAX-BACKLOG.md` |
| Tag/release | **DONE** | v2.2.1, v2.2.2 tagged + pushed; GAUNTLET/corpus/core green post-change |
| **AGENTS.md error policy** | **DONE — fleet-wide** | Adopted in all 8 repos 2026-10-26. Pushed: mjvm, mformatter, tieredstore-rs (direct), m-semantics (PR #51), m-lsp (PR #15). Local-only (repos archived): jvmumps, pymumps, fileman |
| **mjvm CI fix (untracked jars + gates)** | **DONE (2026-10-27)** | GitHub CI had been **red since `9727848`** (local suites green, CI silently broken): `lib/` was gitignored but jars added later were never force-added — `archunit-1.3.0.jar` (`9ea0c2e`) and `jmh-core-1.37.jar` (`0d7eede`) now tracked. GAUNTLET latency gates are env-overridable (`GAUNTLET_{ARITH,STRING,GLOBAL,MIXED}_GATE_NS`, `01910f7`; defaults unchanged); CI sets Global=4000ns for u04's HDD. **GAUNTLET 134/134 green on u04** |

## P2 — JavaM / m-semantics

| Work | Ticket | Status |
|------|--------|--------|
| 1.0 gate (FileMan Tier A/B/C, 135/4/0) | JavaM#32 #25 #26 | **DONE** (2026-10-17) |
| v1.2.0 release | — | **DONE** |
| REPL both engines | JavaM#35 #36 | **OPEN** ← next attack |
| Rename leftovers (docs/CI badges) | JavaM#27 | **OPEN** |
| VistA full run under JavaM + mJVM | JavaM#34 | **OPEN** (last: 99.97%) |
| Dafny deepening (464 verified) | m-semantics | **DONE** this cycle · m-semantics pushes are PR-only (branch policy) |
| **GraphStore.dfy** — MeshGraph store invariants | m-semantics | **DONE (2026-10-27)** — 25 lemmas, 0 errors (Dafny 4.11): paired relation datatype (orientation ambiguity unrepresentable), ^GRAPH/^GRAPHREV two-record model with count agreement + even totals, no-dangling, corpus index integrity (`indexed ⇒ stored`) with the phantom-PTERM incident as violation witness + repair lemma. CI verifies it (PR #67) |

## P3 — m-lsp / mformatter

| Work | Status | Note |
|------|--------|------|
| m-lsp | **CLEAN** at 5aa377d | Self-hosted CI merged (PR #16); runs on `u04-m-lsp` |
| mformatter | **DONE** | `run_mformatter.sh` (parallel VistA corpus driver) committed + pushed (b04cc88) |

## P4 — tieredstore-rs (new repo)

| Work | Status | Note |
|------|--------|------|
| Published github.com/mjandrews1/tieredstore-rs | **DONE** | Mirrored on U03 |
| README | **DONE** | Architecture, module map, Dafny-lemma test table |
| CI (build + clippy -D warnings + fmt + property tests) | **DONE** | First run green (36s); clippy warnings + formatting fixed pre-push |
| Spec sync with `TieredStore.dfy` | **DONE (initial)** | 9 runtime property tests map to Dafny lemmas; keep tracking the spec |

## P5 — Infrastructure

| Work | Status | Note |
|------|--------|------|
| Fleet consolidation (archives → U02, dedup, mirrors) | **DONE** | 2026-10-26, all checksums verified — see MASTER-INVENTORY |
| U03 mirror sync bug (frozen snapshots) | **DONE** | All 11 mirrors carry `+refs/heads/*:refs/heads/*`; verified live |
| U03 mirror health visibility | **DONE** | `update_git_mirrors.sh` logs a timestamped `mirrors-synced: N repos` line per run; staleness detectable from `git-mirrors.log` |
| Monitoring | **CONFIRMED PRESENT** | All four utility hosts + the `edge` container forward `*.*` to U03 via rsyslog TCP 514 (`60-forward-u03.conf`; container uses `imjournal`); U03 stores per-host under `/var/log/remote/{utility-01..04,edge}` (all `syslog:adm` readable). **Logrotate in place (2026-10-27)**: `/etc/logrotate.d/remote-syslog` on U03 (weekly, maxsize 100M, 12 kept, compress, HUP rsyslog postrotate — verified live) + caddy access-log rotation inside the edge container (copytruncate; fail2ban jail verified counting post-truncation) |
| Edge containerization | **DONE (2026-10-27)** | Public web edge on U03 moved to LXD container `edge` (Caddy 2.11.7 + fail2ban caddy-auth jail; host Caddy disabled; router forwards unchanged — NAT proxy `192.168.0.31:80/443` → `10.58.25.10`). LE production cert issued through the new path; snapshot `baseline-2026-10-27`. **Containment (DMZ-equivalent) applied**: container is internet-egress-only — ufw route denies + nftables `edge_fence` (priority -10, preempts Tailscale's `ts-forward` blanket accept and ufw's allow-22); lateral probes to LAN/tailnet/host-sshd verified blocked. Details: `MASTER-INVENTORY.md` §9d |
| U02 `meshgraph-backup` (222G) single copy | **OPEN** | Top data risk. Second copy → U04 (828G free VG — extend root LV or add a volume). Decision pending; U04's first role is CI |
| U01 journal rotation while paused | **CLOSED** | No rotated journals exist; cannot recur without a writer. On resume: manual trim per runbook |
| GitHub App connector | **NOTE** | Lacks repo-create + PR perms; use `gh` CLI on Mac (authed, works) |

## P6 — MeshGraph: RESUMED (2026-10-27)

Owner decision: MeshGraph re-enabled; **c3fst is entirely deprecated** (mdbx already purged; `c3mcp.service` disabled; the 2026-09-25 coldstore-continuation plan is dead history).

Resume record (2026-10-27):

- **DB up on U01**: live `yottadb.dat` 222G opened cleanly (no journal recovery needed); smoke queries OK (MeSH `D000001` Calcimycin; PubMed deep into 36-37M PMIDs). Corpus was fully current through the pause (the Oct-13 missing list of 1,188,839 PMIDs exactly matches the final `CATCHUP DONE`).
- **Services (systemd, U01)**: `mesh-search` (:8081 BM25 web), new `mesh-mcp` (:8082 JSON-RPC read-only MCP — unit created; no unit existed pre-pause), `ydb-web-server` (:9080), `ydb-dashboard-metrics`/`ydb-dashboard-ui` (:9188). Search/MCP/dashboard bind U01's tailscale IP via unit drop-ins (`100.72.84.8`).
- **Public edge (U03 container `edge`)**: `/search*` → 8081, `/mcp*` → 8082, `/dashboard*` → 9188 on `home.flamingyak.com`; new `mcp.flamingyak.com` vhost → 8082 (own LE cert issued). Portal basicauth re-scoped to `/ /ydb /ydb/*` (search/MCP/dashboard public + read-only, parity with pre-pause). Fence: scoped allow `10.58.25.10 → 100.72.84.8:{8081,8082,9188}` before the tailnet deny (both nft fence and a ufw route rule — note `ufw route insert NUM RULE` syntax; plain `ufw insert N route ...` silently fails). Snapshots: `pre-meshgraph-2026-10-27` (before wiring) + `baseline-2026-10-27` (minimal edge). All endpoints verified through the public path.
- **Scheduled updates (U01 systemd timers)**: `meshgraph-update` daily 03:00 UTC — fetch PubMed updatefiles (resumable, md5-verified) → load PMIDs missing from `^PUBMED` (`load_updates_missing.py`, skips present) → BM25/PTERM catch-up for docs lacking `^PTERMDLEN(pmid)` → completeness probe. `meshgraph-author` Sun 04:30 UTC — author pass over updatefiles. Scripts: `ydb-mesh/tools/daily-update.sh`, `tools/weekly-author.sh` (local-only — ydb-mesh repo is ARCHIVED). One-writer: flock `/run/lock/meshgraph-update.lock` + term_index-build guard. First catch-up run launched 2026-10-27 (17 days of updatefiles).
- **Backup (quiescent-copy, fleet precedent)**: `meshgraph-backup` Sat 02:00 UTC — refuses to run while any writer is active or the journal is growing; rsync `.dat` + journals to `U02:coldstore/meshgraph-backup` via `.inprogress` + atomic rename; size-verify; previous kept as `meshgraph-backup.old`. First post-resume backup should run after the first catch-up completes.
- **Known follow-ups**: MARC catline/serline author pass not scheduled (manual, post-update); MCP registry listings (Smithery/official registry, ydb-mesh#28) still TODO; `ydb-dashboard-ui.py` bind change is a local-only divergence (repo archived).

---

## Done (historical — do not reopen)

- **2026-10-26 fleet cleanup** — all 5 phases + follow-ups (PRs #47 #48); YDB backup currency proven; mirrors fixed fleet-wide
- **2026-10-27 U04 commissioned** — fleet CI runner (Ubuntu 26.04, LAN `192.168.0.32`); 4 self-hosted GitHub Actions runners online; all 4 active repos' CI green on U04; mjvm CI red-streak (untracked jars since `9727848`) found + fixed
- **2026-10-27 fleet posture hardened** — key-only SSH on all 4 hosts, UFW everywhere, Caddy+fail2ban consolidated on U03 (edge; brute-force bots now hit a wall), U04 on tailnet as `utility-04` (100.79.52.105)
- **2026-10-27 edge containerized** — public web edge on U03 now the LXD container `edge` (snapshot `baseline-2026-10-27`); router forwards unchanged; central logging covers the container
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
| MeshGraph | data product, **ACTIVE** (resumed 2026-10-27) |
| tsx / comdb2 | time-series plane, **PAUSED** |
| fst / O'Kane / FreeM | frozen / adjunct |
| m-semantics | spec + master docs home (PR-only main) |
