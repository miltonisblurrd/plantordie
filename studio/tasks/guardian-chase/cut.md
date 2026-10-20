# guardian-chase — cut v1 (frozen)

## In scope

### Carry model (server, new `src/server/Carry.luau`)
- **Revealing a seed:** a successful dig reveals a seed pickup on that dirt spot instead of adding to the bag. It's a small glowing seed model with a rarity-colored label. It belongs to the digger for 20 s; after that it despawns.
- **Picking it up:** the digger picks it up with a ProximityPrompt (or by walking over it). The server checks range and that they aren't already carrying.
- **One at a time:** a player carries at most one seed. It shows above their head (BillboardGui with name and rarity), visible to all.
- **Carrying slows you down:** walk speed drops a little (configurable, default ×0.9).
- **Banking:** walking onto your own plot banks the carried seed into `seeds` (secured), ends the chase, and notifies you. The hub fountain no longer banks carried seeds.
- **Leaving the game:** a carried seed is dropped at your position and follows the normal 20 s rule.
- **Old saved bags** (`profile.expedition`) are banked into `seeds` on load (migration v9). Keep the field empty afterwards.
- **API for task 7 (bats):** `Carry.isCarrying(p)`, `Carry.drop(p, pos, reason)` and `Carry.transfer(from, to)` (atomic, no duplicates).

### Chase trigger
- Digging never triggers a chase.
- Picking up a seed (from a dig or a recovered drop) starts that biome's guardian on that player only.
- The guardian records its biome of origin.
- No idle detection of non-carriers. Guardians patrol and ignore players who aren't carrying.

### Guardian speed
- `src/shared/Speed.luau` gains `guardianSpeedFor(recommendedSpeed) = walkSpeedFor(recommendedSpeed) × Config.Guardian.SpeedFactor` (default 0.97). A player at the recommended Speed is slightly faster, and a player below it is slower.
- Carry slowdown is included in the balance note.
- Replaces the fixed ChaseSpeed. Patrol speed is a fraction of it.

### Chase range
- The guardian may leave its biome to chase across the trails and plot approach.
- It stops at: the target's own plot (banked), the hub safe area, or a max chase time (configurable, default 60 s).
- After that it walks back to its biome and patrols.
- It never targets anyone else while chasing.

### Catch
- The server checks distance ≤ catch range.
- Knockback: impulse away from the guardian plus upward. The victim is stunned for about 1.5 s (PlatformStand or WalkSpeed 0).
- The seed drops exactly at the catch position (snapped to ground).
- The guardian stops, waits through a cooldown, then waits or returns. It resumes only if the player picks the seed up again.

### Dropped seed
- A world model with a big countdown BillboardGui "20", ticking down each second.
- Only the original owner can pick it up in this task (task 7 extends this to bat steals). The server locks it so only one pickup succeeds.
- Picking it up resets the timer and restarts the chase: siren, flash and RUN! again.
- It never teleports back to its dirt spot.
- When the timer ends it's destroyed and gone permanently.
- The DROP button creates the same dropped seed at your feet (voluntary).

### Client effects (`src/client/Danger.luau` rework)
- **On chase start or restart:**
  - Siren sound, about 2 s (use a built-in or existing sound id from `Sounds.luau`).
  - Red full-screen flash of about 2.5 s that fades out.
  - A big red "RUN!" banner (bold white text, dark stroke) at top-center that stays up while the chase is active. It pushes the biome banner down via its `YOffset`.
- **Ending:** the banner hides on bank, catch, drop, timeout or chase end.
- **DROP button:** on screen (bottom-center, at least 56 px, mobile friendly), shown only while carrying.

### HUD
The old Bag panel becomes a "Carrying: <seed>" line, or is removed.

### Kept
- 15 unique guardians (existing rigs and names). Must include Fungal Brute for Mushroom Forest; rename the def if needed.
- Day and night have no effect on guardians.

## Out of scope
Bats and steals (task 7), Index (task 6), balance pass (task 8), new guardian models.

## Acceptance checks
- E1. Digging alone never starts a chase. Picking up the revealed seed starts only that biome's guardian on that player: siren, about 2.5 s red flash, and RUN! that stays up.
- E2. Guardian speed follows `guardianSpeedFor(RecommendedSpeed)` (harness table for 15 biomes; all playable, monotonic).
- E3. Catch: knockback plus stun; the seed drops at the catch spot with a visible 20 s countdown; RUN! hides.
- E4. Pickup before 0 resets to 20 and restarts the chase and effects. Caught again, it drops at the new spot. Reaching 0 destroys it permanently.
- E5. Reaching your own plot banks the seed into Seeds; the chase ends and the guardian stops attacking and returns.
- E6. DROP button appears only while carrying and drops the seed at your feet with the 20 s timer.
- E7. Another player is never targeted. Two players chased by two guardians at once work independently.
- E8. Only one pickup of a dropped seed succeeds (server lock). There's no path where a seed duplicates.
- E9. Old saved bags migrate into seeds (v8 → v9). rojo build OK; harness clean except the known assert.
