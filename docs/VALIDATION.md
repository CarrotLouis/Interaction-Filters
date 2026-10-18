# Validation — 0.2.5-entry-only.1

**WITHDRAWN: the user-approved entry-only control executed and still crashed.**
All offline checks remain limited to their stated scope. No new runtime package is produced.

0.2.4 is withdrawn:2026-10-18T05:55:00Z active,05:55:22Z shutdown,
843 returns/local matches,404 observations of type13, zero primary observations/blocks.
Dump header05:55:27Z:read AV0xC0000005 at EXE+0x626296, after shutdown.
The first initiating fault remains unknown. See INVESTIGATION.md.

| Gate | Scope |
| --- | --- |
| Module hashes/native pins | Same supported build and patch-site ownership |
| Lua compile/FFI/shared hashes | Exact composed source and unchanged vendored files |
| Lifecycle/menu | Diagnostic label, same saved ID, ON default/saved OFF, APPLY, restore/refusal |
| Ship/OFF mission entry | 12000/20000 frames with native installation forbidden while OFF |
| Enabled composed entry | 20000 frames, scope/toggle/forwarding; optional saved values untouched |
| Current production machine code | Exact CALL, no mapped engine data, private-only accesses, one original call, arguments/return, entry/return counters |
| Actual Windows execution | Production bytes on private pages;9 calls with invalid manager/actor arguments and0 blocks |
| Actual Windows unwind | Registered table,11 prologue/body/epilogue contexts and distinct saved registers |
| Atomic ownership | CALL prefix/low byte/adjacent bytes preserved, external changes refused |
| Withdrawn0.2.3/0.2.4 history | Separate own fixtures; retained pair-alias cases did not model the real spatial-record layout |
| Native cache consumer research | 8 synthetic tests; reproduces the old retained-primary defect and checks data-only support selection at the request boundary |
| Isolation/package | Source paths/filter body absent, explicit no-filtering metadata, archive/resource/source equality |
| Actual0.2.5 live diagnostic | FAILED:31s active,954/954 last paired log sample,1114 final returns |
| Release policy | Live-failed build/package/source-export refused; --verify-only creates no deliverable |
| Primary filtering/full six-option release | NOT PROVIDED |

Build evidence stays in ignored build/. All gates must pass before packaging.
The checks do not start, attach to or deploy the game. Offline success cannot establish
mission stability or identify the first old fault. Actual testing steps and conditional
conclusions are documented in ENTRY-PROBE.md.


0.2.5 actual UTC timeline:active06:17:15Z,shutdown06:17:46Z,dump06:17:51Z.
The missing STATUS entry/return fields are documented; final entries are unknown,
not assumed equal to1114. Log pairs prove execution. Repeating that crash is unnecessary.
Run scripts/build.py --verify-only for offline checks; ordinary build/source export
must refuse, even after those checks pass. Historical envelope inspection is read-only.

Cache research is not a new runtime build. Its53 instruction pins and3 small native
consumers were matched to the retained25480438 code;7 Lua import names were independently
matched against the pinned local DLL's export directory (read only). The normal frame's
Lua -> plugin -> actor -> collector order is pinned. Other native update paths, lifetime,
real pickup/network effects and host/client behavior remain unproven. See CACHE-BACKEND-RESEARCH.md.
