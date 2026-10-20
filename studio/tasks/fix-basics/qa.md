# fix-basics — QA against cut v1

Build under test: branch `cursor/fix-basics-fd5f` (commits 9748824 … 94483ae). Built by cloud agent bc-5a087428.
Preview: `PlantOrDie-fix-basics.rbxlx` (rojo build of that branch, at the repo root, not committed).

**Verdict: BLOCKED.** Static checks pass. No Roblox Studio playtest has been run, so the runtime rows can't be marked PASS. CI or a green build is not a pass.

| Check | Result | Evidence |
|---|---|---|
| A1 clock counts down, shows time of day, night falls | BLOCKED (runtime) | Code: `RequestState` resends day/night, ReplicatedStorage attributes fallback, HUD format. Not seen running. |
| A2 missed event still shows clock | BLOCKED (runtime) | `State.start` seeds from attributes before `RequestState`; read-only check. |
| A3 starter pack / rescue seed / no extra for stocked profiles | BLOCKED (runtime) | `Garden.luau` rescue only when seeds, planted and plants are all empty. |
| A4 exactly one Starter Shovel after spawn and respawn | BLOCKED (runtime) | `Tools.luau` clears Backpack, StarterGear and character, then puts one in StarterGear and one in Backpack. |
| A5 112×112 biomes, builders run, part count | PASS (static) | Harness: biomes 2,018 → 3,772 parts; world ~2,810 → ~4,564. Over the ~3,100 noted in ARCHITECTURE.md; flagged for Chief. |
| A6 10 spots per biome on dirt circles, ≥ 8 studs apart | PASS (static) / look BLOCKED | Harness: 150 spots, minimum pair 8.0 studs. Visual not seen. |
| A7 walk through exit + gate 2 after buying; blocked without | BLOCKED (runtime) | Back wall split with a 26-stud gap for biomes 1–14; exit lane kept clear of props. |
| A8 rojo build + harness | PASS (rojo) / PARTIAL (harness) | rojo build OK locally. Harness world/dig section passes. It exits 1 on a defense wave assert ("Night 5 boss… wilted after dawn 2") that also fails on unmodified `main`, so it's pre-existing and out of scope. |

## To unblock
Owner or Chief opens `PlantOrDie-fix-basics.rbxlx` in Studio, presses Play, and records A1, A3, A4, A6, A7 (screenshot or short recording each).

> Note (task 3 QA): previews for tasks 1 and 2 do not boot because main is missing the BuyPortal remote. Fixed on the task 3 branch; playtest `PlantOrDie-shops.rbxlx` instead.
