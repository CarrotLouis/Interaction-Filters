# Validation — 0.2.4-call-wrapper.1

**CALL-wrapper test candidate; actual filtering and stability PENDING.**
The prior 0.2.3 candidate remains withdrawn after two user-reported mission crashes.

The user completed the loaded-but-OFF control without a crash. Retained UTC log:
OFF applied15:07:57Z; later mission-mode transition15:20:41Z and shutdown15:26:10Z,
with no native allocation/activation line. The final STATUS is from a later ship-only
launch and must not be misrepresented as the mission's final state.

The enabled failures were27s and92s after installation, zero primary/identity/block
branches, source observer absent. Both dumps record a scheduler access violation
after shutdown logging; exact initial cause remains unknown. The user confirms the
ordinary crash reporter, without a visible error code. See INVESTIGATION.md.

| Gate | Scope |
| --- | --- |
| Build fingerprints / native pins | Installed files and retained native consumers; runtime refuses mismatch |
| Lua compile / FFI / shared hashes | Exact composed source, no forbidden declarations, unchanged upstream bytes |
| Lifecycle / menu | Saved OFF, default ON, APPLY, conflict/refusal, restoration, singleton and optional value retention |
| Ship and disabled mission entry | 12000 ship/20000 mission frames; source queries forbidden, no install when OFF |
| Enabled composed entry | 20000 frames with explicit memory/native boundaries; ON/OFF/scope and forwarding |
| Current native wrapper | Original CALL runs once before stable local-only candidate compaction, correct RET, order, bounds and unknown fail-open |
| Real Windows native execution | Private pages only: original native callee, return, local/remote/OFF, reinforcement/no avatar |
| Real Windows unwind | Registered dynamic table, 11 prologue/body/epilogue contexts, stack and distinct saved nonvolatile registers |
| Atomic code ownership | Preserve opcode/low byte/adjacent instructions, aligned CAS, prefix and tail conflict refusal |
| Withdrawn inline history | Old instruction-state and namespace regressions, not current-runtime approval |
| Isolation / package | Source queries and five optional rows absent; archive manifest/resource/source equality |
| Actual0.2.4 stability / filtering / host-client | PENDING |
| Full six-option release | NOT PROVIDED |

Build records are in ignored build/. The source/package inspection gates must all
pass before delivery. No game is launched, attached, deployed or used as a test
process by these checks. Offline success cannot replace the new in-game acceptance.
