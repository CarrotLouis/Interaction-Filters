# Interaction-Filters contributor instructions

## Canonical project

- This checkout is the maintained Interaction-Filters project.
- Remote: `git@github.com:CarrotLouis/Interaction-Filters.git`; default branch: `main`.
- The initial history commit preserves withdrawn 0.2.2 six-option sources.
  0.2.3 is also withdrawn after two mission crashes; its OFF control passed once.
  0.2.4 is withdrawn after a mission crash with zero primary removals.
  0.2.5 ENTRY-ONLY also exited after 31 seconds with real entry execution.
  All delivered versions are withdrawn. The first fault is unresolved.
  Native sources remain for offline reproduction, not another live recommendation.
  release-policy.json forbids packaging and source-ZIP export of this failed build.
- Read `docs/DEVELOPMENT.md`, `docs/VALIDATION.md` and `docs/ROADMAP.md` before changes.

## Standing user authorization: synchronize changes

The user explicitly requested a public repository and synchronization after every
subsequent change. After each completed set of related edits:

1. Run checks appropriate to the change. Runtime or build changes require the full
   build gates when the documented dependencies are available. For a withdrawn
   build, run build.py --verify-only and verify package/export refusal; never
   change the policy merely because offline checks pass.
2. Review `git diff` and staged paths. Keep generated and private files excluded.
3. Commit with a descriptive message, then push to the existing remote branch.
4. Verify the remote commit matches the local commit and report any sync failure.

No further permission is needed for ordinary commits and pushes within this
project. Do not force-push, rewrite published history, or overwrite unrelated work.
Do not install a background file watcher or upload-on-save service. If authentication
or network access fails, preserve local work and explicitly report that sync is pending.

## Project boundaries

- Never track `outputs/` at any depth. `build/`, `dist/`, `external/`, environments,
  logs, minidumps, game binaries and credentials are also local-only.
- Do not import private incident folders, another mod's complete implementation or
  synced ChatGPT `sources/` files into this repository.
- Keep the GUID, resource name, singleton and persisted setting IDs stable.
- Do not modify checksum-verified upstream files in `vendor/shared/`. Record other
  third-party adaptations in `THIRD_PARTY_NOTICES.md`.
- Native instruction fixtures are small regression inputs, not complete game images.
- Keep offline evidence separate from live acceptance. Do not claim the crash or
  full six-option behavior is fixed until the corresponding in-game test succeeds.
- Packaging never deploys, launches or attaches to the game. This GitHub request
  does not authorize changing the user's game installation or other mods.

## Current investigation boundary

Do not ask the user to repeat the same entry-only crash. Do not relabel it as a fix
or re-enable this detour for a new gameplay candidate. A future candidate needs an
independently reviewed backend that avoids game-code detours/.text writes and
proves local-player scope, refresh ordering and restoration. This is a project
decision from the live controls, not proof that GameGuard caused the exits.
