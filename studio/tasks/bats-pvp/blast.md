# bats-pvp — blast radius

Base: `cursor/index-rewards-37d5` (schema v10).

- `src/server/Carry` (task 5): `isCarrying`, `carried`, `drop(player, pos, reason)`, `transfer(from, to)`; `Carry/Core.luau` has a pluggable `canTake` (owner-only today) for dropped-seed pickups.
- `src/shared/IndexRewards.luau` (task 6): 15 bat skins plus Wooden, with colors and material hints. `profile.batSkins = { owned, equipped }`.
- `src/server/Tools.luau`: shovel tool builder (pattern for a Bat tool; both live in the Backpack).
- `src/shared/Combat.luau`: existing combat helpers (check what's there).
- `src/server/Treadmill.luau` `stun(player, s)` and `applyWalkSpeed`: reuse for hit stun.
- Safe zones: own plot / any plot (`Plots.plotAt`), hub (`Config.Bank.HubRadius`), biome safe zones (`BiomeRegions.inSafeZone`).
- `src/client/ShopStalls.luau` / `Collection.luau`: where a skin equip UI can live.
- `src/client/Shovel.luau`: tool activation pattern (click/tap).
