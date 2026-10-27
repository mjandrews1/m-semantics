// ---------------------------------------------------------------------------
// GraphStore.dfy -- formal invariants of the MeshGraph citation graph store
//                   (ydb-mesh on YottaDB: ^GRAPH / ^GRAPHREV).
//
// Scope: the two-record edge design (every edge stored in both directions),
// relation vocabulary pairing, forward/reverse count agreement, endpoint
// (non-)dangling, and corpus-index referential integrity (^PUBMED vs
// ^PTERMDLEN).
//
// Key contracts:
//   Paired:        every forward record has its reverse (^GRAPHREV) and
//                  vice versa; counts agree; the total is even
//   Kind-safe rels: each relation crosses node kinds, so records are never
//                  self-edges and forward/reverse stores stay disjoint
//   Integrity:      indexed ==> stored (a PTERM entry implies a ^PUBMED
//                  article); the historical phantom-entry incident (1.19M
//                  indexed-but-unloaded PMIDs, 2026-10-27) is exactly the
//                  violation of this property
//
// Design note (#:DEF): relation vocabulary is a paired datatype --
// HasMesh/HasSubject, PublishedInSerial/HasArticle, PublishedInIssn/HasIssn.
// The pre-rebuild loader ambiguity ("orientation of has_mesh differed
// between load-links and the gap loader") is made unrepresentable: a
// relation knows its node kinds, so a misoriented record is not
// well-formed. Serial-vs-ISSN (both 'published_in' in the corpus) are
// distinct constructors.
//
// Verified: 0 errors (Dafny 4.11).
//
// Tags:
//   #:REQ    ydb-mesh requirement (README invariants)
//   #:DEF    our modelling choice
// ---------------------------------------------------------------------------

module GraphStore {

  // ----- node universe ------------------------------------------------------
  // #:DEF node kinds mirror the corpus families (extensible: nct, doi, gene,
  // variant, drug would follow the same scheme).

  datatype NodeKind = KindMesh | KindPubmed | KindSerial | KindIssn

  datatype Node = MkNode(kind: NodeKind, id: string)

  // ----- paired relation vocabulary ------------------------------------------
  // #:REQ every relation has a designated reverse; the corpus emits both
  // directions together (emit-time check).

  datatype Rel = HasMesh | HasSubject
                | PublishedInSerial | HasArticle
                | PublishedInIssn | HasIssn

  function Rev(r: Rel): Rel
  {
    match r
    case HasMesh             => HasSubject
    case HasSubject          => HasMesh
    case PublishedInSerial   => HasArticle
    case HasArticle          => PublishedInSerial
    case PublishedInIssn     => HasIssn
    case HasIssn             => PublishedInIssn
  }

  lemma RevIsInvolution(r: Rel)
    ensures Rev(Rev(r)) == r
  {
  }

  lemma RevIsNotSelf(r: Rel)
    ensures Rev(r) != r
  {
  }

  // #:DEF kind table: which node kinds a relation connects. This is what
  // makes misorientation ill-typed.

  function SrcKind(r: Rel): NodeKind
  {
    match r
    case HasMesh           => KindMesh
    case HasSubject        => KindPubmed
    case PublishedInSerial => KindSerial
    case HasArticle        => KindPubmed
    case PublishedInIssn   => KindIssn
    case HasIssn           => KindPubmed
  }

  function DstKind(r: Rel): NodeKind
  {
    match r
    case HasMesh           => KindPubmed
    case HasSubject        => KindMesh
    case PublishedInSerial => KindPubmed
    case HasArticle        => KindSerial
    case PublishedInIssn   => KindPubmed
    case HasIssn           => KindIssn
  }

  // ----- edges ----------------------------------------------------------------

  datatype Edge = MkEdge(src: Node, rel: Rel, dst: Node)

  predicate WellFormed(e: Edge)
  {
    e.src.kind == SrcKind(e.rel) && e.dst.kind == DstKind(e.rel)
  }

  lemma WellFormedCrossesKinds(e: Edge)
    requires WellFormed(e)
    ensures e.src.kind != e.dst.kind
  {
  }

  lemma WellFormedNotSelf(e: Edge)
    requires WellFormed(e)
    ensures e.src != e.dst
  {
    WellFormedCrossesKinds(e);
  }

  function Swap(e: Edge): Edge
  {
    MkEdge(e.dst, Rev(e.rel), e.src)
  }

  lemma SwapIsInvolution(e: Edge)
    ensures Swap(Swap(e)) == e
  {
    RevIsInvolution(e.rel);
  }

  lemma SwapIsInjective(e: Edge, f: Edge)
    requires Swap(e) == Swap(f)
    ensures e == f
  {
    SwapIsInvolution(e);
    SwapIsInvolution(f);
  }

  // #:DEF the reverse record of a well-formed edge is also well-formed
  // (the table is closed under swapping).

  lemma SwapPreservesWellFormed(e: Edge)
    requires WellFormed(e)
    ensures WellFormed(Swap(e))
  {
    assert Swap(e).src.kind == DstKind(e.rel) == SrcKind(Rev(e.rel));
    assert Swap(e).dst.kind == SrcKind(e.rel) == DstKind(Rev(e.rel));
  }

  function SwapSet(s: set<Edge>): set<Edge>
  {
    set e | e in s :: Swap(e)
  }

  lemma SwapSetCard(s: set<Edge>)
    ensures |SwapSet(s)| == |s|
    decreases |s|
  {
    if s == {} {
      assert SwapSet(s) == {};
    } else {
      var e :| e in s;
      var rest := s - {e};
      SwapSetCard(rest);
      assert SwapSet(s) == SwapSet(rest) + {Swap(e)};
      forall y | y in rest
        ensures Swap(e) != Swap(y)
      {
        if Swap(e) == Swap(y) {
          SwapIsInjective(e, y);
        }
      }
      assert Swap(e) !in SwapSet(rest);
      assert SwapSet(rest) * {Swap(e)} == {};
      assert |SwapSet(s)| == |SwapSet(rest)| + 1;
    }
  }

  // ----- graph state: the two-record store -------------------------------------
  // #:DEF Graph models ^GRAPH (forward records) and ^GRAPHREV (reverse
  // records). Only forward-oriented relations live in fwd; their swaps live
  // in rev.

  function IsFwd(r: Rel): bool
  {
    r == HasMesh || r == PublishedInSerial || r == PublishedInIssn
  }

  datatype Graph = MkGraph(fwd: set<Edge>, rev: set<Edge>)

  predicate Inv(g: Graph)
  {
    (forall e | e in g.fwd :: IsFwd(e.rel)) &&
    SwapSet(g.fwd) == g.rev
  }

  // #:REQ "emit both directions together; COUNT links must be even" --
  // here: the reverse store is exactly the swapped forward store, so the
  // record counts agree and the total is even.

  lemma CountAgreement(g: Graph)
    requires Inv(g)
    ensures |g.fwd| == |g.rev|
  {
    SwapSetCard(g.fwd);
    assert g.rev == SwapSet(g.fwd);
  }

  lemma FwdRevDisjoint(g: Graph)
    requires Inv(g)
    ensures g.fwd * g.rev == {}
  {
    forall e | e in g.fwd
      ensures Swap(e) !in g.fwd
    {
      assert IsFwd(e.rel);
      assert !IsFwd(Rev(e.rel)) by { RevIsNotSelf(e.rel); }
      // Swap(e).rel == Rev(e.rel) is not forward, so Swap(e) cannot be a
      // forward record; Inv makes every member of fwd forward-oriented.
    }
  }

  lemma TotalIsEven(g: Graph)
    requires Inv(g)
    ensures |g.fwd + g.rev| == 2 * |g.fwd|
  {
    CountAgreement(g);
    FwdRevDisjoint(g);
    assert |g.fwd + g.rev| == |g.fwd| + |g.rev|;
  }

  // #:DEF orientation unrepresentability: under Inv the forward store holds
  // only forward relations -- a misoriented record breaks Inv by definition.

  lemma NoBackwardRecords(g: Graph)
    requires Inv(g)
    ensures forall e | e in g.fwd :: IsFwd(e.rel)
  {
  }

  // ----- emit -------------------------------------------------------------------

  // #:REQ emit_edge adds exactly one forward record and its reverse.

  function Emit(g: Graph, a: Node, r: Rel, b: Node): Graph
    requires IsFwd(r) && WellFormed(MkEdge(a, r, b))
  {
    var e := MkEdge(a, r, b);
    MkGraph(g.fwd + {e}, g.rev + {Swap(e)})
  }

  lemma EmitPreservesInv(g: Graph, a: Node, r: Rel, b: Node)
    requires Inv(g)
    requires IsFwd(r) && WellFormed(MkEdge(a, r, b))
    ensures Inv(Emit(g, a, r, b))
  {
    var e := MkEdge(a, r, b);
    SwapPreservesWellFormed(e);
    assert SwapSet(Emit(g, a, r, b).fwd) == SwapSet(g.fwd) + {Swap(e)};
    assert forall f | f in Emit(g, a, r, b).fwd :: IsFwd(f.rel);
  }

  lemma EmitAddsExactlyTwo(g: Graph, a: Node, r: Rel, b: Node)
    requires Inv(g)
    requires IsFwd(r) && WellFormed(MkEdge(a, r, b))
    ensures var g' := Emit(g, a, r, b);
            g'.fwd == g.fwd + {MkEdge(a, r, b)} &&
            g'.rev == g.rev + {Swap(MkEdge(a, r, b))}
  {
  }

  // ----- dangling endpoints -------------------------------------------------------

  // #:REQ no dangling: every edge endpoint must be a loaded node.

  predicate NoDangling(g: Graph, nodes: set<Node>)
  {
    forall e | e in g.fwd + g.rev :: e.src in nodes && e.dst in nodes
  }

  lemma EmitPreservesNoDangling(g: Graph, a: Node, r: Rel, b: Node, nodes: set<Node>)
    requires NoDangling(g, nodes)
    requires a in nodes && b in nodes
    requires IsFwd(r) && WellFormed(MkEdge(a, r, b))
    ensures NoDangling(Emit(g, a, r, b), nodes)
  {
  }

  // ----- corpus index integrity ---------------------------------------------------
  // #:REQ every PTERM-indexed document is a stored ^PUBMED article. The
  // 2026-10-27 incident (term_index run against a missing-PMID list before
  // the corresponding load, creating ~1.19M phantom PTERMDLEN entries)
  // violated exactly this property; the daily-update guard ("index only
  // PMIDs present in ^PUBMED") restores it procedurally.

  datatype Corpus = MkCorpus(stored: set<string>, indexed: set<string>)

  predicate IndexIntegrity(c: Corpus)
  {
    c.indexed <= c.stored
  }

  function LoadMissing(c: Corpus, m: set<string>): Corpus
    requires m <= c.stored
  {
    MkCorpus(c.stored, c.indexed + m)
  }

  lemma LoadMissingPreservesIntegrity(c: Corpus, m: set<string>)
    requires IndexIntegrity(c) && m <= c.stored
    ensures IndexIntegrity(LoadMissing(c, m))
  {
  }

  // Indexing only stored documents preserves integrity (the guarded
  // catch-up path).

  function IndexStored(c: Corpus, m: set<string>): Corpus
    requires m <= c.stored
  {
    MkCorpus(c.stored, c.indexed + m)
  }

  lemma IndexStoredPreservesIntegrity(c: Corpus, m: set<string>)
    requires IndexIntegrity(c) && m <= c.stored
    ensures IndexIntegrity(IndexStored(c, m))
  {
  }

  // The phantom theorem: indexing a document that is not stored necessarily
  // violates integrity.

  lemma PhantomBreaksIntegrity(c: Corpus, p: string)
    requires p !in c.stored
    ensures !IndexIntegrity(MkCorpus(c.stored, c.indexed + {p}))
  {
    assert p in (c.indexed + {p});
    assert p !in c.stored;
  }

  // #:DEF repair: recompute the index as indexed ∩ stored (the cleanup job
  // for the incident above: kill PTERMDLEN entries whose PMID is absent
  // from ^PUBMED).

  function RepairPhantoms(c: Corpus): Corpus
  {
    MkCorpus(c.stored, c.indexed * c.stored)
  }

  lemma RepairRestoresIntegrity(c: Corpus)
    ensures IndexIntegrity(RepairPhantoms(c))
  {
  }

  lemma RepairKeepsStored(c: Corpus)
    requires IndexIntegrity(c)
    ensures RepairPhantoms(c).indexed == c.indexed
  {
  }
}
