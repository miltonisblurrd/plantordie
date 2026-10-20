# fix-basics — cut v1 (frozen)

## In scope
1. **Clock works.** The client always gets the day/night state:
   - The server resends it on `RequestState`.
   - The server mirrors phase, endsAt, duration and night number as `ReplicatedStorage` attributes, and the client reads them if no event has arrived.
   - The HUD shows the phase, the countdown, and the in-game time of day (for example `DAY 4:12 · 9:30 AM`).
   - Lighting visibly moves through day and night.
2. **Starter seed guaranteed.**
   - New profiles still get the starter pack.
   - On every load, a player with zero seeds, nothing planted and no plant items gets at least one starter seed (1 Sunpetal), with a toast.
   - No duplication for players who already have seeds or plants.
3. **Starter Shovel guaranteed.**
   - Rename tier 1 to "Starter Shovel".
   - The tool goes into both `StarterGear` and `Backpack`, and is re-placed after respawn and after shovel upgrades, so a player always has exactly one.
4. **Bigger biomes.**
   - `Config.Biome.Size` goes from 56 to 112. Layout, region checks, gates, trails and map extent follow from config.
   - Builders keep working; scatter counts are scaled by area so biomes don't look empty.
5. **Dig circles.**
   - Each dig spot sits on a flat, visible dirt circle (round brown disc, a little darker rim) that marks where to dig.
   - The circle hides with the spot while it's respawning.
   - 10 spots per biome (`DigSpots = 10`, `ToughSpots = 3`), spread out without overlapping each other, the safe zone or the entrance lane.
6. **Walk through to the next biome.**
   - Each biome's back wall has an exit gap that lines up with the next biome's gate and trail (biomes 1–14; 15 stays closed).
   - After buying the next biome, the player walks from biome N through its exit, through gate N+1, into biome N+1.
   - The server region bounce stays the real rule for locked biomes.

## Out of scope (later tasks)
- Speed stat, treadmill, trails, bats, Index rewards, biome banner, guardian chase rework.
- The new 10-shovel lineup and the Shovel Shop (task 3). Only the tier 1 rename happens here.
- Economy retuning.

## Acceptance checks
- A1. A fresh join: within 2 s the HUD clock shows DAY with a counting-down timer (not 0:00) and a time of day. After the day ends it switches to NIGHT, and the sky gets dark.
- A2. A client that missed the first `DayNight` event (simulated) still shows the correct clock.
- A3. A fresh profile has the starter pack in Seeds. A saved profile with zero seeds, zero planted and zero plants gets 1 Sunpetal on join. A profile with seeds gets nothing extra.
- A4. On spawn and after a respawn, the backpack has exactly one "Starter Shovel" (or the owned tier), and it digs.
- A5. Biome floors are 112×112. Every biome builder runs without errors. The harness world part count is reported and stays within the existing budget, or the new count is noted.
- A6. Each biome has 10 dig spots, each on a visible dirt circle. Spots don't overlap (≥ 8 studs apart) and aren't in the safe zone or the entrance lane.
- A7. With biome 2 bought, a player walks from Green Meadows through its back exit and gate 2 into Mushroom Forest without being blocked. Without buying it, gate 2 blocks the path, and teleporting in gets bounced.
- A8. `rojo build` succeeds; the harness `python3 studio/tools/world_harness.py` runs clean.
