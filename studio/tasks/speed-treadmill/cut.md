# speed-treadmill — cut v1 (frozen)

## In scope
1. **Saved data** (schema v7 with migration):
   - `speed` (number, accumulated Speed stat)
   - `treadmillLevel` (starts at 1)
   - `trails = { owned = { Starter = true }, equipped = "Starter" }`
   - Existing profiles migrate with defaults.
2. **Config** in a new `src/shared/Treadmill.luau`:
   - A level table with `SpeedPerSec` and `Cost` for each level, at least 30 levels. Default curve: SpeedPerSec = 1 × 1.9^(L−1) rounded; Cost = 100 × 2.3^(L−1) rounded. Every number is editable; task 8 balances them.
   - A `Trails` data stub with the Starter Trail at multiplier 1, so the multiplier hook is live. The full list of 10 comes in task 3.
3. **Personal treadmill on every plot.**
   - Placed directly in front of the house, on the walkway side, not on garden tiles, and clear of the spawn point.
   - Blue low-poly treadmill like the reference: dark navy frame, cyan trim, glowing blue belt with a square tile texture, two side rails and a front console.
   - Each plot has its own; owner-only.
4. **Training.**
   - A server tick each second. When the plot owner's HumanoidRootPart is over their own belt, they gain `SpeedPerSec(level) × equippedTrailMultiplier`.
   - Nobody else gains Speed from that plot's treadmill.
   - The client never sends Speed amounts.
5. **"+X 👟" popups.**
   - Each gain fires a client event. The client shows a floating bold "+96K 👟"-style label with a dark outline that rises and fades over the treadmill.
   - Numbers use the shared short format.
6. **Upgrade sign** next to the treadmill:
   - "Upgrade Treadmill", "Lv. X > Lv. X+1", a money price button and a Robux price button.
   - Money: the server checks the price and the owner, then deducts and levels up.
   - Robux: product `TreadmillLevel` in `Products.luau` with Id 0 (disabled toast until the owner creates it). When enabled, its receipt adds +1 level through the existing receipt ledger.
   - At max level the sign shows MAX.
   - Owner-only prompt. Others see the sign but get "That treadmill belongs to another garden."
7. **Speed → movement.**
   - New `src/shared/Speed.luau` with `walkSpeedFor(speed)`: base 16 at 0 Speed, rising with log10, capped around 40 at 1 QA (1e15).
   - Server sets the Humanoid WalkSpeed on spawn and whenever Speed changes.
   - The same module exports the formula so task 5 can scale guardians off it.
8. **HUD:** shows the player's Speed stat ("👟 1.2K Speed") under the money panel.
9. **Short number format** shared module with K, M, B, T, QA (and Qi above that). Existing money format stays `$`-prefixed and switches its `Qa` to `QA`.

## Out of scope
- Trails Shop, buying or equipping trails, and trail visual effects (task 3).
- Index Speed bonus (task 6), rebirth, guardian speed scaling (task 5), biome banner (task 4), balance pass (task 8).

## Acceptance checks
- B1. Every plot has one treadmill in front of the house, not overlapping tiles, the house or the spawn.
- B2. The owner standing on the belt gains Speed every second and sees a "+X 👟" popup. Stepping off stops it. Another player on someone else's treadmill gains nothing.
- B3. Money upgrade: with enough money, the level goes up by 1, the cost is deducted exactly, and the next gain uses the new rate. Without enough money, it's refused with a toast. Max level shows MAX.
- B4. The Robux button shows a disabled toast while Id = 0. The receipt path (DebugGrant "TreadmillLevel") adds exactly one level and is idempotent per PurchaseId.
- B5. Speed raises WalkSpeed per the formula: 16 at 0, monotonic, ≤ about 40 at 1e15.
- B6. Speed, treadmillLevel and trails persist across rejoin, and the v6 → v7 migration fills defaults.
- B7. The HUD shows Speed in short form, and the QA suffix is used for 1e15.
- B8. `rojo build` succeeds; the harness world section is clean.
