# safe-zone — QA against cut v1

Verdict: **BLOCKED** on a Studio playtest. Static and harness evidence is PASS. CI-style checks are not a pass on their own.

## Evidence run (2026-10-25, branch `task/safe-zone`)

- `rojo build default.project.json` → builds.
- `python3 studio/tools/world_harness.py` (latest luau-lang release CLI) → exit 0. New block "Shared Safe Zone (one region)": box X -359..359, Z -124..46. All 8 plots (centre and every wall edge), hub spawn, hub back edge, both stalls, plot path and trail start are inside; the line is full width at Z 46 and one stud past it is outside; 375 sample points across all 15 biomes are outside; 16 keepOut chases toward plot entrances never step inside; the event patrol point at (45, 32) is pushed out.
- Part counts vs `main`: each of the 15 biomes is exactly 2 parts lighter (ring + sign); terrain/props counts are identical per biome, so walls, entrances and prop layout are unchanged. Hub +2 (line + sign). World ~4,800 → ~4,772.
- Harness scan: no `SafeZone` or `SafeSign` part in any biome model.

## Checks

| Check | Result | Evidence |
| --- | --- | --- |
| A chase ends on entry | PASS (code), BLOCKED (runtime) | `GuardianAI.chase` ends `safe` when `SafeZone.contains(target)`; `SafeZone.onEnter` ends it from the 0.1 s server loop. |
| B stops at boundary, never in a plot | PASS (harness), BLOCKED (runtime) | Every `step` goes through `SafeZone.pushOut` (goal) and `keepOut` (move). Harness keepOut chases never end inside. |
| C several plots protected, biome carriers still chased | PASS (code), BLOCKED (runtime) | Protection is per player position; chase start only refuses protected players. |
| D no biome safe zones in 15 biomes | PASS (harness) | Ring/sign removed, API removed, 375 biome points unsafe. |
| E leave → chased again | PASS (code), BLOCKED (runtime) | `escaped[player]` set on a `safe` end; `reacquire` restarts that guardian when the carrier is back in its biome with its seed and outside the box. |
| F close guardian still cancels | PASS (code), BLOCKED (runtime) | Safe check runs before the catch-range check; `catch` re-checks protection. |

## To unblock

Studio playtest (2 clients): walk a seed out of Green Meadows, run home, confirm the RUN! banner clears on the green line and the guardian stops there; step back into Green Meadows with the seed and confirm the chase restarts; swing a bat on the home side (refused) and in a biome (hits).
