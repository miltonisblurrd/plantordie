# bats-pvp — QA against cut v1

Build under test: `cursor/bats-pvp-fbb1` (59435f3 … 06301a3), built by cloud agent bc-3247111f, on top of tasks 1–6. 14 files, +725 −32.
Preview: `PlantOrDie-bats.rbxlx` (repo root, not committed). Contains tasks 1–7.

**Verdict: BLOCKED.** Static checks pass. No Studio playtest yet.

| Check | Result | Evidence |
|---|---|---|
| G1 one Bat and one Shovel; skin look | PASS (static) / BLOCKED (runtime) | Shared clear-and-replace helper in `Tools.luau`. |
| G2 range, cone, LOS, cooldown checked on server | PASS (pure validator) / BLOCKED (feel) | Harness: every refusal path covered. |
| G3 safe zones; never touches guardians | PASS (static) | Plots, hub radius, biome safe circles. Players only. |
| G4 knock loose, 3 s steal window, chase moves to stealer, one pickup | PASS (state machine) / BLOCKED (runtime) | Harness steal-window tests. |
| G5 hit touches only the carried seed | PASS | Harness profile diff identical. |
| G6 skin equip owned only; same stats | PASS (static) | 16 skins build with identical stats. |
| G7 rojo + harness | PASS | rojo OK locally. Harness clean except the known assert. |

Notes: built-in sound paths `swordslash.wav` / `hit.wav` aren't confirmed in the current engine. Bat grip orientation needs a look in Studio.
