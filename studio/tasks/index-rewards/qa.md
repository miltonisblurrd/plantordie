# index-rewards — QA against cut v1

Build under test: `cursor/index-rewards-37d5` (7650615 … 216e417), built by cloud agent bc-7998509a, on top of tasks 1–5. 19 files, +554 −51.
Preview: `PlantOrDie-index.rbxlx` (repo root, not committed). Contains tasks 1–6.

**Verdict: BLOCKED.** Static checks pass. No Studio playtest yet.

| Check | Result | Evidence |
|---|---|---|
| F1 recorded at once; kept after sell or fuse | PASS (static) | `Index.record` on every grant path (carry bank, garden ×6, fusion, event/Robux pack, defense drop). Harness sell test. |
| F2 x / y, %, three rewards from the start | BLOCKED (look) | `client/Collection.luau` sections. |
| F3 claim grants once; rejoin grants nothing | PASS (pure logic) / BLOCKED (runtime) | Harness: refuses incomplete, grants once. Saved `indexClaimed` flag. |
| F4 variants not required; secrets required | PASS (static) | No Secret-rarity plants exist yet, so the 60 required are 4 per biome. The label appears automatically if any are added. |
| F5 treadmill × (1 + speedBonus) | PASS | Harness `Treadmill.gain`. |
| F6 v9 → v10 fold + fields | PASS | Harness migration. |
| F7 server re-check; rojo; harness | PASS | rojo OK locally. Harness clean except the known assert. |

Rewards: cash $50K (Green Meadows) → $5B (Forbidden Bloom); +10% Speed each; 15 skins plus a default Wooden Bat.
