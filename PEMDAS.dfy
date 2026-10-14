// PEMDAS.dfy — optional school-precedence arithmetic (m-semantics#31).
// NOT the default M expression semantics (see MSemantics.dfy / ISO 11756).
// Opt-in helper only: default M parse is unchanged.

module PEMDAS {
  // School-precedence expression (subset: + - * / ** and unary minus).
  // Integer payload keeps SMT tractable; real M values use mstr/toNum elsewhere.
  datatype PExp =
    | PNum(x: int)
    | PNeg(e: PExp)
    | PPow(a: PExp, b: PExp)
    | PMul(a: PExp, b: PExp)
    | PDiv(a: PExp, b: PExp)
    | PAdd(a: PExp, b: PExp)
    | PSub(a: PExp, b: PExp)

  // Right-assoc power on ints (uninterpreted except axioms we need).
  function {:axiom} powI(base: int, exp: int): int

  function peval(e: PExp): (r: int)
    decreases e
  {
    match e
    case PNum(x) => x
    case PNeg(a) => -peval(a)
    case PPow(a, b) => powI(peval(a), peval(b))
    case PMul(a, b) => peval(a) * peval(b)
    case PDiv(a, b) =>
      if peval(b) == 0 then 0 else peval(a) / peval(b)
    case PAdd(a, b) => peval(a) + peval(b)
    case PSub(a, b) => peval(a) - peval(b)
  }

  // M left-assoc ** : ((2**3)**2)
  function mPowLeft(a: int, b: int, c: int): int {
    powI(powI(a, b), c)
  }

  // PEMDAS right-assoc ** : 2**(3**2)
  function pemdasPowRight(a: int, b: int, c: int): int {
    powI(a, powI(b, c))
  }

  // 2+3*4 is 14 under PEMDAS (mul binds tighter than add).
  lemma TwoPlusThreeTimesFour()
    ensures peval(PAdd(PNum(2), PMul(PNum(3), PNum(4)))) == 14
  {
    assert peval(PNum(3)) == 3;
    assert peval(PNum(4)) == 4;
    assert peval(PMul(PNum(3), PNum(4))) == 12;
    assert peval(PNum(2)) == 2;
    assert peval(PAdd(PNum(2), PMul(PNum(3), PNum(4)))) == 14;
  }

  // (2+3)*4 is 20 — different tree, same tokens.
  lemma ParenSumTimesFour()
    ensures peval(PMul(PAdd(PNum(2), PNum(3)), PNum(4))) == 20
  {
    assert peval(PNum(2)) == 2;
    assert peval(PNum(3)) == 3;
    assert peval(PAdd(PNum(2), PNum(3))) == 5;
    assert peval(PNum(4)) == 4;
    assert peval(PMul(PAdd(PNum(2), PNum(3)), PNum(4))) == 20;
  }

  // Unary minus binds looser than power: -(2**2) = -4.
  lemma NegPowTwo()
    requires powI(2, 2) == 4
    ensures peval(PNeg(PPow(PNum(2), PNum(2)))) == -4
  {
    assert peval(PPow(PNum(2), PNum(2))) == 4;
    assert peval(PNeg(PPow(PNum(2), PNum(2)))) == -4;
  }

  // M left-assoc power vs PEMDAS right-assoc.
  lemma PowAssocDiffers()
    requires powI(2, 3) == 8
    requires powI(8, 2) == 64
    requires powI(3, 2) == 9
    requires powI(2, 9) == 512
    ensures mPowLeft(2, 3, 2) == 64
    ensures pemdasPowRight(2, 3, 2) == 512
    ensures mPowLeft(2, 3, 2) != pemdasPowRight(2, 3, 2)
  {
    assert powI(2, 3) == 8;
    assert powI(8, 2) == 64;
    assert powI(3, 2) == 9;
    assert powI(2, 9) == 512;
  }

  // Div-by-zero matches M div convention (result 0).
  lemma DivZeroIsZero()
    ensures peval(PDiv(PNum(1), PNum(0))) == 0
  {
    assert peval(PNum(0)) == 0;
  }
}
