# pod-v2 — frozen cut

Cut version: **v1** (2026-10-17). Source: owner spec, sections 1–18, quoted in `board.md`.

## Owner decisions at intake

- Rebuild on new architecture; v1 code is retired, not extended.
- Repo: `https://github.com/miltonisblurrd/plantordie`, branch `main`.
- QA: code review and static checks only (`selene`/`luau-lsp` analyze, Rojo build). The owner playtests at the end.
- Robux: placeholder IDs in one file, `src/shared/Products.luau`.
- Halloween: live from 2026-10-17 through 2026-11-02 23:59 PT; window is config.
- Art: every model built from Roblox parts in code. No uploaded meshes.

## Architecture (all phases build into this)

```
src/shared/      Config, Plants, Rarities, Sizes, Biomes, DropTables, Zombies,
                 Guardians, Houses, Lanes, Upgrades, Fusion, Events, Products, Remotes
src/server/      Boot, Data (session lock, retries, receipt ledger), Plots, Garden
                 (grid/growth/income), Inventory, Dig, Biomes (build + gates),
                 Guardians, DayNight, Zombies, Combat, House, Fusion, Purchases,
                 Events, World/Builders/* (hub, plot, 15 biome builders, models)
src/client/      Boot, Hud, Inventory, Placement, Camera, Shops, Fusion, Index,
                 Event, Settings, Notifications, Danger
```

The rules every server module follows: the server owns every number. Each remote is validated for type, ownership, distance, cooldown, and rate. Saved times use `os.time()` on the server.

## Phases (two in flight at a time)

### P1 Foundation — §1, 2, 3 grid, 13 HUD, 15, 16
In: hub with 15 biome gates around it; 8 plots, unique assignment, owner name sign; 3-lane grid of soil tiles with locked lanes 4–7 shown with prices; DataStore with session lock, 3 retries, never saving after a failed load, BindToClose flush; HUD for money, income/sec, biome, day/night, house HP.
Checks: A1 unique plot; A21 two players isolated; A25 failed load does not overwrite.

### P2 Planting — §4, 5, 10 (lanes, house tiers)
In: plant definitions with all §4 fields; 7 rarities; sizes ×1/2/5/10/25; income formula from §5 in one function; tap-to-plant with preview and invalid feedback; seed consumed only on success; 4 growth stages with timer; offline growth; buy lanes 4–7; 5 house tiers that change the model and grant HP and slots.
Checks: A2, A3, A4, A5, A22 (seed, money, and plant duplication by remote spam).

### P3 Exploration — §6, 7, 8
In: shovel tool and 4 shovel tiers; dig spots per biome with respawn; server roll from the biome drop table; 15 biomes, each with its own builder, palette, props, 3+ exclusive plants, a drop table, and a gate. Unlock costs: Meadows free, $25K, $250K, $2.5M, $25M, then roughly geometric up to $250M at Forbidden Bloom. 15 guardians with patrol, detection, PathfindingService chase, leash, safe zones, and catch handling that drops only unbanked expedition seeds. Seeds are banked on reaching the home plot.
Checks: A6, A7, A8, A9, A10, A23.

### P4 Defense — §9, 10 (traps, house HP)
In: synced day/night with a countdown; 6 zombie types plus a boss every 5th night, scaled by the player's highest biome and lane count; lane-locked movement from right to left; combat roles projectile, rapid, AoE, slow, burn/poison, wall, and income-only; house HP, repair, and 2 trap types; wave reward. The zombie cap per plot is config.
Checks: A11, A12, A13.

### P5 Advanced — §10 water, 11, 12, 14
In: water upgrades (channel, sprinkler, pond) that speed growth and unlock water-dependent species; Neon Maker and Mega Maker with the spec timers, server validation of 4 identical plants, offline completion, claim-once via a state flag; Developer Products for instant grow, Neon skip, Mega skip, and the Halloween pack, plus a 2× growth boost; idempotent ProcessReceipt using a PurchaseId ledger in the profile; Halloween event with 7 plants, decor, shop, event currency, odds shown before purchase, guardian, 3 quests, and expiry that keeps owned items. The event system is reusable.
Checks: A14, A15, A16, A17, A18, A19, A20.

### P6 Polish and test
In: tweens, sounds (Roblox library sound IDs), mobile layout, a part-count budget, a collection index, settings; walk all 25 acceptance tests in `qa.md`.
Checks: A24 mobile, plus a re-walk of A1–A25.

## Acceptance checks

A1–A25 are the 25 bullets in spec §18, in order. Under this QA mode, each row is marked PASS (code path verified and static checks clean), FAIL, or BLOCKED-RUNTIME (needs a Studio playtest by the owner).

- A1 A new player joins and receives a unique plot.
- A2 The player plants a seed in a valid grid tile.
- A3 The plant grows and generates the correct money per second.
- A4 A larger plant generates more income than a smaller version of the same species.
- A5 The player purchases an additional lane and retains it after rejoining.
- A6 The player digs for a seed in a biome and receives a valid reward.
- A7 The player cannot enter an unreleased or locked biome.
- A8 The player purchases a biome and retains permanent access.
- A9 A guardian detects, chases, and loses the player correctly.
- A10 A caught player loses only the specified unbanked seeds.
- A11 Zombies enter the correct lanes and attack the correct player's garden.
- A12 Defensive plants damage zombies correctly.
- A13 A zombie reaching the house damages its defenses.
- A14 Four identical normal plants can be fused into one Neon plant.
- A15 Four identical Neon plants can be fused into one Mega plant.
- A16 Growth and fusion progress correctly while the player is offline.
- A17 A completed fusion cannot be claimed twice.
- A18 Failed or cancelled purchases do not grant unauthorized rewards.
- A19 Verified Developer Product receipts grant the correct reward exactly once.
- A20 Halloween plants remain in player inventories after the event ends.
- A21 Two players can play simultaneously without affecting each other's plots or inventories.
- A22 Players cannot duplicate seeds, money, or plants through client requests.
- A23 All 15 biomes are implemented and reachable through progression.
- A24 The game remains playable using mobile controls.
- A25 The server handles save failures and player disconnects without intentionally wiping player progress.

## Out of scope for cut v1

- Uploaded meshes, custom animations uploaded to Roblox, and custom audio.
- Real Developer Product and Game Pass IDs.
- Leaderboards, trading, and friend plot permissions (§2 "without permission" is treated as owner-only).
- Separate Board bot, specialist bots, incident watcher (held per studio rules).
