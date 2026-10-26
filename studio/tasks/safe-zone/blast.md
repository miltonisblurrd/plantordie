# safe-zone — blast radius

Remote: `origin` → `https://github.com/miltonisblurrd/plantordie.git`. Base `main` @ `c0cf0f6`.

## Where safety is defined today

- `src/server/World/BiomeKit.luau` `Kit.skeleton` builds a `SafeZone` neon ring and a `SafeSign` "SAFE ZONE" board inside **every** biome (radius `Config.Biome.SafeRadius` = 10, just inside the entrance). Returns `safeCenter`/`safeRadius` in the skeleton. `Kit.isClear` keeps props off that circle.
- `src/shared/BiomeRegions.luau` precomputes `safeCenters` per biome and exposes `safeCenter`, `SafeRadius`, `inSafeZone(biomeId, pos)`.
- `src/server/Biomes.luau` re-exports `Biomes.inSafeZone`.
- `src/server/GuardianAI.luau` `inHubSafe` = 26-stud circle (`Config.Bank.HubRadius`) at the hub spawn (0, -70). Each guardian also carries its own `inRegion`/`clamp`. Chase ends on `inHubSafe`, own plot (`bank`), drop, timeout, loss. Chase moves (`free = true`) are unclamped, so a guardian can run through the plot row.
- `src/server/Bat/init.luau` `Bat.inSafeZone` = any plot, the 26-stud hub circle, or any biome safe circle.
- `src/server/Sync.luau` `areaFor` labels `"<Biome> (Safe)"` from `Biomes.inSafeZone`.

## Home area geometry (from Config + Layout)

- Plot row: 8 plots, span 88, centred on X=0, Z ∈ [-32, 32] (`Config.Plot.Depth` 64). Outer plot edge X = ±347.
- Hub: fountain, spawn, makers and stalls at Z = -70, plaza radius 42.
- Biome 1 floor starts at Z = 32 + `FrontGap` 28 = 60; its gate at Z = 54. Trail 1 runs Z 38 → 60.
- Halloween event guardian zone: centre (45, 0, 57), radius 42 (`src/shared/Events.luau`). One patrol point falls at Z = 32.

## Callers to update

- `GuardianAI` (chase end, chase start, catch, movement), `Bat` (`inSafeZone`), `Sync` (area label), `BiomeKit` (ring, sign, skeleton type), `BiomeRegions`, `Biomes`, `Boot` (start order).
- Harness `studio/tools/world_harness.py` lines 831-834 and 1038-1040 assert the per-biome circles.

## Features touched

Guardian chase (task guardian-chase), bats PvP (task bats-pvp), HUD area label. Not touched: walls, entrances, gates, plot walls, dig spots, Speed gates, guardian models/animations.
