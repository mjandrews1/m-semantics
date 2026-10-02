// ---------------------------------------------------------------------------
// MPattern -- M pattern matching (`expr ? pattern`).
//
// Companion to MSemantics.  Patterns were out of scope there; this module
// covers them so the ports' matchers have a formal statement.
//
// Grammar grounded in RSM's runtime/pattern.c and confirmed against a
// live RSM (V1.83.1):
//
//   atom   := count? ( class+ | '"' literal '"' )
//   count  := n | n.m | n. | .m | .        (default 1; . = 0..255)
//   class  := [A-Za-z]  -- A C E L N P U
//
// Several class letters in one atom are ALTERNATION: a character matches
// the atom if it matches ANY of the letters.  So `1AN` is "one
// alphanumeric" (A or N).  Verified live:
//   "x"?1AN = 1, "1"?1AN = 1, "!"?1AN = 0
//   "a"?1AP = 1, "!"?1AP = 1, "5"?1AP = 0
//
// A match must consume the whole string.
//
// This is the same matcher PyMumps (match_pattern) and C3Mumps
// (src/pattern.c3) implement.  The two ports' matchers are the
// executable form of the definition below.
// ---------------------------------------------------------------------------

module MPattern {

  type Bytes = seq<char>

  // -- character classes -------------------------------------------------
  // A alpha, C control, E any, L lower, N digit, P punct-or-space, U upper.

  predicate isAlpha(c: char) { ('a' <= c <= 'z') || ('A' <= c <= 'Z') }
  predicate isDigit(c: char) { '0' <= c <= '9' }
  predicate isLower(c: char) { 'a' <= c <= 'z' }
  predicate isUpper(c: char) { 'A' <= c <= 'Z' }
  predicate isCtrl(c: char)  { c < ' ' }
  predicate isPunct(c: char)
  {
    c == ' ' || !(isAlpha(c) || isDigit(c) || c == '_')
  }

  // A single class letter is a predicate on characters.
  predicate classOf(c: char, code: char)
  {
    (code == 'a' ==> isAlpha(c))
    && (code == 'c' ==> isCtrl(c))
    && (code == 'e' ==> true)
    && (code == 'l' ==> isLower(c))
    && (code == 'n' ==> isDigit(c))
    && (code == 'p' ==> isPunct(c))
    && (code == 'u' ==> isUpper(c))
  }

  // -- pattern atoms -----------------------------------------------------

  datatype PatKind = CLS | LIT | NOTCLS

  datatype Atom = Atom(lo: nat, hi: nat, kind: PatKind, body: Bytes)

  predicate wellCounted(a: Atom) { a.lo <= a.hi }

  // One character matches an atom's body under alternation: ANY of the
  // class letters suffices.  NOTCLS is the negation of that.
  predicate charMatchesBody(c: char, a: Atom)
  {
    if a.kind == NOTCLS then
      !(exists j :: 0 <= j < |a.body| && classOf(c, a.body[j]))
    else
      exists j :: 0 <= j < |a.body| && classOf(c, a.body[j])
  }

  // A literal matches at position p iff the substring is a.body.
  predicate litMatches(s: Bytes, p: nat, a: Atom)
    requires a.kind == LIT
  {
    p + |a.body| <= |s| && s[p..p + |a.body|] == a.body
  }

  // How far one success of the atom advances.
  function advance(s: Bytes, p: nat, a: Atom): nat
  {
    if a.kind == LIT then (if |a.body| == 0 then 1 else |a.body|) else 1
  }

  // -- matching ----------------------------------------------------------
  // Full-string match: every atom takes between lo and hi repetitions and
  // the whole of s is consumed.

  predicate matchesFrom(s: Bytes, p: nat, atoms: seq<Atom>, ai: nat)
    requires 0 <= ai <= |atoms|
    decreases |atoms| - ai
  {
    if ai == |atoms| then p == |s|
    else
      exists k :: atoms[ai].lo <= k <= atoms[ai].hi &&
        consumes(s, p, atoms[ai], k) &&
        matchesFrom(s, p + k * advance(s, p, atoms[ai]), atoms, ai + 1)
  }

  predicate consumes(s: Bytes, p: nat, a: Atom, k: nat)
    decreases k
  {
    if k == 0 then true
    else
      (if a.kind == LIT then litMatches(s, p, a)
       else p < |s| && charMatchesBody(s[p], a))
      && consumes(s, p + advance(s, p, a), a, k - 1)
  }

  predicate matches(s: Bytes, atoms: seq<Atom>)
    requires forall i :: 0 <= i < |atoms| ==> wellCounted(atoms[i])
  {
    matchesFrom(s, 0, atoms, 0)
  }

  // -- properties --------------------------------------------------------

  // A match is decidable and total on well-counted patterns: for any s the
  // predicate either holds or does not.  (It is a predicate, so this is
  // structural, but it is the property the ports rely on.)
  lemma MatchTotal(s: Bytes, atoms: seq<Atom>)
    requires forall i :: 0 <= i < |atoms| ==> wellCounted(atoms[i])
    ensures matches(s, atoms) || !matches(s, atoms)
  { }

  // The empty pattern matches exactly the empty string.
  lemma EmptyPattern(s: Bytes)
    ensures matches(s, []) == (s == [])
  { }

  // A pattern that matches must consume every character.
  lemma MatchConsumesAll(s: Bytes, atoms: seq<Atom>)
    requires forall i :: 0 <= i < |atoms| ==> wellCounted(atoms[i])
    requires matches(s, atoms)
    ensures matchesFrom(s, 0, atoms, 0)
  { }

  // `1A.AN` semantics: one alpha, then 0..255 alphanumerics.  "a", "ab",
  // "a1" match; "a!" does not.  These are the conformance cases T13/C29.
  // The 255 is RSM's default maximum for an unbounded `.` count.
  predicate alphaThenAlnum(s: Bytes)
  {
    |s| >= 1 && |s| <= 256 && isAlpha(s[0])
    && (forall i :: 1 <= i < |s| ==> isAlpha(s[i]) || isDigit(s[i]))
  }

  // The compiled form of the pattern `1A.AN`.
  function pattern_1A_AN(): seq<Atom>
  {
    [Atom(1, 1, CLS, ['a']),
     Atom(0, 255, CLS, ['a', 'n'])]
  }

  // Unfold helpers: charMatchesBody for the concrete atoms of `1A.AN`.
  lemma CharAlphaMatches(c: char)
    ensures charMatchesBody(c, Atom(1, 1, CLS, ['a'])) == isAlpha(c)
  {
    var a := Atom(1, 1, CLS, ['a']);
    assert |a.body| == 1;
    assert a.body[0] == 'a';
    assert classOf(c, 'a') == isAlpha(c);
    assert charMatchesBody(c, a) == classOf(c, 'a');
  }

  lemma CharAlnumMatches(c: char)
    ensures charMatchesBody(c, Atom(0, 255, CLS, ['a', 'n']))
            == (isAlpha(c) || isDigit(c))
  {
    var a := Atom(0, 255, CLS, ['a', 'n']);
    assert |a.body| == 2;
    assert a.body[0] == 'a';
    assert a.body[1] == 'n';
    assert classOf(c, 'a') == isAlpha(c);
    assert classOf(c, 'n') == isDigit(c);
    assert charMatchesBody(c, a) == (classOf(c, 'a') || classOf(c, 'n'));
  }

  // Consuming a run under a class atom, and its decomposition.
  lemma ConsumesClsRun(s: Bytes, a: Atom, p: nat, k: nat)
    requires a.kind == CLS
    requires advance(s, p, a) == 1
    requires p + k <= |s|
    requires forall i :: p <= i < p + k ==> charMatchesBody(s[i], a)
    ensures consumes(s, p, a, k)
    decreases k
  {
    if k > 0 {
      ConsumesClsRun(s, a, p + 1, k - 1);
    }
  }

  lemma ConsumesClsImplies(s: Bytes, a: Atom, p: nat, k: nat)
    requires a.kind == CLS
    requires advance(s, p, a) == 1
    requires p <= |s|
    requires consumes(s, p, a, k)
    ensures p + k <= |s|
    ensures forall i :: p <= i < p + k ==> charMatchesBody(s[i], a)
    decreases k
  {
    if k == 0 {
    } else {
      assert k >= 1;
      assert p < |s| && charMatchesBody(s[p], a);
      assert p + advance(s, p, a) == p + 1;
      assert consumes(s, p + 1, a, k - 1);
      ConsumesClsImplies(s, a, p + 1, k - 1);
      assert (p + 1) + (k - 1) <= |s|;
      assert p + k <= |s|;
    }
  }

  lemma OneAlphaThenAlnum(s: Bytes)
    ensures matches(s, pattern_1A_AN()) == alphaThenAlnum(s)
  {
    var atoms := pattern_1A_AN();
    if matches(s, atoms) {
      var k :| atoms[0].lo <= k <= atoms[0].hi
               && consumes(s, 0, atoms[0], k)
               && matchesFrom(s, 0 + k * advance(s, 0, atoms[0]), atoms, 1);
      assert atoms[0].lo == 1 && atoms[0].hi == 1;
      assert k == 1;
      assert advance(s, 0, atoms[0]) == 1;
      ConsumesClsImplies(s, atoms[0], 0, 1);
      CharAlphaMatches(s[0]);
      assert isAlpha(s[0]);
      var k2 :| atoms[1].lo <= k2 <= atoms[1].hi
                && consumes(s, 1, atoms[1], k2)
                && matchesFrom(s, 1 + k2 * advance(s, 1, atoms[1]), atoms, 2);
      assert advance(s, 1, atoms[1]) == 1;
      assert 1 + k2 == |s|;
      assert k2 == |s| - 1;
      assert atoms[1].hi == 255;
      assert |s| <= 256;
      ConsumesClsImplies(s, atoms[1], 1, |s| - 1);
      forall i | 1 <= i < |s| {
        CharAlnumMatches(s[i]);
      }
      assert forall i :: 1 <= i < |s| ==> isAlpha(s[i]) || isDigit(s[i]);
    }
    if alphaThenAlnum(s) {
      assert |s| >= 1 && isAlpha(s[0]);
      CharAlphaMatches(s[0]);
      assert charMatchesBody(s[0], atoms[0]);
      assert consumes(s, 0, atoms[0], 1);
      assert atoms[1].lo <= |s| - 1 <= atoms[1].hi;
      forall i | 1 <= i < |s| {
        CharAlnumMatches(s[i]);
      }
      assert forall i {:trigger charMatchesBody(s[i], atoms[1])}
              :: 1 <= i < |s| ==> charMatchesBody(s[i], atoms[1]);
      assert advance(s, 1, atoms[1]) == 1;
      ConsumesClsRun(s, atoms[1], 1, |s| - 1);
      assert consumes(s, 1, atoms[1], |s| - 1);
      assert matchesFrom(s, |s|, atoms, 2);
      assert matchesFrom(s, 1, atoms, 1);
      assert matchesFrom(s, 0, atoms, 0);
    }
  }

  // -- recorded RSM behaviour on the pattern grammar ---------------------
  //
  // "x"?1AN = 1   (x is alpha)
  // "1"?1AN = 1   (1 is numeric)
  // "!"?1AN = 0   (neither)
  // "a"?1AP = 1   (a is alpha)
  // "!"?1AP = 1   (! is punct)
  // "5"?1AP = 0   (neither)
  // "hello"?5E = 1, "hello"?1E = 0, "hello"?1.5E = 1
  // "a!"?1A.AN = 0  (the '!' is neither alpha nor digit)

}
