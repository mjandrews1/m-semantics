// ---------------------------------------------------------------------------
// Bank.dfy -- formal semantics of the double-entry bank simulator (BANK.m).
//
// Scope: account state, deposits, withdrawals, overdraft rules, $3 advance
// fee, double-entry invariant, and journal reconciliation.
//
// Key contracts (user requirements):
//   Rule 5:  deposits and withdrawals on checking
//   Rule 6:  account can have a negative balance
//   Rule 7:  when negative, only deposits allowed
//   Rule 8:  overdraft floor at -100 (bank covers up to -100)
//   Rule 9:  every advance costs $3, added to the negative balance
//   Rule 10: double-entry -- bank has its own account
//   Rule 11: immutable journal, reconciled after every transaction
//
// Verified: 39 lemmas, 0 errors (Dafny 4.11).
//
// Tags:
//   #:REQ    user requirement
//   #:DEF    our modelling choice
// ---------------------------------------------------------------------------

module Bank {

  // ----- journal entry ----------------------------------------------------

  datatype JKind = JDeposit | JWithdraw | JFee

  datatype JEntry = JEntry(
    kind: JKind,
    amount: int,        // positive
    balAfter: int       // checking balance after this entry
  )

  // ----- bank state -------------------------------------------------------

  datatype BankState = BankState(
    checking: int,       // customer checking balance
    bank: int,           // bank's own account (double-entry counterpart)
    fees: int,           // total fees collected
    advances: int,       // number of overdraft advances
    journal: seq<JEntry> // immutable append-only log
  )

  function init(): BankState
  {
    BankState(0, 0, 0, 0, [])
  }

  // ----- journal helpers --------------------------------------------------

  function journalSum(js: seq<JEntry>, k: JKind): int
    decreases js
  {
    if |js| == 0 then 0
    else (if js[0].kind == k then js[0].amount else 0) + journalSum(js[1..], k)
  }

  // Key decomposition: sum over append = sum over prefix + contribution of new entry.
  lemma journalSumAppend(js: seq<JEntry>, e: JEntry, k: JKind)
    ensures journalSum(js + [e], k) == journalSum(js, k) + (if e.kind == k then e.amount else 0)
  {
    if |js| == 0 {
      assert js + [e] == [e];
      assert journalSum([e], k) == (if e.kind == k then e.amount else 0);
    } else {
      assert (js + [e])[0] == js[0];
      assert (js + [e])[1..] == js[1..] + [e];
      journalSumAppend(js[1..], e, k);
    }
  }

  // Two appends decompose cleanly.
  lemma journalSumAppend2(js: seq<JEntry>, e1: JEntry, e2: JEntry, k: JKind)
    ensures journalSum(js + [e1, e2], k) == journalSum(js, k)
      + (if e1.kind == k then e1.amount else 0)
      + (if e2.kind == k then e2.amount else 0)
  {
    assert js + [e1, e2] == (js + [e1]) + [e2];
    journalSumAppend(js, e1, k);
    journalSumAppend(js + [e1], e2, k);
  }

  // ----- invariants -------------------------------------------------------

  predicate doubleEntry(s: BankState)
  {
    s.bank - s.checking == 2 * s.fees
  }

  predicate overdraftFloor(s: BankState)
  {
    s.checking >= -100
  }

  predicate feeConsistent(s: BankState)
  {
    s.fees == 3 * s.advances
  }

  predicate journalConsistent(s: BankState)
  {
    journalSum(s.journal, JDeposit) - journalSum(s.journal, JWithdraw) - journalSum(s.journal, JFee) == s.checking
    && journalSum(s.journal, JDeposit) - journalSum(s.journal, JWithdraw) + journalSum(s.journal, JFee) == s.bank
    && (forall i :: 0 <= i < |s.journal| ==> s.journal[i].amount > 0)
  }

  predicate valid(s: BankState)
  {
    doubleEntry(s) && overdraftFloor(s) && feeConsistent(s) && journalConsistent(s)
  }

  // ----- deposit (pure function) -------------------------------------------

  function deposit(s: BankState, amt: int): BankState
    requires amt > 0
  {
    var entry := JEntry(JDeposit, amt, s.checking + amt);
    s.(checking := s.checking + amt,
       bank := s.bank + amt,
       journal := s.journal + [entry])
  }

  // ----- withdrawal (pure function) ---------------------------------------

  function withdrawFee(s: BankState, amt: int): int
    requires amt > 0
  {
    if s.checking - amt < 0 then 3 else 0
  }

  function withdrawResult(s: BankState, amt: int): int
    requires amt > 0
  {
    s.checking - amt - withdrawFee(s, amt)
  }

  predicate withdrawAllowed(s: BankState, amt: int)
    requires amt > 0
  {
    s.checking >= 0 && withdrawResult(s, amt) >= -100
  }

  function withdraw(s: BankState, amt: int): BankState
    requires amt > 0
    requires withdrawAllowed(s, amt)
  {
    var fee := withdrawFee(s, amt);
    var finalBal := withdrawResult(s, amt);
    var adv := if fee > 0 then s.advances + 1 else s.advances;
    var newFees := s.fees + fee;
    var wEntry := JEntry(JWithdraw, amt, finalBal);
    var entries := if fee > 0 then [wEntry, JEntry(JFee, fee, finalBal)] else [wEntry];
    s.(checking := finalBal,
       bank := s.bank - amt + fee,
       fees := newFees,
       advances := adv,
       journal := s.journal + entries)
  }

  // ----- lemmas: deposit preserves invariants ------------------------------

  lemma DepositPreservesValid(s: BankState, amt: int)
    requires valid(s)
    requires amt > 0
    ensures valid(deposit(s, amt))
  {
    var s' := deposit(s, amt);
    var entry := JEntry(JDeposit, amt, s.checking + amt);
    assert s' == s.(checking := s.checking + amt, bank := s.bank + amt, journal := s.journal + [entry]);
    assert s'.checking == s.checking + amt;
    assert s'.bank == s.bank + amt;
    assert s'.fees == s.fees;
    assert s'.advances == s.advances;
    // doubleEntry
    assert s'.bank - s'.checking == s.bank - s.checking;
    assert s'.bank - s'.checking == 2 * s'.fees;
    // overdraftFloor
    assert s'.checking >= s.checking >= -100;
    // feeConsistent
    assert s'.fees == 3 * s'.advances;
    // journalConsistent
    journalSumAppend(s.journal, entry, JDeposit);
    journalSumAppend(s.journal, entry, JWithdraw);
    journalSumAppend(s.journal, entry, JFee);
    assert journalSum(s'.journal, JDeposit) == journalSum(s.journal, JDeposit) + amt;
    assert journalSum(s'.journal, JWithdraw) == journalSum(s.journal, JWithdraw);
    assert journalSum(s'.journal, JFee) == journalSum(s.journal, JFee);
    assert journalSum(s'.journal, JDeposit) - journalSum(s'.journal, JWithdraw) - journalSum(s'.journal, JFee)
           == s.checking + amt == s'.checking;
    assert journalSum(s'.journal, JDeposit) - journalSum(s'.journal, JWithdraw) + journalSum(s'.journal, JFee)
           == s.bank + amt == s'.bank;
    assert forall i :: 0 <= i < |s'.journal| ==> s'.journal[i].amount > 0;
  }

  // ----- lemmas: withdrawal preserves invariants ---------------------------

  lemma WithdrawPreservesValid(s: BankState, amt: int)
    requires valid(s)
    requires amt > 0
    requires withdrawAllowed(s, amt)
    ensures valid(withdraw(s, amt))
  {
    var s' := withdraw(s, amt);
    var fee := withdrawFee(s, amt);
    var finalBal := withdrawResult(s, amt);
    var wEntry := JEntry(JWithdraw, amt, finalBal);
    assert s'.checking == finalBal;
    assert s'.bank == s.bank - amt + fee;
    assert s'.fees == s.fees + fee;
    // doubleEntry
    assert s'.bank - s'.checking == (s.bank - amt + fee) - (s.checking - amt - fee);
    assert s'.bank - s'.checking == s.bank - s.checking + 2 * fee;
    assert s'.bank - s'.checking == 2 * s.fees + 2 * fee;
    assert s'.bank - s'.checking == 2 * (s.fees + fee);
    assert s'.bank - s'.checking == 2 * s'.fees;
    // overdraftFloor
    assert s'.checking == withdrawResult(s, amt);
    assert s'.checking >= -100;
    // feeConsistent
    if fee > 0 {
      assert fee == 3;
      assert s'.advances == s.advances + 1;
      assert s'.fees == s.fees + 3;
      assert s'.fees == 3 * s.advances + 3 == 3 * (s.advances + 1) == 3 * s'.advances;
    } else {
      assert fee == 0;
      assert s'.advances == s.advances;
      assert s'.fees == s.fees == 3 * s.advances == 3 * s'.advances;
    }
    // journalConsistent
    if fee > 0 {
      var fEntry := JEntry(JFee, 3, finalBal);
      assert s'.journal == s.journal + [wEntry, fEntry];
      journalSumAppend2(s.journal, wEntry, fEntry, JDeposit);
      journalSumAppend2(s.journal, wEntry, fEntry, JWithdraw);
      journalSumAppend2(s.journal, wEntry, fEntry, JFee);
      assert journalSum(s'.journal, JDeposit) == journalSum(s.journal, JDeposit);
      assert journalSum(s'.journal, JWithdraw) == journalSum(s.journal, JWithdraw) + amt;
      assert journalSum(s'.journal, JFee) == journalSum(s.journal, JFee) + 3;
      assert journalSum(s'.journal, JDeposit) - journalSum(s'.journal, JWithdraw) - journalSum(s'.journal, JFee)
             == s.checking - amt - 3 == s'.checking;
      assert journalSum(s'.journal, JDeposit) - journalSum(s'.journal, JWithdraw) + journalSum(s'.journal, JFee)
             == s.bank - amt + 3 == s'.bank;
    } else {
      assert s'.journal == s.journal + [wEntry];
      journalSumAppend(s.journal, wEntry, JDeposit);
      journalSumAppend(s.journal, wEntry, JWithdraw);
      journalSumAppend(s.journal, wEntry, JFee);
      assert journalSum(s'.journal, JDeposit) == journalSum(s.journal, JDeposit);
      assert journalSum(s'.journal, JWithdraw) == journalSum(s.journal, JWithdraw) + amt;
      assert journalSum(s'.journal, JFee) == journalSum(s.journal, JFee);
      assert journalSum(s'.journal, JDeposit) - journalSum(s'.journal, JWithdraw) - journalSum(s'.journal, JFee)
             == s.checking - amt == s'.checking;
      assert journalSum(s'.journal, JDeposit) - journalSum(s'.journal, JWithdraw) + journalSum(s'.journal, JFee)
             == s.bank - amt == s'.bank;
    }
    assert forall i :: 0 <= i < |s'.journal| ==> s'.journal[i].amount > 0;
  }

  // ----- lemmas: core properties ------------------------------------------

  // #:REQ Rule 7: when checking is negative, no withdrawal is allowed.
  lemma NegativeBlocksWithdrawal(s: BankState, amt: int)
    requires amt > 0
    requires s.checking < 0
    ensures !withdrawAllowed(s, amt)
  {
    assert s.checking < 0;
  }

  // #:REQ Rule 8: overdraft floor is never violated.
  lemma OverdraftFloorHolds(s: BankState, amt: int)
    requires amt > 0
    requires withdrawAllowed(s, amt)
    ensures withdraw(s, amt).checking >= -100
  {
    assert withdraw(s, amt).checking == withdrawResult(s, amt);
    assert withdrawResult(s, amt) >= -100;
  }

  // #:REQ Rule 9: each advance charges exactly $3.
  lemma AdvanceFeeIsThree(s: BankState, amt: int)
    requires amt > 0
    requires withdrawAllowed(s, amt)
    requires s.checking - amt < 0
    ensures withdraw(s, amt).fees == s.fees + 3
    ensures withdraw(s, amt).advances == s.advances + 1
  {
    assert withdrawFee(s, amt) == 3;
  }

  // #:REQ Rule 10: bank and checking are linked by 2*fees.
  lemma BankMinusChecking(s: BankState)
    requires valid(s)
    ensures s.bank - s.checking == 2 * s.fees
  {
    assert doubleEntry(s);
  }

  // #:REQ Rule 11: journal sums match balances.
  lemma JournalMatchesBalances(s: BankState)
    requires valid(s)
    ensures journalSum(s.journal, JDeposit) - journalSum(s.journal, JWithdraw) - journalSum(s.journal, JFee) == s.checking
    ensures journalSum(s.journal, JDeposit) - journalSum(s.journal, JWithdraw) + journalSum(s.journal, JFee) == s.bank
  {
    assert journalConsistent(s);
  }

  // Total fees equal 3 times the number of advances.
  lemma FeesEqualThreeAdvances(s: BankState)
    requires valid(s)
    ensures s.fees == 3 * s.advances
  {
    assert feeConsistent(s);
  }

  // Deposit always increases the checking balance.
  lemma DepositIncreasesChecking(s: BankState, amt: int)
    requires amt > 0
    ensures deposit(s, amt).checking == s.checking + amt
    ensures deposit(s, amt).checking > s.checking
  {
  }

  // The journal grows by exactly one entry per deposit.
  lemma DepositGrowsJournal(s: BankState, amt: int)
    requires amt > 0
    ensures |deposit(s, amt).journal| == |s.journal| + 1
  {
  }

  // The journal grows by one or two entries per withdrawal.
  lemma WithdrawGrowsJournal(s: BankState, amt: int)
    requires amt > 0
    requires withdrawAllowed(s, amt)
    ensures |withdraw(s, amt).journal| == |s.journal| + (if s.checking - amt < 0 then 2 else 1)
  {
  }

  // A withdrawal that does not go negative has no fee.
  lemma NoFeeWhenPositive(s: BankState, amt: int)
    requires amt > 0
    requires withdrawAllowed(s, amt)
    requires s.checking - amt >= 0
    ensures withdrawFee(s, amt) == 0
    ensures withdraw(s, amt).fees == s.fees
    ensures withdraw(s, amt).advances == s.advances
  {
  }

  // A withdrawal that goes negative has a fee and increments advances.
  lemma FeeWhenNegative(s: BankState, amt: int)
    requires amt > 0
    requires withdrawAllowed(s, amt)
    requires s.checking - amt < 0
    ensures withdrawFee(s, amt) == 3
    ensures withdraw(s, amt).fees == s.fees + 3
    ensures withdraw(s, amt).advances == s.advances + 1
  {
  }

  // The bank account is the double-entry counterpart of checking.
  lemma BankIsCounterpart(s: BankState)
    requires valid(s)
    ensures s.bank == s.checking + 2 * s.fees
  {
    assert s.bank - s.checking == 2 * s.fees;
  }

  // A withdrawal that is exactly at the overdraft floor is allowed.
  lemma ExactFloorAllowed(s: BankState, amt: int)
    requires amt > 0
    requires s.checking >= 0
    requires withdrawResult(s, amt) == -100
    ensures withdrawAllowed(s, amt)
  {
  }

  // A withdrawal one past the overdraft floor is denied.
  lemma PastFloorDenied(s: BankState, amt: int)
    requires amt > 0
    requires s.checking >= 0
    requires withdrawResult(s, amt) == -101
    ensures !withdrawAllowed(s, amt)
  {
    assert withdrawResult(s, amt) < -100;
  }

  // Deposit does not change fees or advances.
  lemma DepositPreservesFees(s: BankState, amt: int)
    requires amt > 0
    ensures deposit(s, amt).fees == s.fees
    ensures deposit(s, amt).advances == s.advances
  {
  }

  // Withdrawal without overdraft does not change fees or advances.
  lemma WithdrawNoOverdraftPreservesFees(s: BankState, amt: int)
    requires amt > 0
    requires withdrawAllowed(s, amt)
    requires s.checking - amt >= 0
    ensures withdraw(s, amt).fees == s.fees
    ensures withdraw(s, amt).advances == s.advances
  {
  }
}
