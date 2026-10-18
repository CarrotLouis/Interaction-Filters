This mod's own source is 0BSD. It was developed with AI assistance.

The unmodified `bingus_runtime.lua`, `bingus_memory.lua` and `bingus_text.lua` copies in `vendor/shared/` were obtained from [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu). Runtime and memory are CowboyBingus's Bingus Shared Runtime; text is Bingus Text. They are 0BSD; the original license and SHA-256 values are included. The build refuses modified shared copies. `scripts/game_lua.py` is also an unchanged 0BSD test driver from that project; it loads the user's installed Lua DLL into a test process, not the game process.

`scripts/build_mod.py` adapts [HD2 Agent Skills' addon build gates](https://github.com/Puipipi/HD2-Agent-Skills/tree/main/skills/hd2-addon-build), including an FFI-audit update for protected, private `__asm__` declarations. `scripts/inspect_package.py` is its unmodified package inspector. They are MIT; see `vendor/HD2-Agent-Skills-LICENSE`. The guide's exact-source/read-only package checks, candidate release discipline and offline/game validation distinction are retained.

The separate packaging tools `build_addon.py` and `archive.py` are obtained from [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader), and are **not redistributed in this source bundle or mod ZIP**. Set `PPB_BINGUS_TOOLS` to that repository's `scripts/` folder to rebuild.

[HD2Runtime ModBuilder](https://github.com/SkyeShade/HD2Runtime-ModBuilder) and [HD2Runtime](https://github.com/SkyeShade/HD2Runtime) were inspected for SDK capabilities, local player identities, equipment reads and event timing. No Runtime implementation is shipped. The current Runtime's observed post events do not cancel a pickup. A separately researched possibility is filtering a per-actor cached target before the next request consumes it; that backend is not implemented or live-validated. No HD2Runtime runtime dependency is required by this addon.

Native instruction pins and a short original gate fixture were checked against the user's retained unpacked current-build module sections. No complete game resource, executable, module dump, personal configuration, screenshot, log or research snapshot is redistributed. Runtime source packages are version-pinned in `vendor/PROVENANCE.json`.

The user-supplied [Where's My Shit 1.0.1](https://www.nexusmods.com/helldivers2/mods/17095) was inspected without executing it. Its observed rule (map-start equipment and a frozen 1.5-second initial ownership window), Application/Network/GameSession call signatures and current-build component offsets informed the independent source tracker. None of that author's full Lua resource, visual changes, catalog or archive is redistributed; that mod is not a runtime dependency. Reference ZIP SHA-256: `76da2660ac9fec8b65ea26b9ec0b69bac89b802c7062eea8f9a580ba57b8a898`. The inspected Lua resource is `mods/patpatpatrick/wheres_my_shit`, SHA-256 `12825eb33a2a71dd76bcdf75a50b924f75c4049203d16b5673c18ebed5ca7833`.

The 0.2.1 read-only mission decoder uses GameState/GameMode layout facts and native consumer signatures from HD2Runtime's `scripts/research_event_state.py` and `domains/event_natives.lua`. The decoder is independently implemented; no Runtime package or runtime dependency is added.

Development tools: Python, GNU MinGW assembler/objcopy, Lupa LuaJIT, Unicorn and Capstone. They are not bundled with the mod. The native predicate is assembled from `native/filter_v3.S` (the withdrawn v2 source remains historical); it contains no compiler runtime, DLL dependency or external helper program.

0.2.3 primary-only isolation: the source tracker and its GameSession path are absent. The reference above remains historical provenance; none of its implementation is embedded. Avatar network-ID layout/removal facts and the additional native signatures were checked against retained HD2Runtime event metadata and game code. Previously shipped own native blobs are small offline regression fixtures, not active runtime dependencies.


0.2.4 CALL wrapper and its unwind metadata are independently implemented here.
The Windows ABI/unwind contract is documented by Microsoft Learn; no Windows
implementation source or binary is redistributed. The local candidate manager
layout and CALL boundary are pinned to retained current-build native consumers.
Own withdrawn 0.2.3 bytes are a regression fixture, not the active implementation.

The 0.2.4 native fixture is this project's own previously published wrapper, retained
only for historical instruction tests. The current entry_probe.S is original diagnostic
assembly. No reference mod implementation, game binary or private crash material is bundled.

The cache research fixture contains53 native instruction pins and three small
consumer fragments (1055 bytes) from the user's retained current-build sections,
plus callback/import layout facts. They are offline regression inputs; external
engine boundaries are reconstructed. No complete module, private snapshot or DLL
is redistributed. The checker and consumer tests are independently implemented
here and do not import or execute HD2Runtime's research tools.
