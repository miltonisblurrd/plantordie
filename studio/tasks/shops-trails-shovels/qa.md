# shops-trails-shovels — QA against cut v1

Build under test: branch `cursor/shops-trails-shovels-dee5` (688c827 … 53c609b), built by cloud agent bc-fbf79261, on top of tasks 1 and 2. 20 files, +1030 −101.
Preview: `PlantOrDie-shops.rbxlx` (repo root, not committed). It contains tasks 1, 2 and 3 and is the only preview that boots (see below).

**Verdict: BLOCKED.** Static checks pass. No Studio playtest yet.

## Critical finding (affects main and tasks 1–2)
`origin/main` `src/server/Shop.luau:185` calls `Net.on("BuyPortal", …)`, but `BuyPortal` isn't in `src/shared/Remotes.luau`. `Net.on` asserts, so `Boot.server.luau` stops at `Shop.start()`. Expedition, Dig, Tools, GuardianAI, Defense, Fusion, Event, Purchases, DayNight and Data never start. That is the most likely real cause of the owner's "clock 0:00", "no seeds" and "no shovel" reports. This branch adds the remote. The task 1 and 2 previews still have the crash.

| Check | Result | Evidence |
|---|---|---|
| C1 stalls match references; says "Shovel Shop" | PASS (static) / look BLOCKED | Hub builder colors and titles per brand; 14 parts each. |
| C2 auto-open once per entry, stays open, X, reopen, own shop only | BLOCKED (runtime) | `client/ShopStalls.luau` enter-edge polling at about 10 Hz. |
| C3 all 10 of each, exact prices and stats | PASS (static) | Harness exact-value checks. |
| C4 server buy validation, persist v8 | PASS (static, migration) / BLOCKED (runtime) | Range ≤ 30 studs, exact deduction; v7 → v8 keeps shovel tiers. |
| C5 trail multiplies treadmill gain | PASS (static) | `Treadmill.multiplierFor` reads `Trails.ById`. |
| C6 shovel equip swaps look and dig damage | BLOCKED (runtime) | `Tools`/`Dig` read the equipped tier. Server tough-soil check added. |
| C7 trail effects visible to others, survive respawn | BLOCKED (runtime) | `server/TrailFx.luau` rebuilds on equip, load and respawn. |
| C8 migration, rojo, harness | PASS | rojo OK locally. Harness clean except the known defense assert. |

Not done (optional in the cut): equip-anywhere bag button. Equipping is available in the shop menus.
