# Jobs & Schedules Audit — 2026-10-31 (work queue item 6)

Owner-audit of every recurring job across the fleet + Mac + GitHub, with cadence and
state after the 2026-10-31 gigabit-switch shutdown/restart. "Mechanism" = how it starts.
Runbook for host restarts: `~/soak/FLEET-RESTART.md` (updated 2026-10-31 with the U04
/opt/bb symlink, copycomdb2 -P, LD_LIBRARY_PATH, and GTMHTTP @reboot gotchas).

## 1. U01 (utility-01, 100.72.84.8) — live YottaDB/MeshGraph host

| Job | Mechanism | Cadence | Purpose | State 10-31 |
|---|---|---|---|---|
| meshgraph-update | systemd timer→service | daily 03:00 UTC | daily index update (want-filter live, PR #50) | armed, next 11-01 03:00 |
| meshgraph-author | systemd timer→service | daily 04:30 UTC | author-index pass | armed |
| meshgraph-catplus | systemd timer→service | daily 06:00 UTC | catplus ingest | armed |
| meshgraph-backup | systemd timer→service | Sat 02:00 UTC | cold backup to U02 | armed |
| ydb-web-server, ydb-dashboard-ui, ydb-dashboard-metrics, mesh-search, mesh-mcp | systemd services | always-on | YDB web/API + MeshGraph search/MCP | active |
| GTMHTTP :8181 | crontab `@reboot` | boot | GT.M HTTP responder | **BROKEN: @reboot did not fire on the 10-31 reboot; started manually — TODO move to a systemd unit** |
| ILSWEB :8282 | manual (`D ^ILSWEB` via mumps -direct, ilsdata gld) | boot | m-ils GT.M web UI | up, HTTP 200 |
| comdb2 replica + pmux | nohup (runbook) | boot | ilsdb replica on 512-sector loop device | COHERENT |

## 2. U02 (utility-02, 100.89.100.53) — archive + soak carrier

| Job | Mechanism | Cadence | Purpose | State 10-31 |
|---|---|---|---|---|
| comdb2 master + pmux | nohup (runbook) | boot | ilsdb master | COHERENT |
| e_1m.sh / pi_1m.sh | nohup wrapper loops | continuous | 1M-digit e/pi soaks, CHECKPOINTED (mjvm 4ee5636) — wrapper trims ckpt + relaunches on abnormal exit (max 10) | running since 20:15 UTC; e resumed once after a test kill (rc=137 → trim → relaunch, verified) |
| meshgraph-backup receiver | target of U01 Sat backup | weekly | second copy | last good copy verified byte-identical 10-31 |

## 3. U03 (utility-03, 100.121.132.5) — infra/edge

| Job | Mechanism | Cadence | Purpose | State 10-31 |
|---|---|---|---|---|
| lxc `edge` | lxc autostart | boot | public web container | RUNNING |
| lxc `ydbtest` | lxc start (manual) | on demand | YDBTest cross-engine suite (P8) | RUNNING but the 10-30 `basic` suite died with the host reboot — **needs relaunch** |
| home.flamingyak.com IP updater | cron | periodic | DNS for U01 | running |
| rsyslog TCP 514 receiver | systemd | always | fleet logs | running |

## 4. U04 (utility-04, 100.79.52.105) — CI runner (HDD mini)

| Job | Mechanism | Cadence | Purpose | State 10-31 |
|---|---|---|---|---|
| 4 × actions.runner.* (m-lsp, m-semantics, mjvm, tieredstore-rs) | systemd services | on push/PR | GitHub Actions self-hosted CI | active |
| comdb2 replica + pmux | nohup (runbook) | boot | ilsdb replica | COHERENT (recopied from U02 10-31 19:11 via copycomdb2 -P) |

## 5. Mac (marks-macbook-pro-2) — dev + watch loops

| Job | ID/mechanism | Cadence | Purpose | State |
|---|---|---|---|---|
| Soak watch (e/pi 1M on U02) | cron loop 513f4d2d | 4h | verify .res vs Python refs on done; relaunch dead wrappers | armed |
| Fuzzer triage (workstream C) | cron loop e34683a6 | daily | classify fuzz-ledger.jsonl, file NEW findings | armed |
| Fleet disk watch | cron loop ceb6ad87 | 6h | df across all hosts, WARN≥80% CRIT≥90%, log to ~/soak/disk-watch.log | armed |
| Nightly fuzz batch | launchd com.mjvm.fuzz | 02:30 local | 200 programs → ledger | running |
| mJVM web :8282 (m-ils) | manual | boot | m-ils mJVM web UI | up |

## 6. GitHub CI (per repo)

| Repo | Workflow | Runner | Gate |
|---|---|---|---|
| mjvm | gauntlet.yml | u04 self-hosted | GAUNTLET + ORACLE harness (diverge=0) + regressions |
| m-semantics | ci.yml | ubuntu | Dafny verify — PR-only main, merge only when green |
| ydb-mesh, m-lsp, tieredstore-rs | ci.yml | default/self-hosted | unit tests |

## 7. Repo rationalization (2026-10-31)

Active: mjvm, m-semantics, m-ils, ydb-mesh, m-lsp, tieredstore-rs, pymumps (corpus host),
mformatter (idle). Frozen: JavaM (JvMumps oracle; parser/REPL moved to mjvm).
Deprecated/archived 10-31: tsx (PR #97 banner), ydb-infra, ydb-py, freem-ops.
Peer/corpus references (read-only): c3mumps, c3m, c3fst, okanes-mumps, fileman-corpus,
fst, fst-analysis.

## 8. Findings / rationalization actions

1. **U01 GTMHTTP @reboot crontab does not fire** — move to a systemd unit (or accept
   manual start per runbook). TODO.
2. **YDBTest basic suite died with the U03 reboot** — relaunch for P8 triage (the
   standing triage loop expects it).
3. **Soak progress dots are invisible mid-run** — mJVM buffers device-0 output until
   exit; use the ckpt last-block header (`grep '^E1|' ckpt | tail -1`) as the live
   progress indicator (already what cron 513f4d2d reports).
4. Mac session cron loops are only 3 + 1 launchd — no duplication to dedupe.
5. U02 soak wrappers self-resume; the 4h cron only relaunches a fully dead wrapper —
   no overlap risk as long as relaunch checks both java and wrapper pgrep.
6. Comdb2/pmux/nohup services on U01/U02/U04 are runbook-manual, not systemd —
   candidate for systemd units in a future hardening pass (recorded in FLEET-RESTART.md).
