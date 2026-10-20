# index-rewards — blast radius

Base: `cursor/guardian-chase-bc76` (schema v9).

- `src/shared/Discovery.luau`: the discovered set is derived from `collection` plus current holdings (seeds, expedition, plants, planted). Selling or fusing a plant can drop it from the derived set unless `collection` was written. Needs to become a permanent write.
- `src/client/Collection.luau`: Index UI with one section per biome (`Plants.ByBiome`) plus event sections; "species|variant" keys.
- `src/shared/Plants.luau`: `ByBiome`; plant defs include rarity (and Secret tiers if present).
- `src/server/Carry` (task 5): banking point, where a seed becomes owned (discovery moment).
- `src/server/Garden.luau`, `Fusion`, `Purchases`, `Event`: other grant paths.
- `src/server/Data/Schema.luau`: needs `indexClaimed`, `speedBonus` (or a permanent multiplier), `batSkins`.
- `src/server/Treadmill.luau` and `src/shared/Speed.luau`: where a permanent Speed bonus applies.
- No rebirth system exists in the code (grep: none).
