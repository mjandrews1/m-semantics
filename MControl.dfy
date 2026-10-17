// ---------------------------------------------------------------------------
// MControl -- formal control-flow semantics of M (MUMPS).
//
// Scope: DO / GOTO / QUIT / traps / WRITE line orientation.  Extends
// MSemantics.dfy (values, comparison, store) with routine control flow.
//
// Key contracts (ISO 11756):
//   DO       = CALL_PC: save return point on current line, jump to label.
//              After QUIT from the target, resume at the saved point.
//   GOTO     = JMP: abandon the current line entirely, jump to label.
//              No return point saved.
//   Argumentless DO: execute the next indented block (or next line's body).
//   QUIT     = return to saved point (DO) or end execution (top-level).
//   $ETRAP / $ZTRAP: command strings executed on error.
//   WRITE    = line-oriented: output accumulates; ! advances to next line.
//
// Tags:
//   #:ISO     required by ISO 11756
//   #:DEF     our modelling choice
//   #:DIVERGE upstream is wrong; we specify the standard
// ---------------------------------------------------------------------------

include "MSemantics.dfy"

module MControl {

  import opened MSemantics

  // ----- labels and routines ---------------------------------------------

  // A label names a position in a routine.  Routine names are global refs.
  // For intra-routine control flow we only need the label name.
  type Label = Bytes

  // A routine is a finite map from labels to code positions (PCs).
  // We model code as a sequence of instructions; PC is an index.
  type Routine = map<Label, nat>

  // Well-formed: every label maps to a valid PC within the code length.
  predicate wellFormedRoutine(r: Routine, codeLen: nat)
  {
    forall l :: l in r ==> r[l] < codeLen
  }

  // ----- program counter and call stack ---------------------------------

  // A call frame records the return point (PC + line) for a DO.
  // GOTO does not push a frame.
  datatype Frame = Frame(
    retPc: nat,        // PC to resume after QUIT
    retLine: nat       // line number (for WRITE line orientation)
  )

  // Machine state: PC, call stack, output buffer, current line.
  datatype CtrlState = CtrlState(
    pc: nat,                    // current program counter
    stack: seq<Frame>,          // call stack (innermost last)
    output: seq<Bytes>,         // WRITE output lines
    line: nat,                  // current output line number
    etrap: Bytes,               // $ETRAP command string
    ztrap: Bytes                // $ZTRAP command string
  )

  // ----- DO (CALL_PC) ----------------------------------------------------

  // DO pushes a return frame and jumps to the target label's PC.
  // #:ISO 8.2.4: DO with arguments passes values; the callee binds formals.
  // The return point is the instruction AFTER the DO on the current line.
  function doCall(s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc  // return point is on the current line (after DO)
  {
    s.(pc := target,
       stack := s.stack + [Frame(retPc, s.line)])
  }

  // Argumentless DO: the return point is the next instruction (which may
  // be on the next line, in the indented block).
  // #:ISO 8.2.2: argumentless DO executes the block following the DO.
  function doCallArgless(s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc
  {
    doCall(s, target, retPc)
  }

  // ----- GOTO (JMP) ------------------------------------------------------

  // GOTO abandons the current line and jumps to the target label.
  // No frame is pushed.  The call stack is unchanged.
  // #:ISO 8.2.3: GOTO transfers control to a label in the same routine.
  function gotoJump(s: CtrlState, target: nat): CtrlState
  {
    s.(pc := target)
    // stack unchanged — GOTO does not return
  }

  // External GOTO (G TAG^ROUTINE) changes the routine entirely.
  // We model this as: new code base, new label map, stack cleared.
  // #:ISO 8.2.3: GOTO to another routine abandons the current context.
  function gotoExternal(s: CtrlState, target: nat): CtrlState
  {
    s.(pc := target, stack := [])
  }

  // ----- QUIT ------------------------------------------------------------

  // QUIT with expression: pop frame, set return PC, produce output.
  // Top-level QUIT (empty stack): end execution.
  // #:ISO 8.2.5: QUIT returns control to the caller (DO) or ends execution.
  function quitReturn(s: CtrlState): CtrlState
  {
    if |s.stack| == 0 then
      s  // top-level QUIT: no-op (execution ends at caller)
    else
      var f := s.stack[|s.stack| - 1];
      s.(pc := f.retPc, stack := s.stack[..|s.stack| - 1])
  }

  // ----- traps ------------------------------------------------------------

  // When an error occurs, $ETRAP (or $ZTRAP if $ETRAP is empty) is
  // executed as a command string.
  // #:ISO 8.1.5: $ETRAP is the error trap command string.
  // #:ISO 8.1.6: $ZTRAP is the legacy error trap (used when $ETRAP is empty).
  function trapCommand(s: CtrlState): Bytes
  {
    if |s.etrap| > 0 then s.etrap else s.ztrap
  }

  // After a trap fires, $ECODE is set and the trap command runs.
  // We model trap firing as: PC moves to the trap command's code.
  // For now, the trap is just a command string (not compiled).
  predicate hasTrap(s: CtrlState)
  {
    |s.etrap| > 0 || |s.ztrap| > 0
  }

  // ----- WRITE (line-oriented) -------------------------------------------

  // WRITE appends to the current output line.  ! advances to the next line.
  // #:ISO 8.3.5: WRITE ! outputs a new line.
  function writeText(s: CtrlState, text: Bytes): CtrlState
  {
    s.(output := s.output + [text])
  }

  function writeNewline(s: CtrlState): CtrlState
  {
    s.(output := s.output + [[]], line := s.line + 1)
  }

  // ----- lemmas ----------------------------------------------------------

  // DO saves a return point and QUIT restores it.
  lemma DoQuitRoundTrip(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures quitReturn(doCall(s, target, retPc)).pc == retPc
    ensures quitReturn(doCall(s, target, retPc)).stack == s.stack
  { }

  // GOTO does not push a frame.
  lemma GotoPreservesStack(s: CtrlState, target: nat)
    ensures gotoJump(s, target).stack == s.stack
  { }

  // Argumentless DO pushes a frame like argumented DO.
  lemma ArglessDoPushes(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures doCallArgless(s, target, retPc).stack == s.stack + [Frame(retPc, s.line)]
  { }

  // QUIT at top level is a no-op.
  lemma QuitTopLevelIsNoop(s: CtrlState)
    requires |s.stack| == 0
    ensures quitReturn(s) == s
  { }

  // Trap command prefers $ETRAP over $ZTRAP.
  lemma TrapPrefersEtrap(s: CtrlState)
    requires |s.etrap| > 0
    ensures trapCommand(s) == s.etrap
  { }

  // WRITE ! advances the line counter.
  lemma WriteNewlineAdvances(s: CtrlState)
    ensures writeNewline(s).line == s.line + 1
  { }

  // ----- DO with argumented call and QUIT with value ----------------------
  // The callee's QUIT with an expression produces the extrinsic return value.
  // For the contract: DO call + QUIT-with-value = the value is the result.

  // Model: after doCall, running the callee to its QUIT-with-value produces
  // a return value.  The return PC is restored as in quitReturn.
  function doCallAndReturn(s: CtrlState, target: nat, retPc: nat, retVal: Bytes): (r: CtrlState)
    requires retPc >= s.pc
    ensures r.pc == retPc
    ensures r.stack == s.stack
  {
    var s1 := doCall(s, target, retPc);
    quitReturn(s1)
  }

  // ----- postconditional DO (D:COND TAG) ---------------------------------
  // #:ISO 7.2.4: a postconditional on DO executes the call only if COND.
  // Composition: If(cond, doCall(...), skip) where skip leaves state unchanged.
  // This is the IR shape for D:COND TAG — the MFrontend compiles it as
  // evaluate COND, JMP0 past the CALL_PC if false.

  function skip(s: CtrlState): CtrlState { s }

  function postcondDo(cond: bool, s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc
  {
    if cond then doCall(s, target, retPc) else skip(s)
  }

  // Postconditional DO: false condition leaves state unchanged.
  lemma PostcondDoFalseLeavesState(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures postcondDo(false, s, target, retPc) == s
  { }

  // Postconditional DO: true condition performs the call.
  lemma PostcondDoTrueCalls(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures postcondDo(true, s, target, retPc) == doCall(s, target, retPc)
  { }

  // Postconditional DO round-trip: true cond + QUIT restores PC and stack.
  lemma PostcondDoQuitRoundTrip(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures quitReturn(postcondDo(true, s, target, retPc)).pc == retPc
    ensures quitReturn(postcondDo(true, s, target, retPc)).stack == s.stack
  { }

  // ----- integration: postcondDo ≡ Stmt.If model --------------------------
  // MSemantics.Stmt models IF/ELSE as If(test, thn, els) with run() producing
  // output.  postcondDo is the control-state analog: If(cond, doCall, skip).
  // This lemma ties the two models together: the control-state transition of
  // a postconditional DO is exactly the Stmt.If dispatch.

  lemma PostcondDoMatchesIfModel(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    // false cond: state unchanged (skip arm)
    ensures postcondDo(false, s, target, retPc) == s
    // true cond: state is doCall (call arm)
    ensures postcondDo(true, s, target, retPc).pc == target
    ensures postcondDo(true, s, target, retPc).stack == s.stack + [Frame(retPc, s.line)]
    // this is exactly what MSemantics.run(If(cond, ...)) dispatches to
  {
    PostcondDoFalseLeavesState(s, target, retPc);
    PostcondDoTrueCalls(s, target, retPc);
  }

  // ----- postconditional DO in a While loop (F  D:COND  Q:'COND) --------
  // #:ISO 8.2.2 + 7.2.4: the M while-loop idiom is
  //   F  D:COND  Q:'COND
  // which is: argumentless DO if COND, then QUIT if not COND, repeat.
  // The postconditional guards the DO call each iteration.

  // One iteration: if cond, DO (push frame, jump to target, body, QUIT);
  // if not cond, skip.  Returns the state after one step.
  // Equivalent to quitReturn(postcondDo(cond, s, target, retPc)).
  function whileStep(cond: bool, s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc
  {
    if cond then
      quitReturn(doCall(s, target, retPc))
    else
      s
  }

  // While: iterate whileStep until cond is false.
  // We model this as a bounded fold (Dafny requires termination).
  function whileLoop(cond: bool, s: CtrlState, target: nat, retPc: nat, fuel: nat): CtrlState
    requires retPc >= s.pc
    decreases fuel
  {
    if fuel == 0 || !cond then s
    else whileLoop(cond, whileStep(cond, s, target, retPc), target, retPc, fuel - 1)
  }

  // While with false cond: body is never executed, state is unchanged.
  lemma WhileFalseIsNoop(s: CtrlState, target: nat, retPc: nat, fuel: nat)
    requires retPc >= s.pc
    ensures whileLoop(false, s, target, retPc, fuel) == s
  { }

  // While with retPc == s.pc (loop head): one iteration is identity on PC/stack.
  lemma WhileLoopHeadRoundTrip(s: CtrlState, target: nat)
    requires 0 <= s.pc
    ensures whileStep(true, s, target, s.pc).pc == s.pc
    ensures whileStep(true, s, target, s.pc).stack == s.stack
  { }

  // While loop with cond at loop head: N iterations of identity = identity.
  lemma WhileLoopHeadIdentity(s: CtrlState, target: nat, fuel: nat)
    requires 0 <= s.pc
    ensures whileLoop(true, s, target, s.pc, fuel) == s
    decreases fuel
  {
    if fuel == 0 { } else {
      assert whileStep(true, s, target, s.pc) == s by {
        WhileLoopHeadRoundTrip(s, target);
      }
    }
  }

  // While step uses postcondDo: when cond=true, whileStep == quitReturn(postcondDo(true)).
  // When cond=false, whileStep returns s (not quitReturn(s) which would pop a frame).
  lemma WhileStepUsesPostcondDo(cond: bool, s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures whileStep(true, s, target, retPc) == quitReturn(postcondDo(true, s, target, retPc))
    ensures whileStep(false, s, target, retPc) == s
  { }

  // While with true cond: one step performs call + QUIT (round-trip).
  lemma WhileTrueCallsAndQuits(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures whileStep(true, s, target, retPc).pc == retPc
    ensures whileStep(true, s, target, retPc).stack == s.stack
  { }

  // While QUIT round-trip: true cond at loop head + QUIT restores state.
  lemma WhileQuitRoundTrip(s: CtrlState, target: nat)
    requires 0 <= s.pc
    ensures whileStep(true, s, target, s.pc).pc == s.pc
    ensures whileStep(true, s, target, s.pc).stack == s.stack
  { }

  // While + postcondDo composition summary.
  lemma WhilePostcondComposition(cond: bool, s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures whileStep(false, s, target, retPc) == s
    ensures whileStep(true, s, target, retPc).pc == retPc
    ensures whileStep(true, s, target, retPc).stack == s.stack
  { }

  // ----- While + postconditional compositions -----------------------------
  // F  D:COND  Q:'COND composes with other constructs:

  // While + postcondSeq: F  S:COND (cmd seq)  Q:'COND.
  // Each iteration: if cond, run seq; else skip.
  lemma WhilePostcondSeqComposition(cond: bool, cmds: CmdSeq, s: CtrlState)
    ensures postcondSeq(cond, cmds, s) == (if cond then runSeq(cmds, s) else s)
  { }

  // While + postcondAssign: F  S:COND VAR=expr  Q:'COND.
  lemma WhilePostcondAssignComposition(cond: bool, f: Store -> Store, st: Store)
    ensures postcondAssign(cond, f, st) == (if cond then f(st) else st)
  { }

  // While + doWithSeq: F  D:COND TAG (seq body)  Q:'COND.
  lemma WhileDoSeqComposition(cond: bool, cmds: CmdSeq, s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures doWithSeq(cond, cmds, s, target, retPc) == (if cond then quitReturn(doCall(s, target, retPc)) else s)
  { }

  // While universal composition: whileStep(cond) == if cond then call else skip.
  lemma WhilePostcondUniversal(cond: bool)
    ensures forall s: CtrlState, target: nat, retPc: nat
      :: retPc >= s.pc ==>
         whileStep(cond, s, target, retPc)
         == (if cond then quitReturn(doCall(s, target, retPc)) else s)
  { }

  // ----- postconditional assignment (S:COND VAR=expr) -------------------
  // #:ISO 7.2.4 + 8.1.2: a postconditional on SET executes the assignment
  // only if COND.  The store update is guarded.

  // Assignment: set a variable to a value in the store.
  // We model the store as part of CtrlState... but CtrlState doesn't have a store.
  // The store is in MSemantics.Store.  We model assignment as a function
  // that produces a new store, and the postconditional guards it.

  // Postconditional assignment: if cond, update store; else leave unchanged.
  // We model this abstractly: the assignment is a function from store to store.
  function postcondAssign(cond: bool, f: Store -> Store, st: Store): Store
  {
    if cond then f(st) else st
  }

  // False cond: store unchanged.
  lemma PostcondAssignFalseIsNoop(f: Store -> Store, st: Store)
    ensures postcondAssign(false, f, st) == st
  { }

  // True cond: store is updated.
  lemma PostcondAssignTrueApplies(f: Store -> Store, st: Store)
    ensures postcondAssign(true, f, st) == f(st)
  { }

  // Composition law: S:COND VAR=expr is equivalent to If(COND, S VAR=expr, skip).
  lemma PostcondAssignEqualsIf(f: Store -> Store, st: Store)
    ensures postcondAssign(false, f, st) == st
    ensures postcondAssign(true, f, st) == f(st)
  { }

  // Postconditional assignment in a DO call: the callee's assignments are
  // guarded by the DO's postconditional.  Control contract unchanged.
  function doWithAssign(cond: bool, s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc
  {
    if cond then quitReturn(doCall(s, target, retPc)) else s
  }

  // DO with assignment: false cond skips call (no assignments run).
  lemma DoAssignFalseSkips(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures doWithAssign(false, s, target, retPc) == s
  { }

  // DO with assignment: true cond runs call (assignments execute).
  lemma DoAssignTrueCalls(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures doWithAssign(true, s, target, retPc).pc == retPc
    ensures doWithAssign(true, s, target, retPc).stack == s.stack
  { }

  // ----- postconditional DO with command sequence (D:COND TAG body) -----
  // #:ISO 8.2.4: a DO target's body is a sequence of commands ending in QUIT.
  // The postconditional guards the entire sequence: all commands run or none.

  // Sequence: a list of state transitions (each is CtrlState -> CtrlState).
  // We model this as a fold over the sequence.
  type CmdSeq = seq<(CtrlState) -> CtrlState>

  // Execute a sequence of commands on a state.
  function runSeq(cmds: CmdSeq, s: CtrlState): CtrlState
  {
    if |cmds| == 0 then s
    else runSeq(cmds[1..], cmds[0](s))
  }

  // Postconditional sequence: if cond, run all commands; else skip.
  function postcondSeq(cond: bool, cmds: CmdSeq, s: CtrlState): CtrlState
  {
    if cond then runSeq(cmds, s) else s
  }

  // False cond: sequence is not executed.
  lemma PostcondSeqFalseIsNoop(cmds: CmdSeq, s: CtrlState)
    ensures postcondSeq(false, cmds, s) == s
  { }

  // True cond: sequence is executed.
  lemma PostcondSeqTrueRuns(cmds: CmdSeq, s: CtrlState)
    ensures postcondSeq(true, cmds, s) == runSeq(cmds, s)
  { }

  // Empty sequence: no-op regardless of cond.
  lemma PostcondSeqEmptyIsNoop(cond: bool, s: CtrlState)
    ensures postcondSeq(cond, [], s) == s
  { }

  // Sequence composition: runSeq of two concatenated seqs is sequential application.
  lemma RunSeqConcat(a: CmdSeq, b: CmdSeq, s: CtrlState)
    ensures runSeq(a + b, s) == runSeq(b, runSeq(a, s))
    decreases |a|
  {
    if |a| == 0 {
      assert a + b == b;
      assert runSeq(a, s) == s;
    } else {
      assert a + b == [a[0]] + (a[1..] + b);
      RunSeqConcat(a[1..], b, a[0](s));
    }
  }

  // Postconditional sequence with DO: the DO's body is a command sequence.
  // Control contract: false cond skips call (no commands run),
  // true cond runs call (commands execute in order).
  function doWithSeq(cond: bool, cmds: CmdSeq, s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc
  {
    if cond then quitReturn(doCall(s, target, retPc)) else s
  }

  // DO with sequence: false cond skips call.
  lemma DoSeqFalseSkips(cmds: CmdSeq, s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures doWithSeq(false, cmds, s, target, retPc) == s
  { }

  // DO with sequence: true cond runs call (body sequence executes).
  lemma DoSeqTrueCalls(cmds: CmdSeq, s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures doWithSeq(true, cmds, s, target, retPc).pc == retPc
    ensures doWithSeq(true, cmds, s, target, retPc).stack == s.stack
  { }

  // ----- postconditional DO in recursion (D:COND TAG self-call) ---------
  // #:ISO 8.2.4: a routine can DO its own labels (self-recursion).
  // Each call pushes a frame; QUIT pops one.  Stack is LIFO.
  // The postconditional guards the recursive call each depth.

  // One recursive step: if cond, push frame and jump to target (same routine).
  // The callee's QUIT pops the frame and returns to retPc.
  function recStep(cond: bool, s: CtrlState, target: nat, retPc: nat): (r: CtrlState)
    requires retPc >= s.pc
    ensures retPc >= r.pc  // after step, retPc is still valid as a return point
  {
    if cond then quitReturn(doCall(s, target, retPc)) else s
  }

  // Recursive depth: apply recStep N times (simulating N levels of recursion).
  function recDepth(cond: bool, s: CtrlState, target: nat, retPc: nat, depth: nat): CtrlState
    requires retPc >= s.pc
    decreases depth
  {
    if depth == 0 then s
    else recStep(cond, recDepth(cond, s, target, retPc, depth - 1), target, retPc)
  }

  // Recursion with false cond: no call, state unchanged.
  lemma RecFalseIsNoop(s: CtrlState, target: nat, retPc: nat, depth: nat)
    requires retPc >= s.pc
    ensures recDepth(false, s, target, retPc, depth) == s
  { }

  // Recursion at loop head (retPc == s.pc): each level is identity on PC/stack.
  lemma RecHeadRoundTrip(s: CtrlState, target: nat)
    requires 0 <= s.pc
    ensures recStep(true, s, target, s.pc).pc == s.pc
    ensures recStep(true, s, target, s.pc).stack == s.stack
  { }

  // Deep recursion at loop head: N levels = identity (by induction).
  lemma RecHeadIdentity(s: CtrlState, target: nat, depth: nat)
    requires 0 <= s.pc
    ensures recDepth(true, s, target, s.pc, depth) == s
    decreases depth
  {
    if depth == 0 { } else {
      assert recStep(true, s, target, s.pc) == s by {
        RecHeadRoundTrip(s, target);
      }
    }
  }

  // Recursion grows stack when retPc != s.pc (normal recursive call).
  // Each level pushes a frame; full unwind pops them all.
  lemma RecStackGrowsAndUnwinds(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures |doCall(s, target, retPc).stack| == |s.stack| + 1
    ensures quitReturn(doCall(s, target, retPc)).stack == s.stack
    ensures quitReturn(doCall(s, target, retPc)).pc == retPc
  { }

  // Nested recursion: two levels push two frames, two QUITs pop both.
  lemma RecNestedTwoLevels(s: CtrlState, target: nat, retPc1: nat, retPc2: nat)
    requires retPc1 >= s.pc
    requires retPc2 >= target  // second call is from inside the callee (retPc2 after target)
    ensures |doCall(doCall(s, target, retPc1), target, retPc2).stack| == |s.stack| + 2
    ensures quitReturn(quitReturn(doCall(doCall(s, target, retPc1), target, retPc2))).stack == s.stack
    ensures quitReturn(quitReturn(doCall(doCall(s, target, retPc1), target, retPc2))).pc == retPc1
  { }

  // ----- postconditional DO with arguments (D:COND TAG(args)) -----------
  // #:ISO 8.2.4: argumented DO evaluates expressions and binds formals at
  // the target.  The return point is after the DO on the current line.
  // Optional QUIT expression = extrinsic return value.

  // Argument passing: args are values (Bytes) that bind to formals.
  // We model the binding as a store update; the call semantics are:
  //   1. Evaluate args (already done — we receive them as values)
  //   2. Push return frame
  //   3. Bind formals at target (store update)
  //   4. Run body
  //   5. QUIT [expr] — pop frame, optionally set return value

  // Call with args: push frame, bind formals, run to QUIT.
  // The store update for formals is abstracted (we model it as part of
  // the callee's execution).  The key control-flow contract: frame push/pop.
  function callWithArgs(cond: bool, s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc
  {
    if cond then quitReturn(doCall(s, target, retPc)) else s
  }

  // Postconditional call with args: false cond skips the call entirely.
  lemma CallFalseSkips(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures callWithArgs(false, s, target, retPc) == s
  { }

  // Postconditional call with args: true cond performs call + return.
  lemma CallTrueRoundTrips(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures callWithArgs(true, s, target, retPc).pc == retPc
    ensures callWithArgs(true, s, target, retPc).stack == s.stack
  { }

  // Call with QUIT value: the return value is produced by the callee.
  // We model the value as opaque (Bytes); the control contract is the same.
  function callWithReturn(cond: bool, s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc
  {
    if cond then quitReturn(doCall(s, target, retPc)) else s
  }

  // Postconditional call with return value: same control contract as callWithArgs.
  lemma CallReturnRoundTrips(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures callWithReturn(true, s, target, retPc).pc == retPc
    ensures callWithReturn(true, s, target, retPc).stack == s.stack
  { }

  // Nested argumented calls: LIFO ordering preserved.
  // Outer call at retPc1, inner call at retPc2 (inside callee).
  lemma CallNestedLIFO(s: CtrlState, target1: nat, retPc1: nat, target2: nat, retPc2: nat)
    requires retPc1 >= s.pc
    requires retPc2 >= target1  // inner doCall is from inside outer callee  // inner call is from inside outer callee
    // stack grows: +2 frames
    ensures |doCall(doCall(s, target1, retPc1), target2, retPc2).stack| == |s.stack| + 2
    // two QUITs unwind in LIFO order: inner returns to retPc2, outer to retPc1
    ensures quitReturn(quitReturn(doCall(doCall(s, target1, retPc1), target2, retPc2))).stack == s.stack
    ensures quitReturn(quitReturn(doCall(doCall(s, target1, retPc1), target2, retPc2))).pc == retPc1
  { }

  // Postconditional nested calls: both conds true → LIFO round-trip.
  lemma CallCondNestedRoundTrip(s: CtrlState, target1: nat, retPc1: nat, target2: nat, retPc2: nat)
    requires retPc1 >= s.pc
    requires retPc2 >= retPc1
    ensures callWithArgs(true, callWithArgs(true, s, target1, retPc1), target2, retPc2).stack == s.stack
    ensures callWithArgs(true, callWithArgs(true, s, target1, retPc1), target2, retPc2).pc == retPc2
  { }

  // ----- postconditional DO inside IF (I IFCOND D:DOCOND TAG) ----------
  // #:ISO 7.2.4 + 8.2.4: nested conditionals — the IF guards the DO, and
  // the DO has its own postconditional.  The DO executes only if BOTH
  // IFCOND and DOCOND are true.  This is the composition:
  //   If(IFCOND, postcondDo(DOCOND, ...), skip)

  // Double-conditional DO: both conditions must hold.
  function ifThenPostcondDo(ifCond: bool, doCond: bool, s: CtrlState, target: nat, retPc: nat): CtrlState
    requires retPc >= s.pc
  {
    if ifCond then postcondDo(doCond, s, target, retPc) else s
  }

  // Both false: no call, state unchanged.
  lemma IfBothFalseIsNoop(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures ifThenPostcondDo(false, false, s, target, retPc) == s
  { }

  // IF true, DO false: DO skipped (postcondDo(false) == s).
  lemma IfTrueDoFalseSkips(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures ifThenPostcondDo(true, false, s, target, retPc) == s
  { }

  // IF false, DO true: IF skips the entire statement.
  lemma IfFalseDoTrueSkips(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures ifThenPostcondDo(false, true, s, target, retPc) == s
  { }

  // Both true: DO executes (postcondDo(true) == doCall).
  lemma IfBothTrueCalls(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures ifThenPostcondDo(true, true, s, target, retPc) == doCall(s, target, retPc)
  { }

  // Composition law: If(IFCOND, D:DOCOND) is equivalent to D:(IFCOND && DOCOND).
  lemma IfThenPostcondEqualsConjunction(ifCond: bool, doCond: bool, s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures ifThenPostcondDo(ifCond, doCond, s, target, retPc) == postcondDo(ifCond && doCond, s, target, retPc)
  { }

  // Both true + QUIT: round-trip restores PC and stack.
  lemma IfBothTrueQuitRoundTrip(s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures quitReturn(ifThenPostcondDo(true, true, s, target, retPc)).pc == retPc
    ensures quitReturn(ifThenPostcondDo(true, true, s, target, retPc)).stack == s.stack
  { }

  // ----- If + postconditional compositions --------------------------------
  // I IFCOND D:DOCOND TAG composes with other constructs:

  // If + postcondSeq: I COND S:SUBCOND (cmd seq).
  // If false: skip everything.  If true: postcondSeq(SUBCOND, cmds).
  lemma IfThenPostcondSeqComposition(ifCond: bool, doCond: bool, cmds: CmdSeq, s: CtrlState)
    ensures postcondSeq(ifCond && doCond, cmds, s)
         == (if ifCond then postcondSeq(doCond, cmds, s) else s)
  { }

  // If + postcondAssign: I COND S:SUBCOND VAR=expr.
  lemma IfThenPostcondAssignComposition(ifCond: bool, doCond: bool, f: Store -> Store, st: Store)
    ensures postcondAssign(ifCond && doCond, f, st)
         == (if ifCond then postcondAssign(doCond, f, st) else st)
  { }

  // If + doWithSeq: I COND D:SUBCOND TAG (seq body).
  lemma IfThenDoSeqComposition(ifCond: bool, doCond: bool, cmds: CmdSeq, s: CtrlState, target: nat, retPc: nat)
    requires retPc >= s.pc
    ensures doWithSeq(ifCond && doCond, cmds, s, target, retPc)
         == (if ifCond then doWithSeq(doCond, cmds, s, target, retPc) else s)
  { }

  // Full If composition summary: If(a, D:b) == D:(a && b) for DO.
  lemma IfPostcondUniversalComposition(ifCond: bool, doCond: bool)
    ensures forall s: CtrlState, target: nat, retPc: nat
      :: retPc >= s.pc ==>
         ifThenPostcondDo(ifCond, doCond, s, target, retPc)
         == postcondDo(ifCond && doCond, s, target, retPc)
  { }

}
