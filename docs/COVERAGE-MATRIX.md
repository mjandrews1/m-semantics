# M-stack coverage matrix

**Date:** 2026-10-09 · **Corpus:** shared `conformance.json` (139 cases)  
**Home:** `m-semantics/docs/COVERAGE-MATRIX.md` (moved from fst 2026-10-09)

**Out of scope:** YottaDB / ydb-mesh — **storage plane**, not an M language stack.

## Corpus scores

| Stack | MATCH | MISS† | ERR | TOTAL | How scored |
|-------|------:|------:|----:|------:|------------|
| **RSM** (oracle) | 131 | 8 | 0 | 139 | expecteds source; 8 = documented upstream divergences |
| **PyMumps** | **131** | 8 | 0 | 139 | `tools/run_conformance.py` · **w9 ACCEPT** |
| **C3Mumps** | **131** | 8 | 0 | 139 | `tools/run_conformance.py` · **w9 ACCEPT** |
| **JvMumps** | 97 | 42 | 0 | 139 | `CorpusScore *` · see gap table below |
| **mJVM** | 8 | 3 | 128 | 139 | `MjvmCorpusScore` — **subset** frontend; errors are honest |
| **O'Kane** | 92 | 46† | 1 | 139 | `iso_smoke.py` (U01) · †28 upstream / 17 harness-or-port-only / 1 timeout |
| **FreeM** | 98 | 41 | 0 | 139 | `freem_iso_smoke.py` PTY (U01, GitHub GUMP tree) |

†On Py/C3/RSM, the 8 “misses” are **UPSTREAM_BUGS** — the port is **correct ISO** where RSM diverges (ELSE/`$TLEVEL`/string-compare/`=` non-canonical).

**Peer target (Py/C3/RSM level):** `MATCH=131 MISS=8 ERR=0`, and the 8 misses must be exactly the upstream-bug set.

---

## JvMumps gap breakdown (42 → target 8)

7 of the 8 upstream-bug cases are **already ISO-correct** (T11/T12/T15/C16 family). The 8th (`C24.eq-noncanonical`) still matches RSM’s non-ISO `=` and must flip.

| Cluster | N | Cases | Ticket |
|---------|--:|-------|--------|
| Indirection `@` | 5 | C65 ind-args · C66 ind-set · C67 ind-intrinsic · C74 ind-parent-undef · C75 ind-kill | jvmumps#7 |
| DO/GOTO/XECUTE/extrinsic | 9 | C94 do-tag · C95 goto-tag · C97–C98 xecute · C99 do-args · C100 do-postcond · C101 goto-postcond · C102 nested-do · C106 extrinsic-same | jvmumps#8 |
| Traps `$ETRAP`/`$ECODE`/`$ZTRAP` | 5 | C113 set-get · C114 ecode-set-get · C115 etrap-fire · C116 etrap-ecode · C125 ztrap-set-get | jvmumps#9 |
| WRITE device params + `$X`/`$Y` | 6 | C121 write-char · C122 write-char-nl · C123 write-col · C124 write-ff · C90 xy-after-write · C92 xy-set-x | jvmumps#10 |
| FOR/NEXT + `$STACK`/`$TEXT` + SET `$EXTRACT` | 7 | C86 next-forward · C87 next-abbr-name · C69 stack-basic · C70 stack-place · C71 text-empty · C49 set-extract · C81 bare-q-special | jvmumps#11 |
| `$Z*` specials | 3 | C126 zversion-zjob · C127 zlevel-zsystem · C128 zeof | jvmumps#9 |
| ISO `=` flip | 1 | C24 eq-noncanonical (currently MATCHES RSM bug; must diverge like Py) | jvmumps#12 |
| **Already OK as ISO diverge** | 7 | T12 · T12b · T11 · T11b · T11d · T15 · C16 | (keep) |

**After fix:** 35 real gaps closed + C24 flipped → `MATCH=131 MISS=8 ERR=0`.

---

## mJVM gap breakdown (8/3/128 → target 131/8/0)

128 ERR = `mJVM M2: command not in compiled subset` (honest, not crashes). 3 MISS = numeric semantics.

| Cluster | N | Work | Ticket |
|---------|--:|------|--------|
| Commands IF/ELSE/FOR + NEW/KILL/MERGE | ~60 err | M10 subset expansion | jvmumps#13 |
| DO/GOTO/XECUTE/routines + postcond | ~30 err | M11 | jvmumps#14 |
| Intrinsics/specials/patterns/indirection | ~35 err | M11 | jvmumps#14 |
| Numeric semantics | 3 miss | C14 divide-zero-guard · C17 neg · C22 mod-signs | jvmumps#15 |
| Parity gate | — | corpus 131/8/0/0 + FileMan smoke | jvmumps#15 |

Full plan: [`jvmumps/docs/CATCHUP-2026-10.md`](../../jvmumps/docs/CATCHUP-2026-10.md).

---

## Feature surface (Y full · P partial · N none)

| Feature | RSM | PyMumps | C3Mumps | JvMumps | mJVM | O'Kane | FreeM |
|---------|:---:|:-------:|:-------:|:-------:|:----:|:------:|:-----:|
| SET / locals / globals | Y | Y | Y | Y | Y | Y | Y |
| WRITE stream + `!` | Y | Y | Y | Y | Y | Y | P |
| WRITE `*n` / `#` / `?n` | Y | Y | Y | P | P | P | P |
| IF / ELSE / `$TEST` | P | Y | Y | Y | N | P | Y |
| FOR argless / `var=` / `0:0` | Y | Y | Y | P | P | Y | Y |
| DO / GOTO / `$$` extrinsic | Y | Y | Y | P | N | P | P |
| `QUIT` expr (extrinsic) | Y | Y | Y | P | N | P | P |
| Patterns `?` ISO | Y | Y | Y | Y | P | P | Y |
| `$DATA` `$ORDER` `$GET` `$NAME` | Y | Y | Y | P | P | P | Y |
| `$QUERY` `$QLENGTH` `$QSUBSCRIPT` | Y | Y | Y | P | N | P | P |
| `$SELECT` `$CASE` | Y | Y | Y | P | N | P | P |
| `$HOROLOG` / `$H` | Y | Y | Y | Y | P | P | Y |
| `$X` `$Y` | Y | Y | Y | N | N | N | P |
| `$ETRAP` / `$ECODE` / `$ZTRAP` | P | Y | Y | P | P | N | N |
| `VIEW` | P | Y | Y | P | N | N | N |
| `MERGE` | Y | Y | Y | P | N | P | N |
| `NEW` / `KILL` / `$INCREMENT` | Y | Y | Y | P | P | P | P |
| Indirection `@` | Y | Y | Y | P | P | P | P |
| `JOB` / `LOCK` | Y | Y | Y | Y | Y | N | P |
| `TSTART` / `TCOMMIT` / `TROLLBACK` | P | Y | Y | Y | Y | N | N |
| Devices `OPEN`/`USE`/`READ`/`CLOSE` | Y | Y | Y | Y | Y | P | P |
| `$Z*` family (subset) | P | Y | Y | P | P | N | N |

## Notes

- **YottaDB** is scored by `ydb-mesh` tests (loaders, `related()` QA), not this matrix.
- **mJVM** is a compiled subset (M0–M9 toolchain + CLI); 128 corpus errors mean “not in compiled subset”, not crashes.
- **JvMumps** T14 hang **fixed** (jvmumps#6, 2026-10-09): multi-arg `SET` (`S A=1,B=2`) spun `exec()`; `doSet` now walks comma-separated assignments.
- **FreeM** upstream: MERGE segfault + TSTART/VIEW gaps (CoherentLogic/freem#5, #6).
- **O'Kane** MISS clusters: `$QUERY`/`$STACK`/`XECUTE`/`DO` extrinsic/`LOCK` comma (see okanes-mumps#2).
- **Never weaken test wants** to match engine output — fix the engine (ISO/RSM semantics).

## Re-run

```bash
# local ports
python3 pymumps/tools/run_conformance.py
python3 c3mumps/tools/run_conformance.py
java -cp jvmumps/build:jvmumps/lib/* jvmumps.CorpusScore pymumps/tests/conformance.json '*'
java -cp jvmumps/build:jvmumps/lib/* jvmumps.MjvmCorpusScore pymumps/tests/conformance.json '*'

# U01
python3 okane-mumps/iso_smoke.py /tmp/conformance.json
FREEM_BIN=$HOME/freem-github/bin python3 $HOME/freem-github/freem_iso_smoke.py /tmp/conformance.json

# or (from m-semantics/)
python3 tools/coverage_matrix.py --out docs/COVERAGE-MATRIX.md
```

## Harness

`m-semantics/tools/coverage_matrix.py` — scores RSM/Py/C3/Jv/mJVM/O'Kane/FreeM and emits this file.

## O'Kane MISS classification (2026-10-09)

Full table in [okanes-mumps#2](https://github.com/mjandrews1/okanes-mumps/issues/2).

| Class | Count | Examples |
|-------|------:|----------|
| **UPSTREAM** | 28 | `$ORDER` collation · `$DATA` 0/1/10/11 · `$NAME` quotes · `$INCREMENT` · `$QUERY` · MERGE · `$STACK`/`$TEXT` · `$X$Y` · `$SELECT` error · `XECUTE` · LOCK comma · mstr/mod/truthiness |
| **HARNESS / PORT-ONLY** | 17 | DO/extrinsic file-mode · `$ETRAP`/`VIEW`/`$Z*` (W7–W8 cases) · `$IO` impl-specific · C02 RSM error-text |
| **ERR** | 1 | C118 device open timeout (harness) |
