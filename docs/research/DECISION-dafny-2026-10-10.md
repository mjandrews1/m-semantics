# Decision — formal-methods tool for M semantics

**Date:** 2026-10-10 · **Status:** LOCKED · **Rule:** Dafny unless a demonstrably better peer exists · **FOSS preferred**

## Decision

**Adopt Dafny as the sole proof tool for `m-semantics` (M contracts).** Do not add Lean, Rocq, or K as a second stack.

## Criteria vs peers

| Tool | FOSS | Fit for M contracts | Already invested | Verdict |
|------|:----:|---------------------|------------------|---------|
| **Dafny 4.x** | Yes | SMT/imperative — matches ExprEval/PatternMatch + corpus | **79 + 37 verified, 0 errors** | **ADOPT** |
| Lean 4 + mathlib | Yes | Mathlib strength unused for pattern/compare contracts | 0 | Reject (no demonstrable gain) |
| Rocq/Coq | Yes | Strong for interpreters; agent-repair signal better in one 2026 study [F4-11][F4-12] | 0 | Challenger — revisit only if Z3 timeouts block M-semantics |
| K Framework | Yes* | Whole-language rewrite semantics (C11/JS/KEVM) [F4-4–7] | 0 | Overkill for contract layer |
| Isabelle/WasmRef | Yes | Oracle-style monadic interpreters [F4-13] | 0 | Reject |
| F* / Why3 / TLA+ / Alloy | Yes | Adjacent; no better fit for these contracts | 0 | Reject |

\*K is FOSS with commercial dual licensing.

## Why Dafny wins (not just inertia)

1. **Already verified** the hard parts: ISO pattern groups (`MPattern`), compare/truthiness (`MSemantics`) — same surface the ports implement.
2. **Vale lineage** (USENIX Sec 2017, Leino) proves Dafny-class SMT works for low-level correctness [F4-10]; **Jitterbug** shows contract-level specs inside unverified systems [F4-8][F4-9] — our RSM-oracle + 8-upstream-exception setup.
3. **Lean** would require re-proving everything and mathlib is unused for these lemmas.
4. **Rocq** is the only evidence-backed challenger (explicit proof states under agent repair) [F4-11][F4-12] — **trigger to reconsider:** repeated Z3 timeouts on M-semantics lemmas that Rocq closes quickly.

## Trigger to reopen

- Two or more M-semantics lemmas fail Dafny/Z3 that a peer closes in comparable effort.
- We need dependent types / mathlib-scale algebra (collation proofs beyond current `MPattern`).

## Sources
- `research/m-ports-lit/findings/F4.md` (SpecTec, K, Jitterbug, Vale, Rocq-vs-Dafny 2026, WasmRef-Isabelle)
- Local: `m-semantics` Dafny 4.11.0 — `MSemantics.dfy` 79 verified; `MPattern.dfy` 37 verified
