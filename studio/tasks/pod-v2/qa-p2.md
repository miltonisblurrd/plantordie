# pod-v2 — QA, Phase 2 (Planting)

Cut: **v1**. Mode: code review plus static checks. This environment has no Studio runtime, so nothing here was playtested. CI green is not a pass.

Branch `cursor/p1-foundation-cc3f`.

**How the rows were read.** The text of the §18 bullets is not in the repo. `cut.md` maps P2 to A2, A3, A4, A5 and A22, and defines A22 as "seed, money, and plant duplication by remote spam". The other four rows are read from the P2 scope line. **The owner should confirm this mapping against the spec.**

## Build and static results

| Check | Result |
| --- | --- |
| `rojo build -o build.rbxlx` (7.7.1) | PASS |
| `selene src` (`std = "roblox"`) | PASS: 0 errors, 0 warnings |
| `luau-lsp analyze --platform=roblox` (Roblox definitions and sourcemap, all modules `--!strict`) | PASS: 0 errors |

## Acceptance checks in P2

| Check (as read) | Verdict | Evidence |
| --- | --- | --- |
| **A2**: plant a seed on your own unlocked tile, and the seed is spent only on success | PASS (code path), BLOCKED-RUNTIME | `src/server/Garden.luau:216-250` `plantSeed`. It checks plot ownership (`:167`), distance (`:172`), that the lane is unlocked (`:193`), that the tile is empty (`:196`), house slots (`:200`), that the seed is owned (`:224`), and water (`:228`). Every failure returns before any write. The seed is only spent inside the success `Data.update` (`:233-249`). The size is rolled on the server at plant time (`:232`) and stored with the server's `plantedAt = os.time()` (`:243`). |
| **A3**: 4 growth stages with a timer, and growth continues offline | PASS (code path), BLOCKED-RUNTIME | `src/shared/Economy.luau:78-88` gives the progress and the stage (1 Seed, 2 Sprout, 3 Young, 4 Grown), computed from `plantedAt`, `GrowSeconds` and the growth multiplier (`:50-69`, the hook for water and the boost). Because it is based on timestamps, plants keep growing offline. The 1s server tick rebuilds the model when its stage changes (`Garden.luau:317-350`). The plant model is built per stage, and the visual size is capped at 1.8× (`World/Builders/PlantModel.luau`). The client shows the timer or the income label from the server's attributes (`client/GardenView.luau`). |
| **A4**: income comes from one formula, and the server is the only authority | PASS (code path), BLOCKED-RUNTIME | One function: `Economy.incomeOf` = base × rarity × size × variant × bonuses (`Economy.luau:33-47`). Only the server tick adds money (`Garden.luau:337-347`). The HUD income/sec comes from `Garden.incomeOf` through `Sync.setIncomeProvider` (`Boot.server.luau:28`). Offline earnings (`Economy.luau:115`) are capped at 4h and paid at a 0.5 rate (`Config.Garden`), and are granted once on plot assignment with a welcome-back toast (`Garden.luau:116-151`). The client never writes money. |
| **A5**: buy lanes 4-7 in order, and buy house tiers | PASS (code path), BLOCKED-RUNTIME | `src/server/Shop.luau:20-42` only sells the next lane in order and checks the price on the server (`:32`). The change persists in the profile and the plot visuals are rebuilt (`:40`). `Shop.luau:44-71` checks the house cost and the required biome (`:56`, `:60`), swaps the house model (`:68`), and resets HP to the new max (`Sync.resetHouseHp`). Each tier raises the plant slot count (`Houses.luau`, `Slots`). The client confirm dialogs state the benefit and the price (`client/Shops.luau`). |
| **A22**: no duplicating seeds, money or plants by spamming remotes | PASS (code path), BLOCKED-RUNTIME | Every handler checks and then writes inside one synchronous block with no yield in between (`Garden.luau:215` comment, `:216-250`, `:252-276`, `:278-315`; `Shop.luau:20-71`). A repeated call sees the state already updated: the tile is occupied, the seed count is lower, `plants[itemId]` is gone, or the money is already spent. `Net` rate-limits each player and remote (`Remotes.luau:18-22`) and checks argument types and the loaded profile before any handler runs (`Net.luau:93-101`). |

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
