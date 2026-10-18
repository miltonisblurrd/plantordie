# pod-v2 — QA, Phase 2 (Planting)

Cut: **v1**. Mode: code review plus static checks. This environment has no Studio runtime, so nothing here was playtested. CI green is not a pass.

Branch `cursor/p1-foundation-cc3f`.

Row labels use the official §18 text, now quoted in `cut.md` under *Acceptance checks*. The rows were re-labelled on 2026-10-18.

## Build and static results

| Check | Result |
| --- | --- |
| `rojo build -o build.rbxlx` (7.7.1) | PASS |
| `selene src` (`std = "roblox"`) | PASS: 0 errors, 0 warnings |
| `luau-lsp analyze --platform=roblox` (Roblox definitions and sourcemap, all modules `--!strict`) | PASS: 0 errors |

## Acceptance checks in P2

| Check | Verdict | Evidence |
| --- | --- | --- |
| **A2** The player plants a seed in a valid grid tile. | PASS (code path), BLOCKED-RUNTIME | `src/server/Garden.luau:216-250` `plantSeed`. It checks plot ownership (`:167`), distance (`:172`), that the lane is unlocked (`:193`), that the tile is empty (`:196`), house slots (`:200`), that the seed is owned (`:224`), and water (`:228`). Every failure returns before any write. The seed is only spent inside the success `Data.update` (`:233-249`). The size is rolled on the server at plant time (`:232`) and stored with the server's `plantedAt = os.time()` (`:243`). |
| **A3** The plant grows and generates the correct money per second. | PASS (code path), BLOCKED-RUNTIME | Growth: `src/shared/Economy.luau:78-88` gives stages 1-4 from `plantedAt` and `GrowSeconds`. The 1s server tick rebuilds the model when its stage changes and pays income only for grown plants (`src/server/Garden.luau:317-350`, with income at `:337` and money at `:343-345`). Money per second is `Economy.incomeOf` = base × rarity × size × variant × bonuses (`Economy.luau:33-47`), which is the only income formula. The HUD shows the server's own per-player total (`Garden.incomeOf`, wired at `Boot.server.luau:28`). The client never writes money. |
| **A4** A larger plant generates more income than a smaller version of the same species. | PASS (code path), BLOCKED-RUNTIME | `incomeOf` multiplies by `Sizes.ById[size].Multiplier` (`src/shared/Economy.luau:38-44`). The multipliers rise strictly: Small 1, Medium 2, Large 5, Huge 10, Giant 25 (`src/shared/Sizes.luau:11-15`). With species, rarity and variant held equal, a larger size always earns more. The size is rolled on the server at plant time and saved (`Garden.luau:232`, `:240`), and the inspect popup shows it. |
| **A5** The player purchases an additional lane and retains it after rejoining. | PASS (code path), BLOCKED-RUNTIME | Purchase: `src/server/Shop.luau:20-42` only sells the next lane in order and checks the price on the server (`:32`). It writes `lanesUnlocked` into the profile inside `Data.update` (`:36-39`), and the profile is saved by autosave, on leave, and in `BindToClose` (`Data/init.luau`). Rejoin: plot assignment calls `Plots.refresh` (`src/server/Plots.luau:132`), which rebuilds the lanes from the saved `lanesUnlocked` (`:85-92`). Planting checks the same saved value (`Garden.luau:193`). House tiers follow the same pattern (`Shop.luau:44-71`). |
| **A22** Players cannot duplicate seeds, money, or plants through client requests. | PASS (code path), BLOCKED-RUNTIME | Every handler checks and then writes inside one synchronous block with no yield in between (`Garden.luau:215` comment, `:216-250`, `:252-276`, `:278-315`; `Shop.luau:20-71`). A repeated call sees the state already updated: the tile is occupied, the seed count is lower, `plants[itemId]` is gone, or the money is already spent. `Net` rate-limits each player and remote (`Remotes.luau:18-22`) and checks argument types and the loaded profile before any handler runs (`Net.luau:93-101`). |

## Design decisions to note

- **Dig up:** a grown plant moves to the plant inventory with its size and variant kept. A plant dug up before it is grown is destroyed. `Config.Garden.UnripeSeedRefund = 0` sets how many seeds come back (none by default). A plant from the inventory can be placed back with the `PlacePlant` remote and is immediately grown (`matured = true`).
- **Seeds stack by species.** A seed's rarity is the species rarity. Schema v2 migrates the v1 `species|rarity|size` keys (`Data/Schema.luau`, `migrations[1]`).
- **Starter pack:** 5 Sunpetal, 3 Pea Popper and 1 Thornwall, granted once through the `starterGranted` flag.
- **House slots:** the maximum number of planted plants per tier is 15, 27, 40, 54 and 63.
- **Growth multipliers** are applied when growth is evaluated. If a boost ends partway through, the remaining time is recomputed. Phase 5 may want time-weighted accrual instead.

## Known gaps

- `PlacePlant` gives no ripening delay. That is intended, but it is worth noting for balance.
- Lane-sign prompts on other players' plots are hidden on the client. The server rejects those purchases regardless.
- No headless Luau runtime was available, so this logic was reviewed but not executed. Every row stays BLOCKED-RUNTIME until the owner playtests.
