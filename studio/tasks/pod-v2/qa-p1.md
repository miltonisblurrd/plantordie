# pod-v2 — QA, Phase 1 (Foundation)

Cut: **v1**. Mode: code review plus static checks (owner choice at intake). This environment has no Studio runtime, so nothing here was playtested. CI green is not a pass.

Branch `cursor/p1-foundation-cc3f`.

## Build and static results

| Check | Tool | Result |
| --- | --- | --- |
| Rojo build | `rojo build -o build.rbxlx` (Rojo 7.7.1) | PASS, built cleanly |
| Lint | `selene src` (0.29.0, `std = "roblox"`) | PASS: 0 errors, 0 warnings |
| Type check | `luau-lsp analyze --platform=roblox` with Roblox `globalTypes.d.luau` and a Rojo sourcemap | PASS: 0 errors. Shared, server, and client modules are `--!strict`. |

## Acceptance checks in P1

| Check | Verdict | Evidence |
| --- | --- | --- |
| A1: a new player gets a unique plot | PASS (code path), BLOCKED-RUNTIME (visual) | `src/server/Plots.luau:97-128` `assign` runs from `Data.onLoaded` (`:160`). It takes the first index with no owner (`:103`) and writes `ownerByIndex`/`indexByPlayer` with no yield in between (`:112-114`), so two joins on the same frame can't claim the same plot. It returns early if the player already has a plot (`:98`). `release` (`:130`) frees the plot on leave, and so do `Data.onReleasing` and `PlayerRemoving`. The owner name goes on the house billboard (`:119`) and the player spawns at their plot (`:84-95`). Needs a Studio check that the billboard and the spawn look right. |
| A21: two players are isolated | PASS (foundation), BLOCKED-RUNTIME | Ownership has one source of truth: `Plots.ownerOf` and `Plots.isOwner` (`src/server/Plots.luau:36-44`). `isOwner` checks both maps. Tiles carry a `PlotIndex` attribute (`src/server/World/Builders/Plot.luau`, tile loop), so any tile resolves to its owner. Each player's profile is a separate session keyed by UserId (`src/server/Data/init.luau:160-209`). `Net` rejects every client remote unless the profile is loaded, and rate-limits each player and remote separately (`src/server/Net.luau:93-101`). P1 has no client-to-server mutations yet. P2 handlers must call `Plots.isOwner` before they write. |
| A25: a save failure does not wipe data | PASS (code path), BLOCKED-RUNTIME | Loads go through `UpdateAsync` with a session lock (`src/server/Data/init.luau:49-78`). A live lock held by another server and younger than 30 minutes is not taken (`:57-63`). A corrupt record, or one with a newer schema, is refused rather than overwritten (`Schema.luau:139,144`). The load retries 3 times with backoff (`init.luau:80-97`). If it still fails, `session.loaded` stays false and the player is kicked with a friendly message (`:184-191`). `Data.save` refuses to write unless the load succeeded (`:125`), and `Data.get` hides unloaded sessions (`:227`), so the Net gate blocks them too. A save stops if another server owns the lock (`:104-118`). Autosave runs every 60s (`:303`). `BindToClose` flushes every session and waits, including in-flight leave saves (`:312-333`). A rejoin to the same server waits for the previous release save before loading (`:177-180`). **Owner test in Studio:** set the `workspace` attribute `DebugFailDataStore = true` before joining. The player should be kicked after 3 attempts, and nothing should be written (`Store.luau:58-66`). |

## Other P1 scope (not acceptance rows)

All of these need a Studio playtest.

- **Hub:** a grass plaza, a fountain, a title board, 12 trees and 6 rocks, and a stone gate ring (`World/Builders/Hub.luau`). There are 15 gates, 2 per sector between the plot paths, so no gate blocks a plot path (`World/Layout.luau`). Each gate sign shows the name, the cost, and LOCKED or UNLOCKED. Paid gates have a collidable barrier (`World/Builders/Gate.luau`).
- **Locked lanes:** lanes 4-7 have grey soil, a rope, and a price sign (`World/Builders/Plot.luau`, `setLanes` and `buildLaneLock`).
- **Day/night:** the server runs the cycle and broadcasts `endsAt` in server time (`DayNight.luau`). The HUD counts down from `workspace:GetServerTimeNow()`.
- **HUD and controls:** the HUD shows money, income/sec, area, the clock, house HP, and an event slot (`client/Hud.luau`). Notification toasts are in `client/Notifications.luau`. The lane-view camera toggles with a 44 px button or the C key (`client/Camera.luau`).

## Known gaps / risks

- The gate barrier is solid on the server for everyone. The client turns off collision for biomes the player owns (`client/Gates.luau`). That only matters once P3 sells biomes, and P3 travel must re-check ownership on the server.
- The Halloween window in `Events.luau` is hard-coded as UTC seconds for PT dates.
- House HP is per session (it starts full). P4 owns damage and repair.
- No headless Luau runtime was available, so the data-service logic was reviewed but not executed. Every row above stays BLOCKED-RUNTIME until the owner playtests.
