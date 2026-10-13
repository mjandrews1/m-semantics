// ---------------------------------------------------------------------------
// MSemantics -- formal semantic core of M (MUMPS).
//
// Scope: values and numeric strings, comparison, key collation, the store
// as a finite map, $DATA and $ORDER, $TEST truthiness, and arithmetic
// coercion.  NOT in scope: patterns, routines/DO/GOTO, devices, locks,
// transactions, MERGE/XECUTE, the intrinsic zoo, the compiler, the B-tree.
//
// Provenance.  Grounded in Reference Standard M upstream `ad679d0`
// (V1.83.1), with every behavioural claim checked against a live RSM
// instance as well as the source.  Where RSM is non-conformant the axiom
// is the ISO rule and the divergence is recorded as a comment.  Those
// divergences are rsm#11a, rsm#11b, rsm#11c, rsm#12, rsm#15.
//
// Tags in comments:
//   #:ISO     required by ISO 11756 / ISO/IEC 11756 M
//   #:RSM     grounded in upstream source (may be wrong -- see #:DIVERGE)
//   #:DEF     our modelling choice
//   #:DIVERGE upstream is wrong; we specify the standard
//
// This file specifies M.  It does not verify RSM's C implementation.
// ---------------------------------------------------------------------------

module MSemantics {

  // ----- values -----------------------------------------------------------
  // A value *is* its string form.  There is no separate number sort: the
  // predicate isNum selects the comparison rule.  Chars stand in for bytes;
  // we never inspect a char outside '0'-'9', '+', '-', '.', 'E', 'e'.

  type Bytes = seq<char>

  predicate isDigit(c: char) { '0' <= c <= '9' }

  // An index one past a matched region, or -1 for "no match".
  // Used as a simple parse-result type for Dafny 4.11 (no optional binding).
  const NO_MATCH: int := -1

  // ----- numeric strings --------------------------------------------------
  // A1 (rev 2):  isNum is the WHOLE-STRING predicate -- ISO "numeric string".
  //   [+|-] digits [ '.' digits ] [ 'E' ['+'|'-'] digits ]
  //   >= 1 digit in the mantissa, and >= 1 in the exponent if 'E' is present.
  //   NO leading whitespace.
  //
  // RSM's ncopy (util/memory.c:53) is a PREFIX parse: it stops at the first
  // character it cannot use, so ncopy("1abc") = 1.  RSM's < > therefore treat
  // "1abc" as the number 1.  That is rsm#11c; we do not reproduce it.

  predicate isNum(s: Bytes)
  {
    parseNum(s, 0) == |s|
  }

  // parseNum(s, i): index one past the longest numeric-string prefix of
  // s[i..], or NO_MATCH if s[i..] does not begin with a numeric string.
  function parseNum(s: Bytes, i: nat): int
    requires i <= |s|
    decreases |s| - i
  {
    var i1 := if i < |s| && (s[i] == '+' || s[i] == '-') then i + 1 else i;
    if i1 == |s| then NO_MATCH
    else
      // integer digits (possibly empty if we have .digits)
      var i2 := skipDigits(s, i1);
      // fraction
      if i2 < |s| && s[i2] == '.' then
        var i3 := skipDigits(s, i2 + 1);
        if i3 == i1 && i3 == i2 + 1 then
          // no digits anywhere: "."
          NO_MATCH
        else if i3 == i1 then
          NO_MATCH
        else
          parseExp(s, i3)
      else if i2 == i1 then
        NO_MATCH
      else parseExp(s, i2)
  }

  function parseExp(s: Bytes, i: nat): int
    requires i <= |s|
    decreases |s| - i
  {
    if i < |s| && (s[i] == 'E' || s[i] == 'e') then
      var i1 := if i + 1 < |s| && (s[i+1] == '+' || s[i+1] == '-') then i + 2 else i + 1;
      if i1 > |s| then NO_MATCH
      else
        var i2 := skipDigits(s, i1);
        if i2 == i1 then NO_MATCH else i2
    else i
  }

  function skipDigits(s: Bytes, i: nat): (r: nat)
    requires i <= |s|
    ensures i <= r <= |s|
    ensures forall k :: i <= k < r ==> isDigit(s[k])
    ensures r == |s| || !isDigit(s[r])
    decreases |s| - i
  {
    if i < |s| && isDigit(s[i]) then skipDigits(s, i + 1) else i
  }

  // ----- to_num (ncopy semantics) ----------------------------------------
  // A6.  toNum parses like RSM's ncopy: a leading run of '+'/'-' toggles a
  // sign flag, digits and one '.' are consumed, an optional E exponent is
  // applied, and TRAILING JUNK IS IGNORED.  Leading whitespace ends the
  // parse immediately (so toNum(" 1") = 0).
  //
  // Defined on every Bytes -- that is what makes truthy("1abc") = true.

  function pow10(n: nat): (r: real)
    ensures r > 0.0
  {
    if n == 0 then 1.0 else 10.0 * pow10(n - 1)
  }

  // Integer digits s[i..j) as a non-negative real (mantissa).
  function intValue(s: Bytes, j: nat, i: nat): real
    requires i <= j <= |s|
    decreases j - i
  {
    if i == j then 0.0
    else (if isDigit(s[i]) then (s[i] as int - '0' as int) as real else 0.0)
         * pow10(j - i - 1) + intValue(s, j, i + 1)
  }

  // Integer digits s[i..j) as a non-negative integer (used for exponents).
  function natValue(s: Bytes, j: nat, i: nat): nat
    requires i <= j <= |s|
    decreases j - i
  {
    if i == j then 0
    else (if isDigit(s[i]) then (s[i] as int - '0' as int) else 0)
         * pow10int(j - i - 1) + natValue(s, j, i + 1)
  }

  function pow10int(n: nat): nat
  {
    if n == 0 then 1 else 10 * pow10int(n - 1)
  }

  // Fraction digits s[i..j) as a non-negative real in [0, 1).
  function fracValue(s: Bytes, j: nat, i: nat): real
    requires i <= j <= |s|
    decreases j - i
  {
    if i == j then 0.0
    else (if isDigit(s[i]) then (s[i] as int - '0' as int) as real else 0.0) * 0.1
         + 0.1 * fracValue(s, j, i + 1)
  }

  function signOf(s: Bytes, i: nat, stop: nat): (r: int)
    requires i <= stop <= |s|
    ensures r == 1 || r == -1
    decreases stop - i
  {
    if i == stop then 1
    else if s[i] == '-' then -signOf(s, i + 1, stop)
    else if s[i] == '+' then signOf(s, i + 1, stop)
    else 1
  }

  function signEnd(s: Bytes, i: nat): (r: nat)
    requires i <= |s|
    ensures i <= r <= |s|
    ensures forall k :: i <= k < r ==> s[k] == '+' || s[k] == '-'
    decreases |s| - i
  {
    if i < |s| && (s[i] == '+' || s[i] == '-') then signEnd(s, i + 1) else i
  }

  // toNum: ncopy-style, factored as sign x mantissa x scale.
  //
  // A leading run of '+'/'-' toggles a sign flag, digits and one '.' are
  // consumed, an optional E exponent is applied, and TRAILING JUNK IS
  // IGNORED.  Leading whitespace ends the parse immediately (so
  // toNum(" 1") = 0).  The factorisation makes the zero-ness argument
  // immediate: the scale is always > 0, so toNum == 0 iff the mantissa is.
  function toNum(s: Bytes): real
  {
    var i := signEnd(s, 0);
    signOf(s, 0, i) as real * intValuePlusFrac(s, i) * applyExpScale(s, mantEnd(s, i))
  }

  function applyExp(s: Bytes, k: nat, v: real): real
    requires k <= |s|
  {
    if k < |s| && (s[k] == 'E' || s[k] == 'e') then
      (var i3 := if k + 1 < |s| && (s[k+1] == '+' || s[k+1] == '-') then k + 2 else k + 1;
       var eEnd := skipDigits(s, i3);
       var ev := natValue(s, eEnd, i3);
       var esg := signOf(s, k + 1, i3);
       if esg < 0 then v / pow10(ev) else v * pow10(ev))
    else v
  }

  // ----- truthiness ------------------------------------------------------
  // H2/H3 (rev 2).  truthy(s) <=> toNum(s) != 0.  Equivalent to RSM's
  // cstringtob (runtime/util.c:108):
  //   skip leading '+'/'-', ignore '0', allow one '.', true on the first
  //   '1'-'9', else false.
  // NOT "non-empty string" -- truthy("abc") = false.

  predicate truthy(s: Bytes)
  {
    toNum(s) != 0.0
  }

  // A direct characterisation, used to connect to cstringtob.
  predicate truthyByScan(s: Bytes)
  {
    exists k :: 0 <= k <= |s| && truthyScan(s, k, 0, false)
  }

  predicate truthyScan(s: Bytes, limit: nat, i: nat, seenDot: bool)
    requires i <= limit <= |s|
    decreases limit - i
  {
    if i == limit then false
    else if s[i] == '0' then truthyScan(s, limit, i + 1, seenDot)
    else if s[i] == '.' then (if seenDot then false else truthyScan(s, limit, i + 1, true))
    else if '1' <= s[i] <= '9' then true
    else false
  }

  // Skip the sign run, then apply truthyScan.
  predicate truthyByCStringTob(s: Bytes)
  {
    truthyScan(s, |s|, signEnd(s, 0), false)
  }

  // -- helpers for TruthyByScan -----------------------------------------
  // Both truthy and truthyByCStringTob are equivalent to "the mantissa
  // region contains a digit 1-9", which is hasNZ below.  mantEnd is the
  // end of that region: digits [ '.' digits ], exactly what both the
  // ncopy parser and the cstringtob scanner walk.

  predicate hasNZ(s: Bytes, i: nat, j: nat)
    requires i <= j <= |s|
  {
    exists k :: i <= k < j && '1' <= s[k] <= '9'
  }

  // hasNZ over a split range.  The mid point is excluded (it is a '.').
  lemma HasNZSplit(s: Bytes, i: nat, mid: nat, j: nat)
    requires i <= mid < j <= |s| || i <= mid == j <= |s|
    requires mid < |s| && s[mid] == '.'
    ensures hasNZ(s, i, j) == hasNZ(s, i, mid) || (mid + 1 <= j && hasNZ(s, mid + 1, j))
  {
    if mid == j {
      assert mid + 1 > j;
      assert hasNZ(s, i, j) == hasNZ(s, i, mid);
    } else {
      if hasNZ(s, i, j) {
        var k :| i <= k < j && '1' <= s[k] <= '9';
        if k < mid {
          assert hasNZ(s, i, mid);
        } else if k == mid {
          assert s[k] == '.' && !('1' <= s[k] <= '9');
          assert false;
        } else {
          assert mid + 1 <= k < j;
          assert hasNZ(s, mid + 1, j);
        }
      }
      if hasNZ(s, i, mid) {
        assert hasNZ(s, i, j);
      }
      if mid + 1 <= j && hasNZ(s, mid + 1, j) {
        assert hasNZ(s, i, j);
      }
    }
  }

  function mantEnd(s: Bytes, i: nat): (r: nat)
    requires i <= |s|
    ensures i <= r <= |s|
    ensures forall k :: i <= k < r ==> isDigit(s[k]) || s[k] == '.'
    decreases |s| - i
  {
    var j := skipDigits(s, i);
    if j < |s| && s[j] == '.' then skipDigits(s, j + 1) else j
  }

  // ----- comparison ------------------------------------------------------
  // C1-C7.  ISO 11756 8.3: numeric iff BOTH operands are numeric strings,
  // else bytewise lexicographic.  This is what the ports implement.
  //
  // RSM diverges twice, and inconsistently:
  //   rsm#11a  < > <= >= call ncopy on BOTH sides, so a non-numeric string
  //            coerces to 0 and "a"<"b" is 0.  (run.c:475-507)
  //   rsm#11b  = and '= are a raw memcmp of the evaluated string forms and
  //            never call ncopy, so "1.0"=1 is 0 -- while "1.0"<1 and
  //            "1.0">1 are both 0 too.  Not a total order.  (run.c:457-473)
  //   rsm#11c  for < > the numeric test is ncopy's PREFIX parse, so
  //            "1abc"<2 is numeric (1 < 2).  We use isNum (whole string),
  //            so "1abc"<2 is a string comparison.  ISO, recorded here.

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

  function cmp(a: Bytes, b: Bytes): int
  {
    if isNum(a) && isNum(b) then
      (if toNum(a) < toNum(b) then -1 else if toNum(a) > toNum(b) then 1 else 0)
    else lexCompare(a, b)
  }

  // C24 / T11 / T11b.  ISO 11756 8.3 `=` / `'=`.
  // Same numeric-vs-string rule as cmp, but equality:
  //   both numeric strings  -> toNum(a) == toNum(b)   (non-canonical forms
  //                          "1.0", "1E2", "+1" equal their canonical value)
  //   otherwise             -> bytewise string equality
  // Empty is NOT a numeric string (isNum("") is false), so ""=0 is a string
  // compare and is false -- that is T11 / T11b (peer ISO; RSM empty-output bug).
  function mEq(a: Bytes, b: Bytes): bool
  {
    if isNum(a) && isNum(b) then toNum(a) == toNum(b)
    else a == b
  }

  // ----- key collation ---------------------------------------------------
  // D1-D4.  util/key.c:36 -- "Key is in order: NEGATIVE NUMBER . ZERO .
  // POSITIVE NUMBER . STRING".  Empty sorts before everything and is the
  // $ORDER sentinel only (not storable -- see E2).
  //
  // The byte encoding in UTIL_Key_Build (key.c:36-115) confirms the order:
  // empty -> first byte 0; negatives -> 63-dp + nine's complement; zero ->
  // $C(64); positives -> 64+dp; strings -> 128.

  function coll(a: Bytes, b: Bytes): int
  {
    if a == [] && b == [] then 0
    else if a == [] then -1
    else if b == [] then 1
    else if isNum(a) && isNum(b) then
      (if toNum(a) < toNum(b) then -1 else if toNum(a) > toNum(b) then 1 else 0)
    else if isNum(a) then -1     // D3: every number sorts before every string
    else if isNum(b) then 1
    else lexCompare(a, b)
  }

  // ----- refs and key order ----------------------------------------------
  // E1-E5.  A Ref is (name, subscripts); every subscript is non-empty.
  // keyord compares refs sharing a name: lexicographic on the subscript
  // sequences under coll, shorter-is-prefix-first.

  datatype Ref = Ref(name: Bytes, subs: seq<Bytes>)

  predicate wellFormed(r: Ref)
  {
    |r.name| > 0 && forall i :: 0 <= i < |r.subs| ==> |r.subs[i]| > 0
  }

  function subsOrd(a: seq<Bytes>, b: seq<Bytes>): int
  {
    if a == [] && b == [] then 0
    else if a == [] then -1
    else if b == [] then 1
    else
      (var c := coll(a[0], b[0]);
       if c != 0 then c else subsOrd(a[1..], b[1..]))
  }

  function keyord(a: Ref, b: Ref): int
  {
    if a.name != b.name then lexCompare(a.name, b.name)
    else subsOrd(a.subs, b.subs)
  }

  // ----- store -----------------------------------------------------------
  // E1.  Finite map from Ref to value.

  type Store = map<Ref, Bytes>

  // Prefix: a is a proper prefix of b as a subscript sequence.
  predicate properPrefix(a: seq<Bytes>, b: seq<Bytes>)
  {
    |a| < |b| && forall i :: 0 <= i < |a| ==> a[i] == b[i]
  }

  predicate hasDescendant(st: Store, r: Ref)
  {
    exists q :: q in st && wellFormed(q) && q.name == r.name
                && properPrefix(r.subs, q.subs)
  }

  // ----- $DATA -----------------------------------------------------------
  // F1-F3.  0 / 1 / 10 / 11.

  function data(st: Store, r: Ref): int
    requires wellFormed(r)
  {
    if r in st then (if hasDescendant(st, r) then 11 else 1)
    else if hasDescendant(st, r) then 10
    else 0
  }

  // ----- $ORDER ----------------------------------------------------------
  // G1-G7.  cur is the sentinel when it is [].

  // Subscripts appearing at the level below `prefix` under `name`.
  // Ranged over the finite domain of st so the comprehension is bounded.
  function siblings(st: Store, prefix: seq<Bytes>, name: Bytes): set<Bytes>
  {
    set q <- st.Keys
       | wellFormed(q) && q.name == name
         && |q.subs| == |prefix| + 1
         && (forall i :: 0 <= i < |prefix| ==> q.subs[i] == prefix[i])
         && |q.subs[|prefix|]| > 0
       :: q.subs[|prefix|]
  }

  predicate isMin(S: set<Bytes>, s: Bytes)
  {
    s in S && forall t :: t in S ==> coll(s, t) <= 0
  }

  predicate isMax(S: set<Bytes>, s: Bytes)
  {
    s in S && forall t :: t in S ==> coll(s, t) >= 0
  }

  // ----- arithmetic coercion ---------------------------------------------
  // J1-J4.  + - * / # ** coerce both sides via toNum (ncopy), non-numeric
  // -> 0 which is toNum's own value on a non-numeric string.
  // J2: / is real division.  J3: # is FLOORED (sign follows the divisor),
  //     NOT truncated toward zero.
  //
  // RSM's # is confirmed floored by runtime_div with OPMOD
  // (math.c:803-816, 1147-1163) and live: -7#3 = 2, 7#-3 = -2.
  //
  // J5: division by zero is a FAULT (RSM raises ERRM9), not a value.

  // Floor as an uninterpreted mathematical function: the greatest integer
  // not exceeding x.  Specified, not implemented -- the ports implement it
  // with a C cast and a negative correction.
  function {:axiom} floorR(x: real): (n: int)
    ensures (n as real) <= x < (n as real) + 1.0

  function mMod(a: Bytes, b: Bytes): real
    requires toNum(b) != 0.0     // J5: fault otherwise
  {
    toNum(a) - toNum(b) * (floorR(toNum(a) / toNum(b)) as real)
  }

  function mAdd(a: Bytes, b: Bytes): real  { toNum(a) + toNum(b) }
  function mSub(a: Bytes, b: Bytes): real  { toNum(a) - toNum(b) }
  function mMul(a: Bytes, b: Bytes): real  { toNum(a) * toNum(b) }

  function mDiv(a: Bytes, b: Bytes): real
    requires toNum(b) != 0.0     // J5: fault otherwise
  { toNum(a) / toNum(b) }

  // =======================================================================
  // Proofs
  // =======================================================================

  // -- truthy agrees with the cstringtob scan ----------------------------
  //
  // The claim:  toNum(s) != 0  <=>  the cstringtob scan sees a '1'-'9'.
  // Both sides are characterised by hasNZ over the mantissa region
  // [signEnd, mantEnd) -- the region the ncopy parser and the scanner
  // both walk (digits, then at most one '.' plus digits).  The exponent
  // cannot rescue a zero mantissa, so it does not appear in the region.

  // intValue over an all-digit run is 0 iff every digit is '0'.
  lemma IntValueZero(s: Bytes, j: nat, i: nat)
    requires i <= j <= |s|
    requires forall k :: i <= k < j ==> isDigit(s[k])
    ensures intValue(s, j, i) == 0.0 <==> forall k :: i <= k < j ==> s[k] == '0'
    decreases j - i
  {
    if i == j {
    } else {
      assert intValue(s, j, i)
             == (if isDigit(s[i]) then (s[i] as int - '0' as int) as real else 0.0)
                * pow10(j - i - 1) + intValue(s, j, i + 1);
      IntValueZero(s, j, i + 1);
      IntValueNonNeg(s, j, i + 1);
      if s[i] == '0' {
        assert (s[i] as int - '0' as int) == 0;
        assert intValue(s, j, i) == intValue(s, j, i + 1);
      } else {
        assert '1' <= s[i] <= '9';
        var d := (s[i] as int - '0' as int) as real;
        assert d >= 1.0;
        var p := pow10(j - i - 1);
        assert p > 0.0;
        assert d * p > 0.0;
        IntValueNonNeg(s, j, i + 1);
        assert intValue(s, j, i) == d * p + intValue(s, j, i + 1);
        assert intValue(s, j, i) > 0.0;
      }
    }
  }

  // fracValue likewise.
  lemma FracValueZero(s: Bytes, j: nat, i: nat)
    requires i <= j <= |s|
    requires forall k :: i <= k < j ==> isDigit(s[k])
    ensures fracValue(s, j, i) == 0.0 <==> forall k :: i <= k < j ==> s[k] == '0'
    decreases j - i
  {
    if i == j {
    } else {
      assert fracValue(s, j, i)
             == (if isDigit(s[i]) then (s[i] as int - '0' as int) as real else 0.0) * 0.1
                + 0.1 * fracValue(s, j, i + 1);
      FracValueZero(s, j, i + 1);
      FracValueNonNeg(s, j, i + 1);
      if s[i] == '0' {
        assert (s[i] as int - '0' as int) == 0;
        assert fracValue(s, j, i) == 0.1 * fracValue(s, j, i + 1);
      } else {
        assert '1' <= s[i] <= '9';
        assert (s[i] as int - '0' as int) >= 1;
        assert fracValue(s, j, i) >= 0.1 > 0.0;
      }
    }
  }

  // intValue and fracValue are never negative.
  lemma IntValueNonNeg(s: Bytes, j: nat, i: nat)
    requires i <= j <= |s|
    ensures intValue(s, j, i) >= 0.0
    decreases j - i
  {
    if i < j {
      IntValueNonNeg(s, j, i + 1);
    }
  }

  lemma FracValueNonNeg(s: Bytes, j: nat, i: nat)
    requires i <= j <= |s|
    ensures fracValue(s, j, i) >= 0.0
    decreases j - i
  {
    if i < j {
      FracValueNonNeg(s, j, i + 1);
    }
  }

  // The mantissa region contains a 1-9 iff its numeric value is non-zero.
  lemma MantissaNonZero(s: Bytes, i: nat)
    requires i <= |s|
    ensures hasNZ(s, i, mantEnd(s, i))
            <==> (intValuePlusFrac(s, i) != 0.0)
    decreases |s| - i
  {
    var j := skipDigits(s, i);
    var e := mantEnd(s, i);
    IntValueNonNeg(s, j, i);
    if j < |s| && s[j] == '.' {
      // region is [i, j) '.' [j+1, e)
      assert e == skipDigits(s, j + 1);
      assert i <= j <= e <= |s|;
      assert s[j] == '.';
      IntValueZero(s, j, i);
      FracValueZero(s, e, j + 1);
      FracValueNonNeg(s, e, j + 1);
      HasNZSplit(s, i, j, e);
      assert intValuePlusFrac(s, i) == intValue(s, j, i) + fracValue(s, e, j + 1);
      // sum is 0 iff both are 0 (both >= 0)
      if intValue(s, j, i) == 0.0 && fracValue(s, e, j + 1) == 0.0 {
        assert intValuePlusFrac(s, i) == 0.0;
      }
      if intValuePlusFrac(s, i) == 0.0 {
        assert intValue(s, j, i) == 0.0 && fracValue(s, e, j + 1) == 0.0;
      }
    } else {
      assert e == j;
      IntValueZero(s, j, i);
      assert intValuePlusFrac(s, i) == intValue(s, j, i);
    }
  }

  // The value of the mantissa: integer part + fraction.  Isolated so
  // MantissaNonZero can talk about it.
  function intValuePlusFrac(s: Bytes, i: nat): real
    requires i <= |s|
  {
    var j := skipDigits(s, i);
    var ip := intValue(s, j, i);
    if j < |s| && s[j] == '.' then
      (var k := skipDigits(s, j + 1);
       ip + fracValue(s, k, j + 1))
    else ip
  }

  // The scan sees a 1-9 iff the mantissa region has one.
  lemma ScanSeesNZ(s: Bytes, i: nat)
    requires i <= |s|
    ensures truthyScan(s, |s|, i, false) == hasNZ(s, i, mantEnd(s, i))
    decreases |s| - i
  {
    var e := mantEnd(s, i);
    if i == |s| {
    } else if s[i] == '0' {
      // skipping a zero: the region shifts by one
      assert mantEnd(s, i) == mantEnd(s, i + 1) || (s[i] == '0' && i == e);
      ScanSeesNZ(s, i + 1);
    } else if s[i] == '.' {
      // first dot: continue with seenDot = true, which forbids a second
      ScanAfterDot(s, i + 1);
    } else if '1' <= s[i] <= '9' {
      // found one immediately; i < e
      assert hasNZ(s, i, e);
    } else {
      // stop character: the region is empty
      assert e == i;
    }
  }

  // After the first dot the scan forbids a second; it matches the
  // fraction digits of the mantissa region.
  lemma ScanAfterDot(s: Bytes, i: nat)
    requires i <= |s|
    ensures truthyScan(s, |s|, i, true) == hasNZ(s, i, skipDigits(s, i))
    decreases |s| - i
  {
    var e := skipDigits(s, i);
    if i == |s| {
    } else if s[i] == '0' {
      ScanAfterDot(s, i + 1);
    } else if s[i] == '.' {
      // second dot: the scan stops here
      assert e == i;
    } else if '1' <= s[i] <= '9' {
      assert hasNZ(s, i, e);
    } else {
      assert e == i;
    }
  }

  // applyExp is just a multiplication by a positive scale factor.
  lemma ApplyExpFactor(s: Bytes, k: nat, v: real)
    requires k <= |s|
    ensures applyExp(s, k, v) == v * applyExpScale(s, k)
    ensures applyExpScale(s, k) > 0.0
  {
    if k < |s| && (s[k] == 'E' || s[k] == 'e') {
      var i3 := if k + 1 < |s| && (s[k+1] == '+' || s[k+1] == '-') then k + 2 else k + 1;
      var eEnd := skipDigits(s, i3);
      var ev := natValue(s, eEnd, i3);
      var esg := signOf(s, k + 1, i3);
      if esg < 0 {
        assert applyExp(s, k, v) == v / pow10(ev);
        assert applyExpScale(s, k) == 1.0 / pow10(ev);
        assert pow10(ev) > 0.0;
        assert 1.0 / pow10(ev) > 0.0;
        assert v / pow10(ev) == v * (1.0 / pow10(ev));
      } else {
        assert applyExp(s, k, v) == v * pow10(ev);
        assert applyExpScale(s, k) == pow10(ev);
        assert pow10(ev) > 0.0;
      }
    } else {
      assert applyExp(s, k, v) == v;
      assert applyExpScale(s, k) == 1.0;
    }
  }

  // toNum is non-zero iff the mantissa has a 1-9.  toNum is defined as
  // sign x mantissa x scale with scale > 0, so zero-ness is exactly the
  // mantissa's.
  lemma ToNumNonZero(s: Bytes)
    ensures toNum(s) != 0.0
            <==> hasNZ(s, signEnd(s, 0), mantEnd(s, signEnd(s, 0)))
  {
    var i := signEnd(s, 0);
    MantissaNonZero(s, i);
    var sg := signOf(s, 0, i) as real;
    var m := intValuePlusFrac(s, i);
    var scale := applyExpScale(s, mantEnd(s, i));
    assert scale > 0.0;
    assert sg == 1.0 || sg == -1.0;
    assert toNum(s) == sg * m * scale;
    // sign is +/-1, scale > 0, so the product is 0 iff the mantissa is
    if m != 0.0 {
      assert sg * m != 0.0;
      assert (sg * m) * scale != 0.0;
    }
    if toNum(s) != 0.0 {
      assert m != 0.0;
    }
  }

  // The scale factor applyExp contributes: a power of ten, or 1.  Always
  // > 0 (pow10 is), so it cannot create or destroy zero.
  function applyExpScale(s: Bytes, k: nat): real
    requires k <= |s|
    ensures applyExpScale(s, k) > 0.0
  {
    if k < |s| && (s[k] == 'E' || s[k] == 'e') then
      (var i3 := if k + 1 < |s| && (s[k+1] == '+' || s[k+1] == '-') then k + 2 else k + 1;
       var eEnd := skipDigits(s, i3);
       var ev := natValue(s, eEnd, i3);
       var esg := signOf(s, k + 1, i3);
       if esg < 0 then 1.0 / pow10(ev) else pow10(ev))
    else 1.0
  }

  lemma TruthyByScan(s: Bytes)
    ensures truthy(s) <==> truthyByCStringTob(s)
  {
    ScanSeesNZ(s, signEnd(s, 0));
    ToNumNonZero(s);
  }

  // -- coll is a strict total order on non-empty subscripts --------------

  lemma LexIrreflexive(a: Bytes)
    ensures lexCompare(a, a) == 0
  {
    LexIrreflexiveFrom(a, 0);
  }

  lemma LexIrreflexiveFrom(a: Bytes, i: nat)
    requires i <= |a|
    ensures lexCompareFrom(a, a, i) == 0
    decreases |a| - i
  {
    if i == |a| {
    } else {
      LexIrreflexiveFrom(a, i + 1);
    }
  }

  lemma CollIrreflexive(a: Bytes)
    requires |a| > 0
    ensures coll(a, a) == 0
  {
    if isNum(a) {
      // toNum(a) < toNum(a) is false and toNum(a) > toNum(a) is false
    } else {
      LexIrreflexive(a);
    }
  }

  lemma CollAntisymmetric(a: Bytes, b: Bytes)
    requires |a| > 0 && |b| > 0
    ensures coll(a, b) == -coll(b, a)
  {
    if isNum(a) && isNum(b) {
      // numeric compare is antisymmetric
    } else if isNum(a) {
      // number before string
    } else if isNum(b) {
      // string after number
    } else {
      // lexicographic is antisymmetric
      LexAntisymmetric(a, b);
    }
  }

  lemma LexAntisymmetric(a: Bytes, b: Bytes)
    ensures lexCompare(a, b) == -lexCompare(b, a)
  {
    LexAntisymmetricFrom(a, b, 0);
  }

  lemma LexAntisymmetricFrom(a: Bytes, b: Bytes, i: nat)
    requires i <= |a| && i <= |b|
    ensures lexCompareFrom(a, b, i) == -lexCompareFrom(b, a, i)
    decreases |a| - i
  {
    if i == |a| && i == |b| {
    } else if i == |a| {
    } else if i == |b| {
    } else if a[i] as int < b[i] as int {
    } else if a[i] as int > b[i] as int {
    } else {
      LexAntisymmetricFrom(a, b, i + 1);
    }
  }

  lemma CollTransitive(a: Bytes, b: Bytes, c: Bytes)
    requires |a| > 0 && |b| > 0 && |c| > 0
    requires coll(a, b) < 0 && coll(b, c) < 0
    ensures coll(a, c) < 0
  {
    if isNum(a) && isNum(b) && isNum(c) {
      // numeric order is transitive
    } else {
      // mixed: numbers sort before strings, so the only way to have
      // a < b < c across the boundary is a numeric and c a string, or
      // all three on one side.  Check the cases.
      if isNum(a) && !isNum(c) {
        // number < string
      } else if !isNum(a) && isNum(c) {
        // impossible: a string cannot be < a number and that number < a string
        assert coll(a, c) >= 0;
        assert false;
      } else if isNum(a) && isNum(c) && !isNum(b) {
        // a numeric < b string is impossible
        assert false;
      } else if !isNum(a) && !isNum(c) && isNum(b) {
        // a string < b numeric is impossible
        assert false;
      } else {
        LexTransitive(a, b, c);
      }
    }
  }

  lemma LexTransitive(a: Bytes, b: Bytes, c: Bytes)
    requires lexCompare(a, b) < 0 && lexCompare(b, c) < 0
    ensures lexCompare(a, c) < 0
  {
    LexTransitiveFrom(a, b, c, 0);
  }

  lemma LexEqualChar(a: Bytes, b: Bytes, i: nat)
    requires i < |a| && i < |b| && a[i] == b[i]
    ensures lexCompareFrom(a, b, i) == lexCompareFrom(a, b, i + 1)
    decreases |a| - i
  {
    if i + 1 == |a| && i + 1 == |b| {
    } else if i + 1 == |a| {
    } else if i + 1 == |b| {
    } else if a[i+1] as int < b[i+1] as int {
    } else if a[i+1] as int > b[i+1] as int {
    } else {
      LexEqualChar(a, b, i + 1);
    }
  }

  lemma LexTransitiveFrom(a: Bytes, b: Bytes, c: Bytes, i: nat)
    requires i <= |a| && i <= |b| && i <= |c|
    requires lexCompareFrom(a, b, i) < 0 && lexCompareFrom(b, c, i) < 0
    ensures lexCompareFrom(a, c, i) < 0
    decreases |a| - i
  {
    if i == |a| && i == |b| {
    } else if i == |a| {
    } else if i == |b| {
    } else if a[i] as int < b[i] as int {
    } else if a[i] as int > b[i] as int {
    } else {
      // a[i] == b[i]; case on b[i] vs c[i]
      assert a[i] == b[i];
      if b[i] as int < c[i] as int {
        // a[i] == b[i] < c[i], so a < c at this position
      } else if b[i] as int > c[i] as int {
        // contradicts lexCompareFrom(b, c, i) < 0
      } else {
        assert b[i] == c[i];
        LexEqualChar(a, b, i);
        LexEqualChar(b, c, i);
        LexTransitiveFrom(a, b, c, i + 1);
      }
    }
  }

  // coll is a total preorder on byte strings, and a strict total order on
  // numeric VALUES.  It is NOT antisymmetric on string equality: coll
  // ("1.0","1") == 0 because both parse to 1.0, but "1.0" != "1".  The
  // equivalence classes are the numeric values.
  lemma CollTotal(a: Bytes, b: Bytes)
    requires |a| > 0 && |b| > 0
    ensures coll(a, b) == -coll(b, a)
    ensures coll(a, b) < 0 || coll(a, b) == 0 || coll(a, b) > 0
  {
    CollAntisymmetric(a, b);
  }

  // The min/max of a non-empty set is unique as a coll-equivalence class.
  // Byte-string uniqueness would be false ({"1.0","1"} has two minima that
  // are coll-equivalent); what $ORDER needs is that any two minima are
  // coll-equivalent, and $ORDER returns one of them.
  lemma OrderMinUnique(S: set<Bytes>)
    ensures forall s, t :: isMin(S, s) && isMin(S, t) ==> coll(s, t) == 0
  {
    forall s, t | isMin(S, s) && isMin(S, t)
      ensures coll(s, t) == 0
    {
      if |s| > 0 && |t| > 0 {
        CollAntisymmetric(s, t);
      } else {
        // empty subscript is the sentinel; coll handles it by definition
      }
      if coll(s, t) < 0 {
        assert s in S;
        assert coll(t, s) > 0;
        assert !(forall u :: u in S ==> coll(t, u) <= 0);
        assert !isMin(S, t);
      } else if coll(t, s) < 0 {
        assert t in S;
        assert coll(s, t) > 0;
        assert !(forall u :: u in S ==> coll(s, u) <= 0);
        assert !isMin(S, s);
      }
    }
  }

  lemma OrderMaxUnique(S: set<Bytes>)
    ensures forall s, t :: isMax(S, s) && isMax(S, t) ==> coll(s, t) == 0
  {
    forall s, t | isMax(S, s) && isMax(S, t)
      ensures coll(s, t) == 0
    {
      if |s| > 0 && |t| > 0 {
        CollAntisymmetric(s, t);
      }
      if coll(s, t) > 0 {
        assert s in S;
        assert coll(t, s) < 0;
        assert !(forall u :: u in S ==> coll(t, u) >= 0);
        assert !isMax(S, t);
      } else if coll(t, s) > 0 {
        assert t in S;
        assert coll(s, t) < 0;
        assert !(forall u :: u in S ==> coll(s, u) >= 0);
        assert !isMax(S, s);
      }
    }
  }

  // -- keyord is a strict total order on refs under one name -------------

  lemma SubsOrdPrefixFirst(a: seq<Bytes>, b: seq<Bytes>)
    requires |a| < |b|
    requires forall i :: 0 <= i < |a| ==> a[i] == b[i]
    ensures subsOrd(a, b) < 0
  {
    if a == [] {
    } else {
      // a[0] == b[0], so coll(a[0], b[0]) == 0 and we compare the tails
      assert a[0] == b[0];
      if a[0] == [] {
        assert coll(a[0], b[0]) == 0;
      } else {
        CollIrreflexive(a[0]);
        assert coll(a[0], b[0]) == 0;
      }
      SubsOrdPrefixFirst(a[1..], b[1..]);
    }
  }

  lemma KeyordPrefixFirst(a: Ref, b: Ref)
    requires a.name == b.name
    requires properPrefix(a.subs, b.subs)
    ensures keyord(a, b) < 0
  {
    SubsOrdPrefixFirst(a.subs, b.subs);
  }

  // -- collation extras (2026-10-10) ------------------------------------

  // D2: empty subscript sorts before every non-empty subscript.
  lemma CollEmptyFirst(b: Bytes)
    requires |b| > 0
    ensures coll([], b) < 0
  {
  }

  lemma CollEmptyLast(b: Bytes)
    requires |b| > 0
    ensures coll(b, []) > 0
  {
  }

  // D3: every number sorts before every string (class partition).
  lemma CollNumBeforeString(a: Bytes, b: Bytes)
    requires |a| > 0 && |b| > 0
    requires isNum(a) && !isNum(b)
    ensures coll(a, b) < 0
  {
  }

  lemma CollStringAfterNum(a: Bytes, b: Bytes)
    requires |a| > 0 && |b| > 0
    requires !isNum(a) && isNum(b)
    ensures coll(a, b) > 0
  {
  }

  // Numeric equivalence class: equal values collate equal even if
  // byte strings differ ("1.0" vs "1").
  lemma CollNumEqIfToNumEq(a: Bytes, b: Bytes)
    requires |a| > 0 && |b| > 0
    requires isNum(a) && isNum(b)
    requires toNum(a) == toNum(b)
    ensures coll(a, b) == 0
  {
  }

  lemma CollNumOrder(a: Bytes, b: Bytes)
    requires |a| > 0 && |b| > 0
    requires isNum(a) && isNum(b)
    requires toNum(a) < toNum(b)
    ensures coll(a, b) < 0
  {
  }

  // -- subsOrd / keyord total order --------------------------------------

  lemma SubsOrdIrreflexive(a: seq<Bytes>)
    ensures subsOrd(a, a) == 0
    decreases |a|
  {
    if a == [] {
    } else {
      if a[0] == [] {
      } else {
        CollIrreflexive(a[0]);
      }
      SubsOrdIrreflexive(a[1..]);
    }
  }

  lemma SubsOrdAntisymmetric(a: seq<Bytes>, b: seq<Bytes>)
    ensures subsOrd(a, b) == -subsOrd(b, a)
    decreases |a| + |b|
  {
    if a == [] && b == [] {
    } else if a == [] {
    } else if b == [] {
    } else {
      if a[0] == [] || b[0] == [] {
        // empty head: coll is defined by the empty cases
        SubsOrdAntisymmetric(a[1..], b[1..]);
      } else {
        CollAntisymmetric(a[0], b[0]);
        var c := coll(a[0], b[0]);
        if c != 0 {
        } else {
          CollIrreflexive(a[0]);
          SubsOrdAntisymmetric(a[1..], b[1..]);
        }
      }
    }
  }

  // (SubsOrdTransitive left unproven: needs a stronger coll-case split.
  //  OrderMinUnique + CollTotal already give $ORDER uniqueness.)

  lemma KeyordIrreflexive(a: Ref)
    ensures keyord(a, a) == 0
  {
    LexIrreflexive(a.name);
    SubsOrdIrreflexive(a.subs);
  }

  // -- $ORDER / siblings -----------------------------------------------

  // E1: well-formed subscripts are non-empty, so empty never appears as a
  // stored sibling subscript.
  lemma SiblingsNonEmpty(st: Store, prefix: seq<Bytes>, name: Bytes)
    ensures forall t :: t in siblings(st, prefix, name) ==> |t| > 0
  {
  }

  // Forward $ORDER from the empty sentinel yields the minimum sibling.
  lemma OrderFromEmptyIsMin(st: Store, r: Ref)
    requires wellFormed(r) && |r.subs| > 0
    requires r.subs[|r.subs| - 1] == []
    ensures order(st, r, 1) == (if siblings(st, r.subs[..|r.subs|-1], r.name) == {}
                                 then NoMore
                                 else Found(minOf(siblings(st, r.subs[..|r.subs|-1], r.name))))
  {
  }

  // If $ORDER forward finds a successor, it is strictly after cur in coll
  // (or cur was the empty sentinel and the successor is the min).
  lemma OrderForwardAfterCur(st: Store, r: Ref, t: Bytes)
    requires wellFormed(r) && |r.subs| > 0
    requires order(st, r, 1) == Found(t)
    requires r.subs[|r.subs| - 1] != []
    ensures coll(t, r.subs[|r.subs| - 1]) > 0
  {
  }

  // -- keyord extras ----------------------------------------------------

  lemma KeyordTotal(a: Ref, b: Ref)
    requires a.name == b.name
    ensures keyord(a, b) == -keyord(b, a)
    ensures keyord(a, b) < 0 || keyord(a, b) == 0 || keyord(a, b) > 0
  {
    SubsOrdAntisymmetric(a.subs, b.subs);
  }

  // -- $ORDER is well defined --------------------------------------------
  //
  // The successor is unique because coll is a strict total order, so any
  // min/max witness is the min/max.  minOf/maxOf are uninterpreted choice
  // functions with the defining property; uniqueness is OrderMinUnique /
  // OrderMaxUnique below.

  function {:axiom} minOf(S: set<Bytes>): (s: Bytes)
    requires S != {}
    ensures s in S && forall t :: t in S ==> coll(s, t) <= 0

  function {:axiom} maxOf(S: set<Bytes>): (s: Bytes)
    requires S != {}
    ensures s in S && forall t :: t in S ==> coll(s, t) >= 0

  // $ORDER as a relation: result is the unique min/max successor, or None.
  datatype OrderResult = NoMore | Found(s: Bytes)

  function order(st: Store, r: Ref, dir: int): OrderResult
    requires wellFormed(r) && |r.subs| > 0
  {
    var prefix := r.subs[..|r.subs| - 1];
    var cur := r.subs[|r.subs| - 1];
    var S := siblings(st, prefix, r.name);
    if dir > 0 then
      (if cur == [] then
         (if S == {} then NoMore else Found(minOf(S)))
       else
         (var cand := set t | t in S && coll(t, cur) > 0;
          if cand == {} then NoMore else Found(minOf(cand))))
    else
      (if cur == [] then
         (if S == {} then NoMore else Found(maxOf(S)))
       else
         (var cand := set t | t in S && coll(t, cur) < 0;
          if cand == {} then NoMore else Found(maxOf(cand))))
  }

  // -- $DATA's four cases partition --------------------------------------

  lemma DataPartitions(st: Store, r: Ref)
    requires wellFormed(r)
    ensures 0 <= data(st, r) <= 11
    ensures data(st, r) == 0 || data(st, r) == 1
            || data(st, r) == 10 || data(st, r) == 11
    ensures data(st, r) == 11 <==> r in st && hasDescendant(st, r)
    ensures data(st, r) == 1  <==> r in st && !hasDescendant(st, r)
    ensures data(st, r) == 10 <==> r !in st && hasDescendant(st, r)
    ensures data(st, r) == 0  <==> r !in st && !hasDescendant(st, r)
  { }

  // -- prefix lemma ------------------------------------------------------
  // keyord(K, K') < 0 whenever K is a proper prefix of K'.  This is what
  // makes F1's "descendant" test equivalent to "some key strictly greater
  // with this prefix".

  lemma DescendantImpliesKeyord(r: Ref, q: Ref)
    requires wellFormed(r) && wellFormed(q)
    requires q.name == r.name && properPrefix(r.subs, q.subs)
    ensures keyord(r, q) < 0
  {
    KeyordPrefixFirst(r, q);
  }

  // -- mstr round-trip ---------------------------------------------------
  // B1/B3.  mstr is specified by its properties, not implemented: M number
  // formatting (canonic form, the `.5` leading-zero drop, precision) is a
  // separate, lower-risk component.  An uninterpreted function whose
  // `ensures` are the contract.  Injectivity is stated separately so it is
  // not a self-referential ensures.

  function {:axiom} mstr(x: real): (r: Bytes)
    ensures toNum(r) == x                                       // B1
    ensures x == 0.0 ==> r == ['0']                             // B2
    // B3: integer part 0 and a non-zero fraction drops the leading '0' of
    // the fraction, then prefixes '-' iff x < 0.
    ensures 0.0 < x < 1.0 ==> |r| >= 1 && r[0] == '.'
    ensures -1.0 < x < 0.0 ==> |r| >= 2 && r[0] == '-' && r[1] == '.'

  // B5: mstr is injective.  Immediate from B1 (the round-trip
  // toNum(mstr(x)) == x): if mstr(x) == mstr(y) then
  //   x = toNum(mstr(x)) = toNum(mstr(y)) = y.
  lemma MstrInjective(x: real, y: real)
    ensures mstr(x) == mstr(y) ==> x == y
  {
    if mstr(x) == mstr(y) {
      assert toNum(mstr(x)) == x;
      assert toNum(mstr(y)) == y;
    }
  }

  // -- corpus miss proofs: C24, C16, T11, T11b ---------------------------
  // Peer ISO rule (Py/C3/Jv/mJVM).  RSM expecteds disagree; that is why
  // these eight show as MISS/DIVERGES on the shared corpus.

  // C24.eq-noncanonical — non-canonical numeric strings equal their value.
  lemma C24NonCanonicalEq()
    ensures mEq("1.0", "1")
    ensures mEq("1E2", "100")
    ensures mEq("+1", "1")
  {
    assert isNum("1.0") && isNum("1");
    assert isNum("1E2") && isNum("100");
    assert isNum("+1") && isNum("1");
    // toNum is the ncopy-style parse; these are the C24 fixtures
    assert toNum("1.0") == toNum("1");
    assert toNum("1E2") == toNum("100");
    assert toNum("+1") == toNum("1");
  }

  // C16.str-compare — non-numeric operands use string order; case-sensitive.
  lemma C16StringCompare()
    ensures cmp("a", "b") == -1
    ensures cmp("b", "a") == 1
    ensures !mEq("a", "A")
  {
    assert !isNum("a") && !isNum("b") && !isNum("A");
    assert lexCompare("a", "b") == -1;
    assert lexCompare("b", "a") == 1;
  }

  // T11.empty-vs-zero — "" is not a numeric string, so ""=0 is string eq.
  lemma T11EmptyNotZero()
    ensures !isNum([])
    ensures !mEq([], "0")
    ensures !mEq("", "0")
  {
    assert parseNum([], 0) == NO_MATCH;
    assert !mEq([], "0");
  }

  // T11b.zero-vs-empty — equality is symmetric.
  lemma T11bZeroNotEmpty()
    ensures !mEq("0", [])
    ensures !mEq("0", "")
  {
    T11EmptyNotZero();
    assert !mEq("0", []);
  }

  // T11d.cmp-operators — relational opcodes follow cmp / mEq.
  // Peers: ("a"<"b")=1 ("a"="a")=1 ("b">"a")=1 (1<2)=1 (1=2)=0
  // RSM ncopy makes "a"<"b" numeric 0<0 (lt=0); that is the upstream miss.
  lemma T11dRelationalOps()
    ensures cmp("a", "b") == -1
    ensures mEq("a", "a")
    ensures cmp("b", "a") == 1
    ensures cmp("1", "2") == -1
    ensures !mEq("1", "2")
    ensures cmp("2", "1") == 1
    ensures mEq("2", "2")
  {
    assert !isNum("a") && !isNum("b");
    assert isNum("1") && isNum("2");
    assert toNum("1") == 1.0 && toNum("2") == 2.0;
    assert lexCompare("a", "b") == -1;
    assert lexCompare("b", "a") == 1;
    assert toNum("1") < toNum("2");
    assert toNum("2") > toNum("1");
  }

  // T12 / T12b.  ISO 7.2.4 ELSE.
  // Minimal IF/ELSE statement model: false test takes the ELSE arm; a nested
  // IF in the ELSE arm is exactly "ELSE binds to the innermost / next IF".
  datatype Stmt =
    | W(tag: string)
    | If(test: bool, thn: Stmt, els: Stmt)

  function run(s: Stmt): seq<string>
  {
    match s
    case W(tag) => [tag]
    case If(test, thn, els) => if test then run(thn) else run(els)
  }

  // T12.ELSE-binding: S X=0 I X=1 W "THEN",! E  W "ELSE",!  → "ELSE"
  lemma T12ElseBinding()
    ensures run(If(false, W("THEN"), W("ELSE"))) == ["ELSE"]
    ensures run(If(true, W("THEN"), W("ELSE"))) == ["THEN"]
  { }

  // T12b.ELSE-chain: S X=2 I X=1 W "a",! E  I X=2 W "b",! E  W "c",!
  // false outer IF → ELSE arm = nested IF; that nested IF's truth picks "b".
  lemma T12bElseChain()
    ensures run(If(false, W("a"), If(true, W("b"), W("c")))) == ["b"]
    ensures run(If(false, W("a"), If(false, W("b"), W("c")))) == ["c"]
  { }

  // T15.tlevel.  ISO 6.3.20: $TLEVEL is defined; outside a transaction it is 0.
  // RSM raises "Undefined special variable" (upstream miss).  Peers print TLEVEL=0.
  function tlevel(inTransaction: bool): int
  {
    if inTransaction then 1 else 0
  }

  lemma T15TlevelOutsideTX()
    ensures tlevel(false) == 0
    ensures tlevel(true) == 1
  { }

  // -- recorded RSM divergences ------------------------------------------
  //
  // rsm#11a  "a"<"b" == 0 in RSM (both ncopy'd to 0).  We say -1.
  // rsm#11b  "1.0"=1 == 0 in RSM (memcmp).  We say 0 is wrong: cmp = 0.
  //          RSM also says "1.0"<1 == 0 and "1.0">1 == 0, so its '=' is
  //          not order-consistent with its '<' and '>'.
  // rsm#11c  "1abc"<2 is numeric in RSM (ncopy prefix).  We say it is a
  //          string comparison (isNum is whole-string).
  // rsm#12   ELSE never runs in RSM when $TEST is 0.  ISO 7.2.4 says it
  //          does; we specify the ISO rule.
  // rsm#15   $TLEVEL/$TRESTART are "Undefined special variable" in RSM.
  //          ISO 6.3.20/21 says 0 outside a transaction.

  predicate rsm11a() { cmp(['a'], ['b']) == -1 }      // RSM says 0
  predicate rsm11b() { cmp("1.0", "1") == 0 }         // RSM says non-equal
  predicate rsm11c() { !isNum("1abc") }               // RSM treats as 1

  lemma DivergencesHold()
    ensures rsm11a() && rsm11b() && rsm11c()
  { }

}
