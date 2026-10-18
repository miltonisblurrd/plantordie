# pod-v2 — QA, Phase 3 (Exploration)

Cut: **v1**. Mode: code review, static checks, and a headless Luau harness (`studio/tools/world_harness.py`, which runs the real sources against Roblox API stubs). This environment has no Studio runtime, so nothing here was playtested. CI green is not a pass.

Branch `cursor/p1-foundation-cc3f`.

## Build and static results

| Check | Result |
| --- | --- |
| `rojo build -o build.rbxlx` (7.7.1) | PASS |
| `selene src` | PASS: 0 errors, 0 warnings |
| `luau-lsp analyze --platform=roblox`, strict | PASS: 0 errors |
| `python3 studio/tools/world_harness.py` | PASS: builds all 15 biomes and guardians, and prints part counts, the roster, drop odds and pacing |

## Acceptance checks in P3

| Check | Verdict | Evidence |
| --- | --- | --- |
| **A6** The player digs for a seed in a biome and receives a valid reward. | PASS (code path), BLOCKED-RUNTIME | `src/server/Dig.luau:41` `handle`, registered at `:102` with spec `{"string"}`. It checks that the spot exists and is available, the distance (`Config.Dig.Range` + 3), `Biomes.canEnter` plus `inRegion`, that a Shovel is equipped, the shovel's tough tier against the spot's `RequiredTier`, and the cooldown. Only then does it roll `DropTables.roll(biome, luck, rng)` (`src/shared/DropTables.luau:42`), hide the spot and respawn it after `Dig.Respawn`, call `Expedition.add`, and fire `DigResult`. The harness confirms every table only holds species from its own biome and that luck is clamped at `MaxLuck` 0.5 (`DropTables.luau:31`). |
| **A7** The player cannot enter an unreleased or locked biome. | PASS (code path), BLOCKED-RUNTIME | `Biomes.canEnter` (`src/server/Biomes.luau:104`) requires `Released` and the biome to be unlocked. The enforcement loop in `Biomes.start` (`:138`) checks every player every `EnforceSeconds` (0.5s) with `regionOf` (`:70`) and sends anyone in a region they can't enter back to `HubSpawn` with a toast. The client gate barrier only adds feel; the server is the authority. Dig also re-checks `canEnter`. |
| **A8** The player purchases a biome and retains permanent access. | PASS (code path), BLOCKED-RUNTIME | `src/server/Shop.luau:76` `unlockBiome` checks `Released`, that the biome is not already owned, that the previous biome is unlocked, and money on the server, then writes the unlocked biome inside `Data.update`. It is saved by the session-locked DataStore. The client confirm in `src/client/Gates.luau` shows order and price. The gate signs and prompts refresh from the snapshot, and on rejoin `canEnter` reads the saved profile. |
| **A9** A guardian detects, chases, and loses the player correctly. | PASS (code path), BLOCKED-RUNTIME | `src/server/GuardianAI.luau`. Detection (`:216`) uses `DetectRange`, which is ×2.5 inside danger zones (`:92`), and ignores the safe zone (`:221`). Chase (`:167`) recomputes `PathfindingService` off-thread (`computePath`, `:143`, called through `task.spawn` at `:190`) on a per-guardian throttle (1.2s down to 0.5s), with a direct-move fallback. Stuck reset after `StuckSeconds` (`:204`). Lose (`:107`) happens when the target leaves the region, enters the safe zone, or passes the leash (`:177-178`). A cooldown follows, then patrol. A single Heartbeat loop runs every guardian (`tick`, `:234`), and guardians sleep when their biome has no players (`:250-255`). Each guardian has a warning sound and a `Danger` remote. |
| **A10** A caught player loses only the specified unbanked seeds. | PASS (code path), BLOCKED-RUNTIME | `catch` (`GuardianAI.luau:130`) calls `Expedition.lose` (`src/server/Expedition.luau:36`), which clears only `profile.expedition` (the bag). Seeds, plants, money and unlocks are untouched. The player is then sent to their plot spawn. Banking (`Expedition.bank`, `:50`) moves the bag into seeds at the player's own plot or within `Bank.HubRadius` of the fountain. The bag is saved (schema v3, migration `[2]`), so leaving the game does not bank or lose it. |
| **A23** All 15 biomes are implemented and reachable through progression. | PASS (code path), BLOCKED-RUNTIME | 15 builders in `src/server/World/Builders/Biomes/`, each with props, a tint, a safe zone, patrol points, 10 dig spots (3 of them tough) and one guardian. All 15 have `Released = true` in `src/shared/Biomes.luau`. Each has a gate with an unlock prompt and a 5-point trail from the hub (`Layout.biomePath`). The harness builds all 15. Pacing gives 6 to 12 minutes per biome (`pacing.md`). |

## Harness numbers

- Parts: hub 63, 8 plots 648, 15 gates 105, biomes plus guardians 2108 (100 to 190 each), trails 60. **About 2,984 parts at boot.**
- Divine drop odds: 0.719% in Ancient and Cosmic (1.045% at max luck). ForbiddenRose: 2.128% (2.628% at max luck).

## Gaps

- Not playtested in Studio. Guardian movement smoothness and pathfinding are unverified at runtime.
- The 3 water species (KelpRibbon, AnemoneBloom, ToxicVine) can't be planted until water upgrades arrive in P5.
- The dig swing is a client-local Grip tween, so other players don't see it.
- The alert sounds are built-in `rbxasset://` sounds and are placeholders.
- The last trail segment may cross a neighbouring path.
- The pacing model ignores growth and refill time.
