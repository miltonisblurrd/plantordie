# pod-v2 — Biome pacing (cut v1, Phase 3)

The numbers live in `src/shared/Plants.luau`. `studio/tools/world_harness.py` reproduces this table.

## Formulas

- BaseIncome = `BIOME_INCOME[k] × flavour`, where `BIOME_INCOME = {2, 8, 52, 185, 500, 480, 640, 550, 830, 800, 540, 700, 600, 750, 900}`. Rarity multipliers come on top through `Economy.incomeOf`.
- GrowSeconds = `BIOME_GROW[k] × RARITY_GROW[rarity]`, where `BIOME_GROW = {30, 40, 55, 75, 100, 135, 180, 240, 320, 420, 560, 740, 980, 1300, 1700}` and `RARITY_GROW` is 1, 1.4, 2, 3, 4.5, 6, 9 (Common to Divine).
- Combat: `ROLE_STATS[role]`, with damage × `(1 + 0.6 × (k − 1))`.

## Model

A full garden of drops from the newest unlocked biome, at the drop-table rarity mix and an average size multiplier of 2.25. Growth time and refill time are ignored, so real times run a little longer.

## Minutes to afford the next biome

| From biome | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Minutes | 6.2 | 6.1 | 9.9 | 11.9 | 8.2 | 7.0 | 7.6 | 7.2 | 8.5 | 7.7 | 7.9 | 7.8 | 7.5 | 7.5 |

Garden income rises with every biome. The target band is 6 to 12 minutes per biome.
