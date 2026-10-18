# Operator precedence — M vs PEMDAS

**Reference:** `m-semantics/PEMDAS.dfy` (opt-in helper) · `JavaM` `ExprEval` (default M).
**ISO:** 11756 §8.3 · **RSM:** flat left-associative.

## M precedence (default — NOT PEMDAS)

All binary operators are **one level, left-associative** (ISO 11756, RSM):

| Level | Operators | Associativity |
|---|---|---|
| 1 (tightest) | unary `-` `+` `'` | right |
| 2 | `**` `*` `/` `\` `#` `+` `-` | **left** |
| 3 | `_` (concat) | left |
| 4 | `?` `'?` (pattern) | left |
| 5 | `=` `'<` `<` `>` `<=` `>=` `'>` `[` `']` `]` `]]` | left |
| 6 (loosest) | `&` `'&` `!` `'!` | left |

### Key examples (M)

| Expression | M result | Why |
|---|---|---|
| `1+2*3` | **9** | `(1+2)*3` — flat left-assoc |
| `2*3+1` | **7** | `(2*3)+1` — same |
| `2**3**2` | **64** | `(2**3)**2` — power is left-assoc |
| `2+3*4` | **20** | `(2+3)*4` — flat left-assoc |
| `-2**2` | **4** | `(-2)**2` — unary binds first |
| `1_2+3` | **15** | `(1_2)+3` = `12+3` |

## PEMDAS precedence (opt-in helper)

School precedence via `$$PEMDAS(expr)` or `$ARITH("pemdas",expr)`:

| Level | Operators | Associativity |
|---|---|---|
| 1 (tightest) | unary `-` `+` | right |
| 2 | `**` | **right** |
| 3 | `*` `/` | left |
| 4 | `+` `-` | left |

### Key examples (PEMDAS)

| Expression | PEMDAS result | Why |
|---|---|---|
| `1+2*3` | **7** | `1+(2*3)` — mul binds tighter |
| `2*3+1` | **7** | `(2*3)+1` — same |
| `2**3**2` | **512** | `2**(3**2)` — power is right-assoc |
| `2+3*4` | **14** | `2+(3*4)` — mul binds tighter |
| `-2**2` | **-4** | `-(2**2)` — power binds tighter |

## Differences summary

| Expression | M | PEMDAS | Differ? |
|---|---|---|---|
| `1+2*3` | 9 | 7 | **YES** |
| `2**3**2` | 64 | 512 | **YES** |
| `2+3*4` | 20 | 14 | **YES** |
| `-2**2` | 4 | -4 | **YES** |
| `2*3+1` | 7 | 7 | no |
| `(1+2)*3` | 9 | 9 | no (explicit parens) |

## Constraint

**Default M evaluation is oracle-aligned (RSM/ISO).** Any PEMDAS path is **opt-in** and named explicitly (`$$PEMDAS` / `$ARITH`). The corpus gate (`135/4/0`) must not change.
