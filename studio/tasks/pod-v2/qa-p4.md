# pod-v2 — QA, Phase 4 (Defense)

Cut: **v1**. Mode: code review, static checks, and the headless harness (`studio/tools/world_harness.py`). The harness now runs real waves through `src/server/Defense/Core.luau`, the same module the server uses, with Roblox API stand-ins. This environment has no Studio runtime, so nothing here was playtested. CI green is not a pass.

Branch `cursor/p1-foundation-cc3f`.

## Build and static results

| Check | Result |
| --- | --- |
| `rojo build` (7.7.1) | PASS |
| `selene src` | PASS: 0 errors, 0 warnings |
| `luau-lsp analyze --platform=roblox`, strict, with sourcemap | PASS: 0 errors |
| `python3 studio/tools/world_harness.py` | PASS: wave simulations, role checks, isolation and pacing assertions all hold |

## Acceptance checks in P4

| Check | Verdict | Evidence |
| --- | --- | --- |
| **A11** Zombies enter the correct lanes and attack the correct player's garden. | PASS (code path + harness), BLOCKED-RUNTIME | Each plot has its own field (`Defense/init.luau` `attach`, `:459`). `spawnOne` (`:203`) picks a lane from 1 to that player's `lanesUnlocked` and places the model with `worldCFrame` from that plot's own `refs.cframe`. Zombies start at `Config.Plot.ZombieSpawnX` (the right edge) and `Core.zombieStep` (`Core.luau:230`) only ever lowers X, moving left toward the house. A zombie only targets plants in its own field and lane (`:245-252`). Harness, 4 waves: "lanes ok true", "left-only true", max alive ≤ `MaxPerPlot`. Isolation check: plot B's plant fired 0 times at plot A's zombie. |
| **A12** Defensive plants damage zombies correctly. | PASS (code path + harness), BLOCKED-RUNTIME | `Core.plantStep` (`Core.luau:162`) takes stats from `Shared/Combat.luau`, which reads the `Plants` combat field. All damage happens on the server. Harness role checks: Projectile hits only in the same lane, ahead of the plant, within range (20 damage; 0 in another lane, behind it, or out of range). Rapid fires at 3 attacks per second. AoE hits the adjacent lane but not one two lanes away. Slow halves speed (a Tank moved 0.60 of 1.2 studs). Burn keeps ticking after the plant is gone (4.8 HP in 1s). Wall: a Thornwall held a Tank for 13.5s and dealt 17 thorns damage. Income-only plants do 0. A 5-lane mixed garden on night 10 killed 19 of 20 with Burn, Slow and AoE. |
| **A13** A zombie reaching the house damages its defenses. | PASS (code path + harness), BLOCKED-RUNTIME | When a zombie reaches `houseX` (the front of the current house tier), it emits a `house` event for `Damage × HouseHitMultiplier` (`Core.luau:287-292`). `applyEvents` (`init.luau:279`) calls `Sync.setHouseHp`, and the HUD bar redraws from the snapshot. At 0 HP, `loseWave` (`:242`) clears the wave, forfeits its reward, and takes `min(5% of money, 120s of income)`. Plants are never removed. Harness: undefended night 1 gives 5 house hits for 69 HP against a 100 HP Starter Shack. |
| **A21** (re-check) Two players can play simultaneously without affecting each other's plots or inventories. | PASS (code path), BLOCKED-RUNTIME | Defense state is keyed by player. Zombies, plants and traps live in that player's own field and that plot's `Zombies` folder. `HitZombie` (`:583`) only looks up ids in the caller's own field and checks distance. The client only fires it for models whose `Owner` attribute matches the local user (`client/Defense.luau:108`). `UseTrap` and `Repair` only touch the caller's state and profile. `CombatFx` is visual only. |
| **A22** (re-check) Players cannot duplicate seeds, money, or plants through client requests. | PASS (code path), BLOCKED-RUNTIME | The new remotes (`Repair`, `UseTrap`, `HitZombie`) are rate-limited in `Remotes.luau` and type-checked by `Net.on` (`init.luau:616-618`). `repair` and `useTrap` check cooldown and money, set the cooldown, and spend inside `Data.update` with no yield in between. The wave reward is granted only in `endWave` (`:405`), which sets `st.wave = nil` before paying, so each wave pays once. There is no client path that grants money or seeds. |

## Design decisions to note

- **Fairness (away players).** Every online player with a plot gets a wave at nightfall; players who join mid-night start next night. While the owner is inside a biome, spawning pauses, and unspawned zombies are dropped at dawn. Zombies already on the lanes keep coming. Exploring at night is allowed, but only a defended wave pays a reward. A night spent entirely away spawns nothing and pays nothing.
- **Scaling.** Wave size is `ceil(lanes × (1.5 + 0.25 × (night − 1)))`, which stops growing after night 12 and is capped at 40. The density per lane is the same at 3, 5 and 7 lanes (about 4.3 per lane at night 12). Zombie HP scales by `1 + 0.6(k − 1)` with the highest owned biome, matching how plant damage scales, plus 4% per night up to night 20. Types unlock by biome or by night, whichever comes first. A Rot King boss joins every 5th night.
- **House hits.** A zombie that reaches the house hits once for 3× its damage and leaves, rather than chewing forever where no plant can reach it.
- **Wilted plants.** A plant at 0 HP wilts: the model turns brown and loses its lights, it stops fighting, and it earns no income. It is never deleted. It recovers at dawn or with Repair. Wilting is not saved, so a rejoin also recovers it.
- **Money** for rewards, costs and penalties is measured in seconds of the player's own income, with a floor, so it stays proportional at every stage. Survival pays 30s of income plus 1s per bounty point, and one bonus seed rolled from the highest biome's drop table.
- **Traps** are used during the night with a cooldown and a small cost. The server places them in the lane of the zombie closest to the house: a spike strip (damage per second for 15s) or a freeze mine (freezes and damages within 14 studs when tripped).
- **Player assist.** Clicking or tapping your own zombie deals `max(2, 5% of its max HP)`. The server checks distance (45 studs) and rate-limits it to 5 per second.

## Part budget

A zombie is 5 to 7 parts. The caps (18 per plot, 100 per server) bound the worst case at about 700 extra parts. A typical 3-lane night has 1 to 3 zombies alive at once on a plot. Combat effects are client-local neon parts, at most 30 per batch, skipped beyond 220 studs, and cleaned up by Debris.

## Gaps

- Not playtested in Studio. Movement smoothness at a 10 Hz PivotTo step, health bar readability, click hit-testing on mobile, and the night tint are unverified at runtime.
- If a zombie stands on a tile, a click aimed at that tile hits the zombie instead. Placement and Inspect are not changed.
- Trap placement is automatic (the lane of the closest zombie). There is no lane picker.
- Late biomes: biome 15 Walkers (188 HP) against the best plant in that biome (37.6 DPS) are tuned by formula, not by play.
