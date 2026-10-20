# balance-pass — cut v1 (frozen)

## Fixed by the owner (do not change)
- The 15 RecommendedSpeed values.
- The 10 trail prices and multipliers.
- The 10 shovel prices.
- Guardian rule: a carrier at the recommendation outruns the guardian, and one at 1/10 of it doesn't.

## In scope
1. **Progression model in the harness.** A deterministic simulation of a player who:
   - plays biome by biome;
   - earns income from the plants that biome drops;
   - buys the next biome, then the shovel that fits, then treadmill levels and trails as money allows;
   - trains on the treadmill for a share of the time (default 30%);
   - claims each Index reward.

   It prints a table per biome: time to afford the unlock, time to reach the RecommendedSpeed, which shovel and trail are owned, and digs per spot.
2. **Pacing targets** (configurable at the top of the sim):
   - Reaching each biome's recommended Speed takes no more than about 1.5× the time to afford its unlock.
   - Total time to reach Forbidden Bloom's recommendation: 25–60 h of play.
   - No biome has a dead wall over 3 h.
3. **Tune only these to hit the targets:**
   - Treadmill: level count (up to 60), rate curve and cost curve.
   - Biome unlock Costs, which must stay strictly increasing.
   - Shovel Damage, DigSeconds and Luck. Dirt HP so the matching shovel for each biome breaks a spot in 3–8 swings.
   - Index cash and speed bonus.
   - Plant income only if unavoidable, and noted.
4. **Shovel ladder fit.** The shovel prices span $25K to $2.5T, so map each biome to the shovel expected there and make sure that biome's income can afford it. Change biome Costs and income so the ladders line up with the fixed shovel and trail prices.
5. **Treadmill Robux at max level:** hide or disable the R$ button at MAX, and refuse the prompt, instead of banking a useless credit.
6. **Pre-existing defense assert** ("Night 5 boss … wilted after dawn 2"): investigate. Fix the game bug if it's real, or fix the harness if the check is wrong, and say which. The full harness should run to exit 0.
7. **Write `studio/tasks/balance-pass/pacing.md`** with the before and after tables and every changed number.

## Out of scope
New features; changing owner-fixed numbers; the device playthrough (owner or QA in Studio; that row stays BLOCKED).

## Acceptance checks
- H1. The harness prints the pacing table and meets the targets in item 2 (or every miss is explained in `pacing.md`).
- H2. The owner-fixed numbers are unchanged (harness asserts them).
- H3. The guardian fairness asserts still pass.
- H4. Each biome's expected shovel breaks a spot there in 3–8 swings.
- H5. No R$ treadmill offer at MAX.
- H6. The full harness exits 0; the defense assert is fixed and explained.
- H7. rojo build OK. Device playthrough is BLOCKED until Studio.
