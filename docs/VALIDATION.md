# Validation scope — 0.2.3-primary-only.1

Prepared 2026-10-17 (Asia/Shanghai). **Isolation candidate, actual filtering and stability unverified.**

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
| Isolation source gate | Source/history modules and query symbols absent from the exact composed artifact; eight deliberate violations refused |
| Envelope inspector | GUID, archive/resource, companion files, exact source equality, checksums |
| Real primary filtering and0.2.3 stability | PENDING |
| Full six-option release | NOT PROVIDED by this isolation build |

The final tests-passed.json and package-inspection.json record actual gate outcomes. Passing offline tests is not proof of frame rate, game stability, host/client behavior or reinforcement in the actual engine. Source absence isolates a path; it does not prove that path caused the old crash. Test primary ON/OFF and death/reinforcement in one mission, preserving the new logs.
