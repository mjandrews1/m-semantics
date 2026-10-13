# M-stack coverage matrix

**Date:** 2026-10-12 · **Corpus:** shared `conformance.json` (139 cases)  
**Home:** `m-semantics/docs/COVERAGE-MATRIX.md`  
**Refresh:** rsm#31 — after native mJVM joined the peer target (131/8/0)

**Out of scope:** YottaDB / ydb-mesh — **storage plane**, not an M language stack.

## Corpus scores (2026-10-12 verified)

| Stack | MATCH | MISS† | ERR | TOTAL | How scored |
|-------|------:|------:|----:|------:|------------|
| **RSM** (oracle) | 131 | 8 | 0 | 139 | expecteds source; 8 = documented upstream divergences |
| **PyMumps** | **131** | 8 | 0 | 139 | `tools/run_conformance.py` · **w9 ACCEPT** |
| **C3Mumps** | **131** | 8 | 0 | 139 | `tools/run_conformance.py` · **w9 ACCEPT** |
| **JvMumps** | **131** | 8 | 0 | 139 | `CorpusScore *` · **peer target hit** |
| **mJVM LineInterp** | **131** | 8 | 0 | 139 | `MjvmCorpusScore *` · shared-semantics gate |
| **mJVM native** | **131** | 8 | 0 | 139 | `MjvmNativeScore *` · MFrontend+IrMachine (no LineInterp) |
| **O'Kane** | 92 | 46† | 1 | 139 | `iso_smoke.py` (U01, 2026-10-09) · †28 upstream / 17 harness-or-port-only / 1 timeout |
| **FreeM** | 98 | 41 | 0 | 139 | `freem_iso_smoke.py` PTY (U01, 2026-10-09) |

†On Py/C3/Jv/mJVM/RSM, the 8 “misses” are **UPSTREAM_BUGS** — the peer port is **correct ISO** where RSM diverges.

**Peer target (now held by all five language stacks):** `MATCH=131 MISS=8 ERR=0`, miss set exactly:

| ID | Name | RSM got (wrong) | ISO / peer (right) |
|----|------|-----------------|---------------------|
| T12 | `ELSE-binding` | empty (ELSE skipped) | executes ELSE |
| T12b | `ELSE-chain` | empty | chain runs |
| T11 | `empty-vs-zero` | empty | `""'=0` |
| T11b | `zero-vs-empty` | empty | `0'=""` |
| T11d | `cmp-operators` | RSM collation | ISO relational results |
| T15 | `tlevel` | defines `$TLEVEL=0` | undefined special |
| C16 | `str-compare` | RSM string `<` | ISO `"a"<"b"` etc. |
| C24 | `eq-noncanonical` | `1.0=1` etc. true | non-canonical `=` false |

---

## Dafny proof coverage for the upstream-eight (rsm#31 tracking)

Peers implement **ISO** on these; RSM does not. Proof obligation is the ISO rule (or an explicit “RSM divergence” lemma), not matching RSM.

| Case | ISO rule / lemma target (m-semantics) | Status |
|------|----------------------------------------|--------|
| T12 / T12b | ELSE binds innermost IF; false-IF skips THEN only | behavioral — Py/C3/Jv/mJVM agree |
| T11 / T11b | `""` vs `0` numeric-empty inequality | behavioral |
| T11d | relational operators on strings vs numbers | `MPattern` / `m_compare` family |
| T15 | `$TLEVEL` undefined (not a defined special) | specials table |
| C16 | string relational compare (not numeric) | `m_compare` |
| C24 | non-canonical numeric strings `≠` canonical numbers | `is_numstr` / `m_compare` |

Full lemma mapping is open work under m-semantics (not required for corpus parity).

---

## History (superseded)

| Date | JvMumps | mJVM |
|------|---------|------|
| 2026-10-09 | 97/42/0 | 8/3/128 (subset) |
| 2026-10-12 | **131/8/0** | **131/8/0** native + LineInterp |

JvMumps catch-up closed indirection, DO/GOTO/XECUTE, traps, `$X$Y`, FOR/`$STACK`/`$TEXT`, `$Z*`, and flipped C24 to ISO (was matching the RSM bug). mJVM M0–M12 + native catch-up (MEMORY-mjvm-native-catchup) took the IR path to the same gate.

---

## Feature surface (Y full · P partial · N none)

| Feature | RSM | PyMumps | C3Mumps | JvMumps | mJVM | O'Kane | FreeM |
|---------|:---:|:-------:|:-------:|:-------:|:----:|:------:|:-----:|
| SET / locals / globals | Y | Y | Y | Y | Y | Y | Y |
| WRITE stream + `!` | Y | Y | Y | Y | Y | Y | P |
| WRITE `*n` / `#` / `?n` | Y | Y | Y | Y | Y | P | P |
| IF / ELSE / `$TEST` | P | Y | Y | Y | Y | P | Y |
| FOR argless / `var=` / `0:0` | Y | Y | Y | Y | Y | Y | Y |
| DO / GOTO / `$$` extrinsic | Y | Y | Y | Y | Y | P | P |
| `QUIT` expr (extrinsic) | Y | Y | Y | Y | Y | P | P |
| Patterns `?` ISO | Y | Y | Y | Y | Y | P | Y |
| `$DATA` `$ORDER` `$GET` `$NAME` | Y | Y | Y | Y | Y | P | Y |
| `$QUERY` `$QLENGTH` `$QSUBSCRIPT` | Y | Y | Y | Y | Y | P | P |
| `$SELECT` `$CASE` | Y | Y | Y | Y | Y | P | P |
| `$HOROLOG` / `$H` | Y | Y | Y | Y | Y | P | Y |
| `$X` `$Y` | Y | Y | Y | Y | Y | N | P |
| `$ETRAP` / `$ECODE` / `$ZTRAP` | P | Y | Y | Y | Y | N | N |
| `VIEW` | P | Y | Y | Y | Y | N | N |
| `MERGE` | Y | Y | Y | Y | Y | P | N |
| `NEW` / `KILL` / `$INCREMENT` | Y | Y | Y | Y | Y | P | P |
| Indirection `@` | Y | Y | Y | Y | Y | P | P |
| `JOB` / `LOCK` | Y | Y | Y | Y | Y | N | P |
| `TSTART` / `TCOMMIT` / `TROLLBACK` | P | Y | Y | Y | Y | N | N |
| Devices `OPEN`/`USE`/`READ`/`CLOSE` | Y | Y | Y | Y | Y | P | P |
| `$Z*` family (subset) | P | Y | Y | Y | Y | N | N |

mJVM column = **native** stack (MFrontend + IrMachine + CLI). LineInterp gate is the same corpus score.

## Notes

- **YottaDB** is scored by `ydb-mesh` tests (loaders, `related()` QA), not this matrix.
- **Never weaken test wants** to match engine output — fix the engine (ISO/RSM semantics).
- **FreeM** upstream: MERGE segfault + TSTART/VIEW gaps (CoherentLogic/freem#5, #6).
- **O'Kane** MISS clusters: `$QUERY`/`$STACK`/`XECUTE`/`DO` extrinsic/`LOCK` comma (okanes-mumps#2).

## Re-run

```bash
# local ports (2026-10-12 gate)
python3 pymumps/tools/run_conformance.py
python3 c3mumps/tools/run_conformance.py
export PATH=/opt/homebrew/opt/openjdk/bin:$PATH
CP=jvmumps/build:jvmumps/lib/sqlite-jdbc.jar:jvmumps/lib/slf4j-api.jar:jvmumps/lib/slf4j-nop.jar
java -cp "$CP" jvmumps.CorpusScore pymumps/tests/conformance.json '*'
java -cp "$CP" jvmumps.MjvmCorpusScore pymumps/tests/conformance.json '*'
java -cp "$CP" jvmumps.MjvmNativeScore pymumps/tests/conformance.json '*'

# harness (optional remote O'Kane/FreeM)
python3 tools/coverage_matrix.py --out docs/COVERAGE-MATRIX.md
```

## Harness

`m-semantics/tools/coverage_matrix.py` — scores RSM/Py/C3/Jv/mJVM-native+interp/O'Kane/FreeM and emits a table.

## O'Kane MISS classification (2026-10-09)

Full table in [okanes-mumps#2](https://github.com/mjandrews1/okanes-mumps/issues/2).

| Class | Count | Examples |
|-------|------:|----------|
| **UPSTREAM** | 28 | `$ORDER` collation · `$DATA` 0/1/10/11 · `$NAME` quotes · `$INCREMENT` · `$QUERY` · MERGE · `$STACK`/`$TEXT` · `$X$Y` · `$SELECT` error · `XECUTE` · LOCK comma · mstr/mod/truthiness |
| **HARNESS / PORT-ONLY** | 17 | DO/extrinsic file-mode · `$ETRAP`/`VIEW`/`$Z*` (W7–W8 cases) · `$IO` impl-specific · C02 RSM error-text |
| **ERR** | 1 | C118 device open timeout (harness) |
