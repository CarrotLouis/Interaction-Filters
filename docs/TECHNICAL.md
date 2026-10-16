# Primary-only isolation implementation

Product version 0.2.3; build ID 0.2.3-primary-only.1. The withdrawn six-option source is retained in the repository's initial history commit. Same addon resource, GUID and primary option ID make this candidate a replacement, not a second addon.

Only `primary` is present in Controller.DEFS. Its applied mask is 0 or1. A production Mod Options Menu test seeds an old optional saved value, toggles primary and verifies the unregistered value survives persistence. Optional source/history modules are not copied or composed. `verify_isolation.py` rejects source-observer/query symbols and optional registrations in the exact composed Lua, with eight negative gate probes; the envelope inspector then requires packaged-source equality.

The existing native hook site remains game.dll+0x9A0DAB, atomic word +0x9A0DA8. It filters category1 before ranking. Native backend/cache code remains unchanged except the known identity namespace correction and separately named diagnostic data; the controller never enables its other bits or publishes a source cache. The RX/RW allocation, exact-word CAS, protection/flush checks, lifecycle restoration and retained page lifetime are unchanged to keep the source-path isolation narrow.

The local manager global is +0x3326468. Its +0x88 is the locally owned player partition count; a single local record is required. +0x3A8 is the current avatar NETWORK ID, not the engine unit handle. Actor descriptor+0x10 holds the corresponding network ID; +0x0C is recorded separately as the unit diagnostic. 0x7FFF is no avatar. The native removal writer at +0x60C6F2 and descriptor network-ID consumer at +0x9A3554 are additionally pinned. Remote network IDs pass, even when a unit number happens to equal the local network ID. Each candidate rereads the identity, including after reinforcement.

Network-ID telemetry adds one u32 at control+0x2240, after the bounded 64-type histogram, within the existing private allocation. `native.last_actor_unit`, `native.last_actor_network_id` and `native.last_local_network_id` now name separate fields correctly. Diagnostic samples can mix during concurrent native updates; behavior uses registers from the current invocation rather than reading diagnostic samples.

Mission gating is retained: confirmed GameState4 plus one known readable GameMode; ship/menu/loading/unknown states restore the owned original patch. Primary toggles and transitions reuse the same retained native pages. No source read, Script temporary-arena, Application world, Network session or GameSession ownership call is part of this package. Shared localization and Mod Options Menu keep their normal responsibilities.

Tests execute the exact native code on Unicorn, including the retained type-loading instruction prefix, all backend mask/cache paths, register/flags/stack preservation and CAS. Namespace regressions use distinct unit and network IDs, the reported unit4196913, old0.2.2 misses/collisions, missing avatar, changed network ID after reinforcement and unit reuse. These reconstructed cases are not new live captures of actor network IDs.

The composed entry runs 12000 ship frames with only its memory boundary substituted, and 20000 Mission frames with memory/native-system boundaries substituted. Source APIs throw if reached. Primary ON/OFF, return-to-ship, mission resume, forwarding and optional saved-value preservation are checked. Production Windows operations run only on private pages in the test process, not the game.

Rebuild with Python3.12+, requirements-dev.txt and MinGW x64 (PPB_TOOLCHAIN or PATH). Supply BingusSharedLoader/scripts separately through PPB_BINGUS_TOOLS or external/BingusSharedLoader/scripts; supply ModOptionsMenu through PPB_MOM_SOURCE or external/ModOptionsMenu. HD2_LUA51_DLL must explicitly select the installed game Lua DLL loaded into a separate test process. See [DEVELOPMENT.md](DEVELOPMENT.md) for setup and pinned dependency revisions.

```powershell
python -B scripts/build.py
python -B scripts/export_source.py --output-dir outputs
python -B scripts/verify_isolation.py --source build/addon.lua --json
```

Build gates never deploy. The last command reads only by default; --report explicitly writes a JSON proof under this checkout's build/ folder. It exits nonzero for a missing input or scope violation and rejects reintroduced source APIs. All package claims remain offline-only until actual primary filtering and stability are tested.
