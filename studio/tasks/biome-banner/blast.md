# biome-banner — blast radius

Base: `cursor/shops-trails-shovels-dee5`.

- `src/shared/Biomes.luau`: biome list (Index, Id, Name, Cost, Palette). Gets Emoji and RecommendedSpeed.
- `src/server/Biomes.luau`: `inside(info, pos)` is a square region of `Config.Biome.Size/2 + 1` around each biome CFrame (from `Layout.biomeCFrame`). This is the server's authority for access.
- `src/server/World/Layout.luau`: `biomeCFrame(index)`; the client can recompute regions from shared Config and Layout, or read the `Biome_<Id>` model floor (`BiomeFloor` attribute in `BiomeKit.ground`).
- `src/server/World/BiomeKit.luau` skeleton: biome safe zone ring (`SafeZone` part, `Config.Biome.SafeRadius`).
- `src/server/Sync.luau` `areaFor` / `client/Hud.luau` Area panel: the existing server-side area name (0.5 s).
- `src/shared/Format.luau` `short`: K/M/B/T/QA.
- Hub and plots: the central safe area (`Config.Bank.HubRadius`) and plot footprints (`Plots.plotAt`).
