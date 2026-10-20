# speed-treadmill — QA against cut v1

Build under test: branch `cursor/speed-treadmill-ef77` (3c1ceae … 3c827b9), built by cloud agent bc-c3ca34b5, on top of `cursor/fix-basics-fd5f`. 20 files, +715 −10.
Preview: `PlantOrDie-speed-treadmill.rbxlx` (repo root, not committed). It includes task 1.

**Verdict: BLOCKED.** Static checks pass. No Studio playtest yet.

| Check | Result | Evidence |
|---|---|---|
| B1 one treadmill per plot, clear of tiles, house and spawn | PASS (static) | Harness footprint check: 26 parts per plot, clear of the garden, every house tier and the spawn. |
| B2 owner gains Speed on belt, popups, others gain nothing | BLOCKED (runtime) | `server/Treadmill.luau` tick: own plot's belt only, local-space box check. |
| B3 money upgrade exact deduction, refuse, MAX | BLOCKED (runtime) | `upgrade()` checks plot, next level and money; deducts the exact cost. |
| B4 Robux disabled toast; DebugGrant adds one level, idempotent | BLOCKED (runtime) | Existing receipt ledger. At max it banks a credit that has no use yet (note for task 8). |
| B5 WalkSpeed formula | PASS (static) | Harness: 0 → 16.0, 1K → 20.8, 1B → 30.4, 1e15 → 40.0, monotonic. |
| B6 persist + v6 → v7 migration | PASS (static, migration) / BLOCKED (DataStore) | Harness migration test plus broken-trails repair. |
| B7 HUD Speed short form, QA suffix | PASS (static, format) / BLOCKED (look) | `Format.short` examples in the harness. |
| B8 rojo build + harness | PASS | rojo OK locally. Harness clean up to the known pre-existing defense assert. |

World parts: ~4,564 → ~4,772 (+26 per plot).
