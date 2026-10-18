# pod-v2 — Biome pacing (cut v1)

The numbers live in `src/shared/Plants.luau`. `studio/tools/world_harness.py` reproduces this table and fails if income per plant ever drops from one biome to the next.

## Formulas

- BaseIncome = `BIOME_INCOME[k] × flavour`, where `BIOME_INCOME = {2, 8, 52, 185, 500, 334, 525, 338, 475, 335, 217, 219, 146, 147, 180}`. Rarity multipliers come on top through `Economy.incomeOf`.
- GrowSeconds = `BIOME_GROW[k] × RARITY_GROW[rarity]`, where `BIOME_GROW = {30, 40, 55, 75, 100, 135, 180, 240, 320, 420, 560, 740, 980, 1300, 1700}` and `RARITY_GROW` is 1, 1.4, 2, 3, 4.5, 6, 9 (Common to Divine).
- Combat: `ROLE_STATS[role]`, with damage × `(1 + 0.6 × (k − 1))`.

## Model

The model assumes a full garden of drops from the newest unlocked biome, at the drop-table rarity mix and an average size multiplier of 2.25. House slots are those of the best house allowed by that biome.

Each step also includes one growth cycle. After a refill, the garden earns nothing until the newest biome's plants are grown, so the model adds their drop-weighted average GrowSeconds. Refill walking time and house purchases are still left out, so real play takes a little longer. Income, biome costs and house prices are unchanged. Only the model changed.

## Minutes to afford the next biome (revised 2026-10-18, growth included)

| Step | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 | 8→9 | 9→10 | 10→11 | 11→12 | 12→13 | 13→14 | 14→15 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Growth (min) | 0.6 | 0.9 | 1.2 | 2.3 | 2.2 | 4.1 | 3.9 | 7.2 | 7.2 | 12.7 | 23.8 | 31.4 | 57.8 | 76.7 |
| Minutes | 6.7 | 6.9 | 11.1 | 14.2 | 10.4 | 14.2 | 13.3 | 18.9 | 22.0 | 31.0 | 43.4 | 56.3 | 88.8 | 115.2 |

Total: about 453 minutes (7.5 hours). That is 221 minutes of income time plus 232 minutes of growth. The previous table, which left growth out, said about 221 minutes (3.7 hours).

## What growth changes

The early steps barely move, because those plants grow in under a minute. From biome 8 on, growth is a large share of each step. Steps 8 to 11 now land inside the 20 to 45 minute target. Steps 12 to 15 run over it (56, 89 and 115 minutes), because the late biomes' Legendary and Mythical plants take a long time to grow.

Retuning is out of this cut. Bringing steps 12 to 15 back under 45 minutes would mean shorter late GrowSeconds or cheaper late biomes, and either one is the PM's call.

## Money sinks (Phase 5)

Biome costs stay frozen and plant income is not retuned. The late steps are stretched by spending, not by lower income. These one-time purchases compete with the next biome unlock:

| Sink | Costs |
| --- | --- |
| House tiers 2-5 | $25K, $1M, $40M, $500M |
| Water (Channel, Sprinkler, Pond) | $50K, $2M, $75M |
| Neon maker, Mega maker | $250K, $25M |

Sinks after biome 8 total about $640M. At the late-game income in the table above, that is roughly the price of three more late biomes, so buying them all makes the late steps longer still. The sinks are optional, so the table above stays the floor for players who skip them.
