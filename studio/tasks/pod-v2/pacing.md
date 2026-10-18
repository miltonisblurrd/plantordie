# pod-v2 — Biome pacing (cut v1)

The numbers live in `src/shared/Plants.luau`. `studio/tools/world_harness.py` reproduces this table and fails if income per plant ever drops from one biome to the next.

## Formulas

- BaseIncome = `BIOME_INCOME[k] × flavour`, where `BIOME_INCOME = {2, 8, 52, 185, 500, 334, 525, 338, 475, 335, 217, 219, 146, 147, 180}`. Rarity multipliers come on top through `Economy.incomeOf`.
- GrowSeconds = `BIOME_GROW[k] × RARITY_GROW[rarity]`, where `BIOME_GROW = {30, 40, 55, 75, 100, 135, 180, 240, 320, 420, 560, 740, 980, 1300, 1700}` and `RARITY_GROW` is 1, 1.4, 2, 3, 4.5, 6, 9 (Common to Divine).
- Combat: `ROLE_STATS[role]`, with damage × `(1 + 0.6 × (k − 1))`.

## Model

The model assumes a full garden of drops from the newest unlocked biome, at the drop-table rarity mix and an average size multiplier of 2.25. House slots are those of the best house allowed by that biome. Growth time, refill time and house purchases are ignored, so real play takes longer.

## Minutes to afford the next biome (revised 2026-10-18)

| Step | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 | 8→9 | 9→10 | 10→11 | 11→12 | 12→13 | 13→14 | 14→15 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Minutes | 6.2 | 6.1 | 9.9 | 11.9 | 8.2 | 10.1 | 9.3 | 11.7 | 14.8 | 18.4 | 19.6 | 24.9 | 31.0 | 38.5 |

Total: about 221 minutes (3.7 hours) of income time, up from about 2 hours.

## Why the late steps stop at about 39 minutes, not 45

The cut fixes biome costs: geometric to $25M, then roughly ×1.25 per biome up to $250M. With costs fixed, a longer step can only come from a lower garden income. Going lower than the table above would make a newer biome's plants earn less per plant than older ones, so players would have no reason to plant them. The harness enforces that floor.

To reach 20 to 45 minutes on every step from 8 to 15, one of these is needed:

- Raise the late biome costs above $250M. This is a cut change, so it is the PM's call.
- Make a later phase add a money sink, such as house tiers 4 and 5 ($40M and $500M), which this model leaves out.
