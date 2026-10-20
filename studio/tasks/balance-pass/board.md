# balance-pass — board

- Opened: 2026-10-19 · From: Chief (task 8 of 8 in `studio/tasks/intake-2026-10-19.md`, derived from the owner's requirements). Built on `cursor/bats-pvp-fbb1`.

## Owner lines this serves (quoted)

> Each recommendation must be configurable so it can be balanced against guardian movement speed, chase distance, escape routes, and treadmill progression.
> Shovel damage and prices should be configurable to balance progression across the biomes.
> The chase should remain challenging but fair, with enough opportunity for players to recover dropped seeds and escape.
> The system must work smoothly on PC, mobile, and tablet.

## Problems found during tasks 2–7
- Treadmill max (Lv 30, 121M/s) × Divine 50× × (1 + 1.5 Index bonus) ≈ 15B Speed/s, so 1 QA takes about 18 h of training and 500T about 9 h. Too slow at the top.
- Price ladders don't line up: biome unlocks top out at $250M, but shovels go to $2.5T, treadmill Lv 30 costs about $3T and trails go to $2.5B. Income per biome has never been checked against them.
- Robux TreadmillLevel at max banks a credit that can never be used.
- Pre-existing harness assert "Night 5 (boss) … wilted after dawn 2" fails on main; it hides every later harness section.
