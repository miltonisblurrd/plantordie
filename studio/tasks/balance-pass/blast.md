# balance-pass — blast radius

Base: `cursor/bats-pvp-fbb1`.

- `src/shared/Treadmill.luau`: level table (1.9^L rate, 2.3^L cost, 30 levels) and `gain`.
- `src/shared/Trails.luau`: prices and multipliers. The owner fixed these exactly; don't change them.
- `src/shared/Upgrades.luau` `Shovels`: prices are owner-fixed; Damage, DigSeconds and Luck are tunable.
- `src/shared/Biomes.luau`: Cost (unlock) is tunable; RecommendedSpeed is owner-fixed.
- `src/shared/IndexRewards.luau`: cash and speed bonus.
- `src/shared/Speed.luau` + `Config.Guardian.SpeedFactor` 0.87, `Config.Carry.SpeedFactor` 0.9.
- `src/shared/Economy.luau`, `Plants.luau`, `Rarities.luau`, `Sizes.luau`: income per plant by biome.
- `Config.Biome.DirtHpPerIndex`, `ToughHpMultiplier`: dirt HP vs shovel damage.
- `studio/tasks/pod-v2/pacing.md` and the harness pacing table: the existing pacing model.
- `src/server/Purchases/init.luau`: TreadmillLevel credit at max.
- Harness defense sim / `src/server/Defense/*`: the "wilted after dawn" assert.
