# Entry-only control — 0.2.5-entry-only.1 (WITHDRAWN)

**Completed: the user reported another mission exit. Do not repeat this control.**

## Question

0.2.4 crashed after the native entry had been active for about22seconds, with843
collector returns/local identity matches and zero primary removals. A prior0.2.3
loaded-but-OFF mission did not crash. Unwind registration did not resolve the issue.
The dump still records a scheduler read AV after shutdown, not an identified first fault.

The user explicitly agreed to a control that keeps the native entry but does no filtering.
This is not a proposed stable fix. Ground-primary pickups must remain possible.

## Retained and removed

| Boundary | 0.2.5 diagnostic |
| --- | --- |
| CALL at game+0x9A35F6, aligned tail CAS, original return address | Retained |
| Near allocation, protection/cache flush, code ownership/restoration | Retained |
| Same three pushes/64-byte frame and dynamic Win64 unwind table | Retained |
| Original collector call and original parameters/return | Retained exactly once |
| Private telemetry | Entry/return counters only |
| Player/actor globals, avatar identity or descriptor reads | Removed |
| Interactable hash/zone classification, candidate or retained reads | Removed |
| Candidate/count/retained writes or primary blocking | Removed |
| Source observer and five optional filters | Still absent |
| UI | Explicit no-filtering diagnostic label; same saved ID |

The only extra pre-collector register use is volatile R11. The pinned collector
starts by overwriting R11 with RSP; argument registers and XMM arguments are forwarded.
No flags are expected as call inputs; the original caller overwrites its flags immediately
after returning. The leaf CAS helper and retained function table are unchanged.

## Instrument and gates

Current assembly is `native/entry_probe.S`. Its pointer literals are only control
and original collector. `native.entry_calls` increments before the collector;
`native.returned_calls` and legacy `native.visits` increment after it returns.
Calls in flight can make separate counter reads unequal. An entry-only count is
not on its own proof of a stuck collector or a fault: workers may be preempted.

Unicorn executes the exact patched CALL and production bytes with engine data
unmapped. Data-access hooks allow only private stack/code/counter addresses.
A collector-stop case proves entered/returned counters distinguish the two phases.
Actual Windows private pages execute the same bytes with deliberately invalid
manager/descriptor arguments, check argument/return forwarding and all9 calls.
Actual RtlLookupFunctionEntry/RtlVirtualUnwind still checks11 frame positions.
Historical0.2.3 and0.2.4 tests use separate own fixtures and do not validate live stability.

## Historical live instructions (completed; do not repeat)

Enable/APPLY on the ship, enter a mission and play normally for about3minutes.
If stable, return to the ship or exit normally. No weapon/death testing is required.
If it exits, preserve the logs and report the phase; repeated identical crashes add little.
Verify the new build ID and nonzero entry/return counters before evaluating the run.

- Still exits with actual entry execution: removed actor/candidate reads and filter
  writes are not necessary. Investigate common entry/allocation/call environment and
  mod interaction; this does not automatically prove anti-cheat or a specific hook defect.
- Stable with entry execution: focus on the removed body or timing differences;
  it does not identify a particular bad pointer or prove a filtering fix.
- No entry executions/refused install: inconclusive; diagnose the instrument first.

No game was launched, attached, deployed or tested by the offline suite.


## Actual result — 2026-10-18

UTC:06:17:15 active,06:17:46 shutdown (31seconds),06:17:51 dump.
Paired log samples:54/54,354/354,654/654 and954/954 at06:17:43.
Final STATUS: native.visits1114 (returns), no role/type/block counters changed.
The STATUS serializer omitted entry_calls/returned_calls, so the final entered
count is unknown; do not invent1114/1114. Paired appended logs establish that the
instrument fired, and another crash run is not needed to correct this omission.

The removed body is not necessary for the exit. The dump still contains the
post-shutdown scheduler read AV at EXE+0x626296, not an identified initiating fault.
The test does not split game-code modification, allocation, call environment or
mod interaction. The build is withdrawn and packaging is blocked independently
of offline success. See NATIVE-FREE-RESEARCH.md for the next research boundary.
