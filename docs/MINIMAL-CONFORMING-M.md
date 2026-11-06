# Minimal-conforming M — definition for SwiftM (Phase 6.1c, m-semantics#72)

**Status:** definition doc (no code). **Owner:** A. **Date:** 2026-11-06.
**Question answered:** which of the 139 shared-corpus cases
(`pymumps/tests/conformance.json`, loaded by mjvm `J0Smoke`) must a
*minimal conforming* M implementation (ISO/IEC 11756) pass, and which are
vendor-specific extensions a conforming implementation may skip?

## Definition

A **minimal-conforming-M** implementation MUST pass all **ISO-core** and
**ISO-1999** cases below (124 of 139). The **vendor** cases (15) are NOT
required for conformance; an implementation MAY implement them (SwiftM
targets GT.M/YDB compatibility for the fleet, so it should), but they are
excluded from the conformance gate.

- **ISO-core (116):** ISO/IEC 11756:1992/1999 core language — commands
  (SET/KILL/NEW/IF/ELSE/FOR/DO/GOTO/QUIT/XECUTE/WRITE/HANG/LOCK/MERGE),
  postconditionals, indirection, patterns, operators, and the core
  intrinsics ($ASCII $CHAR $DATA $EXTRACT $FIND $GET $INCREMENT $JUSTIFY
  $LENGTH $NAME $ORDER $PIECE $QUERY(1999) $SELECT $TEXT $TRANSLATE $HOROLOG
  $IO/$PRINCIPAL(1999) $TEST $X $Y $ETRAP $ECODE(1999) $STACK(1999)
  $TLEVEL(1999)).
- **ISO-1999 (8):** variables added by the 1999 revision: $TLEVEL, $QUERY,
  $STACK (+place), $ECODE, $IO/$PRINCIPAL.
- **Vendor (15):** GT.M/YDB/VA extensions a conforming M need not have:
  $REVERSE, $FNUMBER, $RANDOM, $QLENGTH, $QSUBSCRIPT, bare `$Q`,
  $NEXT/$N, VIEW, $DEVICE, $STORAGE, $SYSTEM, $ZTRAP, $ZVERSION, $ZJOB,
  $ZLEVEL, $ZSYSTEM, $ZEOF.

## Notes on judgment calls (arbiter: ISO text; GT.M V7.2-001 on U01 where semantics diverge)

- **C24.eq-noncanonical** is ISO-core even though GT.M diverges (C24 class,
  pinned in `MRelOps.dfy`): ISO compares numerically (`"1.0"=1` is true);
  GT.M compares string forms. A conforming implementation follows ISO.
- **C30.prec-mul-add** (`1+2*3=9`) is the ISO left-to-right rule, NOT an
  error: M has no operator precedence. Pinned by the PEMDAS module.
- **C16/C34** string-collation cells follow GT.M where ISO is silent on
  collation of non-numerics (C16 class, pinned in `MRelOps.dfy`).
- **C81** bare `$Q` (no argument) is treated as vendor; ISO `$QUERY`
  requires a reference argument.
- **C86/C87** `$NEXT`/`$N` are GT.M abbreviations of `$ORDER`; ISO has
  `$ORDER` only.

## Case-by-case table

| Class | Count | Cases |
|-------|-------|-------|
| ISO-core | 116 | T11, T11b, T11c, T11d, T12, T12b, T13, T13b, T14, T14b, C01–C42 (minus C43), C44–C46, C49–C53, C56–C80 (minus C54, C55), C83–C85, C88–C116 (minus C86, C87, C114, C117–C120), C121–C124 |
| ISO-1999 | 8 | T15 ($TLEVEL), C53 ($QUERY), C69/C70/C72 ($STACK), C82 ($QUERY arity), C114 ($ECODE), C120 ($IO/$PRINCIPAL) |
| Vendor | 15 | C43 ($REVERSE), C47 ($FNUMBER), C48 ($RANDOM), C54 ($QLENGTH), C55 ($QSUBSCRIPT), C81 (bare $Q), C86 ($NEXT), C87 ($N), C117 (VIEW), C118 ($DEVICE), C119 ($STORAGE/$SYSTEM), C125 ($ZTRAP), C126 ($ZVERSION/$ZJOB), C127 ($ZLEVEL/$ZSYSTEM), C128 ($ZEOF) |

## Gate for SwiftM (Phase 6.3)

The minimal-conforming subset of the 139-corpus that SwiftM must pass on
**swiftm AND mjvm AND GT.M**: the 124 ISO-core + ISO-1999 cases, with the
Dafny corpus green (`dafny verify`, 547+ lemmas). The 15 vendor cases are a
compatibility target, not a gate.
