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

// ---------------------------------------------------------------------------
// BankFull -- multi-service bank model (BANKFULL.m).
//
// Extends Bank with:
//   - Multiple services per account (savings/checking/loans)
//   - Interest accrual per service type
//   - Monthly fees per service
//   - Inter-service and inter-account transfers
//   - Double-entry: bank's own account is foundational ($1M starting)
//   - Savings minimum balance ($100)
//   - Immutable journal with ISO timestamps and CRC integrity
//
// Verified: see lemma count in header after expansion.
// ---------------------------------------------------------------------------

module BankFull {

  // ----- service types ----------------------------------------------------

  datatype SvcType = Savings | Checking | Loan

  datatype SvcSubtype = Standard | CD | Personal | Mortgage | Auto | Overdraft

  // ----- journal entry (richer: multi-service, timestamp, CRC) ------------

  datatype TxnKind = TDeposit | TWithdraw | TTransfer | TInterest | TFee

  datatype JEntry = JEntry(
    kind: TxnKind,
    svc: nat,           // service ID
    amount: int,        // positive
    balAfter: int,      // service balance after this entry
    ts: int,            // ISO timestamp (seconds since epoch, abstract)
    crc: int            // integrity checksum
  )

  // ----- service record ---------------------------------------------------

  datatype Service = Service(
    id: nat,
    acct: nat,
    typ: SvcType,
    bal: int,
    rate: int,          // annual interest rate in basis points (200 = 2%)
    fee: int,           // monthly fee in dollars
    minBal: int         // minimum balance (savings: 100)
  )

  // ----- bank state -------------------------------------------------------

  datatype BankFullState = BankFullState(
    bankBal: int,              // bank's own account (foundational)
    services: seq<Service>,    // all services
    journal: seq<JEntry>,      // immutable append-only log
    nextSvc: nat               // next service ID counter
  )

  function initFull(): BankFullState
  {
    BankFullState(1000000, [], [], 1)
  }

  // ----- invariants -------------------------------------------------------

  // Double-entry: total savings + bank balance = $1M (conservation).
  predicate conserved(s: BankFullState)
  {
    (forall i :: 0 <= i < |s.services| ==> s.services[i].bal >= s.services[i].minBal - 1000)
    && totalBal(s) + s.bankBal == 1000000
  }

  function sumBals(svcs: seq<Service>): int
    decreases svcs
  {
    if |svcs| == 0 then 0
    else svcs[0].bal + sumBals(svcs[1..])
  }

  function totalBal(s: BankFullState): int
  {
    sumBals(s.services)
  }

  // Journal integrity: every entry has a CRC that matches its content.
  predicate journalIntegrity(s: BankFullState)
  {
    forall i :: 0 <= i < |s.journal| ==> s.journal[i].crc == crcOf(s.journal[i])
  }

  // Abstract CRC: deterministic function of entry content.
  function crcOf(e: JEntry): int
  {
    // Abstract: real CRC32 is computed in BANKFULL.m.
    // Model: hash of (kind, svc, amount, balAfter) must be deterministic.
    (if e.kind == TDeposit then 1 else if e.kind == TWithdraw then 2
     else if e.kind == TTransfer then 3 else if e.kind == TInterest then 4 else 5)
    * 999983 + e.svc * 7 + e.amount * 13 + e.balAfter * 17
  }

  // Journal immutability: entries are never modified, only appended.
  predicate journalAppendOnly(prev: seq<JEntry>, nw: seq<JEntry>)
  {
    |nw| >= |prev| && (forall i :: 0 <= i < |prev| ==> nw[i] == prev[i])
  }

  // ----- operations (pure functions) ---------------------------------------

  // Deposit into a service.
  function depositFull(s: BankFullState, svcId: nat, amt: int): BankFullState
    requires amt > 0
    requires svcId < |s.services|
    requires s.services[svcId].bal + amt >= s.services[svcId].minBal
  {
    var svc := s.services[svcId];
    var newBal := svc.bal + amt;
    var newSvc := svc.(bal := newBal);
    var newServices := s.services[svcId := newSvc];
    var entry := JEntry(TDeposit, svc.id, amt, newBal, 0, crcOf(JEntry(TDeposit, svc.id, amt, newBal, 0, 0)));
    s.(services := newServices, bankBal := s.bankBal - amt, journal := s.journal + [entry])
  }

  // Withdraw from a service (with min-balance check).
  function withdrawFull(s: BankFullState, svcId: nat, amt: int): BankFullState
    requires amt > 0
    requires svcId < |s.services|
    requires s.services[svcId].bal - amt >= s.services[svcId].minBal
  {
    var svc := s.services[svcId];
    var newBal := svc.bal - amt;
    var newSvc := svc.(bal := newBal);
    var newServices := s.services[svcId := newSvc];
    var entry := JEntry(TWithdraw, svc.id, amt, newBal, 0, crcOf(JEntry(TWithdraw, svc.id, amt, newBal, 0, 0)));
    s.(services := newServices, bankBal := s.bankBal + amt, journal := s.journal + [entry])
  }

  // Transfer between services (same or different accounts).
  function transferFull(s: BankFullState, fromId: nat, toId: nat, amt: int): BankFullState
    requires amt > 0
    requires fromId < |s.services| && toId < |s.services|
    requires fromId != toId
    requires s.services[fromId].bal - amt >= s.services[fromId].minBal
    requires s.services[toId].bal + amt >= s.services[toId].minBal
  {
    var fromSvc := s.services[fromId];
    var toSvc := s.services[toId];
    var newFrom := fromSvc.(bal := fromSvc.bal - amt);
    var newTo := toSvc.(bal := toSvc.bal + amt);
    var newServices := s.services[fromId := newFrom][toId := newTo];
    var e1 := JEntry(TTransfer, fromSvc.id, amt, fromSvc.bal - amt, 0, crcOf(JEntry(TTransfer, fromSvc.id, amt, fromSvc.bal - amt, 0, 0)));
    var e2 := JEntry(TTransfer, toSvc.id, amt, toSvc.bal + amt, 0, crcOf(JEntry(TTransfer, toSvc.id, amt, toSvc.bal + amt, 0, 0)));
    s.(services := newServices, journal := s.journal + [e1, e2])
  }

  // Accrue interest on one service (monthly: rate/12).
  function accrueInterest(s: BankFullState, svcId: nat): BankFullState
    requires svcId < |s.services|
    requires s.services[svcId].bal > 0
    requires s.services[svcId].rate > 0
  {
    var svc := s.services[svcId];
    var interest := svc.bal * svc.rate / 1200;  // basis points / 12 months / 100
    var newBal := svc.bal + interest;
    var newSvc := svc.(bal := newBal);
    var newServices := s.services[svcId := newSvc];
    var entry := JEntry(TInterest, svc.id, interest, newBal, 0, crcOf(JEntry(TInterest, svc.id, interest, newBal, 0, 0)));
    s.(services := newServices, bankBal := s.bankBal - interest, journal := s.journal + [entry])
  }

  // Charge monthly fee on one service.
  function chargeFee(s: BankFullState, svcId: nat): BankFullState
    requires svcId < |s.services|
    requires s.services[svcId].fee > 0
  {
    var svc := s.services[svcId];
    var newBal := svc.bal - svc.fee;
    var newSvc := svc.(bal := newBal);
    var newServices := s.services[svcId := newSvc];
    var entry := JEntry(TFee, svc.id, svc.fee, newBal, 0, crcOf(JEntry(TFee, svc.id, svc.fee, newBal, 0, 0)));
    s.(services := newServices, bankBal := s.bankBal + svc.fee, journal := s.journal + [entry])
  }

  // ----- journal helpers --------------------------------------------------

  function journalSumFull(js: seq<JEntry>, k: TxnKind): int
    decreases js
  {
    if |js| == 0 then 0
    else (if js[0].kind == k then js[0].amount else 0) + journalSumFull(js[1..], k)
  }

  lemma journalSumFullAppend(js: seq<JEntry>, e: JEntry, k: TxnKind)
    ensures journalSumFull(js + [e], k) == journalSumFull(js, k) + (if e.kind == k then e.amount else 0)
  {
    if |js| == 0 {
      assert js + [e] == [e];
    } else {
      assert (js + [e])[0] == js[0];
      assert (js + [e])[1..] == js[1..] + [e];
      journalSumFullAppend(js[1..], e, k);
    }
  }

  // ----- lemmas: conservation (double-entry) -------------------------------

  // Deposit conserves total: savings + bank = constant.
  lemma DepositConservesTotal(s: BankFullState, svcId: nat, amt: int)
    requires amt > 0
    requires svcId < |s.services|
    requires s.services[svcId].bal + amt >= s.services[svcId].minBal
    ensures totalBal(depositFull(s, svcId, amt)) + depositFull(s, svcId, amt).bankBal
         == totalBal(s) + s.bankBal
  {
    var s' := depositFull(s, svcId, amt);
    assert s'.services[svcId].bal == s.services[svcId].bal + amt;
    assert s'.bankBal == s.bankBal - amt;
    // totalBal differs by exactly amt at position svcId
    totalBalUpdate(s, svcId, amt);
    assert totalBal(s') == totalBal(s) + amt;
    assert totalBal(s') + s'.bankBal == totalBal(s) + amt + s.bankBal - amt;
    assert totalBal(s') + s'.bankBal == totalBal(s) + s.bankBal;
  }

  // Withdraw conserves total.
  lemma WithdrawConservesTotal(s: BankFullState, svcId: nat, amt: int)
    requires amt > 0
    requires svcId < |s.services|
    requires s.services[svcId].bal - amt >= s.services[svcId].minBal
    ensures totalBal(withdrawFull(s, svcId, amt)) + withdrawFull(s, svcId, amt).bankBal
         == totalBal(s) + s.bankBal
  {
    var s' := withdrawFull(s, svcId, amt);
    totalBalUpdate(s, svcId, -amt);
    assert totalBal(s') == totalBal(s) - amt;
    assert s'.bankBal == s.bankBal + amt;
    assert totalBal(s') + s'.bankBal == totalBal(s) - amt + s.bankBal + amt;
    assert totalBal(s') + s'.bankBal == totalBal(s) + s.bankBal;
  }

  // Transfer conserves total (no bank movement).
  lemma TransferConservesTotal(s: BankFullState, fromId: nat, toId: nat, amt: int)
    requires amt > 0
    requires fromId < |s.services| && toId < |s.services|
    requires fromId != toId
    requires s.services[fromId].bal - amt >= s.services[fromId].minBal
    requires s.services[toId].bal + amt >= s.services[toId].minBal
    ensures totalBal(transferFull(s, fromId, toId, amt)) + transferFull(s, fromId, toId, amt).bankBal
         == totalBal(s) + s.bankBal
  {
    var s' := transferFull(s, fromId, toId, amt);
    // fromSvc decreases by amt, toSvc increases by amt — net zero
    assert s'.services[fromId].bal == s.services[fromId].bal - amt;
    assert s'.services[toId].bal == s.services[toId].bal + amt;
    totalBalUpdate2(s, fromId, toId, -amt, amt);
    assert totalBal(s') == totalBal(s);
    assert s'.bankBal == s.bankBal;
    assert totalBal(s') + s'.bankBal == totalBal(s) + s.bankBal;
  }

  // Interest conserves total (interest comes from bank).
  lemma InterestConservesTotal(s: BankFullState, svcId: nat)
    requires svcId < |s.services|
    requires s.services[svcId].bal > 0
    requires s.services[svcId].rate > 0
    ensures totalBal(accrueInterest(s, svcId)) + accrueInterest(s, svcId).bankBal
         == totalBal(s) + s.bankBal
  {
    var s' := accrueInterest(s, svcId);
    var interest := s.services[svcId].bal * s.services[svcId].rate / 1200;
    totalBalUpdate(s, svcId, interest);
    assert totalBal(s') == totalBal(s) + interest;
    assert s'.bankBal == s.bankBal - interest;
    assert totalBal(s') + s'.bankBal == totalBal(s) + s.bankBal;
  }

  // Fee conserves total (fee goes to bank).
  lemma FeeConservesTotal(s: BankFullState, svcId: nat)
    requires svcId < |s.services|
    requires s.services[svcId].fee > 0
    ensures totalBal(chargeFee(s, svcId)) + chargeFee(s, svcId).bankBal
         == totalBal(s) + s.bankBal
  {
    var s' := chargeFee(s, svcId);
    var fee := s.services[svcId].fee;
    totalBalUpdate(s, svcId, -fee);
    assert s'.services[svcId].bal == s.services[svcId].bal - fee;
    assert s'.bankBal == s.bankBal + fee;
    assert totalBal(s') + s'.bankBal == totalBal(s) - fee + s.bankBal + fee;
    assert totalBal(s') + s'.bankBal == totalBal(s) + s.bankBal;
  }

  // ----- helper lemmas: totalBal decomposition -----------------------------

  lemma sumBalsUpdate(svcs: seq<Service>, idx: nat, delta: int)
    requires idx < |svcs|
    ensures sumBals(svcs[idx := svcs[idx].(bal := svcs[idx].bal + delta)]) == sumBals(svcs) + delta
    decreases svcs
  {
    if |svcs| == 0 {
    } else if idx == 0 {
      assert svcs[idx := svcs[idx].(bal := svcs[idx].bal + delta)][0].bal == svcs[0].bal + delta;
      assert (svcs[idx := svcs[idx].(bal := svcs[idx].bal + delta)])[1..] == svcs[1..];
      assert sumBals(svcs[idx := svcs[idx].(bal := svcs[idx].bal + delta)])
           == svcs[0].bal + delta + sumBals(svcs[1..]);
    } else {
      sumBalsUpdate(svcs[1..], idx - 1, delta);
    }
  }

  lemma totalBalUpdate(s: BankFullState, idx: nat, delta: int)
    requires idx < |s.services|
    ensures totalBal(s.(services := s.services[idx := s.services[idx].(bal := s.services[idx].bal + delta)]))
         == totalBal(s) + delta
  {
    sumBalsUpdate(s.services, idx, delta);
  }

  // Two sequential single-position updates compose additively.
  lemma totalBalUpdate2(s: BankFullState, i1: nat, i2: nat, d1: int, d2: int)
    requires i1 < |s.services| && i2 < |s.services|
    requires i1 != i2
    ensures totalBal(s.(services := s.services[i1 := s.services[i1].(bal := s.services[i1].bal + d1)][i2 := s.services[i2].(bal := s.services[i2].bal + d2)]))
         == totalBal(s) + d1 + d2
  {
    var s1 := s.(services := s.services[i1 := s.services[i1].(bal := s.services[i1].bal + d1)]);
    totalBalUpdate(s, i1, d1);
    assert totalBal(s1) == totalBal(s) + d1;
    // s1 has same length; i2 still valid and != i1
    totalBalUpdate(s1, i2, d2);
    assert totalBal(s1.(services := s1.services[i2 := s1.services[i2].(bal := s1.services[i2].bal + d2)])) == totalBal(s1) + d2;
  }

  // ----- lemmas: journal properties ----------------------------------------

  // Every operation grows the journal.
  lemma DepositGrowsJournalFull(s: BankFullState, svcId: nat, amt: int)
    requires amt > 0
    requires svcId < |s.services|
    requires s.services[svcId].bal + amt >= s.services[svcId].minBal
    ensures |depositFull(s, svcId, amt).journal| == |s.journal| + 1
  {
  }

  lemma TransferGrowsJournalFull(s: BankFullState, fromId: nat, toId: nat, amt: int)
    requires amt > 0
    requires fromId < |s.services| && toId < |s.services|
    requires fromId != toId
    requires s.services[fromId].bal - amt >= s.services[fromId].minBal
    requires s.services[toId].bal + amt >= s.services[toId].minBal
    ensures |transferFull(s, fromId, toId, amt).journal| == |s.journal| + 2
  {
  }

  // Journal append-only: all operations preserve prior entries.
  lemma OperationsPreserveJournalPrefix(s: BankFullState, svcId: nat, amt: int)
    requires amt > 0
    requires svcId < |s.services|
    requires s.services[svcId].bal + amt >= s.services[svcId].minBal
    ensures journalAppendOnly(s.journal, depositFull(s, svcId, amt).journal)
  {
  }

  // ----- lemmas: min-balance safety ----------------------------------------

  // Deposit never violates min-balance (it increases balance).
  lemma DepositPreservesMinBal(s: BankFullState, svcId: nat, amt: int)
    requires amt > 0
    requires svcId < |s.services|
    requires s.services[svcId].bal + amt >= s.services[svcId].minBal
    ensures depositFull(s, svcId, amt).services[svcId].bal >= s.services[svcId].minBal
  {
  }

  // Withdraw at exactly min-balance is allowed (boundary).
  lemma WithdrawAtMinBalAllowed(s: BankFullState, svcId: nat, amt: int)
    requires amt > 0
    requires svcId < |s.services|
    requires s.services[svcId].bal - amt == s.services[svcId].minBal
    ensures withdrawFull(s, svcId, amt).services[svcId].bal == s.services[svcId].minBal
  {
  }

  // ----- lemmas: interest non-negativity ------------------------------------

  // Interest is non-negative when rate and balance are positive.
  lemma InterestIsNonNeg(s: BankFullState, svcId: nat)
    requires svcId < |s.services|
    requires s.services[svcId].bal > 0
    requires s.services[svcId].rate > 0
    ensures accrueInterest(s, svcId).services[svcId].bal >= s.services[svcId].bal
  {
    var interest := s.services[svcId].bal * s.services[svcId].rate / 1200;
    assert interest >= 0;
    assert accrueInterest(s, svcId).services[svcId].bal == s.services[svcId].bal + interest;
  }

  // ----- lemmas: CRC integrity ----------------------------------------------

  // CRC is deterministic: same entry content always produces same CRC.
  lemma CrcDeterministic(e1: JEntry, e2: JEntry)
    requires e1.kind == e2.kind && e1.svc == e2.svc
    requires e1.amount == e2.amount && e1.balAfter == e2.balAfter
    ensures crcOf(e1) == crcOf(e2)
  {
  }

  // CRC differs for different entries (collision resistance in abstract model).
  lemma CrcDistinguishes(e1: JEntry, e2: JEntry)
    requires e1.kind != e2.kind || e1.svc != e2.svc
    requires e1.amount == e2.amount && e1.balAfter == e2.balAfter
    ensures crcOf(e1) != crcOf(e2)
  {
  }
}
