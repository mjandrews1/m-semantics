# Master critical path — all projects (unified)

**Last updated:** 2026-11-01 (fleet check; open items reordered — edge P0 + logrotate on top, U01 recovery confirmed; m-ils MVP expanded + item 11 added) · **2026-11-02:** dashboard/fuzz/disk-watch jobs moved Mac→U03 host (cron; dashweb on U03:8383, http://100.121.132.5:8383/); Mac Caddy + com.mjvm.fuzz launchd removed, Mac job-free; item 12 added (mJVM Java→Kotlin analysis, no code) · **2026-11-02 (eve):** U01 YottaDB DB scratched (block corruption confirmed; nightly update aborting) — meshgraph timers disabled on U01, GT.M migration confirmed (items 3, 11) · **2026-11-04:** critical + stand-alone lists merged into ONE plan ("★ THE PLAN" below, 6 phases, steps per phase, 2 parked) — it is now the critical path; end state = all steps DONE · **2026-11-04 (eve):** Phase 0 DONE — PR #45 merged (4e79149), GAUNTLET green on main; step 4 handed to agent: parser fixes committed on `p1b-parser` (34e8780, ec05094, 0aa9038), issues #4 #13 #16 #17 #18 #19 #21 #22 #24 #25 #35 closed, PR #47 open (local: ORACLE 97 pass/0 diverge, MFrontendRegression 53/53, GauntletRun 108/108); U03 fuzz ran 2026-11-04 07:30Z, 0 NEW · **2026-11-05:** step 17 SwiftM (P7) added — spec-first M in Swift for macOS, spec-validation learning port (m-semantics#72); step 8 blocker cleared (device-less O/U/C), dual-engine re-time done, EVAL_STORE fusion in PR #52; Dafny-proof gates added to steps 4, 8, 11, 14, 17 · **2026-11-06:** Phase 6.1 agent work landed on m-semantics branch `phase6-1-dafny-prereqs` — `MSetList.dfy` (SET comma-list left-to-right, comma-IF conjunction, NEW/KILL lists incl. exclusive kill; 33 verified), `MCommand.dfy` (postconditional universality, QUIT-in-FOR exits loop not routine, FOR list/postcond, argumentless NEW/KILL $TEST exception; 26 verified), `docs/MINIMAL-CONFORMING-M.md` (139-corpus split: 116 ISO-core + 8 ISO-1999 = 124 gate cases, 15 vendor) · step 1.3 refresh on U02 RUNNING (~75% at 2026-11-06 00:05Z check) · step 2.2 design doc DONE on m-ils master (aac99a0); impl PR m-ils#2 open (ILSTEST 39/39 dual-engine) · step 2.1 re-time on merged #52: mjvm ~0.91 s vs GT.M ~0.34 s = 2.7x on the 15 MB CAT fixture — ≤2x gate NOT met; next lever = IR dispatch structure, else owner-M call at ~2.7x · 2026-11-05 07:30Z U03 fuzz still shows parser-family KNOWNs (sub-gate NOT confirmed) + triage push rejected (remote ahead) · **1.5 mlang onboarding** (new Lenovo MX Linux laptop 192.168.0.36) launched as Mac background job `~/tools/mlang-onboard.sh` (status `~/soak/mlang-onboard.status`, log `~/soak/mlang-onboard.log`): polls for ssh, bootstraps via password (`~/.mlang-pass`), then fleet posture (key-only ssh, UFW, tailscale, rsyslog→U03, no-sleep masks) — port 22 was flapping/closed at launch; needs `sudo systemctl enable --now ssh` on the console if it stays closed · **2026-11-06 (rev3):** 1.3/1.4 demoted to ops once green (standing jobs, not plan steps); 2.1 gate decision framed (declare ~2.7x OR re-gate in-process steady-state); 2.3–2.5 await m-ils#2 merge; 3.1 gains triage re-baseline step; 4.1 pulled forward (parallel with Phase 2); 5.1 Dafny gate unblocked by 6.1 modules; 6.1 follow-up = open+merge PR for `phase6-1-dafny-prereqs`; 1.5 gate extended (inventory row + dashboard + role decision) · **2026-11-06 (later):** 6.1 PR opened (m-semantics#120); 3.1 re-baseline DONE on U03 after javac rebuild — parser-family KNOWNs persisted reduced (#19=12, #22=8, #24=4, #29=5, #30=6, #31=16; NEW=0) — U03 build/ was stale since 11-04, `fuzz-nightly.sh` now rebuilds+pulls before fuzzing; **6.2 DONE** — `mjandrews1/swiftm` repo created, docs-only scaffold on main (285890b) · **2026-11-06 (eve):** the KNOWN cluster root-caused to the NEW_ALL scope leak, NOT the FOR parser — fixed in **mjvm PR #55** (63a7cee): NEW now hides and exactly restores ALL locals; NewAllRegression 8/8; ORACLE 98/0/0; **fuzz seeds 61106–61111 (1,200 programs): KNOWN 0, NEW=0** · **1.3 DONE-OK 2026-11-06 02:51:42Z — all 3 files md5-identical U02==U04** · **4.1 LAUNCHED** as Mac background job `tools/mesh-4.1-drive.sh` (ydb-mesh PR #59, tools MESHX/MESHL: line-based R/X-tagged binary-safe export, cross-engine round-trip md5-verified; status `~/soak/mesh-4.1.status`) · **1.4 WIRED** on U03 (web-lxc-check.sh cron+dashboard, ydb-mesh f2307b2) — caught **edge https=000 incident** (edge Caddy has no 443 listener; LE cert not provisioned — owner M decision) · **6.3 WIP**: swiftm core interpreter committed on `impl/6.3-core-interp` (a314a7e) — MValue/AST/parser/store/intrinsics/CLI written, build mid-fix, corpus gate not yet run; 5.1 not started · **2026-11-06 (rev4):** **1.6 added — mlang role DECIDED (owner M): production M-runtime host** — mlang (192.168.0.36) runs production distributions/instances of **RSM, GT.M, PyMumps, mJVM, SwiftM, and Mumps II (Kevin O'Kane) delivered from the dev/test machines** (Mac/U03/U04); NO dev/test work on the engines themselves happens on mlang — only M code is written there and run against the six environments; **Mumps II runs with its default built-in storage mechanism, NOT relational databases**; deliverables = (a) GitHub repo for the M code written on mlang, (b) standard install/maintenance/upgrade/uninstall process for all six environments, (c) install/maintain tooling, (d) standard test + timing + performance apparatus (shared corpus `pymumps/tests/conformance.json` + timing suite across all six engines) — see step 1.6 below · **6.3 progress 2026-11-06:** swiftm build fixed on `impl/6.3-core-interp` (Parser/Interpreter/Store/CLI); corpus gate harness = `swiftm dump` vs mjvm LineEngine dump over all 139 cases: **136/136 match** (the 3 remaining corpus cases C103/C104/C105/C107 are multi-routine and skipped by mjvm LineEngine too — harness-limited) after fixing WRITE forms `*n/?n/#/@`, `@`-indirection, `$P` splice, `$F`/`$A`/`[` edges, postconditionals, patterns, $QUERY/$ORDER, $ETRAP — commit+PR pending · **2026-11-06 (rev5, eve):** re-ordered by execution priority + renumbered (m-ils MVP = Phase 1, fleet/ops = Phase 2, campaign = Phase 3, migration = Phase 4, VistA = Phase 5, SwiftM = Phase 6 — mapping in THE PLAN intro) — mjvm#55 + m-semantics#120 MERGED 23:18Z, swiftm#1 open (136/136), mesh-4.1 RUNNING (EXPORT-U02 since 03:06Z), mlang onboarding PROVISIONING; old 1.3 closed DONE-OK, old 1.2 + weekly U02 refresh + hourly web-lxc-check demoted to standing ops · **Home:** `m-semantics/docs/MASTER_CRITICAL_PATH.md` · **≡** `~/CRITICAL_PATH.md`


## ★ THE PLAN — single merged critical path (rebuilt 2026-11-04; reordered + renumbered 2026-11-05 rev2; rev3 2026-11-06; rev5 2026-11-06 eve — re-ordered by execution priority + renumbered) ← HERE ★

One list, in execution order. **End state = every step DONE.** Owner: **M** = mark (user), **A** = agent (Vibe).
**Numbering rev5 (2026-11-06 eve):** re-ordered by execution priority and renumbered — m-ils MVP is Phase 1, fleet/ops Phase 2, conformance campaign Phase 3, MeshGraph migration Phase 4, VistA Phase 5, SwiftM Phase 6; steps numbered within each phase. Mapping from rev3 (2026-11-06): old 2.x → 1.x, old 1.x → 2.x, old 3.1 → 3.1, old 4.x → 4.x, old 5.1 → 5.1, old 6.x → 6.x. Older numberings for issue-tracker references: 2026-11-04 steps 1–17; 2026-11-05 rev1/rev2 phases.
Tracked on GitHub: mjvm#46 (Phases 3, 5) · m-ils#1 (Phase 1) · ydb-mesh#58 (Phase 4) · m-semantics#72 (Phase 6).
Gates referenced: corpus 139 (`J0Smoke`), ORACLE (`tools/oracle/run.sh`, red only on diverge/err), GAUNTLET CI on u04,
JMH bench, smoke suite. Dafny corpus (m-semantics, 13 .dfy modules: MSemantics 73, MControl 84, MRelOps 24, MPattern 25, PEMDAS 5, TieredStore 28, GraphStore 20, BM25 21, Scan 8, BST 14, Bank 48, MSetList 33, MCommand 26 lemmas; 547+ verified — MSetList/MCommand landed 2026-11-06 via m-semantics#120) — every semantic change lands with lemma verification (`dafny verify`). Current state noted per step.

(Recently DONE, for the record: #40 collation 5135b54 · #33 store consolidation a93e081 · Comdb2 3-node COHERENT · jobs audit PR #100 · dashboard PR #101 · edge restored ydb-mesh#53 · logrotate ydb-mesh#54 · portal rotation 2026-11-03 · U01 YDB DB scratched 2026-11-02 (corrupt; timers disabled) · perf tranche 2026-11-03/04 (-50% hot loop; PR #45 merged 4e79149 — 11-04 step 1) · 1M-PMID export→reload verified on U04 · parser family DONE 2026-11-04 eve (PR #47 merged 2220408, ORACLE known-bugs=0; Dafny: operator fixes pinned in MRelOps.dfy, 24 lemmas, C24/C16 classes — 11-04 step 4) · engine-gap micro-benchmarks recorded 2026-11-04 (INTLOOP 5.6x GT.M — 11-04 step 5) · YDBTest cross-engine scoped run DONE 2026-11-04 (`m-ecosystem/YDBTEST-CROSSENGINE-2026-11-04.md` — 11-04 step 6) · fuzz-triage loop live on U03 since 2026-11-03, 0 NEW 10-29→11-04 (11-04 step 3) · **2026-11-05:** ingest device-loop blocker cleared (device-less `O fn`/`U fn`/`C fn` from PR #50; `ils-fixture/mjvm_full.m` ported), dual-engine re-time done (mjvm ~0.91 s vs GT.M ~0.34 s ingest-only on the 15 MB CAT fixture, dumps byte-identical, 20,723 lines), EVAL_STORE fusion in PR #52 (-6.0% on the 20M SET loop), fixture runner added (mjvm PR #53, `tools/build-fixture-run.sh`) · SwiftM (P7) on the path as Phase 6; ydbtest LXC container STOPPED 2026-11-05 (job done 11-04, idle since; image/snapshot kept — recreate for the parked full-gtmtest engagement).)

### Phase 1 — m-ils MVP (m-ils#1) — active product milestone, first in execution order
- [ ] 1.1 **Merge m-ils#2 — min-viable auth/accounts + circulation + ILL** (was 2.3–2.5): implemented on `impl/mvp-expansion-20261102` (c6e17e3, ea7ac7f), ILSTEST 39/39 dual-engine, PR open since 2026-11-02. Owner M review+merge; every change ILSTEST all-OK on GT.M (U01:8282) AND mjvm (Mac:8282). Design doc DONE 2026-11-02 (aac99a0, `docs/MVP-EXPANSION-DESIGN.md`; was 2.2).
- [ ] 1.2 **Ingest gate decision (mjvm#43, was 2.1)** — mjvm ~0.91 s vs GT.M ~0.34 s = **2.7x** on the 15 MB / 2,663-rec CAT fixture, dumps byte-identical (re-time 2026-11-06 on main after PR #52 EVAL_STORE fusion a818c35). Owner M: (a) declare ~2.7x done with rationale (plan allowance), or (b) re-gate as in-process steady-state ingest (same methodology as the 20M SET loop). Either closes the gate and unblocks 1.3. Re-time via `tools/build-fixture-run.sh` (PR #53). Dafny: store write-through design, if pursued, is specified in `TieredStore.dfy` (28 lemmas); pure dispatch/fusion perf needs no proofs.
- [ ] 1.3 **m-ils MVP close-out (was 2.6)** — gate: m-ils#1 MVP definition met ("minimally feature complete to run a biomedical research library in North America today"): dual-engine ILSTEST all-OK on GT.M + mjvm; store = tieredstore default + comdb2 `ilsdb` 3-node cluster (no sqlite/h2/mapdb); perf gate per 1.2; ops rows current (dashboard U03:8383). Owner M.

### Phase 2 — Fleet & ops (was Phase 1)
- [ ] 2.1 **Edge https=000 incident (from old 1.4 first run)** — U03 `edge` container Caddy has no 443 listener; LE cert not provisioned (:80 answers 308→https). Caught 2026-11-06 by `web-lxc-check.sh` (wired same day, ydb-mesh f2307b2, hourly cron :15 on U03 + dashboard section). Owner M decision: provision LE via DNS-01 for home.flamingyak.com OR switch to a tailscale-issued cert. Gate: `https://home.flamingyak.com/` → 401/200/308 from outside + a green week of hourly checks; then demotes to standing ops.
- [ ] 2.2 **mlang onboarding (was 1.5)** — new fleet node Lenovo MX Linux 192.168.0.36; Mac background job `~/tools/mlang-onboard.sh` (status `~/soak/mlang-onboard.status` = PROVISIONING at 2026-11-06 — tailscale installed, `tailscale up` login pending; port 22 was flapping at launch, console fallback `sudo systemctl enable --now ssh` / `~/tools/mlang-bootstrap.sh`). Gate: status DONE-OK + key-only ssh verified from Mac + fleet row in `MASTER-INVENTORY.md` + dashboard host row.
- [ ] 2.3 **mlang = production M-runtime host (was 1.6; role DECIDED by owner M 2026-11-06)** — runs production distributions/instances of **RSM, GT.M, PyMumps, mJVM, SwiftM, Mumps II (O'Kane — default built-in storage, NOT relational DBs)** delivered from dev/test machines (Mac/U03/U04); no engine dev/test on mlang — only M code written there, run against the six environments. Sub-items: 2.3a GitHub repo `mjandrews1/mlang-m` for all production M routines + tests — **DRAFTED 2026-11-07 (created, scaffolded, pushed: README + routines/ + tests/ + runbooks); real routines/tests TBD**; 2.3b standard install/maintenance/upgrade/uninstall runbook + script per environment — **drafted**: docs/OPERATIONS.md standard lifecycle + docs/runbooks/{rsm,gtm,pymumps,mjvm,swiftm,mumps2}.md + tools/envs/install-*.sh (Mumps II native-storage-only noted); 2.3c `mlang-env` toolkit (install/upgrade/uninstall/list/verify each); 2.3d standard test + timing + performance apparatus across all six (shared 139-corpus + timing suite, comparable report archived) — tools/run-corpus.sh drafted. Gate: all six installed via the standard process + repo cloned + apparatus green. Depends on 2.2. Owner A (build) + M (review).

### Phase 3 — mjvm conformance campaign (mjvm#46; sprint ends 2026-11-30)
- [ ] 3.1 **Sustain NEW=0 / KNOWN=0 → exit (was 3.1)** — parser-family KNOWNs root-caused to the NEW_ALL scope leak (not the FOR parser) and fixed in **mjvm PR #55 (63a7cee) — MERGED 2026-11-06 23:18Z**; post-fix seeds 61106–61111 (1,200 programs): KNOWN 0, NEW 0; U03 `fuzz-nightly.sh` now rebuilds+pulls before fuzzing (stale-build false alarm resolved). ORACLE known-bugs=0 since PR #47 (2026-11-04). Gate: NEW=0 sustained through **2026-11-30** on the nightly U03 runs; then demotes to standing ops. Owners M+A.

### Phase 4 — MeshGraph YottaDB→GT.M migration (ydb-mesh#58)
- [ ] 4.1 **Full-corpus load — RUNNING** — ydb-mesh PR #59 open (MESHX/MESHL line-based R/X-tagged binary-safe export, cross-engine round-trip md5-verified YDB U02 → GT.M U04); driver `tools/mesh-4.1-drive.sh` as Mac background job, status `~/soak/mesh-4.1.status` = **EXPORT-U02** (started 2026-11-06 03:06Z), gated on old-1.3 DONE-OK. Gate: per-global re-export cmp match + node counts on U04 scratch GT.M. 1M-PMID fixture verified 2026-11-04.
- [ ] 4.2 **Port services to M** — BM25 `term_index`+search, MCP, web portal, dashboard (GTMHTTP v4 socket pattern). Gate: parity harness vs YDB read side — top-k identical on :8081; Dafny re-verify `GraphStore.dfy` (20) + `BM25.dfy` (21) + `Scan.dfy` (8). Owner A+M.
- [ ] 4.3 **Pipeline dual-load** — updatefiles → both DBs; counters + query parity for 2 weekly cycles. Gate: zero parity diffs.
- [ ] 4.4 **Cutover** — U03 edge Caddyfile repoint to U04 (one line per route, instant rollback); soak; U01 YDB → read-only archive (keep yottadb.dat until validated); backups + timers ported U04→U02. Depends on 2.1 (edge cert) for the outside-green gate (401/200/308). Owner M.

### Phase 5 — VistA swallowed-syntax (mjvm#46)
- [ ] 5.1 **Class reduction (13.7% failing → target)** — comma class first (17,057 routines, 28.3% of backlog); **Dafny gate unblocked: `MSetList.dfy` (33) + `MCommand.dfy` (26) merged via m-semantics#120 (6ab912c, 2026-11-06)** — cite them when landing class-4 fixes. Each class lands with a regression test in `mjvm/docs/VISTA-SYNTAX-BACKLOG.md` + a .dfy lemma where formalizable. Owner M. Gate: failing-routine % at target. *State 2026-11-06: in-flight MFrontend parser/runtime fixes ($ specials in NEW/KILL/SET lists, ^$W globals, READ format args !,#,*,?,prompts) are UNCOMMITTED in the local mjvm working tree (MFrontend*.java modified, post-63a7cee) — commit to a branch before further work; GAUNTLET green, MFrontendRegression 52/53 (one test `set-list-unsupported-recorded` encodes the old reject-$X-in-SET-list behavior — update it); full U02 ledger re-run pending.*

### Phase 6 — SwiftM: spec-first M in Swift for macOS (m-semantics#72)
- [ ] 6.1 **Review + merge swiftm#1 (core interpreter)** — `impl/6.3-core-interp`: build green (69b1b2f), `swiftm dump` vs mjvm LineEngine per-case dump **136/136 match** (all 139 minus the multi-routine cases mjvm LineEngine itself skips — harness-limited), external routines `DO tag^RT` / `$$tag^RT(args)` landed (977828e); PR open since 2026-11-06 23:35Z. Fixes folded in: WRITE `*n`/`?n`/`#`/`@`, `@`-indirection, `$P` splice, `$F`/`$A` edges, postconditionals, patterns, $QUERY/$ORDER, $ETRAP. Scaffold DONE 2026-11-06 (285890b, docs-only; repo `mjandrews1/swiftm`); Dafny prereqs DONE (m-semantics#120). *Agent review 2026-11-06: no review comments, CI pending (no checks configured); swift 6.4 build green locally.*
- [ ] 6.2 **Minimal-conforming gate** — 124 ISO-core + ISO-1999 cases per `docs/MINIMAL-CONFORMING-M.md` (15 vendor = compatibility target, not gate) pass on **swiftm AND mjvm AND GT.M**, with `dafny verify` green. Written against ISO 11756 first, Dafny as cross-check. *Measured 2026-11-06 (agent): dafny verify all 13 modules green, 651 lemmas, 0 errors. Corpus: swiftm==mjvm LineEngine on 120/124 gate cases (the 4 others — C103/C104/C105/C107 multi-routine — are mjvm-harness-limited but PASS on swiftm via externals; raw dump agreement 132/139 + 3 error-message trailing-newline artifacts). Vs corpus expected: swiftm 116/124, mjvm 112/124, GT.M (U01) 105/124; the 8 swiftm/mjvm-shared fails vs expected (T11,T11b,T11d,T12,T12b,T15,C16,C24) are documented upstream/ISO-vs-GT.M arbiter classes (C16/C24 pinned in MRelOps.dfy). GT.M deltas on $STACK/$X/$Y/error-message-format (C69-C72,C89-C93,C02,C74) match mjvm's known divergences — swiftm is exactly as conformant as mjvm. Owner call: gate = cross-engine agreement (met, 120/124 + 4 swiftm-only) vs strict GT.M-expected pass.*
- [ ] 6.3 **First real workload** — portable concurrency app (JOB/LOCK/$TEST/TSTART; actor-based); macOS-only (fleet is Linux); NOT a replacement for mjvm/JavaM; no full VistA surface (21k swallowed-line cases are Phase 5's job).

### Parked / decisions (not blocking the phases)
- P-1. **#12 Java→Kotlin conversion** — trigger: after Phase 1 close-out (1.3). Follow `mjvm/docs/KOTLIN-MIGRATION-DESIGN.md` (order ir→AST→emitter→store→runtime→core→MFrontend-last; per-step gates corpus+ORACLE+GAUNTLET+JMH). Design-only, green-lit 2026-11-04. Owner M decides.
- P-2. **ORACLE upstream parity decision** (WRITE line-break class — RSM appends END_WRITE, GT.M doesn't): owner review, parked by design (flipping it changes the corpus peer target).

### Standing ops (demoted from plan steps 2026-11-06 rev5 — cron/launchd jobs watched via dashboard U03:8383, not re-planned here)
- GAUNTLET CI green on u04 (old 1.1 DONE 2026-11-05 via PR #54, merged 23e1790; watch the Mixed latency gate flake — retried green once, do NOT loosen gates)
- U03 nightly fuzz-triage (`fuzz-nightly.sh`, rebuilds+pulls first) — 0 NEW since 2026-10-29; feeds 3.1
- Weekly U02 coldstore ← U04 `/backup` refresh (standing cron on U02; one-shot old-1.3 DONE-OK 2026-11-06 02:51:42Z, all 3 files md5-identical U02==U04)
- Hourly U03 `web-lxc-check.sh` (dashweb :8383, GTMHTTP :8181, public edge, `lxc list`) — closes after a green week + 2.1
- comdb2 `ilsdb` 3-node cluster COHERENT; dashboard; central logging → U03

## Next steps — recorded 2026-11-06 (rev5 execution order)
1. **1.1** — owner review + merge m-ils#2 (ILSTEST 39/39 dual-engine; covers auth/circulation/ILL).
2. **1.2** — owner decision on the ingest gate: declare ~2.7x done OR re-gate in-process steady-state; either closes it and unblocks 1.3.
3. **2.1** — edge cert decision (LE DNS-01 vs tailscale) + fix; watch hourly web-lxc-check until a green week.
4. **6.1 → 6.2** — review + merge swiftm#1, then run the 124-case minimal-conforming gate on swiftm AND mjvm AND GT.M with `dafny verify` green.
5. **4.1** — watch `~/soak/mesh-4.1.status` (EXPORT-U02 since 03:06Z); on completion verify per-global re-export cmp + node counts on U04.
6. **2.2 → 2.3** — finish mlang onboarding (PROVISIONING; tailscale login pending), add inventory + dashboard rows, then stand up the production M-runtime role (2.3a–d).
7. **3.1** — watch U03 nightly fuzz post-#55; campaign exit 2026-11-30 if NEW=0 holds.
8. **5.1** — commit the uncommitted MFrontend work to a branch first; then start the VistA comma class with the Dafny gate (MSetList/MCommand on main).
9. **4.2 → 4.4** — after Phase 1: services port → dual-load 2 weekly cycles → cutover (needs 2.1).
10. **1.3** — m-ils MVP close-out once 1.1 + 1.2 are done.

**Detail docs:** JavaM `jvmumps/CRITICAL_PATH.md` · `jvmumps/docs/ROADMAP-0.5.0.md` · mjvm `mjvm/docs/` · inventory `m-semantics/docs/MASTER-INVENTORY.md`

**Name lock:** **MeshGraph** = product · **`ydb-mesh`** = code · **JavaM** = `mjandrews1/JavaM` (JvMumps) — **FROZEN oracle**; parser/lexer (and REPL) moved to mjvm, one codebase, one dev path going forward · **mjvm** = `mjandrews1/mjvm` (JIT engine) · **tsx** = Comdb2 time-series.

**Focus (end of 2026-10-28):** mjvm v2.2.2 shipped (P1b comma work in flight) · fleet hardened (key-only SSH, UFW everywhere, public 22 closed, edge containerized + fenced) · MeshGraph RESUMED + **post-resume heal DONE 2026-10-28** (retention semantics verified — NO phantom kill; dead PTERM guard fixed; 142,763 docs indexed; dangling cleared; WAND pruning live; updatefile retention live; first post-resume backup run) · **ydb-mesh repo reactivated** (PR #49: ops files + registry package + live tree) · Dafny corpus 547 verified · **JavaM REPL (#35/#36) verified DONE** — CI smoke restored to mjvm (c8ada1a) · **P8 M ecosystem survey cloned** (`~/m-ecosystem/`, 34 artifacts incl. GT.M V7.2-001) · **P9 GT.M instance RUNNING on U01:8181** · c3fst deprecated · **2026-10-29:** MeshGraph services restored + update/author timers re-armed; dangling=0 verified; still_missing=78,463 root-caused (benign); GTMHTTP back on 8181 with @reboot persistence; mjvm bench/micro landed (#5, #9, #10, #11 closed; #12/#13 filed); **U01 journaling RE-ENABLED 2026-10-29 00:26 UTC** (writer-quiesced after DAILY_DONE; verified by write-through) — P0c DONE; P5e monthly MARC timer armed; P8 mumps 1.71 tarball captured; P9 inventory documented ($ZCHSET=M, gtmcrypt plugin; GTMHTTP serial responder can wedge — restart is the remedy) · remaining: mjvm comma backlog (P1b) + #4/#13 (MFrontend, coordinate with P1b), YDBTest cross-engine run (scoped), MCP registry publish (external accounts). (Portal rotation DONE 2026-11-03 — item 4; U02 backup second copy DONE 2026-10-29 — P0b.)

## How to read

Priority-ordered path. Status: **OPEN** · **IN FLIGHT** · **DONE** · **FROZEN** · **PAUSED**.

---

## Project map (2026-11-05)

| Project | Role | State | Stream |
|---------|------|-------|--------|
| **mjvm** | M → JVM JIT engine (v2.2.2, GAUNTLET 134/134, CI green on u04) | active, Mac-only tree | **P1** |
| **JavaM** (JvMumps) | full-M oracle (v1.2.0, 1.0 gate) — **FROZEN**; parser/lexer + REPL live in mjvm; one codebase, one dev path | frozen, local reference | P2 |
| **m-semantics** | Dafny spec (**547 lemmas**: 464 M-sem + 25 GraphStore + 42 BM25 + 16 Scan) + master docs | active | P2 |
| **MeshGraph / ydb-mesh** | YottaDB citation index (44.4M corpus, 42.5M indexed docs, 7.0B postings; repo **ACTIVE — unarchived + upstreamed 2026-10-28**, PR #49) | **ACTIVE — resumed 2026-10-27, post-resume heal 2026-10-28** | **P5** |
| **m-lsp** | language server | active, clean | P3 |
| **mformatter** | M formatter | idle | P3 |
| **m-ils** | demo Integrated Library System in M — CATLINE/SERLINE records, MeSH authority control, TUI + web UI from one codebase; MVP = auth + circulation + ILL (m-ils#1) | active, design-first (2.2); perf-blocked on Phase 2.1 | Phase 2 |
| **swiftm** (proposed) | spec-first M in Swift — validates Dafny proofs against an independent implementation; native Apple Silicon; actor-based JOB/LOCK | **PROPOSED** — after P1/P2 stabilize | **P7** |
| **tieredstore-rs** | Rust TieredStore prototype (published, CI green on u04) | active | P4 |
| **pymumps** | peer corpus host (restored on Mac) | active | P5 |
| **fileman** | frozen VistA corpus | frozen | FROZEN |
| **tsx / comdb2** | time-series + SQL plane | **DEPRECATED 2026-10-31** | FROZEN |
| **RSM** | archived → `U02:coldstore/mac-rsm-2026-10-26/` | FROZEN | FROZEN |

---

## Critical path (end of 2026-10-28)

```
  P0a Portal password rotation               (user) DONE 2026-11-03
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
| Rotate portal credential (`home.flamingyak.com`) | **DONE 2026-11-03** (user) | Scrubbed from skill files 2026-10-26; rotated in edge container Caddyfile (bcrypt) 2026-11-03; 401/200 verified; edge re-secured (no sshd, no temp login) |
| U02 `meshgraph-backup` second copy | **DONE 2026-10-29 23:40 UTC** | The completing rsync (started ~02:40 UTC Wed, `--inplace` from U02's post-heal backup) finished with its last writes 2026-10-28 22:12 UTC — the monitoring cron's later "in flight" reports were pgrep false positives (the pattern matched the monitor's own ssh command line; the log's `Host key verification failed` lines were from post-completion restart attempts, not the completing run). Verified byte-exact against U02: `yottadb.dat` 237,585,666,048 bytes and directory `du -sb` 240,233,879,552 on both sides; renamed to `/backup/meshgraph-backup` on U04 (56% of 443G root). **Follow-ups:** (1) DONE 2026-11-03 — U04 `known_hosts` now has U02's host keys (tailnet 100.89.100.53 + LAN 192.168.0.24, hashed; BatchMode ssh U04→U02 verified); (2) monitoring greps must use self-match-proof patterns (`grep [r]sync` / `pgrep -x rsync`) |
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
| P5d | MCP registry listings (ydb-mesh#28) | **BLOCKED 2026-11-01 — public edge down (ydb-mesh#53); tailnet smoke 100.72.84.8:8082 tools/list still OK** | Package tracked in `ydb-mesh/registry/` (PR #49): README (identity + tool schemas verified against source, client snippet, submission checklist), `official-registry.json`, `smithery.json`, `glama.json` (drafts; validate against live registry schemas at submission). Corrected vs. issue: `/mcp` is public read-only (no auth). Live smoke on U01 2026-10-29: `tools/list` on 100.72.84.8:8082 returns both tools (mesh_search, mesh_get). Registry submission (external accounts) is the only remaining step |
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

- **2026-11-01 track A fixes** — public edge restored on U03 via persistent iptables DNAT (edge-proxy-dnat.service; snap-LXD proxies don't bind at boot) verified 401/200/200/200 over the LAN path (ydb-mesh#53); logrotate fixed on U01/U02 with socket-guarded fail2ban postrotate (ydb-mesh#54).

- **2026-11-01 fleet check + Mac jobs restored** — all four hosts up (1d 1h48m); U01 mesh/ydb services healthy + DAILY_DONE 03:50:48 UTC (ydb-mesh#52); public edge DOWN, LXD proxy unbound on U03 (ydb-mesh#53); logrotate broken on U01/U02 (ydb-mesh#54); U04 runners ×4 active, U03 mirrors fresh, comdb2 COHERENT on U01/U02; Mac: caddy launchd, dashweb.m :8383 + disk-watch + hourly dashboard regen restarted, com.mjvm.fuzz launchd armed 02:30.

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
