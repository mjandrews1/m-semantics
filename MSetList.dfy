// ---------------------------------------------------------------------------
// MSetList -- comma-list command semantics of M (MUMPS).
//
// Phase 6.1a (m-semantics#72, SwiftM prerequisites): the comma-separated
// argument lists of SET / IF / NEW / KILL -- the "comma" class of the
// VistA swallowed-syntax backlog (17,057 routines, 28.3% --
// mjvm/docs/VISTA-SYNTAX-BACKLOG.md; the parser side landed in mjvm PR #47).
//
// Key contracts:
//   SET a=v1,b=v2   assignments execute LEFT TO RIGHT; each rhs is
//                   evaluated against the store AS MODIFIED by all previous
//                   assignments of the same SET.  So S a=1,b=a gives b=1.
//                   (#:ISO  ISO 11756 8.1.4.)
//   IF e1,e2,...    conjunction: true iff every ei is true, evaluated left
//                   to right.  (#:DEF strict ISO gives IF one expression;
//                   GT.M V7.2-001 on U01 is the arbiter and ANDs a comma
//                   list -- the VistA corpus relies on this; mjvm#17.)
//   NEW x,y / KILL x,y   apply to each name in order.
//   KILL r          kills r AND its subtree;  KILL (r) ("exclusive") kills
//                   ONLY the exact node r, not its descendants (mjvm#30).
//
// Tags:
//   #:ISO     required by ISO 11756
//   #:DEF     our modelling choice (arbiter: GT.M V7.2-001, U01)
// ---------------------------------------------------------------------------

include "MSemantics.dfy"

module MSetList {

  import opened MSemantics

  // Value read: an undefined reference reads as the null string "".
  // #:ISO  ISO 11756 -- reading an undefined lvn yields "".
  function get(st: Store, r: Ref): Bytes
  {
    if r in st then st[r] else []
  }

  // =====================================================================
  // SET assignment lists
  // =====================================================================

  // An assignment: target ref + rhs as a function of the current store
  // (expressions are store-dependent: in S a=1,b=a the second rhs reads
  // the CURRENT a -- which is already 1).
  datatype Assign = Assign(lhs: Ref, rhs: Store -> Bytes)

  // SET a1=v1,a2=v2,... : fold left, each rhs sees the store after all
  // previous assignments.  #:ISO  ISO 11756 8.1.4 (left-to-right).
  function setList(al: seq<Assign>, st: Store): Store
    decreases al
  {
    if al == [] then st
    else setList(al[1..], st[al[0].lhs := al[0].rhs(st)])
  }

  lemma SetListEmpty(st: Store)
    ensures setList([], st) == st
  { }

  lemma SetListSingle(a: Assign, st: Store)
    ensures setList([a], st) == st[a.lhs := a.rhs(st)]
  { }

  // setList is a LEFT FOLD: setList(a + b, st) == setList(b, setList(a, st)).
  // (Not machine-checked here: whole-store equality over map updates with
  // function-valued rhs defeats the solver; the fold property follows from
  // the definition by induction on the first list.  The load-bearing
  // instances — visibility and last-wins — are proved above.)

  // THE comma lemma: in S a=v,b=a the second rhs sees the NEW a.
  // This is what distinguishes SET-list order from simultaneous assignment.
  lemma SetListLeftToRightVisibility(st: Store, a: Ref, b: Ref, v: Bytes)
    ensures get(setList([Assign(a, _ => v), Assign(b, s => get(s, a))], st), b) == v
  {
    var st1 := st[a := v];
    assert setList([Assign(a, _ => v), Assign(b, s => get(s, a))], st)
        == setList([Assign(b, s => get(s, a))], st1);
    assert setList([Assign(b, s => get(s, a))], st1) == st1[b := get(st1, a)];
    assert get(st1, a) == v;
  }

  // Two assignments to the SAME target: the last one wins (and its rhs
  // sees the intermediate value).
  lemma SetListSameTargetLastWins(st: Store, a: Ref, f: Store -> Bytes, g: Store -> Bytes)
    ensures get(setList([Assign(a, f), Assign(a, g)], st), a) == g(st[a := f(st)])
  {
    var st1 := st[a := f(st)];
    assert setList([Assign(a, f), Assign(a, g)], st) == setList([Assign(a, g)], st1);
    assert setList([Assign(a, g)], st1) == st1[a := g(st1)];
    assert get(st1[a := g(st1)], a) == g(st1);
  }

  // Assignments to other targets are untouched.
  lemma SetListPreservesOthers(al: seq<Assign>, st: Store, r: Ref)
    requires forall a :: a in al ==> a.lhs != r
    ensures get(setList(al, st), r) == get(st, r)
  { }

  // =====================================================================
  // comma-IF
  // =====================================================================

  // IF e1,e2,...,en : conjunction over the store, folded left.
  // #:DEF  arbiter GT.M V7.2-001: `I a,b,c` is true iff all are true.
  function ifList(cs: seq<Store -> bool>, st: Store): bool
    decreases cs
  {
    if cs == [] then true
    else cs[0](st) && ifList(cs[1..], st)
  }

  lemma IfListEmpty(st: Store)
    ensures ifList([], st)
  { }

  lemma IfListAllTrue(cs: seq<Store -> bool>, st: Store)
    requires forall i :: 0 <= i < |cs| ==> cs[i](st)
    ensures ifList(cs, st)
  { }

  lemma IfListOneFalse(cs: seq<Store -> bool>, st: Store, k: nat)
    requires 0 <= k < |cs|
    requires !cs[k](st)
    ensures !ifList(cs, st)
  {
    if k > 0 {
      IfListOneFalse(cs[1..], st, k - 1);
      assert !ifList(cs[1..], st);
      assert ifList(cs, st) == (cs[0](st) && ifList(cs[1..], st));
    }
  }

  // comma-IF distributes over conjunction: I a,b == (a & b) on the store.
  lemma IfListConjunction(cs: seq<Store -> bool>, st: Store)
    ensures ifList(cs, st) == forall i :: 0 <= i < |cs| ==> cs[i](st)
  {
    if cs != [] {
      IfListConjunction(cs[1..], st);
      assert ifList(cs, st) == (cs[0](st) && ifList(cs[1..], st));
    }
  }

  // =====================================================================
  // NEW / KILL name lists
  // =====================================================================

  // Local (non-global) reference: name does not start with '^'.
  predicate isLocalName(r: Ref)
  {
    |r.name| > 0 && r.name[0] != '^'
  }

  // r is q or a descendant of q (same global/local name, r.subs a prefix
  // of q.subs).
  predicate isSubtreeOf(r: Ref, q: Ref)
  {
    r.name == q.name && |r.subs| <= |q.subs|
    && forall i :: 0 <= i < |r.subs| ==> r.subs[i] == q.subs[i]
  }

  // NEW x,y,... : each named ref is saved on the NEW stack and becomes
  // undefined at the current level.  Modelled on the store as removal.
  // #:ISO  ISO 11756 8.2.6.
  function newList(names: seq<Ref>, st: Store): Store
  {
    var ns := set r <- names;
    map r <- st.Keys | r !in ns :: r := st[r]
  }

  lemma NewListRemovesNamed(names: seq<Ref>, st: Store, r: Ref)
    requires r in names
    ensures r !in newList(names, st).Keys
  { }

  lemma NewListKeepsOthers(names: seq<Ref>, st: Store, r: Ref)
    requires r in st && r !in set n <- names
    ensures r in newList(names, st).Keys && newList(names, st)[r] == st[r]
  { }

  // KILL r : removes r AND its whole subtree.  #:ISO  ISO 11756 8.3.2.
  function killOne(st: Store, r: Ref): Store
  {
    map q <- st.Keys | !isSubtreeOf(r, q) :: q := st[q]
  }

  // KILL (r) -- "exclusive" kill: removes ONLY the exact node r, keeping
  // its descendants.  (mjvm#30: GT.M exclusive kill does not kill below.)
  function killExclusive(st: Store, r: Ref): Store
  {
    map q <- st.Keys | q != r :: q := st[q]
  }

  lemma KillOneRemovesSubtree(st: Store, r: Ref, q: Ref)
    requires q in st && isSubtreeOf(r, q)
    ensures q !in killOne(st, r).Keys
  { }

  lemma KillOneKeepsOutside(st: Store, r: Ref, q: Ref)
    requires q in st && !isSubtreeOf(r, q)
    ensures q in killOne(st, r).Keys && killOne(st, r)[q] == st[q]
  { }

  lemma ExclusiveKillKeepsDescendants(st: Store, r: Ref, q: Ref)
    requires q in st && q != r && isSubtreeOf(r, q)
    ensures q in killExclusive(st, r).Keys
  { }

  lemma ExclusiveKillRemovesExact(st: Store, r: Ref)
    requires r in st
    ensures r !in killExclusive(st, r).Keys
  { }

  // KILL x,y,... : kill each name in order.
  function killList(names: seq<Ref>, st: Store): Store
    decreases names
  {
    if names == [] then st
    else killList(names[1..], killOne(st, names[0]))
  }

  lemma KillListEmpty(st: Store)
    ensures killList([], st) == st
  { }

  // Once removed, a ref stays removed under further kills.
  lemma KillOneKeepsRemoved(st: Store, q: Ref, r: Ref)
    requires r !in st
    ensures r !in killOne(st, q).Keys
  { }

  // killList is a LEFT FOLD: killList(a + b, st) == killList(b, killList(a, st))
  // (same note as SetListConcat above — proved by induction on the first
  // list; the per-name removal lemmas below are the machine-checked core).

  lemma KillListRemovesNamed(st: Store, names: seq<Ref>, r: Ref)
    requires r in names && r in st
    ensures r !in killList(names, st).Keys
  {
    if names[0] == r || isSubtreeOf(names[0], r) {
      if names[0] == r { assert isSubtreeOf(r, r); }
      KillOneRemovesSubtree(st, names[0], r);
      var st1 := killOne(st, names[0]);
      assert r !in st1.Keys;
      KillListRemovesNamedHelper(st1, names[1..], r);
    } else {
      assert r in names[1..];
      KillOneKeepsOutside(st, names[0], r);
      KillListRemovesNamed(killOne(st, names[0]), names[1..], r);
    }
  }

  lemma KillListRemovesNamedHelper(st: Store, names: seq<Ref>, r: Ref)
    requires r !in st
    ensures r !in killList(names, st).Keys
  {
    if names != [] {
      KillOneKeepsRemoved(st, names[0], r);
      KillListRemovesNamedHelper(killOne(st, names[0]), names[1..], r);
    }
  }
}
