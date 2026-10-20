# balance-pass — QA against cut v1

Build under test: `cursor/balance-pass-89e8` (9c4c37f … dd6565d), built by cloud agent bc-8da06f19, on top of tasks 1–7. 15 files, +458 −52. The whole stack vs `main`: 62 files, +4965 −609.
Preview: `PlantOrDie-all-tasks.rbxlx` (repo root, not committed). Contains tasks 1–8.

**Verdict: BLOCKED** (H7 device playthrough). Everything else passes.

| Check | Result | Evidence |
|---|---|---|
| H1 pacing targets | PASS | Sim: 26.5 h to the Forbidden Bloom recommendation (was 1,186 h); worst step 2.76 h; 20 % / 40 % treadmill share both pass. |
| H2 owner-fixed numbers unchanged | PASS | Harness asserts the recommendations, trail and shovel prices. |
| H3 guardian fairness | PASS | Asserts kept. |
| H4 3–8 swings with the expected shovel | PASS | Normal 4–7, tough 7–14. |
| H5 no R$ at MAX | PASS (stub) / BLOCKED (runtime) | Button hidden, prompt off, receipt refused. |
| H6 full harness exit 0; defense assert explained | PASS | Real bug: wilted plants never recovered at dawn (`setPlant` kept a stale `wilted` flag). Fixed. |
| H7 rojo OK; device playthrough | rojo PASS / playthrough BLOCKED | Needs Studio on PC, phone and tablet. |

Changed tunables are listed in `pacing.md` on the branch. Late plant income was raised for biomes 6–15 so the fixed trail and shovel prices are reachable.
