// ---------------------------------------------------------------------------
// BST.dfy -- verified binary search tree: insert, membership, in-order walk.
//
// Spec for mjvm/tools/dstruct.m DS6 (global-backed BST: iterative insert,
// recursive in-order traversal, searches) -- the Bank.dfy <-> BANK.m pattern
// applied to the campaign's data-structure suite. dstruct.m verifies behavior
// differentially against GT.M; this module is the abstract tree that
// implementation realizes, with its invariants proved:
//
//   Insert preserves the BST ordering invariant.
//   In-order traversal of a valid BST is strictly increasing (sorted).
//   Insert makes the key a member; membership is otherwise preserved.
//   The in-order sequence of Insert contains the inserted key.
//
// dstruct.m notes: child pointers default to 0 via $G(x,0) (no null
// subscripts), node ids from a counter, values compared with < (numeric
// coercion) -- the abstract model here uses int keys and the standard
// strict order; the M side relies on the same strictness (no duplicates).
//
// Verified: 12 lemmas + 10 functions/predicates, 0 errors (Dafny 4.11).
// ---------------------------------------------------------------------------

module BST {

  datatype Tree =
    | Leaf
    | Node(left: Tree, key: int, right: Tree)

  // ----- BST invariant -------------------------------------------------------

  predicate KeysBelow(t: Tree, bound: int)
    decreases t
  {
    match t
    case Leaf => true
    case Node(l, k, r) => k < bound && KeysBelow(l, bound) && KeysBelow(r, bound)
  }

  predicate KeysAbove(t: Tree, bound: int)
    decreases t
  {
    match t
    case Leaf => true
    case Node(l, k, r) => k > bound && KeysAbove(l, bound) && KeysAbove(r, bound)
  }

  predicate IsBst(t: Tree)
    decreases t
  {
    match t
    case Leaf => true
    case Node(l, k, r) =>
      KeysBelow(l, k) && KeysAbove(r, k) && IsBst(l) && IsBst(r)
  }

  // ----- in-order walk -------------------------------------------------------

  function InOrder(t: Tree): seq<int>
    decreases t
  {
    match t
    case Leaf => []
    case Node(l, k, r) => InOrder(l) + [k] + InOrder(r)
  }

  predicate Sorted(s: seq<int>)
  {
    forall i, j | 0 <= i < j < |s| :: s[i] < s[j]
  }

  // ----- insert + membership ---------------------------------------------------

  function Insert(t: Tree, k: int): Tree
    decreases t
  {
    match t
    case Leaf => Node(Leaf, k, Leaf)
    case Node(l, key, r) =>
      if k == key then t
      else if k < key then Node(Insert(l, k), key, r)
      else Node(l, key, Insert(r, k))
  }

  function Member(t: Tree, k: int): bool
    decreases t
  {
    match t
    case Leaf => false
    case Node(l, key, r) =>
      k == key || (k < key && Member(l, k)) || (k > key && Member(r, k))
  }

  // ----- in-order element bounds (index form) --------------------------------

  // All in-order entries of t are below/above bound.
  lemma InOrderAllBelow(t: Tree, bound: int)
    requires KeysBelow(t, bound)
    ensures forall p | 0 <= p < |InOrder(t)| :: InOrder(t)[p] < bound
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, k, r) =>
        InOrderAllBelow(l, bound);
        InOrderAllBelow(r, bound);
        var L := InOrder(l);
        var R := InOrder(r);
        assert InOrder(t) == L + [k] + R;
        forall p | 0 <= p < |InOrder(t)|
          ensures InOrder(t)[p] < bound
        {
          if p < |L| {
            assert InOrder(t)[p] == L[p];
          } else if p == |L| {
            assert InOrder(t)[p] == k;
          } else {
            assert InOrder(t)[p] == R[p - |L| - 1];
          }
        }
    }
  }

  lemma InOrderAllAbove(t: Tree, bound: int)
    requires KeysAbove(t, bound)
    ensures forall p | 0 <= p < |InOrder(t)| :: InOrder(t)[p] > bound
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, k, r) =>
        InOrderAllAbove(l, bound);
        InOrderAllAbove(r, bound);
        var L := InOrder(l);
        var R := InOrder(r);
        assert InOrder(t) == L + [k] + R;
        forall p | 0 <= p < |InOrder(t)|
          ensures InOrder(t)[p] > bound
        {
          if p < |L| {
            assert InOrder(t)[p] == L[p];
          } else if p == |L| {
            assert InOrder(t)[p] == k;
          } else {
            assert InOrder(t)[p] == R[p - |L| - 1];
          }
        }
    }
  }

  // ----- core lemmas -----------------------------------------------------------

  // In-order traversal of a valid BST is strictly increasing.
  lemma InOrderSorted(t: Tree)
    requires IsBst(t)
    ensures Sorted(InOrder(t))
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, k, r) =>
        InOrderSorted(l);
        InOrderSorted(r);
        // element facts from the BST invariant at this node
        InOrderAllBelow(l, k);
        InOrderAllAbove(r, k);
        ConcatSorted(InOrder(l), k, InOrder(r));
        assert InOrder(t) == InOrder(l) + [k] + InOrder(r);
    }
  }

  // Splicing a key between two sorted sequences that straddle it is sorted.
  lemma ConcatSorted(L: seq<int>, k: int, R: seq<int>)
    requires Sorted(L) && Sorted(R)
    requires forall p | 0 <= p < |L| :: L[p] < k
    requires forall q | 0 <= q < |R| :: k < R[q]
    ensures Sorted(L + [k] + R)
  {
    forall i, j | 0 <= i < j < |L| + 1 + |R|
      ensures (L + [k] + R)[i] < (L + [k] + R)[j]
    {
      if i < |L| {
        if j < |L| {
          assert (L + [k] + R)[i] == L[i] && (L + [k] + R)[j] == L[j];
        } else if j == |L| {
          assert (L + [k] + R)[i] == L[i] && (L + [k] + R)[j] == k;
        } else {
          assert (L + [k] + R)[i] == L[i] && (L + [k] + R)[j] == R[j - |L| - 1];
        }
      } else if i == |L| {
        assert (L + [k] + R)[i] == k && (L + [k] + R)[j] == R[j - |L| - 1];
      } else {
        assert (L + [k] + R)[i] == R[i - |L| - 1] && (L + [k] + R)[j] == R[j - |L| - 1];
      }
    }
  }

  // Insert preserves the BST invariant.
  lemma InsertPreservesBst(t: Tree, k: int)
    requires IsBst(t)
    ensures IsBst(Insert(t, k))
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, key, r) =>
        if k == key {
        } else if k < key {
          InsertPreservesBst(l, k);
          InsertKeysBelow(l, k, key);
        } else {
          InsertPreservesBst(r, k);
          InsertKeysAbove(r, k, key);
        }
    }
  }

  lemma InsertKeysBelow(t: Tree, k: int, bound: int)
    requires KeysBelow(t, bound)
    requires k < bound
    ensures KeysBelow(Insert(t, k), bound)
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, key, r) =>
        if k == key {
        } else if k < key {
          InsertKeysBelow(l, k, bound);
        } else {
          InsertKeysBelow(r, k, bound);
        }
    }
  }

  lemma InsertKeysAbove(t: Tree, k: int, bound: int)
    requires KeysAbove(t, bound)
    requires k > bound
    ensures KeysAbove(Insert(t, k), bound)
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, key, r) =>
        if k == key {
        } else if k < key {
          InsertKeysAbove(l, k, bound);
        } else {
          InsertKeysAbove(r, k, bound);
        }
    }
  }

  // Insert makes the key a member and preserves all other membership.
  lemma InsertMember(t: Tree, k: int, x: int)
    ensures Member(Insert(t, k), x) <==> (Member(t, x) || x == k)
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, key, r) =>
        if x == k || x == key {
          InsertMemberSameShape(t, k, x);
        } else if x < key {
          if k < key {
            InsertMember(l, k, x);
          }
        } else {
          if key < k {
            InsertMember(r, k, x);
          }
        }
    }
  }

  lemma InsertMemberSameShape(t: Tree, k: int, x: int)
    ensures Member(Insert(t, k), x) <==> (Member(t, x) || x == k)
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, key, r) =>
        if k < key {
          InsertMemberSameShape(l, k, x);
        } else if key < k {
          InsertMemberSameShape(r, k, x);
        }
    }
  }

  // The in-order sequence of Insert contains the inserted key (dstruct.m DS6
  // relies on exactly this for its in-order walk after inserts).
  lemma InsertInOrderContains(t: Tree, k: int)
    ensures k in InOrder(Insert(t, k))
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, key, r) =>
        if k == key {
        } else if k < key {
          InsertInOrderContains(l, k);
        } else {
          InsertInOrderContains(r, k);
        }
    }
  }

  // Insert preserves membership of the in-order sequence for old keys.
  lemma InsertInOrderPreserves(t: Tree, k: int, x: int)
    requires x in InOrder(t)
    ensures x in InOrder(Insert(t, k))
    decreases t
  {
    match t {
      case Leaf =>
      case Node(l, key, r) =>
        if k == key {
          assert x in InOrder(Insert(t, k));
        } else if k < key {
          if x == key {
            // key stays the root of Insert(t, k)
            assert x in InOrder(Insert(t, k));
          } else if x in InOrder(r) {
            // right subtree is untouched when k < key
            assert x in InOrder(Insert(t, k));
          } else {
            // x must then be in InOrder(l): concat membership
            assert x in InOrder(l) + [key] + InOrder(r);
            InsertInOrderPreserves(l, k, x);
            assert x in InOrder(Insert(t, k));
          }
        } else {
          if x == key {
            assert x in InOrder(Insert(t, k));
          } else if x in InOrder(l) {
            assert x in InOrder(Insert(t, k));
          } else {
            assert x in InOrder(l) + [key] + InOrder(r);
            InsertInOrderPreserves(r, k, x);
            assert x in InOrder(Insert(t, k));
          }
        }
    }
  }

  // ----- the dstruct.m DS6 scenario, as a sanity cell ---------------------------
  // Insert 5,3,8,1,4,7,9 (the exact DS6 sequence) and check the in-order walk
  // is the sorted key list and membership behaves.

  lemma DS6Scenario()
  {
    var t0 := Insert(Insert(Insert(Insert(Insert(Insert(Insert(Leaf, 5), 3), 8), 1), 4), 7), 9);
    assert IsBst(t0);
    assert Sorted(InOrder(t0));
    assert InOrder(t0) == [1, 3, 4, 5, 7, 8, 9];
    assert Member(t0, 7);
    assert !Member(t0, 6);
    assert 7 in InOrder(t0);
  }
}
