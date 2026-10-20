# fix-basics — blast radius

Remote: `origin` = https://github.com/miltonisblurrd/plantordie.git, branch `main` (base commit 9b8a0ba).

## Clock stuck at "DAY 0:00"
- `src/client/Hud.luau:62`: initial text `"DAY  0:00"`; it only changes once `State.dayNight` is set (`Hud.luau:148`).
- `src/client/State.luau:115`: `State.dayNight` is set only by the `DayNight` RemoteEvent.
- `src/server/Boot.server.luau:50-51`: `DayNight.sendTo` fires once, inside `Data.onLoaded`. `src/client/Boot.client.luau:70` connects the listener last, after every controller starts. Nothing ever resends it.
- `src/server/Sync.luau:153`: the `RequestState` handler resends the snapshot only, not day/night.
- `src/server/DayNight.luau`: the server cycle itself is correct (300 s day / 150 s night, tweens `Lighting.ClockTime`).

## No starter seeds
- `src/server/Garden.luau:226-253`: starter pack (`Config.Garden.StarterSeeds`) granted once, gated by `profile.starterGranted`; runs on `Plots.onAssigned`.
- Saved profiles that already used the pack (or never got a plot) end up with zero seeds and no way to start.

## No shovel
- `src/server/Tools.luau`: tool is put only in `Backpack` on `CharacterAdded` (deferred) and `Data.onLoaded`. Nothing in `StarterGear`, so a Backpack reset on spawn loses it.
- `src/shared/Upgrades.luau:27`: tier 1 is named "Rusty Shovel" (owner calls it "Starter Shovel").

## Small biomes, few dig spots
- `src/shared/Config.luau:49-62`: `Biome.Size = 56`, `DigSpots = 8`, `ToughSpots = 3`.
- `src/server/World/BiomeKit.luau:296-310`: spot placement; `digSpotModel` (235-273) draws a mound + marker, with no ground circle.
- `src/server/World/Layout.luau`: biome line positions derive from `Biome.Size`; `mapExtent` too.
- 15 builders in `src/server/World/Builders/Biomes/*.luau` use `Kit.at`/`Kit.scatter` (clamped to size, so they keep working when it grows; prop counts are fixed).

## Wall blocks the next biome
- `src/server/World/BiomeKit.luau:112`: `WallBack` is a solid full-width wall at the biome's +Z edge. The biomes are a straight line (`Layout.luau`), so the trail to biome N+1 (`Layout.biomePath`) runs straight into biome N's back wall. Opening the gate barrier (`client/Gates.luau:30`) can't get past it.
- `src/server/World/Builders/Gate.luau`: gate barrier (works: client turns CanCollide off for owned biomes).
- `src/server/Biomes.luau:162-176`: server region bounce for locked biomes (the real rule; unchanged).

## Features touched
Day/night HUD, starter kit, shovel tool, biome layout and size, dig spots, biome walls.
