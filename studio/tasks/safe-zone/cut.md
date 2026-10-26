# safe-zone — cut v1 (frozen)

## In scope

1. **One region.** New `src/shared/SafeZone.luau`: one axis-aligned box over the whole home area. X covers every plot plus `Config.SafeZone.SideMargin`. Z runs from behind the hub plaza (`BackMargin`) to the boundary line `FrontInset` studs in front of the plot row, across the full map width at that line. `contains(pos)`, `bounds()`, `keepOut(from, to)` (clamps a move so it never crosses in), `pushOut(pos)`.
2. **Server authority.** New `src/server/SafeZone.luau`: a `CheckSeconds` loop reads each character's server position, sets the player attribute `InSafeZone`, and fires `onEnter` / `onLeave`. `isProtected(player)`.
3. **Remove biome safe zones.** Delete the `SafeZone` ring and `SafeSign` from `Kit.skeleton`, the `safeCenter`/`safeRadius` skeleton fields, `BiomeRegions.safeCenter`/`SafeRadius`/`inSafeZone`, `Biomes.inSafeZone`, `Config.Biome.SafeRadius`. The entrance prop clearing in `Kit.isClear` stays (same numbers) so walls, entrances and prop layout do not move.
4. **Guardians.** Every guardian (15 biome + event) uses the one region:
   - chase ends `safe` the tick the target is protected, and immediately on `onEnter`;
   - a chase cannot start on a protected player;
   - no catch on a protected player;
   - every guardian move is passed through `keepOut`, so it stops at the boundary;
   - patrol and return goals inside the region are pushed out;
   - after a `safe` end the guardian returns to patrol (no teleport);
   - a carrier who escaped to safety, left again, and is back in that guardian's biome while still carrying that biome's seed is chased again.
5. **Bats.** `Bat.inSafeZone` = the one region.
6. **HUD label.** Own or other plot names stay; anywhere else inside the region reads `Safe Zone`; biomes show only their name.
7. **Boundary visual.** One thin, non-colliding green strip across the full width at the boundary, plus one `SAFE ZONE` sign at the trail. No new walls.
8. **Harness.** Replace the per-biome circle asserts with one-region asserts (plots, hub, path covered; biome 1 entrance, biome interiors, and all 15 biomes not covered; `keepOut` never ends inside).

## Out of scope

Zone size, walkway and wall layout (separate canvas). Auto Dig, progress notes, Speed/Luck upgrades. Guardian models, animations, speeds, detect ranges. Day/night zombie defense.

## Acceptance checks (maps to canvas tests A-F)

- A: carrier runs from a biome into the region → chase ends `safe` within one tick.
- B: the guardian's position never ends inside the region; it does not reach any plot entrance.
- C: players on several plots are all `InSafeZone`; a carrier in a biome is still chased.
- D: no `SafeZone`/`SafeSign` part in any of the 15 biomes; no biome point is `contains`.
- E: carrier leaves the region and re-enters the seed's biome → chased again.
- F: guardian within catch range at the moment of entry → chase still ends, no catch.
