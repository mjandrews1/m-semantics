// ---------------------------------------------------------------------------
// MCommand -- command-level semantics of M: SET / IF / FOR / NEW / KILL with
// comma lists, the postconditional on EVERY command, and the FOR/QUIT
// interaction.  Phase 6.1b (m-semantics#72, SwiftM prerequisites).
//
// Extends MControl.dfy (DO/GOTO/QUIT/$ETRAP/WRITE, FOR loop core) with the
// command forms MControl does not yet pin down.
//
// Key contracts:
//   Postconditional universality (#:ISO ISO 11756 7.1.3): EVERY command may
//     carry `:cond` — C:cond executes iff cond is true.  For every command
//     shape f,  C:cond  ==  if cond then C else skip.
//   QUIT inside a FOR body exits the FOR loop, NOT the routine (mjvm#13):
//     the call stack (DO frames) is preserved; only the loop is abandoned.
//   FOR var=list (C10 `F I=5,3,1`): iterate over the values in order.
//   FOR:COND: postconditional FOR runs zero iterations when COND is false.
//   Argumentless NEW / KILL: affect all LOCALS except $TEST
//     (#:ISO ISO 11756 8.2.6 / 8.3.2 -- $TEST is the documented exception).
//
// Tags:
//   #:ISO     required by ISO 11756
//   #:DEF     our modelling choice (arbiter: GT.M V7.2-001, U01)
// ---------------------------------------------------------------------------

include "MControl.dfy"
include "MSetList.dfy"

module MCommand {

  import opened MSemantics
  import opened MControl
  import opened MSetList

  // =====================================================================
  // Postconditional universality
  // =====================================================================

  // The postconditional wrapper, generic over the state the command acts on
  // (Store for SET/NEW/KILL, CtrlState for WRITE/DO/GOTO/QUIT/FOR).
  // #:ISO  ISO 11756 7.1.3: C:cond is defined for every command C.
  function postcond<A>(c: bool, f: A -> A, x: A): A
  {
    if c then f(x) else x
  }

  // THE universality lemma: for any command effect f and any state x,
  // C:cond is exactly if-then-else.  One proof covers every command shape.
  lemma PostcondIsIfThenElse<A>(c: bool, f: A -> A, x: A)
    ensures postcond(c, f, x) == (if c then f(x) else x)
  { }

  lemma PostcondFalseIsSkip<A>(f: A -> A, x: A)
    ensures postcond(false, f, x) == x
  { }

  lemma PostcondTrueRuns<A>(c: bool, f: A -> A, x: A)
    requires c
    ensures postcond(c, f, x) == f(x)
  { }

  // Instantiated per command shape (SET list, KILL list, NEW list, WRITE):
  lemma PostcondSetList(c: bool, al: seq<Assign>, st: Store)
    ensures postcond(c, s => setList(al, s), st) == (if c then setList(al, st) else st)
  { }

  lemma PostcondKillList(c: bool, names: seq<Ref>, st: Store)
    ensures postcond(c, s => killList(names, s), st) == (if c then killList(names, st) else st)
  { }

  lemma PostcondNewList(c: bool, names: seq<Ref>, st: Store)
    ensures postcond(c, s => newList(names, s), st) == (if c then newList(names, st) else st)
  { }

  lemma PostcondWrite(c: bool, text: Bytes, s: CtrlState)
    ensures postcond(c, s0 => writeText(s0, text), s) == (if c then writeText(s, text) else s)
  { }

  // Postconditional composes: C1:c1 C2:c2 on one line == if c1 then (if c2 ...)
  lemma PostcondComposes<A>(c1: bool, c2: bool, f: A -> A, g: A -> A, x: A)
    ensures postcond(c1, a => postcond(c2, g, f(a)), x)
             == (if c1 then (if c2 then g(f(x)) else f(x)) else x)
  { }

  // =====================================================================
  // QUIT inside FOR: exits the loop, not the routine (mjvm#13)
  // =====================================================================

  // MControl.quitReturn pops the innermost DO frame.  Inside a FOR body a
  // QUIT must instead jump to the loop exit with the call stack UNCHANGED:
  // the FOR loop is abandoned, the enclosing DO/routine continues.
  // #:ISO  ISO 11756 7.2.3 + 8.2.3.
  function quitInFor(s: CtrlState, loopExit: nat): CtrlState
  {
    s.(pc := loopExit)
  }

  lemma QuitInForPreservesStack(s: CtrlState, loopExit: nat)
    ensures quitInFor(s, loopExit).stack == s.stack
  { }

  lemma QuitInForSetsExitPc(s: CtrlState, loopExit: nat)
    ensures quitInFor(s, loopExit).pc == loopExit
  { }

  // Contrast with quitReturn: popping the stack is the DO-QUIT semantics;
  // the FOR-QUIT must NOT do that while a DO frame is live.
  lemma QuitInForDiffersFromQuitReturn(s: CtrlState, loopExit: nat)
    requires |s.stack| > 0
    requires loopExit != quitReturn(s).pc || |quitReturn(s).stack| != |s.stack|
    ensures quitInFor(s, loopExit).stack != quitReturn(s).stack
          || quitInFor(s, loopExit).pc != quitReturn(s).pc
  { }

  // =====================================================================
  // FOR list form (C10: F I=5,3,1) and postconditional FOR
  // =====================================================================

  // FOR var=e1,e2,...,en : iterate over the values in the given order.
  // #:ISO  ISO 11756 7.2.3: the FOR control variable takes each value in
  // the list; the body runs once per value.
  function forListLoop(vals: seq<int>, s: CtrlState, fuel: nat): CtrlState
    decreases fuel
  {
    if fuel == 0 || vals == [] then s
    else forListLoop(vals[1..], s, fuel - 1) // body abstract (sets var, runs body)
  }

  lemma ForListEmptyIsNoop(s: CtrlState, fuel: nat)
    ensures forListLoop([], s, fuel) == s
  { }

  lemma ForListBoundedByFuel(s: CtrlState, vals: seq<int>, fuel: nat)
    requires |vals| > fuel
    ensures forListLoop(vals, s, fuel) == forListLoop(vals[fuel..], s, 0)
  {
    if fuel > 0 && vals != [] {
      ForListBoundedByFuel(s, vals[1..], fuel - 1);
    }
  }

  // FOR:COND — postconditional FOR: false cond means zero iterations.
  function forPostcond(cond: bool, varVal: int, step: int, end: int, s: CtrlState, fuel: nat): CtrlState
  {
    postcond(cond, s0 => forLoop(varVal, step, end, s0, fuel), s)
  }

  lemma ForPostcondFalseIsNoop(varVal: int, step: int, end: int, s: CtrlState, fuel: nat)
    ensures forPostcond(false, varVal, step, end, s, fuel) == s
  { }

  lemma ForPostcondTrueRuns(varVal: int, step: int, end: int, s: CtrlState, fuel: nat)
    requires forContinues(varVal, step, end) || !forContinues(varVal, step, end)
    ensures forPostcond(true, varVal, step, end, s, fuel) == forLoop(varVal, step, end, s, fuel)
  { }

  // =====================================================================
  // Argumentless NEW / KILL: all locals except $TEST
  // =====================================================================

  // $TEST special variable reference.
  function testRef(): Ref { Ref("$TEST", []) }

  // Argumentless NEW: every local ref is stacked and becomes undefined,
  // EXCEPT $TEST which keeps its value.  #:ISO  ISO 11756 8.2.6.
  // (Globals, name starting with '^', are never affected by NEW.)
  function newAllButTest(st: Store): Store
  {
    map r <- st.Keys | !isLocalName(r) || r == testRef() :: r := st[r]
  }

  lemma NewAllButTestPreservesTest(st: Store)
    ensures get(newAllButTest(st), testRef()) == get(st, testRef())
  { }

  lemma NewAllButTestRemovesOtherLocals(st: Store, r: Ref)
    requires isLocalName(r) && r != testRef()
    ensures r !in newAllButTest(st).Keys
  { }

  lemma NewAllButTestPreservesGlobals(st: Store, r: Ref)
    requires r in st && !isLocalName(r)
    ensures r in newAllButTest(st).Keys && newAllButTest(st)[r] == st[r]
  { }

  // Argumentless KILL: every local is killed EXCEPT $TEST.
  // #:ISO  ISO 11756 8.3.2 ($TEST exception); mjvm#30/#31 track the
  // engine-side fixes.
  function killAllButTest(st: Store): Store
  {
    map r <- st.Keys | !isLocalName(r) || r == testRef() :: r := st[r]
  }

  lemma KillAllButTestPreservesTest(st: Store)
    ensures get(killAllButTest(st), testRef()) == get(st, testRef())
  { }

  lemma KillAllButTestRemovesOtherLocals(st: Store, r: Ref)
    requires isLocalName(r) && r != testRef()
    ensures r !in killAllButTest(st).Keys
  { }

  // Argumentless NEW then argumentless KILL compose to: locals (except
  // $TEST) undefined; $TEST and globals intact.
  lemma NewThenKillAllButTest(st: Store, r: Ref)
    requires isLocalName(r) && r != testRef()
    ensures r !in killAllButTest(newAllButTest(st)).Keys
  { }
}
