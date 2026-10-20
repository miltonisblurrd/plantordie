# balance-pass — Progression pacing (cut v1)

`python3 studio/tools/world_harness.py` runs this. The "Progression sim" section prints the after-table and fails the harness on any missed target (`SIM.Enforce = true`). The player model and targets live in the `SIM` table at the top of that section.

## Player model (deterministic, 5 s steps)

- **Income.** The garden is full of the newest arrived biome's drops, using house slots by biome (the pod-v2 assumption). Income per plant uses the real `Economy.incomeOf`, weighted by drop weight and by size weight. Portal income bonus is 1x and variants are Normal. After each move, the old garden keeps earning for one growth cycle (the new biome's drop-weighted `GrowSeconds`) before switching.
- **Time split.** 30% of play time is on the treadmill (`SIM.TreadmillShare`) and the rest is digging. Garden income flows the whole time.
- **Digging and the index.** Digging happens in the current biome only. Seconds per dig = swings × `DigSeconds` + 6 s walk. The index is claimed after the expected number of digs to see every species once (coupon collector over `DropTables.weighted` at the owned shovel's luck), plus a 60 s bank trip per species. A claim pays `IndexRewards` cash and the speed bonus.
- **Buying, greedy.** The next biome unlock is bought as soon as it is affordable. Shovels are bought one tier at a time, only when the price is no more than the next unlock. Treadmill levels and trails are bought by best speed gain per dollar while speed is below the next biome's recommendation. While still saving for the unlock, upgrades may spend only 50% of cash (`SIM.SaveShare`); after the unlock, they may spend all of it.
- **Arrival.** The player moves into biome k once it is unlocked and speed is at or above its `RecommendedSpeed`.
- **Targets.**
  - Time to reach the recommendation is at most 1.5x the time to afford the unlock, plus 5 minutes of slack for unlocks that take seconds.
  - Reaching Forbidden Bloom's recommendation takes 25-60 h in total.
  - No step is longer than 3 h.
  - A normal spot takes 3-8 swings with the shovel owned on arrival.

## Before (base branch numbers, same sim)

| Step | Cost | Afford | Reach rec | Shovel | Swings | Trail | Lv |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1→2 | 25K | 10m | 12m | 2 | 2 | Nature | 7 |
| 2→3 | 250K | 10m | 11m | 2 | 3 | Lightning | 9 |
| 3→4 | 2.5M | 12m | 14m | 4 | 1 | Mystic | 12 |
| 4→5 | 25M | 11m | 14m | 5 | 1 | Rainbow | 15 |
| 5→6 | 32M | 9m | 21m | 5 | 1 | Golden | 16 |
| 6→7 | 40M | 0m | 53m | 5 | 1 | Galaxy | 18 |
| 7→8 | 50M | 9m | 1.30h | 5 | 2 | Galaxy | 19 |
| 8→9 | 63M | 0m | 1.01h | 5 | 2 | Void | 19 |
| 9→10 | 80M | 8m | 2.04h | 5 | 2 | Void | 20 |
| 10→11 | 100M | 11m | 1.77h | 5 | 2 | Void | 20 |
| 11→12 | 125M | 0m | 2.88h | 5 | 2 | Void | 21 |
| 12→13 | 160M | 0m | 5.04h | 5 | 2 | Void | 21 |
| 13→14 | 200M | 0m | **754.6h** | 5 | 2 | Divine | 26 |
| 14→15 | 250M | 0m | **415.7h** | 6 | 2 | Divine | 27 |

Forbidden Bloom's recommendation took **1186 h**. 30 of the target checks missed.

- Index cash was 2x the next unlock, so unlocks were often "0m": the index paid for them outright.
- Late garden income was flat at about $100K/s, so shovels past tier 6, treadmill levels past about Lv27, and money in general never caught up with the ladders.
- Swings were 1-3 everywhere.

## After

| Step | Cost | Afford | Reach rec | Rec/afford | Step time | Shovel | Swings (tough) | Trail | Lv | Prev index |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1→2 | 50K | 21m | 15m | 0.71 | 21m | 1 | 7 (14) | Nature | 13 | claimed |
| 2→3 | 1.2M | 38m | 14m | 0.36 | 38m | 3 | 5 (10) | Lightning | 18 | claimed |
| 3→4 | 10M | 48m | 14m | 0.28 | 48m | 4 | 5 (9) | Inferno | 22 | claimed |
| 4→5 | 100M | 1.15h | 17m | 0.24 | 1.15h | 5 | 5 (9) | Rainbow | 29 | claimed |
| 5→6 | 350M | 1.22h | 14m | 0.19 | 1.22h | 5 | 5 (10) | Rainbow | 30 | claimed |
| 6→7 | 450M | 2.16h | 1.46h | 0.68 | 2.16h | 5 | 6 (12) | Galaxy | 34 | claimed |
| 7→8 | 1.35B | 2.40h | 1.82h | 0.76 | 2.40h | 6 | 5 (10) | Void | 37 | claimed |
| 8→9 | 4.2B | 2.73h | 45m | 0.27 | 2.73h | 6 | 6 (12) | Void | 39 | claimed |
| 9→10 | 11B | 2.24h | 25m | 0.19 | 2.24h | 7 | 5 (10) | Void | 40 | claimed |
| 10→11 | 40B | 2.60h | 31m | 0.20 | 2.60h | 7 | 5 (10) | Divine | 42 | claimed |
| 11→12 | 125B | 2.49h | 1m | 0.01 | 2.49h | 8 | 4 (8) | Divine | 42 | claimed |
| 12→13 | 350B | 2.65h | 50m | 0.32 | 2.65h | 8 | 5 (9) | Divine | 48 | claimed |
| 13→14 | 1.1T | 2.76h | 2.05h | 0.74 | 2.76h | 9 | 4 (7) | Divine | 60 | claimed |
| 14→15 | 4.5T | 2.35h | 0m | 0.00 | 2.35h | 9 | 4 (8) | Divine | 60 | claimed |

Forbidden Bloom's recommendation now takes **26.5 h**, and every target check passes.

- The worst step is 2.76 h (Cosmic Garden).
- Biome 1 takes 4 swings with the Starter Shovel.
- All 14 indexes are claimed, for a +140% speed bonus.
- At the end the player owns shovel 9, the Divine trail and treadmill Lv60.

Sensitivity to the treadmill share (not committed, `SIM.Enforce` passes in all three):

| Share | Total | Worst step |
| --- | --- | --- |
| 20% | 28.0 h | 2.80 h |
| 30% (default) | 26.5 h | 2.76 h |
| 40% | 25.5 h | 2.78 h |

**Reading the table.** Money is now the pacing gate in every step, and speed arrives at 0.0-0.8x of the afford time. Forbidden Bloom shows 0m because the owner-fixed recommendations are only 2x apart (500T → 1 QA): the treadmill gain needed to reach 500T in Cosmic Garden carries the player past 1 QA while they save the $4.5T unlock.

**Legacy table.** The older "minutes to afford the next biome" table (pod-v2 model, still printed above the sim) ignores index cash and upgrades. That is why its 14→15 row reads 233 min. The sim includes the index cash, which brings the step to 2.35 h.

## Every changed number

### `src/shared/Biomes.luau`: unlock `Cost` (strictly increasing, asserted)

| Biome | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Before | 0 | 25K | 250K | 2.5M | 25M | 32M | 40M | 50M | 63M | 80M | 100M | 125M | 160M | 200M | 250M |
| After | 0 | 50K | 1.2M | 10M | 100M | 350M | 450M | 1.35B | 4.2B | 11B | 40B | 125B | 350B | 1.1T | 4.5T |

`RecommendedSpeed` is unchanged (owner-fixed, asserted).

### `src/shared/Plants.luau`: `BIOME_INCOME` (plant income, unavoidable)

| Biome | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Before | 2 | 8 | 52 | 185 | 500 | 334 | 525 | 338 | 475 | 335 | 217 | 219 | 146 | 147 | 180 |
| After | 2 | 8 | 52 | 185 | 500 | 460 | 1,730 | 1,750 | 8,150 | 15,500 | 30,500 | 88,000 | 450,000 | 650,000 | 2,450,000 |

Full-garden income goes from about $65K/s at biome 5 to about $478M/s at biome 14. Before, it was flat at about $100K/s from biome 5 on.

**Why this change is unavoidable.** The owner-fixed trail ladder tops out at $2.5B and the shovel ladder at $2.5T. At $100K/s those take 7 h and 6,900 h of income, so nothing else can make them line up with biome income.

- Biomes 1-5 are unchanged, which also leaves the Halloween event tier (index 4) untouched.
- Average income per plant still rises every biome (the harness asserts this).
- Combat stats are not affected.

### `src/shared/Treadmill.luau`: levels, rate curve, cost curve

| | Levels | Rate | Cost of level L |
| --- | --- | --- | --- |
| Before | 30 | `round(1.9^(L-1))` | `round(100 × 2.3^(L-1))` |
| After | 60 | `1.35^(min(L,50)-1) × 2.3^max(0,L-50)`, forced strictly increasing | `100 × 1.52^(min(L,50)-1) × 1.05^max(0,L-50)` |

| Level | Before rate / cost | After rate / cost (cumulative) |
| --- | --- | --- |
| 2 | 2 / $230 | 2 / $152 |
| 10 | 323 / $180K | 15 / $4.3K ($12K) |
| 20 | 198K / $746M | 299 / $285K ($833K) |
| 30 | 121M / $3.1T (max) | 6.0K / $18.8M ($55M) |
| 40 | n/a | 121K / $1.2B ($3.6B) |
| 50 | n/a | 2.4M / $81B ($238B) |
| 55 | n/a | 157M / $104B ($710B) |
| 60 | n/a | 10.1B / $133B ($1.31T) |

Levels 51-60 are a cosmic tier, where rate climbs x2.3 per level and price only x1.05. It exists because Cosmic Garden's owner-fixed recommendation is 2000x Ancient Wilds'.

### `src/shared/Upgrades.luau`: shovel `Damage`

Prices, `DigSeconds`, `LuckBonus` and `ToughTier` are unchanged.

| Tier | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Before | 2 | 5 | 10 | 18 | 30 | 50 | 80 | 130 | 210 | 340 |
| After | 3 | 4 | 6 | 9 | 12 | 16 | 22 | 30 | 40 | 55 |

The expected shovel by biome is 1, 1, 3, 4, 5, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9.

- Shovel 2 is a stepping stone: the sim buys it and shovel 3 inside step 2→3.
- Shovel 10 ($2.5T) is the first purchase after reaching Forbidden Bloom. Forbidden Bloom's garden pays for it in well under an hour.

### `src/shared/Config.luau`: `Biome`

| | Before | After |
| --- | --- | --- |
| `DirtHpPerIndex` | 4 | 10 |
| `ToughHpMultiplier` | 2.5 | 2 |

### `src/shared/IndexRewards.luau`: index cash and speed bonus

| | Before | After |
| --- | --- | --- |
| Cash, biomes 1-14 | 2 × next unlock | 0.25 × next unlock (`NEXT_MULT`) |
| Cash, Forbidden Bloom | 20 × own cost | 1 × own cost (`LAST_MULT`) |
| `SpeedBonus` | 0.10 | 0.10 (unchanged) |
| `MIN_CASH` | 5,000 | 5,000 (unchanged) |

The multipliers are now exported as `CashNextMultiplier` and `CashLastMultiplier`. Cash goes from $12.5K for Green Meadows to $4.5T for Forbidden Bloom.

## Not modelled (unchanged sinks, so real play runs a little longer)

- **Fixed money sinks.** House tiers ($25K-$500M), water ($50K-$75M) and fusion machines are left out. Late in the game they are now trivial next to income.
- **Garden assumptions.** Portal income tiers (1-3.5x) are not counted. Refill walking time is not counted.
- **Night defense.** Defense bounties are not counted.
