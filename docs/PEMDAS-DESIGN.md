# PEMDAS arithmetic — optional M helper (design)

**Issue:** m-semantics#31 · **Status:** design only (no engine change)  
**Date:** 2026-10-14 · **Constraint:** default M expression semantics stay **RSM/ISO** (corpus `131/8/0`).

---

## 1. Problem

M operator precedence is **not** PEMDAS/BODMAS. Writers who assume school math get silent wrong results.

### M (RSM / ISO / `ExprEval`) — high → low

| Level | Operators | Assoc |
|------:|-----------|-------|
| 1 | unary `-` `+` `'` | right |
| 2 | `**` `*` `/` `\` `#` | left (`**` left too; `2**3**2=64`) |
| 3 | `+` `-` | left |
| 4 | `_` (concat) | left |
| 5 | `=` `<` `>` `<=` `>=` `[` `]` `]]` `'<` … | left |
| 6 | `&` | left |
| 7 | `!` | left |

### PEMDAS (school) — high → low

| Level | Operators | Assoc |
|------:|-----------|-------|
| 1 | unary `-` `+` | right |
| 2 | `^` / `**` (power) | **right** (`2^3^2 = 2^9 = 512`) |
| 3 | `*` `/` | left |
| 4 | `+` `-` | left |

### Concrete divergences

| Expr | M | PEMDAS | Why |
|------|---|--------|-----|
| `2+3*4` | **14** | **14** | agree |
| `2**3**2` | **64** (left) | **512** (right) | `**` assoc |
| `-2**2` | **4** (`(-2)**2`) | **-4** (`-(2**2)`) | unary vs power |
| `8/4/2` | **1** (left) | **1** | agree |
| `10#2+3` | **15**? or M `#` first | n/a | M-only ops |
| `1\2` , `1#2` | M modulus/remainder | n/a | no PEMDAS meaning |
| `a_b` | concat after arith | n/a | M-only |

Only a **small subset** of M exprs is PEMDAS-shaped (`+ - * / **` and unary minus).

---

## 2. ISO / extension stance

| Question | Position |
|----------|----------|
| Change default `=` / expr parse? | **No.** |
| Extra intrinsic/function? | **Allowed as a named extension** if peers agree and it is **opt-in**. |
| Name it like ISO? | Avoid bare `$PEMDAS` if it could be confused with a future standard; prefer explicit **`$$PEMDAS(expr)`** (extrinsic) or **`$ARITH("pemdas",expr)`**. |
| RSM oracle? | RSM will **not** implement it; peers may. Default corpus must still match RSM where RSM is right / ISO where RSM diverges. |

**Project rule:** Dafny contract **before** shipping on JavaM/PyMumps/C3Mumps.

---

## 3. Proposed surface (pick one)

| Option | Form | Pros | Cons |
|--------|------|------|------|
| **A (preferred)** | `$$PEMDAS(expr)` extrinsic / M function | explicit, doesn’t touch `ExprEval` default | needs symbol table hook per engine |
| **B** | `$ARITH("pemdas",expr)` | room for later modes | invents a more general special |
| **C** | flag on evaluator (`setPemdasMode`) | easy in Java | **dangerous** — silent global mode |

**Recommendation: A** — `$$PEMDAS` / `$$PEMDAS.EVAL` tag in a routine, or engine builtin with that name. **No mode flag.**

**Evaluation contract:**
1. Parse `expr` with **PEMDAS** grammar (only `+ - * / **` + unary `-` + parens + numeric literals / identifiers as operands).
2. Operands use **M values** (`toNum` / `mstr`); non-numeric strings → same coercion as M `+`.
3. If the string contains M-only ops (`_` `\` `#` `!` `&` relational, etc.) → **error** (do not silently reinterpret).
4. Result is an M numeric value (or M string via `mstr` when used as string).

---

## 4. Dafny sketch (new `PEMDAS.dfy`)

```dafny
datatype PExp =
  | PNum(x: real)
  | PNeg(e: PExp)
  | PPow(a: PExp, b: PExp)      // right-assoc
  | PMul(a: PExp, b: PExp)
  | PDiv(a: PExp, b: PExp)
  | PAdd(a: PExp, b: PExp)
  | PSub(a: PExp, b: PExp)

function peval(e: PExp): real
  decreases e
{
  match e
  case PNum(x) => x
  case PNeg(a) => -peval(a)
  case PPow(a, b) => /* a ^ b */ ...
  case PMul(a, b) => peval(a) * peval(b)
  case PDiv(a, b) => if peval(b) == 0.0 then 0.0 else peval(a) / peval(b)
  case PAdd(a, b) => peval(a) + peval(b)
  case PSub(a, b) => peval(a) - peval(b)
}
```

**Lemmas (examples):**
- `peval(PPow(PNum(2), PPow(PNum(3), PNum(2)))) == 512` (right assoc)
- `peval(PMul(PAdd(PNum(2), PNum(3)), PNum(4)))` is **not** `2+3*4`’s M parse — show both trees
- `PNeg(PPow(PNum(2), PNum(2))) == -4` vs M `-2**2 == 4`

**M default** stays in `MSemantics` `cmp` / `mAdd`… — **not** replaced.

---

## 5. Implementation plan (after contract sign-off)

| Step | Where | Gate |
|------|-------|------|
| 1 | `m-semantics/PEMDAS.dfy` + lemmas | Dafny verify |
| 2 | JavaM: `$$PEMDAS` builtin or `jvmumps.PemdasEval` **separate** class | new suite `PemdasSmoke`; **corpus 131/8/0 unchanged** |
| 3 | PyMumps / C3Mumps (optional) | same suite names |
| 4 | Docs: name lock, “not ISO”, examples | README / BRANDING-style note |

**Tests:** separate `tests/pemdas_cases.json`; never fold into `conformance.json` expecteds.

---

## 6. Open questions (for you)

1. **Name:** `$$PEMDAS(expr)` vs `$ARITH("pemdas",expr)`?
2. **Power operator:** M `**` only, or also `^` in the helper?
3. **Div-by-zero:** M `div` is `0`; PEMDAS path should match M `div` (0) or raise?
4. **Ship on peers now, or JavaM-only prototype first?**
