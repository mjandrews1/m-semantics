// MRelOps.dfy — relational-operator family semantics (P1d).
//
// Pins the GT.M-verified truth table from mjvm/tools/opmatrix.m
// (13 operators x 20 operand-type pairs, 2026-10-29, GT.M V7.2-001 on
// U01) and formalizes the two documented upstream divergence classes:
//
//   C24     = / '= on non-canonical numerics: ISO compares numerically
//            ("007" = 7), GT.M compares the string forms ("007" != "7").
//   C16 / rsm#11   < > <= >= on non-numeric strings: ISO compares
//            lexically ("a" < "b"), GT.M/RSM coerce both sides to
//            numbers (val("a") = val("b") = 0, so the answer is 0).
//
// The pymumps corpus arbiter has no `]`-family implementation, so GT.M
// is the sole arbiter there; this module is its permanent record.
//
// Companion implementation: mjvm ExprEval.compare() / numCollAfter()
// (fixes mjvm#26-#28). The CanonAgree lemma is the safety statement for
// ExprEval's numeric fast path: both rule-sets coincide on canonical
// numerics, so the fast path needs only the canonical-operand guard.
//
// Verified: 23 results (13 lemmas + 2 datatype functions from the initial
// parallel-session draft; 10 more lemmas merged from the v1 draft on branch
// mrelops-dfy), 0 errors (Dafny 4.11).

module MRelOps {

  type Str = seq<char>

  // Operand classification, at the type level. This carries exactly the
  // distinctions the operator family needs (no string parsing required):
  datatype Opnd =
    | ONull                      // the null string "" (val 0 under coercion)
    | ONum(x: real, r: Str)      // canonical number, string form r ("1","0.5","-1")
    | ONumStr(x: real, r: Str)   // numeric but NON-canonical string ("007","1.0")
    | OStr(r: Str)               // non-numeric string ("a","ERR")

  function num(v: Opnd): real
  {
    match v
    case ONull => 0.0
    case ONum(x, _) => x
    case ONumStr(x, _) => x
    case OStr(_) => 0.0
  }

  function str(v: Opnd): Str
  {
    match v
    case ONull => []
    case ONum(_, r) => r
    case ONumStr(_, r) => r
    case OStr(r) => r
  }

  function isNumKind(v: Opnd): bool
  {
    v.ONum? || v.ONumStr?
  }

  // ----- lexical compare (bytewise, M collation) -------------------------
  // a shorter than b => a < b (MUMPS collation; e.g. "abc" < "abcd").
  function lex(a: Str, b: Str): int
    decreases |b|
  {
    if |a| == 0 && |b| == 0 then 0
    else if |a| == 0 then -1
    else if |b| == 0 then 1
    else if a[0] < b[0] then -1
    else if a[0] > b[0] then 1
    else lex(a[1..], b[1..])
  }

  function realCmp(x: real, y: real): int
  {
    if x < y then -1 else if x > y then 1 else 0
  }

  // ----- [ / '[ contains -------------------------------------------------
  function startsWith(a: Str, i: nat, b: Str): bool
    requires i <= |a|
    decreases |b|
  {
    if |b| == 0 then true
    else if i == |a| then false
    else a[i] == b[0] && startsWith(a, i + 1, b[1..])
  }

  function containsFrom(a: Str, i: nat, b: Str): bool
    requires i <= |a|
    decreases |a| - i
  {
    if i + |b| > |a| then false
    else startsWith(a, i, b) || containsFrom(a, i + 1, b)
  }

  // "" is contained in everything (the opmatrix cells agree: contains
  // with a null right operand is true).
  function mContains(a: Opnd, b: Opnd): bool
  {
    containsFrom(str(a), 0, str(b))
  }

  function mNotContains(a: Opnd, b: Opnd): bool
  {
    !mContains(a, b)
  }

  // ----- = / '= : two rule sets ------------------------------------------
  // ISO 11756 8.3 (corpus arbiter: pymumps, MSemantics.dfy mEq):
  // numeric iff BOTH operands are numeric strings (loose parse), else
  // bytewise string equality.
  function isoEq(a: Opnd, b: Opnd): bool
  {
    if isNumKind(a) && isNumKind(b) then num(a) == num(b) else str(a) == str(b)
  }

  // GT.M V7.2-001 (C24): numeric iff BOTH are canonical; non-canonical
  // numerics fall to the string compare.
  function gtmEq(a: Opnd, b: Opnd): bool
  {
    if a.ONum? && b.ONum? then num(a) == num(b) else str(a) == str(b)
  }

  // ----- < > <= >= : two rule sets ---------------------------------------
  // ISO 11756 8.3 (corpus arbiter): numeric iff both numeric strings,
  // else lexical (MSemantics.dfy cmp).
  function isoCmp(a: Opnd, b: Opnd): int
  {
    if isNumKind(a) && isNumKind(b) then realCmp(num(a), num(b)) else lex(str(a), str(b))
  }

  // GT.M / RSM (rsm#11a): ALWAYS numeric coercion of both sides.
  function gtmCmp(a: Opnd, b: Opnd): int
  {
    realCmp(num(a), num(b))
  }

  // ----- ] sorts-after (bytewise) / '] negation --------------------------
  function mSortsAfter(a: Opnd, b: Opnd): bool
  {
    lex(str(a), str(b)) > 0
  }

  function mNotSortsAfter(a: Opnd, b: Opnd): bool
  {
    !mSortsAfter(a, b)
  }

  // ----- ]] follows, GT.M numeric collation (mjvm#28) --------------------
  // Canonical MUMPS collation: null string first, then numbers
  // (numerically — "007" is the number 7), then non-numeric strings
  // (lexically). ']] is its negation.
  function collRank(v: Opnd): int
  {
    match v
    case ONull => 0
    case ONum(_, _) => 1
    case ONumStr(_, _) => 1
    case OStr(_) => 2
  }

  function mCollAfter(a: Opnd, b: Opnd): bool
  {
    if collRank(a) == 0 then false                    // null sorts first
    else if collRank(b) == 0 then true                // everything follows null
    else if collRank(a) == 1 && collRank(b) == 1 then num(a) > num(b)
    else if collRank(a) == 1 then false               // numbers before strings
    else if collRank(b) == 1 then true                // strings after numbers
    else lex(str(a), str(b)) > 0
  }

  function mNotCollAfter(a: Opnd, b: Opnd): bool
  {
    !mCollAfter(a, b)
  }

  // ----- general lemmas ---------------------------------------------------

  // C24: the arbiters disagree exactly on numeric-but-non-canonical pairs
  // with equal numeric values and different string forms.
  lemma C24NonCanonical(ra: Str, rb: Str)
    requires ra != rb
    ensures isoEq(ONum(7.0, ra), ONumStr(7.0, rb)) && !gtmEq(ONum(7.0, ra), ONumStr(7.0, rb))
  {
  }

  // C16 / rsm#11: on two distinct non-numeric strings the GT.M ordering
  // compare is 0 (both coerce to 0) while ISO compares lexically.
  lemma C16StringOrdering(ra: Str, rb: Str)
    requires ra != rb
    ensures gtmCmp(OStr(ra), OStr(rb)) == 0
  {
  }

  // Safety statement for the ExprEval numeric fast path: on canonical
  // numerics both arbiters coincide on every ordering and equality op.
  lemma CanonAgree(a: Opnd, b: Opnd)
    requires a.ONum? && b.ONum?
    ensures isoEq(a, b) == gtmEq(a, b)
    ensures isoCmp(a, b) == gtmCmp(a, b)
  {
  }

  // Collation laws (GT.M ]]): null first, numbers before non-numbers.
  lemma CollLaws(x: Opnd)
    ensures x.ONull? ==> forall y: Opnd :: !mCollAfter(x, y)
    ensures forall y: Opnd :: mCollAfter(y, ONull) == !y.ONull?
    ensures forall y: Opnd :: x.OStr? ==> mCollAfter(x, y) || !y.ONum?
  {
  }

  // ----- opmatrix truth-table cells (GT.M V7.2-001, 2026-10-29) ----------
  // Representative cells from tools/opmatrix.m, GT.M column. Every assert
  // was produced by GT.M on U01; mjvm matches all of them after #26-#28.
  lemma TruthTableEquality()
  {
    // = : C24 cells — GT.M string-compares, ISO numeric-compares.
    assert !gtmEq(ONum(7.0, "7"), ONumStr(7.0, "007"));      // 7="007" -> 0 in GT.M
    assert isoEq(ONum(7.0, "7"), ONumStr(7.0, "007"));       // -> 1 in ISO/pymumps
    assert gtmEq(ONum(1.0, "1"), ONumStr(1.0, "1.0")) == false;
    // = on plain strings and mixed: both arbiters agree.
    assert gtmEq(OStr("a"), OStr("a"));
    assert !gtmEq(OStr("a"), OStr("b"));
    assert !gtmEq(ONum(0.0, "0"), ONull);                    // "0" != ""
    assert !gtmEq(OStr("ERR"), ONum(0.0, "0"));
    assert !gtmEq(OStr("A"), OStr("a"));
  }

  lemma TruthTableOrdering()
  {
    // GT.M: ordering is numeric always (C16).
    assert gtmCmp(OStr("a"), OStr("b")) == 0;               // "a"<"b" is 0 in GT.M
    assert gtmCmp(OStr("abc"), OStr("ab")) == 0;
    // ISO: lexical.
    assert isoCmp(OStr("a"), OStr("b")) == -1;
    assert isoCmp(OStr("A"), OStr("a")) == -1;              // "A" < "a"
    assert isoCmp(OStr("abc"), OStr("ab")) == 1;            // "abc" > "ab"
    // Numbers: both agree.
    assert gtmCmp(ONum(1.0, "1"), ONum(2.0, "2")) == isoCmp(ONum(1.0, "1"), ONum(2.0, "2"));
    // Mixed number/string: GT.M numeric (0 vs 0), ISO lexical ("0" vs "" -> 1).
    assert gtmCmp(ONum(0.0, "0"), ONull) == 0;
  }

  lemma TruthTableContains()
  {
    assert mContains(OStr("abc"), OStr("b"));
    assert !mContains(OStr("abc"), OStr("z"));
    assert !mNotContains(OStr("abc"), OStr("b"));
    assert mNotContains(OStr("abc"), OStr("z"));
    assert mContains(ONum(123.0, "123"), ONum(2.0, "2"));   // "123" contains "2" (GT.M 1; was mjvm#26)
    assert !mNotContains(ONum(123.0, "123"), ONum(2.0, "2"));
    assert mContains(OStr("0123456789"), OStr("3"));
  }

  lemma TruthTableSortsAfter()
  {
    // ] bytewise sorts-after.
    assert mSortsAfter(OStr("b"), OStr("a"));
    assert !mSortsAfter(OStr("a"), OStr("b"));
    assert !mSortsAfter(OStr("a"), OStr("a"));              // equal does not sort after
    assert mSortsAfter(ONum(2.0, "2"), ONum(1.0, "1"));     // "2" sorts after "1" bytewise
    assert mSortsAfter(ONum(7.0, "7"), ONumStr(7.0, "007"));         // "7" > "007" bytewise
    assert !mSortsAfter(OStr("10"), ONum(9.0, "9"));        // "10" < "9" bytewise
    // '] is NOT-sorts-after (mjvm#28: was mis-implemented as not-contains).
    assert mNotSortsAfter(OStr("b"), OStr("a")) == false;
    assert mNotSortsAfter(OStr("x"), OStr("x"));            // equal -> ' after is TRUE
    assert mNotSortsAfter(ONum(2.0, "2"), ONum(1.0, "1")) == false;
  }

  lemma TruthTableCollation()
  {
    // ]] GT.M numeric collation (mjvm#28).
    assert mCollAfter(ONum(10.0, "10"), ONum(9.0, "9"));    // numeric: 10 > 9 (GT.M 1)
    assert !mCollAfter(ONum(7.0, "7"), ONumStr(7.0, "007")); // numeric: 7 > 7 is false
    assert !mCollAfter(ONum(2.0, "2"), ONum(2.0, "2"));     // equal
    assert mCollAfter(OStr("abc"), ONum(9.0, "9"));         // strings sort after numbers
    assert !mCollAfter(ONum(9.0, "9"), OStr("abc"));
    assert mCollAfter(ONum(0.0, "0"), ONull);                // everything follows null
    assert !mCollAfter(ONull, ONull);
    assert !mCollAfter(ONull, ONum(0.0, "0"));
    // ']] is the negation.
    assert !mNotCollAfter(ONum(10.0, "10"), ONum(9.0, "9"));
    assert mNotCollAfter(ONum(7.0, "7"), ONumStr(7.0, "007"));
    assert mNotCollAfter(ONum(2.0, "2"), ONum(2.0, "2"));
  }

  // ===========================================================================
  // Structural lemmas and extended cell coverage (merged from the parallel
  // session's v1 draft, branch mrelops-dfy): lex laws, collation laws, and
  // the remaining opmatrix GT.M cells.
  // ===========================================================================

  // ----- lex laws -----------------------------------------------------------

  lemma LexReflexive(a: Str)
    ensures lex(a, a) == 0
    decreases |a|
  {
    if |a| > 0 {
      LexReflexive(a[1..]);
    }
  }

  lemma LexNeg(a: Str, b: Str)
    ensures lex(a, b) == -lex(b, a)
    decreases |a| + |b|
  {
    if |a| == 0 || |b| == 0 {
    } else if a[0] < b[0] || a[0] > b[0] {
    } else {
      LexNeg(a[1..], b[1..]);
    }
  }

  lemma LexAntisymmetric(a: Str, b: Str)
    ensures lex(a, b) > 0 ==> lex(b, a) < 0
  {
    LexNeg(a, b);
  }

  // ----- collation laws (structural) ----------------------------------------

  lemma CollNoSelf(x: Opnd)
    ensures !mCollAfter(x, x)
  {
    match x {
      case ONull =>
      case ONum(_, _) =>
      case ONumStr(_, _) =>
      case OStr(r) =>
        LexReflexive(r);
    }
  }

  lemma CollAntisymmetric(a: Opnd, b: Opnd)
    ensures mCollAfter(a, b) ==> !mCollAfter(b, a)
  {
    if a.OStr? && b.OStr? {
      LexNeg(str(a), str(b));
    }
  }

  // ----- null-string containment ---------------------------------------------

  // The null string is contained in everything; a non-null string is
  // contained in nothing (opmatrix row 9, cells 10-14).
  lemma ContainsNull(a: Opnd, b: Opnd)
    ensures mContains(a, ONull)
    ensures |str(b)| > 0 ==> !mContains(ONull, b)
  {
  }

  // ----- negated equality (C24 from the '= side) -----------------------------

  function isoNotEq(a: Opnd, b: Opnd): bool
  {
    !isoEq(a, b)
  }

  function gtmNotEq(a: Opnd, b: Opnd): bool
  {
    !gtmEq(a, b)
  }

  // ----- extended opmatrix cells ---------------------------------------------

  lemma TruthTableContainsExtra()
  {
    // Null containment cells (GT.M: "0123456789"["" is 1; ""["x" is 0).
    assert mContains(OStr("0123456789"), ONull);
    assert mContains(ONull, ONull);
    assert !mContains(ONull, OStr("x"));
    // "123" contains no "4" (mjvm#26 numeric-coercion companion cell).
    assert !containsFrom("123", 3, "4");
    assert !containsFrom("123", 2, "4");
    assert !containsFrom("123", 1, "4");
    assert !containsFrom("123", 0, "4");
    assert !mContains(ONum(123.0, "123"), ONum(4.0, "4"));
    // The digit string contains no 'a'.
    assert !containsFrom("0123456789", 10, "a");
    assert !containsFrom("0123456789", 9, "a");
    assert !containsFrom("0123456789", 8, "a");
    assert !containsFrom("0123456789", 7, "a");
    assert !containsFrom("0123456789", 6, "a");
    assert !containsFrom("0123456789", 5, "a");
    assert !containsFrom("0123456789", 4, "a");
    assert !containsFrom("0123456789", 3, "a");
    assert !containsFrom("0123456789", 2, "a");
    assert !containsFrom("0123456789", 1, "a");
    assert !containsFrom("0123456789", 0, "a");
    assert !mContains(OStr("0123456789"), OStr("a"));
  }

  lemma TruthTableSortsAfterExtra()
  {
    // ] is bytewise even when both sides are numeric: "999" sorts after
    // "2" (GT.M 999]2 -> 1), but "10" does not sort after "9" (-> 0).
    assert mSortsAfter(ONum(999.0, "999"), ONum(2.0, "2"));
    assert !mSortsAfter(ONum(10.0, "10"), ONum(9.0, "9"));
    // '] cells (GT.M probes 2026-10-29):
    //   1']2 -> 1, "a"']"b" -> 1, "x"']"x" -> 1, 2']1 -> 0, "b"']"a" -> 0.
    assert mNotSortsAfter(ONum(1.0, "1"), ONum(2.0, "2"));
    assert mNotSortsAfter(OStr("a"), OStr("b"));
    assert mNotSortsAfter(OStr("x"), OStr("x"));
    assert !mNotSortsAfter(ONum(2.0, "2"), ONum(1.0, "1"));
    assert !mNotSortsAfter(OStr("b"), OStr("a"));
    // Case sensitivity is bytewise: "a" sorts after "A".
    assert mSortsAfter(OStr("a"), OStr("A"));
  }

  lemma TruthTableCollationExtra()
  {
    // The string class of ]] collates lexically (opmatrix row 12).
    assert mCollAfter(OStr("b"), OStr("a"));
    assert !mCollAfter(OStr("a"), OStr("b"));
    assert !mCollAfter(OStr("A"), OStr("a"));
    // Numbers sort before strings regardless of magnitude.
    assert !mCollAfter(ONum(0.25, "0.25"), OStr("A"));
    assert mCollAfter(OStr("A"), ONum(0.25, "0.25"));
    // ']] probes (GT.M 2026-10-29):
    //   "10"']]9 -> 0, "9"']]9 -> 1, "abc"']]9 -> 0.
    assert !mNotCollAfter(ONum(10.0, "10"), ONum(9.0, "9"));
    assert mNotCollAfter(ONum(9.0, "9"), ONum(9.0, "9"));
    assert !mNotCollAfter(OStr("abc"), ONum(9.0, "9"));
  }

  lemma TruthTableNegatedEquality()
  {
    // '= agrees on canonical numerics and plain strings.
    assert !isoNotEq(ONum(5.0, "5"), ONum(5.0, "5"));
    assert !gtmNotEq(ONum(5.0, "5"), ONum(5.0, "5"));
    assert isoNotEq(ONum(1.0, "1"), ONum(2.0, "2"));
    assert gtmNotEq(ONum(1.0, "1"), ONum(2.0, "2"));
    assert isoNotEq(OStr("a"), OStr("b"));
    assert gtmNotEq(OStr("a"), OStr("b"));
    // C24 seen from '=: ISO numeric-loose says "7"'"007" is 0 (they are
    // numerically equal); GT.M says 1 (bytewise different).
    assert !isoNotEq(ONum(7.0, "7"), ONumStr(7.0, "007"));
    assert gtmNotEq(ONum(7.0, "7"), ONumStr(7.0, "007"));
    // T11: "" is not a numeric string in either arbiter, so ""'"0" is 1.
    assert isoNotEq(ONull, ONum(0.0, "0"));
    assert gtmNotEq(ONull, ONum(0.0, "0"));
  }
}
