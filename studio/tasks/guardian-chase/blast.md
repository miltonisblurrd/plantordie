# guardian-chase — blast radius

Base: `cursor/biome-banner-87c7`.

- `src/server/GuardianAI.luau` (427 lines): patrol, detect (nearest visitor in the biome within DetectRange), chase (pathfinding), lose (leash, safe zone, out of biome, stuck), catch (teleport home plus `Expedition.lose`). One loop, sleeping biomes skipped. Event guardian support (`setEventGuardian`).
- `src/server/Expedition.luau`: saved unbanked bag `profile.expedition` (species → count); `add`, `lose`, `bank` at own plot or the hub fountain (`Config.Bank`).
- `src/server/Dig.luau`: a successful dig rolls a drop and calls `Expedition.add` immediately (no pickup step today).
- `src/shared/Guardians.luau`: 15 defs (Name, Shape, colors, WalkSpeed, ChaseSpeed ≤ 19, DetectRange, LeashRange, Predict). Unique shapes already exist (`World/Builders/GuardianRig.luau`).
- `src/client/Danger.luau`: red vignette, banner naming the guardian, and an alert sound on the `Danger` event.
- `src/client/Hud.luau`: Bag panel (unbanked count).
- `src/shared/Speed.luau` (task 2): `walkSpeedFor(speed)`, so guardian speed can use the same curve.
- `src/client/BiomeBanner.luau` (task 4): `YOffset` attribute so RUN! can push it down.
- `src/shared/Sounds.luau` and `src/client/Sfx.luau`: sound ids.
- `studio/tools/world_harness.py`: guardian sections.
