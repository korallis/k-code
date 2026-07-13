# k-zero pre-existing multiplayer findings (from fix-track-b4 review gate, 2026-07-13)

Surfaced by the no-mistakes review but located in code already on main before the fix branch - NOT introduced by the fix. Feed these into the AAA overhaul plan synthesis (plan-fable-r7 / plan-sol-w2 cross-review):

- **Respawn cheat vector** (`module/src/index.ts`): `respawn` is fully client-controlled and bypasses the position-delta limit; a client can publish arbitrary coordinates with `respawn: true` - teleport/speed cheats. Respawns must be derived server-side; movement enforced against server elapsed time.
- **Checkpoints never advance server-side** (`src/game/track/Track.tsx`): `reportCheckpointCrossed()` has no callers; multiplayer races cannot finish.
- **Local race vs lobby race lifecycle conflict** (`src/game/race/RaceController.tsx`): local race auto-starts even while the network lobby waits; HUD/input lock can enter GO/racing independent of the shared lobby. Needs offline-fallback-vs-server-driven decision.
- **Lobby dead-end after finish** (`src/hud/Lobby.tsx`): after server `finished`, Ready toggle renders but `set_ready` rejects `finished` and nothing calls `resetLobby`. Reset policy undefined.
- **Disconnect policy undefined** (`module/src/index.ts`): a participant disconnecting during countdown/racing stays unfinished; race can only end via the 5-minute timeout. DNF/remove/reconnect policy needed.
