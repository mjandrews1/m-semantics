// ---------------------------------------------------------------------------
// MRelOps.dfy -- formal semantics of the M relational-operator family.
//
// Scope: the comparison operators of ISO 11756 8.3 in TWO dialects, plus the
// sorts-after family, which the corpus does not cover at all (pymumps
// implements only = '= < > <= >= '< '>, so GT.M is the sole arbiter there):
//
//   [   '[    contains / not-contains          (dialect-independent)
//   ]   ']    sorts-after / negated            (lexical collation)
//   ]]  ']]   follows / negated                (GT.M numeric collation:
//                                             null < numbers < strings)
//   =   '=    equality                        (ISO: numeric iff both numeric
//                                             strings; GT.M: canonical only)
//   < > <= >= '< '>  ordering                 (ISO: numeric iff both numeric
//                                             strings, else lexical; GT.M:
//                                             ALWAYS numeric coercion)
//
// Dialects and why both are modelled:
//   ISO 11756 / RSM / pymumps / corpus conformance.json -- the campaign's
//     corpus arbiter; mJVM implements this side (peer target 131/8/0).
//   GT.M V7.2-001 (U01) -- the ORACLE harness arbiter; diverges from ISO on
//     two documented classes, pinned here as lemmas:
//       C24      = on non-canonical numerics ("7"="007" is 0 in GT.M,
//                 numeric-equal in ISO) -- corpus upstream miss family.
//       C16/rsm#11  < > <= >= on two non-numeric strings ("a"<"b" is 0 in
//                 GT.M, both sides coerce to 0; ISO compares lexically).
//
// Truth-table source: mjvm/tools/opmatrix.m -- 13 operators x 20 operand-type
// pairs, three-way verified (mJVM native, mJVM --class, GT.M) 2026-10-29;
// fixes mjvm#26, #27, #28. Every lemma cell below was produced by GT.M on U01.
//
// Verified: 28 lemmas, 0 errors (Dafny 4.11).
//
// Number format subset (#:DEF): decimal only (no exponent); toNum parses an
// optional '-', digits, optional '.' + digits. The opmatrix operand set uses
// no exponents, so MSemantics.dfy's full prefix-parser is not needed here.
//
// Tags:
//   #:DEF  our modelling choice (may differ from an engine's detail)
// ---------------------------------------------------------------------------

module MRelOps {

  type Bytes = seq<char>

  // ----- character helpers -------------------------------------------------

  function isDigit(c: char): bool
  {
    '0' <= c && c <= '9'
  }

  function digitVal(c: char): int
    requires isDigit(c)
  {
    (c as int) - ('0' as int)
  }

  function skipDigits(s: Bytes, i: nat): nat
    requires i <= |s|
    ensures i <= skipDigits(s, i) <= |s|
    ensures forall k :: i <= k < skipDigits(s, i) ==> isDigit(s[k])
    decreases |s| - i
  {
    if i < |s| && isDigit(s[i]) then skipDigits(s, i + 1) else i
  }

  // Digits s[start..end) as an integer; empty range is 0.
  function natValue(s: Bytes, end: nat, start: nat): int
    requires start <= end <= |s|
    requires forall k :: start <= k < end ==> isDigit(s[k])
    decreases end - start
  {
    if end <= start then 0
    else natValue(s, end - 1, start) * 10 + digitVal(s[end - 1])
  }

  function pow10(n: nat): real
    ensures pow10(n) >= 1.0
    decreases n
  {
    if n == 0 then 1.0 else 10.0 * pow10(n - 1)
  }

  // ----- numeric parse (subset, #:DEF no exponent) --------------------------

  // Position just past the sign.
  function signEnd(s: Bytes): nat
  {
    if |s| > 0 && (s[0] == '-' || s[0] == '+') then 1 else 0
  }

  // toNum: sign * (integer part + fraction). Unparseable -> 0.
  function toNum(s: Bytes): real
  {
    var i := signEnd(s);
    var sg := if i == 1 && s[0] == '-' then -1.0 else 1.0;
    var j := skipDigits(s, i);
    // fraction: '.' then digits s[j+1..k)
    var k := if j < |s| && s[j] == '.' then skipDigits(s, j + 1) else j;
    var ip := natValue(s, j, i);
    var fp := if k > j then fracValue(s, j + 1, k, 1) else 0.0;
    sg * (ip as real + fp)
  }

  // Fraction digits s[start..end) at 1-based places m, m+1, ...
  function fracValue(s: Bytes, start: nat, end: nat, m: nat): real
    requires start <= end <= |s| && m >= 1
    requires forall p :: start <= p < end ==> isDigit(s[p])
    decreases end - start
  {
    if end <= start then 0.0
    else (digitVal(s[start]) as real) / pow10(m) + fracValue(s, start + 1, end, m + 1)
  }

  // Whole-string numeric test (loose): sign? digits? ('.' digits?)? -- at
  // least one digit, and the WHOLE string must be consumed.  "007" yes,
  // "" no, "1abc" no, ".5" yes.  (ISO/RSM-lineage "is numeric string".)
  predicate isNum(s: Bytes)
  {
    var i := signEnd(s);
    var j := skipDigits(s, i);
    var k := if j < |s| && s[j] == '.' then skipDigits(s, j + 1) else j;
    k == |s| && (j > i || k > j + 1)
  }

  // Canonical numeric (mstr form, #:DEF): no '+'; integer part has no
  // leading zero (single "0" allowed, but "0.x" is NOT canonical -- mstr
  // prints ".5"); a fraction, when present, does not end in '0' ("1.0" is
  // not canonical; mstr prints "1").
  predicate isCanon(s: Bytes)
  {
    var i := signEnd(s);
    var j := skipDigits(s, i);
    var k := if j < |s| && s[j] == '.' then skipDigits(s, j + 1) else j;
    isNum(s)
      && (|s| == 0 || s[0] != '+')
      && (j == i || s[i] != '0' || (j == i + 1 && k == j))
      && (k == j || s[k - 1] != '0')
  }

  // ----- lexical collation --------------------------------------------------

  function lexCompare(a: Bytes, b: Bytes): int
  {
    lexCompareFrom(a, b, 0)
  }

  function lexCompareFrom(a: Bytes, b: Bytes, i: nat): int
    requires i <= |a| && i <= |b|
    decreases |a| - i
  {
    if i == |a| && i == |b| then 0
    else if i == |a| then -1
    else if i == |b| then 1
    else if a[i] as int < b[i] as int then -1
    else if a[i] as int > b[i] as int then 1
    else lexCompareFrom(a, b, i + 1)
  }

  // ----- equality: both dialects --------------------------------------------

  // ISO 11756 8.3 = (RSM / pymumps / corpus / mJVM).  Numeric iff BOTH
  // operands are numeric strings, non-canonical forms equal their canonical
  // value; otherwise bytewise.  "" is not numeric, so ""="0" is false (T11).
  predicate mEq(a: Bytes, b: Bytes)
  {
    if isNum(a) && isNum(b) then toNum(a) == toNum(b) else a == b
  }

  // GT.M V7.2-001 = (#:DEF): numeric iff BOTH operands are CANONICAL
  // numbers; non-canonical numerics ("007", "1.0") fall to bytewise compare.
  predicate gtmEq(a: Bytes, b: Bytes)
  {
    if isCanon(a) && isCanon(b) then toNum(a) == toNum(b) else a == b
  }

  // ----- ordering: both dialects --------------------------------------------

  // ISO 11756 / RSM-lineage ordering: numeric iff both numeric strings,
  // otherwise lexical (this is MSemantics.dfy's cmp, mirrored here to keep
  // the file standalone for `dafny verify MRelOps.dfy`).
  function mCmp(a: Bytes, b: Bytes): int
  {
    if isNum(a) && isNum(b) then
      (if toNum(a) < toNum(b) then -1 else if toNum(a) > toNum(b) then 1 else 0)
    else lexCompare(a, b)
  }

  // GT.M V7.2-001 ordering: ALWAYS numeric -- both sides coerce through
  // toNum ("a"<"b" is 0 < 0, false).  This is the C16 / rsm#11 class.
  function gtmCmp(a: Bytes, b: Bytes): int
  {
    if toNum(a) < toNum(b) then -1 else if toNum(a) > toNum(b) then 1 else 0
  }

  // ----- contains family (dialect-independent) -------------------------------

  // A[B : true iff B occurs in A as a substring.
  predicate containsFrom(a: Bytes, b: Bytes, k: nat)
    requires k <= |a|
    decreases |a| - k
  {
    if k + |b| > |a| then false
    else a[k..k + |b|] == b || containsFrom(a, b, k + 1)
  }

  predicate containsStr(a: Bytes, b: Bytes)
  {
    containsFrom(a, b, 0)
  }

  // A witness position proves containment.
  lemma L_containsWitness(a: Bytes, b: Bytes, k: nat)
    requires k + |b| <= |a|
    requires a[k..k + |b|] == b
    ensures containsStr(a, b)
  {
    L_containsFromUp(a, b, 0, k);
  }

  lemma L_containsFromUp(a: Bytes, b: Bytes, i: nat, k: nat)
    requires i <= k <= |a|
    requires k + |b| <= |a|
    requires a[k..k + |b|] == b
    ensures containsFrom(a, b, i)
    decreases k - i
  {
    if i == k {
      assert a[k..k + |b|] == b;
    } else {
      L_containsFromUp(a, b, i + 1, k);
    }
  }

  // Absence at every position proves non-containment.
  lemma L_containsBasics()
  {
    // witnesses for the positives
    assert "0123456789"[2..3] == "2";
    assert "abc"[0..3] == "abc";
    assert "abc"[1..3] == "bc";
    L_containsWitness("0123456789", "2", 2);
    L_containsWitness("abc", "abc", 0);
    L_containsWitness("abc", "bc", 1);
    assert containsStr("0123456789", "2");
    assert containsStr("abc", "abc");
    assert containsStr("abc", "bc");
    // "0123456789" contains no 'a' (GT.M: "0123456789"["a" is 0) --
    // every window differs; explicit walk.
    assert "0123456789"[0..1] != "a";
    assert "0123456789"[1..2] != "a";
    assert "0123456789"[2..3] != "a";
    assert "0123456789"[3..4] != "a";
    assert "0123456789"[4..5] != "a";
    assert "0123456789"[5..6] != "a";
    assert "0123456789"[6..7] != "a";
    assert "0123456789"[7..8] != "a";
    assert "0123456789"[8..9] != "a";
    assert "0123456789"[9..10] != "a";
    assert !containsFrom("0123456789", "a", 10);
    assert !containsFrom("0123456789", "a", 9);
    assert !containsFrom("0123456789", "a", 8);
    assert !containsFrom("0123456789", "a", 7);
    assert !containsFrom("0123456789", "a", 6);
    assert !containsFrom("0123456789", "a", 5);
    assert !containsFrom("0123456789", "a", 4);
    assert !containsFrom("0123456789", "a", 3);
    assert !containsFrom("0123456789", "a", 2);
    assert !containsFrom("0123456789", "a", 1);
    assert !containsFrom("0123456789", "a", 0);
    assert !containsStr("0123456789", "a");
    // equal length, different contents
    assert !containsFrom("abc", "abd", 1);
    assert "abc"[0..3] != "abd";
    assert !containsFrom("abc", "abd", 0);
    assert !containsStr("abc", "abd");
  }

  // The empty string is contained in everything (GT.M: "0123456789"["" is 1).
  lemma L_containsEmpty()
  {
    assert ""[0..0] == "";
    L_containsWitness("0123456789", "", 0);
    assert containsStr("0123456789", "");
    L_containsWitness("", "", 0);
    assert containsStr("", "");
    // |"x"| > |""|: out of range at position 0
    assert !containsFrom("", "x", 0);
    assert !containsStr("", "x");
  }

  // Numeric operands coerce to their string forms: 123[2 is "123"["2" = 1
  // (mjvm#26: the engine's numeric fast path used to return 0 here).
  lemma L_containsNumericCoercion()
  {
    assert "123"[1..2] == "2";
    L_containsWitness("123", "2", 1);
    assert containsStr("123", "2");
    assert "123"[0..1] != "4";
    assert "123"[1..2] != "4";
    assert "123"[2..3] != "4";
    assert !containsFrom("123", "4", 3);
    assert !containsFrom("123", "4", 2);
    assert !containsFrom("123", "4", 1);
    assert !containsFrom("123", "4", 0);
    assert !containsStr("123", "4");
  }

  predicate sortsAfter(a: Bytes, b: Bytes)
  {
    lexCompare(a, b) > 0
  }

  // '] negates ] (the ' binds to ], never to [).  mjvm#28.
  predicate notSortsAfter(a: Bytes, b: Bytes)
  {
    !sortsAfter(a, b)
  }

  // ]] follows under GT.M numeric collation: the null string sorts first,
  // then numbers (numerically, "007" = 7), then non-numeric strings
  // (lexically).  Verified cell-by-cell against GT.M by tools/opmatrix.m.
  predicate followsColl(a: Bytes, b: Bytes)
  {
    if |a| == 0 then false
    else if |b| == 0 then true
    else if isNum(a) && isNum(b) then toNum(a) > toNum(b)
    else if isNum(a) then false
    else if isNum(b) then true
    else lexCompare(a, b) > 0
  }

  // ']] negates ]].
  predicate notFollowsColl(a: Bytes, b: Bytes)
  {
    !followsColl(a, b)
  }

  // ===========================================================================
  // Truth-table cells (all produced by GT.M V7.2-001 on U01, 2026-10-29)
  // ===========================================================================

  // ----- sorts-after ] and '] -------------------------------------------------

  lemma L_sortsAfterBasics()
  {
    assert sortsAfter("b", "a");
    assert !sortsAfter("a", "b");
    assert !sortsAfter("x", "x");
    // GT.M: 999]2 -> "999" sorts after "2" (lexical, even for numbers)
    assert sortsAfter("999", "2");
    // GT.M: "10"]9 -> 0 (lexical; numeric 10>9 does NOT apply to ])
    assert !sortsAfter("10", "9");
  }

  // '] is NOT-sorts-after (mjvm#28: mJVM had it as not-contains).
  lemma L_notSortsAfterCells()
  {
    // GT.M probes: "b"']"a"=0  "a"']"b"=1  "x"']"x"=1  2']1=0  1']2=1
    assert !notSortsAfter("b", "a");
    assert notSortsAfter("a", "b");
    assert notSortsAfter("x", "x");
    assert !notSortsAfter("2", "1");
    assert notSortsAfter("1", "2");
  }

  // ----- ]] numeric collation --------------------------------------------------

  lemma L_followsCollNumeric()
  {
    // GT.M: "10"]]9 = 1 (numeric collation, unlike ] which is lexical)
    assert followsColl("10", "9");
    // GT.M: 7]]"007" = 0 ("007" is the number 7; 7 does not follow 7)
    assert !followsColl("7", "007");
    // GT.M: 2]]2 = 0
    assert !followsColl("2", "2");
  }

  lemma L_followsCollStringAfterNumber()
  {
    // GT.M: "abc"']]9 = 0, so ]] puts "abc" AFTER the number 9.
    assert followsColl("abc", "9");
    // ... and the number does not follow the string.
    assert !followsColl("9", "abc");
  }

  lemma L_followsCollNullFirst()
  {
    // GT.M opmatrix cells 13/14 of the ]] row: 0]]"" = 1, 1]]"" = 1.
    assert followsColl("0", "");
    assert followsColl("1", "");
    // The null string sorts before everything, including itself.
    assert !followsColl("", "");
    assert !followsColl("", "5");
  }

  lemma L_followsCollStringsLexical()
  {
    assert followsColl("b", "a");
    assert !followsColl("a", "b");
    assert !followsColl("x", "x");
  }

  lemma L_notFollowsCollCells()
  {
    // GT.M probes: "10"']]9=0  2']]2=1  "9"']]9=1  "abc"']]9=0
    assert !notFollowsColl("10", "9");
    assert notFollowsColl("2", "2");
    assert notFollowsColl("9", "9");
    assert !notFollowsColl("abc", "9");
  }

  // ----- C24: equality on non-canonical numerics -------------------------------

  // ISO / RSM / corpus / mJVM: "7"="007" and "1"="1.0" are numeric-equal.
  lemma L_eqISO_nonCanonical()
  {
    assert mEq("7", "007");
    assert mEq("1", "1.0");
    assert mEq("0", "00");
  }

  // GT.M: both fall to bytewise comparison and are FALSE.
  lemma L_eqGTM_nonCanonical()
  {
    assert !gtmEq("7", "007");
    assert !gtmEq("1", "1.0");
  }

  // T11 / T11b: "" is not a numeric string, so ""="0" is false in BOTH
  // dialects (bytewise in each).
  lemma L_eqEmptyVsZero()
  {
    assert !mEq("", "0");
    assert !gtmEq("", "0");
  }

  // Canonical numerics agree across dialects.
  lemma L_eqCanonicalAgreement()
  {
    assert gtmEq("7", "7");
    assert mEq("7", "7");
    assert gtmEq("2", "2") == mEq("2", "2");
    assert !gtmEq("1", "2");
    assert !mEq("1", "2");
  }

  // ----- C16 / rsm#11: ordering on two non-numeric strings ---------------------

  // ISO / corpus: lexical comparison.
  lemma L_orderISO_strings()
  {
    assert mCmp("a", "b") == -1;
    assert mCmp("b", "a") == 1;
    assert mCmp("a", "a") == 0;
    assert mCmp("A", "a") == -1;
  }

  // GT.M: both sides coerce to 0, so every two non-numeric strings are
  // "equal" numerically: < and > are false, <= and >= are true.
  lemma L_orderGTM_strings()
  {
    assert gtmCmp("a", "b") == 0;
    assert gtmCmp("b", "a") == 0;
    // opmatrix row 5 cell 8: "b"<="a" is 1; row 6 cell 7: "a">="b" is 1.
  }

  // On numeric operands the dialects agree (mJVM matches GT.M here).
  lemma L_orderNumericAgreement()
  {
    assert mCmp("1", "2") == gtmCmp("1", "2") == -1;
    assert mCmp("2", "1") == gtmCmp("2", "1") == 1;
    assert mCmp("0.5", "0.25") == gtmCmp("0.5", "0.25") == 1;
    assert mCmp("-1", "0") == gtmCmp("-1", "0") == -1;
  }

  // ----- structural lemmas -----------------------------------------------------

  lemma L_lexCompareReflexive(a: Bytes)
    ensures lexCompare(a, a) == 0
  {
    L_lexCompareFromReflexive(a, 0);
  }

  lemma L_lexCompareFromReflexive(a: Bytes, i: nat)
    requires i <= |a|
    ensures lexCompareFrom(a, a, i) == 0
    decreases |a| - i
  {
    if i < |a| {
      L_lexCompareFromReflexive(a, i + 1);
    }
  }

  lemma L_mEqReflexive(a: Bytes)
    ensures mEq(a, a)
  {
    if isNum(a) {
      assert toNum(a) == toNum(a);
    } else {
      assert a == a;
    }
  }

  lemma L_mEqSymmetric(a: Bytes, b: Bytes)
    ensures mEq(a, b) == mEq(b, a)
  {
  }

  lemma L_sortsAfterAntisymmetric(a: Bytes, b: Bytes)
    ensures sortsAfter(a, b) ==> !sortsAfter(b, a)
  {
    L_lexCompareFromNeg(a, b, 0);
  }

  // lexCompare is antisymmetric, by induction on the shared prefix.
  lemma L_lexCompareFromNeg(a: Bytes, b: Bytes, i: nat)
    requires i <= |a| && i <= |b|
    ensures lexCompareFrom(a, b, i) == -lexCompareFrom(b, a, i)
    decreases |a| + |b| - 2 * i
  {
    if i < |a| && i < |b| {
      if a[i] as int < b[i] as int || a[i] as int > b[i] as int {
      } else {
        L_lexCompareFromNeg(a, b, i + 1);
      }
    }
  }

  // ]] collation is a strict order except across the null/number/string
  // classes: within one class, or between different classes, at most one
  // direction holds; null never follows anything.
  lemma L_followsCollNullNeverFollows(a: Bytes)
    ensures !followsColl("", a)
  {
  }

  lemma L_followsCollNoSelfFollow(a: Bytes)
    ensures !followsColl(a, a)
  {
    if |a| == 0 {
    } else if isNum(a) {
      assert toNum(a) == toNum(a);
    } else {
      L_lexCompareReflexive(a);
    }
  }

  lemma L_followsCollAntisymmetric(a: Bytes, b: Bytes)
    ensures followsColl(a, b) ==> !followsColl(b, a)
  {
    // All five branches of followsColl are individually strict:
    //  - null never follows (|a|==0)
    //  - non-null follows null, but null follows nothing
    //  - numeric class: toNum is a strict order
    //  - number/string classes: only string-follows-number holds
    //  - string class: sortsAfter is strict (see L_sortsAfterAntisymmetric)
    if |a| == 0 || |b| == 0 {
    } else if isNum(a) && isNum(b) {
    } else if isNum(a) {
      // a number never follows a string
      assert !followsColl(a, b);
    } else if isNum(b) {
      // a string follows a number; the number never follows back
      assert !followsColl(b, a);
    } else {
      L_sortsAfterAntisymmetric(a, b);
    }
  }
}
