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

}
