# biome-banner — QA against cut v1

Build under test: `cursor/biome-banner-87c7` (2b37149 … 2159961), built by cloud agent bc-58dc8396, on top of tasks 1–3. 9 files, +381 −59.
Preview: `PlantOrDie-banner.rbxlx` (repo root, not committed). Contains tasks 1–4.

**Verdict: BLOCKED.** Static checks pass. No Studio playtest yet.

| Check | Result | Evidence |
|---|---|---|
| D1 emoji, name, exact short values incl. "1 QA" | PASS (static) / look BLOCKED | Harness: 100, 10K … 500T, 1 QA. |
| D2 updates within 0.5 s, no flicker | BLOCKED (runtime) | 5 Hz poll with 1-stud or 0.3 s hysteresis. |
| D3 hidden at hub, plots and gaps; respawn | PASS (static, regions) / BLOCKED (runtime) | Harness: hub, plots and gaps → nil at 8,222 sample points. |
| D4 no Instance.new on update | PASS (static) | Built once in `start`. |
| D5 server and client same region math | PASS | `server regionOf == shared regionOf == pre-move math` at 8,222 points. |
| D6 phone readability, no overlap | BLOCKED (runtime) | Money panel moved to top-left. Possible overlap with the left action bar on very small phones. |
| D7 rojo + harness | PASS | rojo OK locally. Harness clean except the known assert. |
