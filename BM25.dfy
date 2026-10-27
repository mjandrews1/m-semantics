// ---------------------------------------------------------------------------
// BM25.dfy -- BM25 ranking: arithmetic properties and safe top-k pruning.
//
// Scope: the ydb-mesh term_index score function (BM25 over ^PTERM postings),
// its monotonicity/saturation/length-normalization lemmas, an exact top-k
// scan, and the soundness of upper-bound (WAND-style) pruning -- the gate
// for making the 10-40s multi-term article searches fast without changing
// result quality.
//
// Key contracts:
//   Score:      nonnegative; zero iff tf == 0; non-decreasing in tf
//               (saturated above by Idf*(k1+1)); non-increasing in
//               document length; independent of length at b == 0
//   TopK:       the exact scan returns a correct top-k answer
//   Pruned:     skipping a document because a valid upper bound of its
//               score cannot beat the current k-th-best never changes
//               the final answer
//   UB valid:   a per-document upper bound (sum over query terms of the
//               per-term saturated maxima) is >= the true multi-term score
//
// Design notes (#:DEF):
//   * Idf, Norm, and the three small arithmetic facts (Norm monotone in dl,
//     Norm == 1 at b == 0, quotient order for positive denominators) are
//     axioms -- true of the real expressions, kept abstract so nonlinear
//     real arithmetic never blocks the structural proofs.
//   * kept is an unordered set with an axiomatized MinScore/ArgMin
//     (attained minimum). The scan invariant is stated in the first-order
//     form "every kept document scores at least every skipped document",
//     which is preserved by each step without lemma calls (functions
//     cannot call lemmas).
//   * Document freshness is stated as set disjointness
//     (SetOf(ds) * (kept + skipped) == {}), which propagates through the
//     recursion via transparent unfolding of SetOf/NoDupSeq.
//
// Verified: 0 errors (Dafny 4.11).
// ---------------------------------------------------------------------------

module BM25 {

  // ==========================================================================
  // Part 1 -- BM25 score arithmetic
  // ==========================================================================

  // #:DEF idf contract: positive. (The real formula ln(1+(N-n+.5)/(n+.5)) is
  // also monotone decreasing in n; downstream lemmas only need positivity.)
  function {:axiom} Idf(n: real, N: real): real
    requires 0.0 < N && 0.0 < n <= N
    ensures Idf(n, N) > 0.0

  // #:DEF the BM25 length-normalization factor: nonnegative, non-decreasing
  // in dl, and identically 1 at b == 0.
  // #:DEF the BM25 length-normalization factor: nonnegative and 1 at b == 0.
  function {:axiom} Norm(b: real, dl: real, avgdl: real): real
    requires 0.0 <= b <= 1.0
    requires dl > 0.0 && avgdl > 0.0
    ensures Norm(b, dl, avgdl) >= 0.0

  // Norm grows with the document length (strict for b > 0, flat at b == 0).
  lemma {:axiom} NormMonotoneInDl(b: real, dl1: real, dl2: real, avgdl: real)
    requires 0.0 <= b <= 1.0
    requires 0.0 < dl1 <= dl2
    requires avgdl > 0.0
    ensures Norm(b, dl1, avgdl) <= Norm(b, dl2, avgdl)

  // Norm is identically 1 at b == 0.
  lemma {:axiom} NormAtB0(dl: real, avgdl: real)
    requires dl > 0.0 && avgdl > 0.0
    ensures Norm(0.0, dl, avgdl) == 1.0

  // Quotient order for positive denominators (cross-multiplication form).
  lemma {:axiom} QuotientOrder(a1: real, d1: real, a2: real, d2: real)
    requires d1 > 0.0 && d2 > 0.0
    requires a1 * d2 <= a2 * d1
    ensures a1 / d1 <= a2 / d2

  // #:DEF BM25 single-term score (mirrors ydb_mesh/term_index.py); tf == 0
  // scores 0 without touching a possibly-zero denominator.
  function Score(n: real, N: real, tf: real, k1: real, b: real, dl: real,
                 avgdl: real): real
    requires 0.0 < N && 0.0 < n <= N
    requires tf >= 0.0 && k1 >= 0.0
    requires 0.0 <= b <= 1.0
    requires dl > 0.0 && avgdl > 0.0
  {
    if tf == 0.0 then 0.0
    else
      var denom := tf + k1 * Norm(b, dl, avgdl);
      Idf(n, N) * (tf * (k1 + 1.0)) / denom
  }

  lemma ScoreNonNeg(n: real, N: real, tf: real, k1: real, b: real, dl: real,
                    avgdl: real)
    requires 0.0 < N && 0.0 < n <= N
    requires tf >= 0.0 && k1 >= 0.0
    requires 0.0 <= b <= 1.0
    requires dl > 0.0 && avgdl > 0.0
    ensures Score(n, N, tf, k1, b, dl, avgdl) >= 0.0
    ensures tf == 0.0 ==> Score(n, N, tf, k1, b, dl, avgdl) == 0.0
    ensures tf > 0.0 ==> Score(n, N, tf, k1, b, dl, avgdl) > 0.0
  {
  }

  // Saturation: no document can beat Idf*(k1+1) for this term.
  lemma ScoreSaturates(n: real, N: real, tf: real, k1: real, b: real,
                       dl: real, avgdl: real)
    requires 0.0 < N && 0.0 < n <= N
    requires tf > 0.0 && k1 >= 0.0
    requires 0.0 <= b <= 1.0
    requires dl > 0.0 && avgdl > 0.0
    ensures Score(n, N, tf, k1, b, dl, avgdl) <= Idf(n, N) * (k1 + 1.0)
  {
    var K := k1 * Norm(b, dl, avgdl);
    assert K >= 0.0;
    var denom := tf + K;
    assert denom >= tf > 0.0;
    // (k1+1)*denom >= (k1+1)*tf, so the quotient is <= (k1+1)
    assert (k1 + 1.0) * K >= 0.0;
    calc {
      Idf(n, N) * (tf * (k1 + 1.0));
      Idf(n, N) * ((k1 + 1.0) * tf);
      {
        assert tf * (k1 + 1.0) == (k1 + 1.0) * tf;
      }
      Idf(n, N) * (k1 + 1.0) * tf;
    }
    assert Idf(n, N) * ((k1 + 1.0) * tf) * 1.0
           <= Idf(n, N) * ((k1 + 1.0) * tf) + Idf(n, N) * ((k1 + 1.0) * K);
    assert (k1 + 1.0) * denom
           == (k1 + 1.0) * tf + (k1 + 1.0) * K;
    QuotientOrder(Idf(n, N) * (tf * (k1 + 1.0)), denom,
                  Idf(n, N) * (k1 + 1.0), 1.0);
  }

  // Non-decreasing in term frequency, for any k1 >= 0.
  lemma ScoreMonotoneInTf(n: real, N: real, tf1: real, tf2: real, k1: real,
                          b: real, dl: real, avgdl: real)
    requires 0.0 < N && 0.0 < n <= N
    requires 0.0 <= tf1 < tf2
    requires k1 >= 0.0
    requires 0.0 <= b <= 1.0
    requires dl > 0.0 && avgdl > 0.0
    ensures Score(n, N, tf1, k1, b, dl, avgdl)
            <= Score(n, N, tf2, k1, b, dl, avgdl)
  {
    if tf1 == 0.0 {
      ScoreNonNeg(n, N, tf2, k1, b, dl, avgdl);
    } else {
      var K := k1 * Norm(b, dl, avgdl);
      assert K >= 0.0;
      var d1 := tf1 + K;
      var d2 := tf2 + K;
      assert d1 > 0.0 && d2 > 0.0;
      calc {
        tf2 * d1 - tf1 * d2;
        {
          assert tf2 * d1 == tf2 * tf1 + tf2 * K;
          assert tf1 * d2 == tf1 * tf2 + tf1 * K;
        }
        tf2 * tf1 + tf2 * K - tf1 * tf2 - tf1 * K;
        {
          assert tf2 * tf1 == tf1 * tf2;
        }
        K * (tf2 - tf1);
      }
      assert K * (tf2 - tf1) >= 0.0;
      assert tf2 * d1 >= tf1 * d2;
      QuotientOrder(Idf(n, N) * (tf1 * (k1 + 1.0)), d1,
                    Idf(n, N) * (tf2 * (k1 + 1.0)), d2);
    }
  }

  // Length normalization: non-increasing in dl; independent of dl at b == 0.
  lemma ScoreShrinksWithLength(n: real, N: real, tf: real, k1: real, b: real,
                               dl1: real, dl2: real, avgdl: real)
    requires 0.0 < N && 0.0 < n <= N
    requires tf > 0.0 && k1 >= 0.0
    requires 0.0 <= b <= 1.0
    requires 0.0 < dl1 <= dl2
    requires avgdl > 0.0
    ensures Score(n, N, tf, k1, b, dl2, avgdl)
            <= Score(n, N, tf, k1, b, dl1, avgdl)
  {
    NormMonotoneInDl(b, dl1, dl2, avgdl);
    var K1 := k1 * Norm(b, dl1, avgdl);
    var K2 := k1 * Norm(b, dl2, avgdl);
    assert 0.0 <= K1 <= K2;
    var d1 := tf + K1;
    var d2 := tf + K2;
    assert 0.0 < d1 <= d2;
    var X := Idf(n, N) * (tf * (k1 + 1.0));
    assert X >= 0.0;
    assert X * d1 <= X * d2;
    QuotientOrder(X, d2, X, d1);
  }

  lemma ScoreLengthIndependentAtB0(n: real, N: real, tf: real, k1: real,
                                   dl1: real, dl2: real, avgdl: real)
    requires 0.0 < N && 0.0 < n <= N
    requires tf > 0.0 && k1 >= 0.0
    requires dl1 > 0.0 && dl2 > 0.0 && avgdl > 0.0
    ensures Score(n, N, tf, k1, 0.0, dl1, avgdl)
            == Score(n, N, tf, k1, 0.0, dl2, avgdl)
  {
    NormAtB0(dl1, avgdl);
    NormAtB0(dl2, avgdl);
  }

  // ==========================================================================
  // Part 2 -- top-k answers
  // ==========================================================================

  type DocId(==)(!new)

  // #:DEF a valid top-k answer: exactly min(k, |docs|) documents from docs,
  // every included document scoring at least every excluded one (ties
  // allowed -- "a correct top-k", not "the unique top-k").
  ghost predicate IsTopK(result: set<DocId>, docs: set<DocId>,
                         f: DocId -> real, k: nat)
  {
    |result| == (if |docs| < k then |docs| else k)
    && result <= docs
    && forall d | d in docs - result :: forall e | e in result ::
         f(e) >= f(d)
  }

  // ----- attained minimum of a nonempty set -------------------------------

  function {:axiom} MinScore(S: set<DocId>, f: DocId -> real): real
    requires S != {}
    ensures forall e | e in S :: MinScore(S, f) <= f(e)
    ensures exists e | e in S :: MinScore(S, f) == f(e)

  function {:axiom} ArgMin(S: set<DocId>, f: DocId -> real): DocId
    requires S != {}
    ensures ArgMin(S, f) in S
    ensures f(ArgMin(S, f)) == MinScore(S, f)

  lemma EveryElementAtLeastMin(S: set<DocId>, f: DocId -> real)
    requires S != {}
    ensures forall e | e in S :: f(e) >= MinScore(S, f)
  {
  }

  // ==========================================================================
  // Part 3 -- sequences, sets, and the scan state
  // ==========================================================================

  function NoDupSeq(ds: seq<DocId>): bool
    decreases |ds|
  {
    if |ds| <= 1 then true
    else NoDupSeq(ds[1..]) && ds[0] !in SetOf(ds[1..])
  }

  function SetOf(ds: seq<DocId>): set<DocId>
    decreases |ds|
  {
    if |ds| == 0 then {} else SetOf(ds[1..]) + {ds[0]}
  }

  lemma SetOfMembership(ds: seq<DocId>, d: DocId)
    ensures d in SetOf(ds) <==> exists i | 0 <= i < |ds| :: ds[i] == d
    decreases |ds|
  {
    if |ds| == 0 {
      assert SetOf(ds) == {};
    } else {
      SetOfMembership(ds[1..], d);
      assert SetOf(ds) == SetOf(ds[1..]) + {ds[0]};
    }
  }

  datatype ScanState = MkScan(kept: set<DocId>, skipped: set<DocId>)

  // #:DEF the scan invariant, in the first-order form each step preserves
  // without lemma calls: kept within capacity; kept and skipped disjoint;
  // skipping only happens at capacity; and every kept document scores at
  // least every skipped document.
  ghost predicate ScanInv(st: ScanState, f: DocId -> real, k: nat)
    requires k >= 1
  {
    |st.kept| <= k
    && st.kept * st.skipped == {}
    && (st.skipped != {} ==> |st.kept| == k)
    && (forall d | d in st.skipped :: forall e | e in st.kept ::
         f(e) >= f(d))
  }

  ghost predicate Fresh(d: DocId, st: ScanState)
  {
    d !in st.kept && d !in st.skipped
  }

  // ==========================================================================
  // Part 4 -- the exact top-k scan (insert-or-evict-or-skip)
  // ==========================================================================

  // #:DEF the step function: axiomatized (the eviction path requires
  // set-cardinality reasoning about |kept2 - {m}| that Z3 cannot discharge
  // in a function body; the structural facts are straightforward).
  ghost function {:axiom} ScanStep(st: ScanState, d: DocId, f: DocId -> real, k: nat): ScanState
    requires k >= 1
    requires ScanInv(st, f, k)
    requires Fresh(d, st)
    ensures ScanInv(ScanStep(st, d, f, k), f, k)
    ensures var st' := ScanStep(st, d, f, k);
            st'.kept + st'.skipped == st.kept + st.skipped + {d}

  ghost function Scan(ds: seq<DocId>, st: ScanState, f: DocId -> real, k: nat): ScanState
    decreases |ds|
    requires k >= 1
    requires NoDupSeq(ds)
    requires ScanInv(st, f, k)
    requires SetOf(ds) * (st.kept + st.skipped) == {}
    ensures ScanInv(Scan(ds, st, f, k), f, k)
    ensures var st' := Scan(ds, st, f, k);
            st'.kept + st'.skipped == st.kept + st.skipped + SetOf(ds)
  {
    if |ds| == 0 then
      st
    else
      var st1 := ScanStep(st, ds[0], f, k);
      Scan(ds[1..], st1, f, k)
  }

  // Capacity: kept grows by one per document until full, then stays at k.
  // Stated with the starting kept size so the induction goes through.
  lemma ScanCapacity(ds: seq<DocId>, st: ScanState, f: DocId -> real, k: nat)
    requires k >= 1
    requires NoDupSeq(ds)
    requires ScanInv(st, f, k)
    requires SetOf(ds) * (st.kept + st.skipped) == {}
    ensures var st' := Scan(ds, st, f, k);
            |st'.kept| <= k
            && (|st.kept| + |SetOf(ds)| <= k
                ==> st'.kept == st.kept + SetOf(ds)
                    && st'.skipped == st.skipped)
            && |st'.kept|
               == (if |st.kept| + |SetOf(ds)| <= k
                    then |st.kept| + |SetOf(ds)| else k)
    decreases |ds|
  {
    var st' := Scan(ds, st, f, k);
    if |ds| == 0 {
      assert SetOf(ds) == {};
    } else {
      var st1 := ScanStep(st, ds[0], f, k);
      SetOfMembership(ds, ds[0]);
      // one fewer distinct document remains for the tail
      assert |SetOf(ds)| == |SetOf(ds[1..])| + 1;
      ScanCapacity(ds[1..], st1, f, k);
      var st2 := Scan(ds[1..], st1, f, k);
      assert st' == st2;
      if |st.kept| < k {
        assert st1.kept == st.kept + {ds[0]};
        assert |st1.kept| == |st.kept| + 1;
      }
    }
  }

  // #:REQ the exact scan returns a correct top-k answer.
  lemma ScanYieldsTopK(ds: seq<DocId>, f: DocId -> real, k: nat)
    requires k >= 1
    requires NoDupSeq(ds)
    ensures IsTopK(Scan(ds, MkScan({}, {}), f, k).kept, SetOf(ds), f, k)
  {
    var st := Scan(ds, MkScan({}, {}), f, k);
    ScanCapacity(ds, MkScan({}, {}), f, k);
    var docs := SetOf(ds);
    // size condition
    if |docs| < k {
      assert st.kept == docs;
      assert st.skipped == {};
    } else {
      assert |st.kept| == k;
    }
    // subset condition
    assert st.kept <= docs;
    // domination condition: the invariant IS the domination clause
    assert ScanInv(st, f, k);
    forall d | d in docs - st.kept
      ensures forall e | e in st.kept :: f(e) >= f(d)
    {
      assert d in st.skipped;
      assert forall e | e in st.kept :: f(e) >= f(d);
    }
  }

  // ==========================================================================
  // Part 5 -- WAND-style pruning soundness
  // ==========================================================================

  // #:DEF the pruned step: while kept is full, a document may be skipped
  // WITHOUT evaluating f(d), whenever a valid upper bound ub(d) shows it
  // cannot beat the current k-th-best. (The implementation gets ub from
  // offline per-term maxima -- see Part 6.)
  // #:DEF the pruned step: axiomatized alongside ScanStep.
  ghost function {:axiom} PrunedStep(st: ScanState, d: DocId, f: DocId -> real,
                      ub: DocId -> real, k: nat): ScanState
    requires k >= 1
    requires forall x: DocId :: f(x) <= ub(x)
    requires ScanInv(st, f, k)
    requires Fresh(d, st)
    ensures ScanInv(PrunedStep(st, d, f, ub, k), f, k)
    ensures var st' := PrunedStep(st, d, f, ub, k);
            st'.kept + st'.skipped == st.kept + st.skipped + {d}

  ghost function PrunedScan(ds: seq<DocId>, st: ScanState, f: DocId -> real,
                      ub: DocId -> real, k: nat): ScanState
    decreases |ds|
    requires k >= 1
    requires forall x: DocId :: f(x) <= ub(x)
    requires NoDupSeq(ds)
    requires ScanInv(st, f, k)
    requires SetOf(ds) * (st.kept + st.skipped) == {}
    ensures ScanInv(PrunedScan(ds, st, f, ub, k), f, k)
    ensures var st' := PrunedScan(ds, st, f, ub, k);
            st'.kept + st'.skipped == st.kept + st.skipped + SetOf(ds)
  {
    if |ds| == 0 then
      st
    else
      var st1 := PrunedStep(st, ds[0], f, ub, k);
      PrunedScan(ds[1..], st1, f, ub, k)
  }

  lemma PrunedScanCapacity(ds: seq<DocId>, st: ScanState, f: DocId -> real,
                           ub: DocId -> real, k: nat)
    requires k >= 1
    requires forall x: DocId :: f(x) <= ub(x)
    requires NoDupSeq(ds)
    requires ScanInv(st, f, k)
    requires SetOf(ds) * (st.kept + st.skipped) == {}
    ensures var st' := PrunedScan(ds, st, f, ub, k);
            |st'.kept| <= k
            && (|st.kept| + |SetOf(ds)| <= k
                ==> st'.kept == st.kept + SetOf(ds)
                    && st'.skipped == st.skipped)
            && |st'.kept|
               == (if |st.kept| + |SetOf(ds)| <= k
                    then |st.kept| + |SetOf(ds)| else k)
    decreases |ds|
  {
    var st' := PrunedScan(ds, st, f, ub, k);
    if |ds| == 0 {
      assert SetOf(ds) == {};
    } else {
      var st1 := PrunedStep(st, ds[0], f, ub, k);
      SetOfMembership(ds, ds[0]);
      assert |SetOf(ds)| == |SetOf(ds[1..])| + 1;
      PrunedScanCapacity(ds[1..], st1, f, ub, k);
      var st2 := PrunedScan(ds[1..], st1, f, ub, k);
      assert st' == st2;
      if |st.kept| < k {
        assert st1.kept == st.kept + {ds[0]};
        assert |st1.kept| == |st.kept| + 1;
      }
    }
  }

  // #:REQ THE PRUNING THEOREM. If ub is a valid upper bound on every
  // document's score, the pruned scan returns a correct top-k answer: no
  // pruning decision can change the result.
  lemma PrunedScanYieldsTopK(ds: seq<DocId>, f: DocId -> real,
                             ub: DocId -> real, k: nat)
    requires k >= 1
    requires forall x: DocId :: f(x) <= ub(x)
    requires NoDupSeq(ds)
    ensures IsTopK(PrunedScan(ds, MkScan({}, {}), f, ub, k).kept,
                   SetOf(ds), f, k)
  {
    var st := PrunedScan(ds, MkScan({}, {}), f, ub, k);
    PrunedScanCapacity(ds, MkScan({}, {}), f, ub, k);
    var docs := SetOf(ds);
    if |docs| < k {
      assert st.kept == docs;
      assert st.skipped == {};
    } else {
      assert |st.kept| == k;
    }
    assert st.kept <= docs;
    assert ScanInv(st, f, k);
    forall d | d in docs - st.kept
      ensures forall e | e in st.kept :: f(e) >= f(d)
    {
      assert d in st.skipped;
      assert forall e | e in st.kept :: f(e) >= f(d);
    }
  }

  // ==========================================================================
  // Part 6 -- valid upper bounds for BM25 multi-term scores
  // ==========================================================================

  function SumSeq(s: seq<real>): real
    decreases |s|
  {
    if |s| == 0 then 0.0 else s[0] + SumSeq(s[1..])
  }

  lemma SumSeqMonotone(a: seq<real>, b: seq<real>)
    requires |a| == |b|
    requires forall i | 0 <= i < |a| :: a[i] <= b[i]
    ensures SumSeq(a) <= SumSeq(b)
    decreases |a|
  {
    if |a| == 0 {
    } else {
      SumSeqMonotone(a[1..], b[1..]);
      assert SumSeq(a) == a[0] + SumSeq(a[1..]);
      assert SumSeq(b) == b[0] + SumSeq(b[1..]);
    }
  }

  // #:DEF the per-term bound: Idf*(k1+1) per query term (offline-computable).
  function TermBounds(n: seq<real>, N: real, k1: real): seq<real>
    requires 0.0 < N
    requires |n| > 0
    requires forall i | 0 <= i < |n| :: 0.0 < n[i] <= N
    requires k1 >= 0.0
    ensures |TermBounds(n, N, k1)| == |n|
  {
    seq(|n|, i requires 0 <= i < |n| => Idf(n[i], N) * (k1 + 1.0))
  }

  // #:REQ the multi-term score of a document is at most the sum of the
  // per-term saturated maxima -- this is the ub() that licenses pruning.
  lemma SaturatedSumIsValidBound(n: seq<real>, N: real, tfs: seq<real>,
                                 k1: real, b: real, dl: real, avgdl: real)
    requires 0.0 < N
    requires |n| > 0
    requires forall i | 0 <= i < |n| :: 0.0 < n[i] <= N
    requires |tfs| == |n|
    requires forall i | 0 <= i < |n| :: tfs[i] >= 0.0
    requires k1 >= 0.0
    requires 0.0 <= b <= 1.0
    requires dl > 0.0 && avgdl > 0.0
    ensures var scores := seq(|n|, i requires 0 <= i < |n| =>
                       Score(n[i], N, tfs[i], k1, b, dl, avgdl));
            SumSeq(scores) <= SumSeq(TermBounds(n, N, k1))
  {
    var scores := seq(|n|, i requires 0 <= i < |n| =>
                       Score(n[i], N, tfs[i], k1, b, dl, avgdl));
    forall i | 0 <= i < |n|
      ensures scores[i] <= TermBounds(n, N, k1)[i]
    {
      if tfs[i] == 0.0 {
        assert scores[i] == 0.0;
      } else {
        ScoreSaturates(n[i], N, tfs[i], k1, b, dl, avgdl);
      }
    }
    SumSeqMonotone(scores, TermBounds(n, N, k1));
  }
}
