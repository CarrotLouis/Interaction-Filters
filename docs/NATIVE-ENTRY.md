# Historical 0.2.4 CALL entry and unwind proof

**WITHDRAWN after a live mission crash. Unwind correctness did not establish stability.**
The subsequent no-filtering diagnostic also failed; it is described in [ENTRY-PROBE.md](ENTRY-PROBE.md).

## Evidence and limits

The enabled 0.2.3 runs exited after 27 and 92 seconds. A subsequent user-reported
OFF mission completed without a crash. The retained log shows OFF before entry,
no allocation/install record and about 5.5 minutes from the second mission-mode
transition to shutdown. This associates the failure with the enabled native path;
it does not identify the precise first fault or prove that unwind metadata caused it.

The old inline stub has seven stack pushes and is reached by a jump from inside
another function. It has no unwind table. Ordinary instruction-state simulation
does not cover Windows stack walking at such a PC.

[Microsoft's x64 exception documentation](https://learn.microsoft.com/en-us/cpp/build/exception-handling-x64)
requires function-table support for dynamically generated stack-using/calling code.
The new wrapper is entered by a real CALL and has its own prologue, epilogue and
[registered function table](https://learn.microsoft.com/en-us/windows/win32/api/winnt/nf-winnt-rtladdfunctiontable).
The tests invoke the actual Windows lookup/unwind APIs on private test pages.

## Atomic displacement update

The original native call is `E8 B5 CF FF FF` at game+0x9A35F6. Its return is at
+0x9A35FB. An aligned word at +0x9A35F8 is `CF FF FF 33 C0 89 44 24`.

The wrapper's entry offset is 0xB0 within an aligned VirtualAlloc reservation.
Its new signed relative displacement must retain byte 0xB5. The update replaces
only the high three displacement bytes, using one aligned 64-bit CAS, preserving
the next five bytes. The original opcode/low byte are verified before install and
while active. Another owner's change is never overwritten. The old mid-function
MOV/JMP site is not modified.

## Call frame

The wrapper saves RBX, RSI and RDI, allocates 64 bytes (including 32-byte shadow
space), forwards the original registers to the original collector exactly once,
then filters the returned local cache. The original RAX result is preserved.
Nonvolatile GPRs and XMM6–15 retain their ABI contract.

The prologue is `53 56 57 48 83 EC 40`. UNWIND_INFO is
`01 07 04 00 07 72 03 70 02 60 01 30`: version1, prologue7, four codes describing
64-byte allocation and the three pushes. The leaf classifier and CAS routine do
not allocate stack or alter nonvolatile registers. Normal CALL/RET pairs preserve
the caller return address without manual return-address edits.

The retained function-table record uses offsets relative to the allocation base;
it and its unwind data occupy the same retained executable allocation as the code.
Registration failure prevents publication. Test fixtures unregister only after
all their private calls have completed, before freeing their own pages.

## Gates

- Exact current native bytes and module fingerprints; CALL-tail alignment/refusal.
- Unicorn executes the actual call site, collector boundary, wrapper and RET;
  checks post-collection filtering, order, maximum cache, unknown fail-open,
  remote/OFF, ABI state, original return value and adjacent instruction bytes.
- Real Windows executes the wrapper on private pages, including native collector,
  local/remote, OFF, reinforcement and no-avatar cases.
- Actual RtlLookupFunctionEntry/RtlVirtualUnwind checks 11 prologue/body/epilogue
  contexts and restores distinct nonvolatile register values from the saved stack.
- The legacy inline fixture remains separate historical coverage, not evidence
  that the current engine is stable.

All these are offline/private-process checks. Actual primary pickup rejection,
same-location support pickup, mission stability and reinforcement remain pending.
