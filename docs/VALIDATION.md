# Validation scope — 0.2.3-primary-only.1

Updated 2026-10-17 (Asia/Shanghai). **WITHDRAWN: two confirmed 0.2.3 mission crashes. Actual primary filtering remains unverified; stability acceptance FAILED.**

0.2.3 activation/shutdown: 08:10:05Z → 08:10:32Z (27 s), and 08:15:18Z → 08:16:50Z (92 s). The first run's last log sample has 546 visits; the second run's final STATUS has 5752. Both record zero primary candidates, enabled candidates, identity matches and blocks. Source observers were absent. The two new dumps fault at helldivers2.exe+0x626296 in the task scheduler, after shutdown was logged, so the initial exit cause is still unproven. The user confirms the ordinary game crash reporter with no visible error code.

User comparison: reinstall0.2.2 → crash before death; remove → one death and reinforcement completed. Real0.2.2 startup20:05:59Z, native activation20:07:44Z, observer20:07:47Z, shutdown20:08:08Z (local04:05:59–04:08:08 on Oct17). Last status: mask63, visits100, type13 only, enabled_candidates0, local_matches0, blocked0, retained_cleared0, source_published7, reads65/81820bytes. Thus the new failure did not enter the enabled-category/actor/target-clear branch. The common native path and source observer still require isolation; precise cause unproven. Raw dumps/logs remain private backups.

| Gate | Scope |
| --- | --- |
| Current file fingerprints and14 native pins | Installed hashes and retained current-build code; runtime refuses mismatch |
| Lua compile / FFI / unchanged shared sources | Exact composed source; no forbidden global declarations |
| Namespace regression | Actual native code, distinct network/unit IDs, old shipped misses/collisions, absent avatar, reinforcement and unit reuse |
| Native original-prefix and gate differential | Original retained type-load prefix, masks, local/remote, registers/flags/stack, source-cache backend safety and atomic CAS |
| Windows system adapter | Private process pages only; allocation backend/fallback, cache/diagnostic bounds, conflict and restore checks |
| Primary-only controller and real menu API | Default ON, saved OFF, Apply, singleton, callbacks, unchanged unregistered optional saved values |
| Composed ship entry | 12000 frames, source APIs throw, zero source/hook-site reads on ship |
| Composed mission entry | 20000 frames, source APIs throw, primary-only mask, ON/OFF and ship/mission transitions |
| Composed saved-OFF control | Production controller/hook, 12000 ship + 20000 mission frames, no native preparation/code writes or source queries; live control remains pending |
| Isolation source gate | Source/history modules and query symbols absent from the exact composed artifact; eight deliberate violations refused |
| Envelope inspector | GUID, archive/resource, companion files, exact source equality, checksums |
| Real primary filtering | PENDING: neither failed run reached a primary candidate |
| Real0.2.3 stability | FAILED: user reports two mission crashes |
| Full six-option release | NOT PROVIDED by this isolation build |

The tests-passed.json and package-inspection.json record offline gate outcomes only. They cannot override failed live acceptance. The old native patch remains suspect, not proven to be the initial fault. The next controlled comparison keeps this addon loaded with primary OFF before mission entry, so it exercises polling/menu lifecycle without installing native code. Keep it OFF for 3–5 minutes of ordinary mission activity; do not re-enable or deliberately die to reproduce a crash.
