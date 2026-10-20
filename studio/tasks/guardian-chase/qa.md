# guardian-chase — QA against cut v1

Build under test: `cursor/guardian-chase-bc76` (9d2859c … 40bfce8), built by cloud agent bc-d00ab410, on top of tasks 1–4. 18 files, +1047 −355.
Preview: `PlantOrDie-guardian.rbxlx` (repo root, not committed). Contains tasks 1–5.

**Verdict: BLOCKED.** Static checks pass. No Studio playtest yet.

Chief balance call during build: guardian factor 0.97 → 0.87, so a carrier at the recommended Speed (×0.9 carry) is +0.6 to +1.2 studs/s faster than the guardian, and a carrier at 1/10 of the recommendation is slower (biomes 2–15). The harness asserts both.

| Check | Result | Evidence |
|---|---|---|
| E1 dig ≠ chase; pickup → that guardian only; siren, flash, RUN! | BLOCKED (runtime) | `Dig` only reveals; the chase starts from `Carry.onPickup`. |
| E2 guardian speed from RecommendedSpeed | PASS (static) | Harness table for 15 biomes, 16.7 → 34.8, monotonic. |
| E3 knockback + stun, drop at catch spot, 20 s countdown | BLOCKED (runtime) | Server impulse, client mirror; ground-snap raycast. |
| E4 pickup resets and restarts; new drop spot; expiry permanent | PASS (state machine) / BLOCKED (runtime) | Harness Carry/Core tests. |
| E5 bank at own plot ends chase; guardian returns | BLOCKED (runtime) | Return state in GuardianAI. |
| E6 DROP button only while carrying | BLOCKED (runtime) | `client/Danger.luau`. |
| E7 only the target chased; parallel chases | PASS (static) / BLOCKED (runtime) | One target per guardian. Note: a second carrier from the same biome isn't chased while that guardian is busy. |
| E8 one pickup wins, no dupes | PASS (state machine) | Harness. |
| E9 v8 → v9 bag → seeds; rojo; harness | PASS | Migration is idempotent. rojo OK locally. |

Known notes for task 8: biome safe zones no longer stop a chase (hub only, per cut); a dropped seed within 4 studs of your spawn is picked up on respawn; the Halloween guardian has no event seeds to chase yet.
