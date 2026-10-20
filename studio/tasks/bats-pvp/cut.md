# bats-pvp — cut v1 (frozen)

## In scope
1. **Bat tool.**
   - Every player gets a "Bat" tool in the Backpack and StarterGear, next to the shovel. Exactly one of each.
   - It looks like the equipped skin: Wooden by default, or the skin's colors and material from `IndexRewards`.
   - Skins never change stats.
2. **Swing.**
   - Click or tap while equipped sends `SwingBat()`. No target is sent; the server picks the target.
   - The client plays a swing animation (tween like the shovel) and a whoosh.
3. **Server hit check.**
   - Cooldown: `Config.Bat.Cooldown` (default 1.2 s) per player.
   - Target: the nearest other player whose root is within `Range` (default 7 studs) and inside a forward cone (dot > 0.3).
   - Line of sight: a raycast between roots that ignores characters.
   - Both players alive.
   - Neither player is in a safe zone: any plot, the hub safe radius, or a biome safe zone.
   - Bats never affect guardians or zombies.
4. **On hit.**
   - The victim is knocked back: a horizontal impulse (default 45) plus up (25), about 0.8 s ragdoll-free stun using `Treadmill.stun`. Short, and never pushes anyone out of the map. Clamp the velocity.
   - If the victim is carrying an unsecured seed, it's knocked loose with `Carry.drop(victim, pos, "hit")`, using the normal 20 s timer.
   - The attacker gets a 3 s steal window: during it, both the attacker and the victim can pick that dropped seed up. Extend `canTake` to allow the attacker who caused the drop, plus the original owner. First server pickup wins; no duplicates.
   - If the attacker picks it up, they become the carrier. The guardian chase transfers to them (`Carry` restarts the chase on the new carrier, with that seed's origin guardian), and they must bank it at their own plot.
   - After the 3 s window only the original owner can recover it, as in task 5.
5. **Never stealable or lost from a hit:** banked seeds, the inventory, garden plants, money, Speed, Index discoveries and rewards. A hit only ever moves the one carried seed.
6. **Skin equip.**
   - A "Bats" tab or button in the Index panel (or the bag) lists owned skins with an Equip button.
   - Remote `EquipBatSkin(id)`. The server checks ownership, saves `batSkins.equipped` and rebuilds the tool.
7. **Feedback.**
   - Hit sound and a small spark at the impact point for both players.
   - The victim sees a toast "<attacker> knocked your seed loose!" when that happens.
   - Attempts in a safe zone show a small "Safe zone, no fighting" hint (throttled).

## Out of scope
New bat stats or bat purchases, bat damage or health, balance pass.

## Acceptance checks
- G1. Every player has exactly one Bat and one Shovel after spawn and respawn. The bat shows the equipped skin.
- G2. A swing within 7 studs, in front, with line of sight knocks the target back briefly. Behind a wall, out of range or during cooldown nothing happens (server-checked).
- G3. No hits inside plots, the hub safe area or biome safe zones. Bats never touch guardians.
- G4. Hitting a carrier knocks the seed loose. The attacker can grab it within 3 s and becomes the carrier, and the guardian now chases the attacker. The victim can also grab it back. Only one pickup succeeds.
- G5. A hit never changes the victim's seeds, plants, garden, money, Speed or Index (harness: profile diff on hit equals only the carried-seed change).
- G6. Equipping an owned skin changes the bat look. Unowned skins are refused. Stats are the same for every skin.
- G7. rojo build and harness clean (except the known assert).
