# Validation status — 0.2.2-dev.1

**WITHDRAWN on 2026-10-16 after a death-crash report.** The 21:42 death exit and the 21:45 intentional Alt+F4 exit without this mod share EXE+0x626296; that is insufficient to identify the initial death trigger. No death/reinforcement baseline without the mod has yet been tested. New telemetry establishes an identity namespace bug: descriptor +0x0C is a unit handle, while player manager +0x3A8 holds the avatar network ID, which belongs against descriptor +0x10. The original synthetic fixture incorrectly treated these as one namespace. A separate native-code proof reproduces the miss and checks the corrected comparison, but is not a live death repair. The original build/test results below remain historical offline results, not acceptance.

Prepared on 2026-10-16 (Asia/Shanghai). **Current-local-unit revision and staged diagnostics; this version's filtering/stability remain pending live testing.**

The user reports no crash with 0.2.1, but primary weapons remain pickable. The preserved 2026-10-16 run starts at 11:19:26Z (19:19:26 Asia/Shanghai), reaches Ship at 11:19:49Z, mission preparation at 11:27:23Z, and successful allocation/filter installation at 11:27:52Z. Saved mask63 includes primary ON. Shutdown at 11:29:31Z retains zero blocks in all categories. These observations rule out the old allocation failure and a disabled primary option. Old logs contain no native entry/type/identity stages and cannot establish the failing predicate condition. A shutdown callback alone does not prove a clean exit; the no-crash observation is the user's report.

0.2.2 uses the exact current local-unit ID and exactly one active local player, removing fixed-blueprint/network-authority assumptions. Synthetic cases reproduce old misses when those extra conditions differ; they are not live captures of the user's actor. New entry, type, identity and old-guard rejection counters measure the remaining uncertainty. The old run's precise cause remains unproven.

0.2.0 is withdrawn after the user's ship-crash report. Its allocation succeeded and native filtering was installed on the ship. Repeated minidumps report 0xC0000005 in the engine task scheduler at EXE+0x626296; assert strings identify bikeshed task IDs. WER also reports an invalid execute target. These do not prove a specific addon instruction or anti-cheat cause. Several later dumps lack a matching addon startup marker. Full logs, dumps and event records remain private workspace backups, excluded from exports.

| Check | Result / limit |
| --- | --- |
| Supported EXE/DLL and native consumers | Enforced: nine hook/local-unit pins and three state pins; current disk fingerprints unchanged |
| Mission-state decoder | PASS in both LuaJIT VMs; only Mission + exactly one readable known GameMode record permits work; ship/menu/load/unknown/fault refuse |
| Composed ship entry | PASS; 12000 simulated frames, six settings and update forwarding; zero source engine calls/source reads/hook-site access |
| Controller/hook scope transition | PASS; 5000 ship frames with zero allocations/code writes, then automatic Mission enable and exact restore when leaving |
| Source empty-list/ship refusal | PASS; no Application/Script/Network/GameSession calls, backpack boundary retained |
| Original six filters / defaults / persistence | PASS; primary ON, five options OFF, independent masks, production menu API and legacy migration |
| Source history | PASS; original team/field/own classification, pickup/re-drop, delayed IDs, absent carrying rows and mission reset |
| Source engine boundary | PASS against doubles; startup grace, temporary arena restoration, restore failure stop and bounded reads; actual mission query behavior pending |
| Windows allocator / protection / atomic CAS | PASS on private test-process pages, including full source cache and conflict handling; no game process |
| Native x64 behavior | PASS; all masks/actors, unchanged-gate differential, retained-target clearing and malformed/stale/concurrent cache refusal |
| Revised local identity | Same current unit blocks regardless of resource/authority flags; different units, missing local record and sentinel pass |
| Original native type-load boundary | 144 executions of retained instructions; three zones/eight category-source cases/local and remote actors/three masks |
| Old-predicate regression | Three synthetic misses reproduced against the shipped 0.2.1 blob, without claiming these match the user's actor |
| Native diagnostics | Private page decoding, complete source-cache separation, stage/histogram counts, final shutdown sampling |
| Compile / private FFI / shared vendor hashes | PASS; exact composed LuaJIT entry, unchanged shared libraries, no forbidden declarations |
| ZIP contents / exact source equality | Enforced by final build and archive inspector |
| Real ship stability of 0.2.1 | User reports no crash in this test; broader stability unproven |
| 0.2.1 actual primary filtering | FAILED per user; log counters zero despite installation |
| 0.2.2 primary/support selection and five options | PENDING |
| 0.2.2 stability, host/client, respawn and transitions | PENDING |
| In-game timing and GameGuard compatibility | PENDING |

The task guard and empty-list protection are retained. The final tests-passed.json and package-inspection.json record whether each offline gate passed. Offline emulation, file fingerprints and private test-process memory operations cannot establish that the hooked path executes for a particular live interaction, or that this candidate is stable in all sessions.

Replace the previous version with 0.2.2 and restart. For the first mission test, enable primary only: approach a dropped primary and try picking it up, then turn the option OFF/APPLY and verify recovery. Repeat after respawn. STATUS/log must show build_id=0.2.2-dev.1; compare native.visits / primary_seen / local_matches / legacy_rejected / blocked.primary. Ship stays inactive with zero source reads. Applied settings persist on upgrade; the five optional filters default OFF only on first use. Test them separately afterward. Preserve the logs before another game test overwrites them.
