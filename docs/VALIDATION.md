# Validation — 0.3.0-cache-primary.1

**NEW primary-only data-cache candidate. Live acceptance pending.**
All0.2.x delivered versions remain withdrawn; their first fault is unresolved.
There is no new game process, deployment, attachment or live measurement in this build.

| Gate | Scope |
| --- | --- |
| Shared hashes/LuaJIT compile/FFI | Exact composed source, unchanged vendor copies, private aliases, no user32 |
| Current backend | Local NETWORK ID + ownership + entity map; only one actor;64-bit pointers never treated as IDs |
| Pool lifetime | Native fixed2048slots, spatial/payload/zone/grid round trips; removal, reuse, invalid/unaligned pointers |
| Selection | Primary-only retained target, eligible highest-scored alternative, native type/ownership constraints, pending-request sentinel |
| Commit refusal | Fresh actor/target snapshot, row reallocation/identity change/despawn, private RW8-byte boundary |
| Actual Windows writer | Private Lua buffer only; readback; null/alignment/image/unmapped/race/contract refusals |
| Both real LuaJIT VMs | Lupa LuaJIT2.1 and installed lua51.dll loaded in a private test process |
| Composed entry | 20000 filtered frames,12000 ship frames,OFF/APPLY,lower Lua update ordering,death/reinforcement,shutdown/final status |
| Actual menu API | Stable ID,firstON,savedOFF,invalid values,optional saved setting retained |
| Mission scope | Ship/load/unknown/state/mode/count/build/pin guards and mission epoch |
| Independent native consumers | Production Lua -> original getter/manual request/availability bytes: support zones0/1/7,clear,OFF,other owned actor,high32-bit hash |
| Native instruction evidence | Existing53 timing/consumer pins +45 new layout pins; compact fixtures,not a full game image |
| Historical regressions | Withdrawn0.2.3/0.2.4/0.2.5 instructions; never composed into this addon |
| Exact artifact isolation | No detour,executable allocator,protection changes,function-pointer engine calls or source observer |
| Release policy | Reviewed-source SHA match; known failed IDs permanently refused; stale complete-gate stamp refused |
| Envelope | GUID/resource/header/sidecars/README,forbidden extensions,exact source equality |
| Actual mission/weapon/death/host/client tests | PENDING |
| Other five options/full six-option release | NOT PROVIDED |

Full gate output and machine-readable reports stay in ignored build/.
The final ZIP is inspected before copying to outputs/. A failed gate produces no
new deliverable. The source ZIP records this scope, not a claim of gameplay success.

Independent native-consumer checks use reconstructed engine tables and mock the
external template resolver, special preamble and final network request boundary.
They establish which target the retained consumer submits, not the actual network
pickup or crash-free play. Source audit and native checks are not an external human review.

The normal Lua -> plugin -> actor -> collector frame order is pinned. The additional
0xFDAEE0 entry and other mods' updates are not completely proven. The fixed-slot
and actor-move tests cover synthetic lifetime changes, not all live destruction paths.
See[CACHE-BACKEND-REVIEW](CACHE-BACKEND-REVIEW.md) for constraints and first test steps
in the source GUIDE. A write verification failure stops this backend and is logged.

Historical0.2.5:active06:17:15Z,shutdown06:17:46Z,dump06:17:51Z on2026-10-18.
Last paired entry/return954/954;final returned1114;final entry count unknown.
Its diagnostic failed and must not be repeated or relabelled as a working build.
