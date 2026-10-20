# shops-trails-shovels — cut v1 (frozen)

## In scope

### Data (schema v8)
- `shovels = { owned = { [tier] = true }, equipped = tier }`.
- Migration from v7: owned = every tier ≤ the old `shovelTier`, equipped = the old `shovelTier`.
- `shovelTier` stays as a mirror of the equipped tier, so existing readers keep working (or switch them all to the equipped tier).
- Trails already save (`trails.owned`, `trails.equipped`).

### Config
- **`src/shared/Trails.luau`**: the 10 trails with Id, Name, Price, Multiplier, effect colors and kind, exactly as the owner listed them:
  1. Starter: 0, 1×
  2. Nature: 5,000, 2×
  3. Lightning: 50,000, 4×
  4. Inferno: 250,000, 6×
  5. Mystic: 1M, 8×
  6. Rainbow: 5M, 12×
  7. Golden: 25M, 18×
  8. Galaxy: 100M, 25×
  9. Void: 500M, 35×
  10. Divine: 2.5B, 50×

  `Treadmill.multiplierFor` reads from it.
- **`src/shared/Upgrades.luau` `Shovels`**: the 10 shovels with these prices:
  1. Starter: 0
  2. Steel: 25,000
  3. Crystal: 250,000
  4. Inferno: 2.5M
  5. Emerald: 25M
  6. Plasma: 250M
  7. Toxic: 2.5B
  8. Ancient: 25B
  9. Cosmic: 250B
  10. Divine: 2.5T

  Each has a configurable Damage that rises with tier, plus DigSeconds, LuckBonus, ToughTier (min(tier, 5)), Color and an effect look.

### Two shared stalls in the hub
- Low-poly wooden stalls: posts, counter, and a striped fabric canopy (alternating stripes).
- A glowing flat circle on the ground beneath each one.
- A large floating title (BillboardGui, always on top off, readable from about 80 studs, scales with distance).
- **Trails Shop:** green-and-white canopy, green circle, green title "Trails Shop".
- **Shovel Shop:** cyan-and-white canopy, blue circle, cyan title "Shovel Shop".
- Placed in clear hub space, not overlapping the machines, fountain, spawn or Halloween decor.
- Gentle idle animation: the title bobs and the circle pulses.

### Auto-open
- The client detects when your character enters a circle (horizontal distance ≤ radius; checked about 10×/s; no Touched spam).
- It opens that shop's menu once per entry.
- Walking off leaves the menu open.
- An X closes it.
- Re-entering after leaving opens it again. Staying on the circle never reopens it.
- Each circle opens only its own shop.

### Menus
- Scrollable, mobile-friendly, consistent with `Ui.luau`.
- Each row shows the name, price (or FREE), the stat (Trails: "12× Speed"; Shovels: "Damage N"), a visual preview (colored swatch or ViewportFrame icon) and one button: Buy, Equip or Equipped.
- Big tap targets (at least 44 px).
- **Trails:** one equipped at a time. You can also unequip, which falls back to Starter.

### Server
- New remotes `BuyTrail(id)`, `EquipTrail(id)`, `BuyShovel(tier)`, `EquipShovel(tier)`, rate-limited.
- The server checks the item exists, it isn't already owned, there's enough money and the player is within range of the stall (≤ 30 studs from its circle), then deducts the exact price.
- Equip requires the item to be owned.
- Equipping a shovel rebuilds the tool (`Tools.giveShovel`) with that shovel's look. Dig uses the equipped shovel's Damage, DigSeconds, LuckBonus and ToughTier.

### Trail visual effects
- The equipped trail shows on the player's character while they move, visible to everyone (server-side Trail plus ParticleEmitter attachments on HumanoidRootPart).
- Each trail has its own colors and particles matching the owner's descriptions. Rainbow cycles hue.
- They're replaced on equip and on respawn.
- Reduced-effects setting lowers the particle rate.

### Retire the old panel
- Remove the old "Upgrade Shovel" panel and button (`client/Shovel.luau` `buildPanel`), and keep the dig behavior.
- Add a small "Trails" / "Shovels" inventory access: equip owned items from a bag button without walking to the stall (optional; if done, same remotes, but no range check for equip).

## Out of scope
Bats, Index, banner, guardians, balance pass, Robux trail purchases.

## Acceptance checks
- C1. Two stalls match the references (colors, canopy stripes, circle, floating title) and the Shovel Shop never says "Pickaxe".
- C2. Stepping on the green circle opens Trails only; stepping on the cyan circle opens Shovels only. The menu opens once per entry, stays open off the circle, closes with X, and reopens on re-entry.
- C3. Each trail and shovel row shows name, price, stat, preview and status. All 10 of each, with prices and multipliers exactly as listed.
- C4. Buying deducts the exact price on the server. Not enough money, already owned or out of range is refused with a toast. Purchases persist (v8).
- C5. Equipping a trail changes the treadmill gain (Rainbow gives 12× the base). Only one trail applies, and Starter is 1×.
- C6. Equipping a shovel swaps the tool look, and the dig damage matches its config.
- C7. Trail effects show on the moving character for other players too, and respawn keeps them.
- C8. v7 → v8 migration keeps old shovel progress; `rojo build` succeeds; harness clean (except the known defense assert).
