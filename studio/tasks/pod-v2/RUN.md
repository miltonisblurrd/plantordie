# PLANT OR DIE — How to run it in Roblox Studio

## 1. Install the tools

1. Install Rokit: <https://github.com/rojo-rbx/rokit> (on macOS or Linux: `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`; on Windows use the installer from the releases page).
2. In the repo root, run `rokit install`. This installs Rojo 7.7.1, pinned in `rokit.toml`. Check with `rojo --version`.
3. Install the Rojo Studio plugin with `rojo plugin install`, or get "Rojo" from the Creator Store. The plugin version should match 7.7.x.

## 2. Serve and connect

1. In the repo root, run `rojo serve`. It serves `default.project.json` on `localhost:34872`.
2. Open Roblox Studio and create a new Baseplate place.
3. Plugins tab > Rojo > Connect. The place now mirrors `src/`; edits sync live.
4. Alternatively, run `rojo build -o PlantOrDie.rbxlx` and open that file directly.
5. Optional: to use real DataStores, publish the place, then turn on Game Settings > Security > "Enable Studio Access to API Services". Without it, `Data/Store` uses an in-memory store and warns in the output; nothing persists between Play sessions.

## 3. Play

Press **Play** (F5). For the two-player check (A21), go to Test > Clients and Servers, pick 2 players, and press Start.

What a new player can do in the first five minutes:
1. Spawn on your own plot (one of 8 on the ring around the hub). The camera switches to Lane View; press C or the bottom-right button to switch to the follow camera.
2. Open **Seeds**. You start with 5 Sunpetal, 3 PeaPopper, 1 Thornwall and $100. Pick a seed and click a tile in lanes 1–3. On touch, tap once to preview and tap again to plant. Plants pop in and grow through Seed, Sprout, Young and Grown, then earn money every second (HUD top-left).
3. Take the shovel and walk the trail to Green Meadows. Dig at mounds and glowing markers. Finds go into your unbanked bag. Avoid the guardian; if it catches you, you lose the bag only. Bank the bag at your plot or by the hub fountain.
4. Open **Upgrades** to buy lane 4, the next house tier, or water upgrades. Every purchase asks for confirmation with the exact price.
5. After the 240 s day, a 30 s warning sounds and night falls for 120 s. Zombies walk your unlocked lanes. Defensive plants fight. Tap zombies to hit them; use Repair, Spikes and Freeze. Surviving pays a dawn reward.
6. Later: build the Neon maker ($250K) at the pad behind your plot, open **Index** to see your collection, and **Settings** for volume, camera mode and reduced effects.
7. Halloween: the event is active inside the `Events.Halloween2026` window (2026-10-17 to 2026-11-03 UTC, `src/shared/Events.luau`), so it is on today. To test the "event ended" path (A20), set `EndsAt` in the past; within 10 s the decor and fog go away and the shop closes, but your Halloween plants stay. While it is active, the hub then gets the shack and pumpkin patch, and the **Event** button opens the shop with its countdown, odds table and quests.

## 4. DebugGrant (Studio only)

`ServerStorage.DebugGrant` is a BindableFunction created only when `RunService:IsStudio()`. It runs the same receipt ledger as a real purchase. In Play mode, switch the command bar to **Server** (the Current: Server toggle on the Test tab) and run:

```lua
local p = game.Players:GetPlayers()[1]
print(game.ServerStorage.DebugGrant:Invoke(p, "GrowthBoost"))           -- Granted
print(game.ServerStorage.DebugGrant:Invoke(p, "NeonSkip", "test-1"))     -- finishes the Neon fusion (or banks a credit)
print(game.ServerStorage.DebugGrant:Invoke(p, "NeonSkip", "test-1"))     -- same PurchaseId: Granted, no second grant
```

Keys: `InstantGrow`, `NeonSkip`, `MegaSkip`, `GrowthBoost`, `HalloweenPack`. If a grant can't be applied right now (for example, nothing is fusing), it is kept as a credit, which the matching button spends.

## 5. Forcing a failed DataStore save

1. Command bar (Server): `workspace:SetAttribute("DebugFailDataStore", true)`. Every `Store.update` now errors, Studio only.
2. Run `game.ServerStorage.DebugGrant:Invoke(p, "GrowthBoost", "fail-1")`. Expected result: `NotProcessedYet`, nothing granted, and a warning in the output.
3. Run `workspace:SetAttribute("DebugFailDataStore", false)`, then invoke again with `"fail-1"`. It grants once.
4. With the failure on, stop Play. Saves warn and retry 3 times; the profile stays in memory until they succeed or the player leaves. Data is never overwritten with defaults, because a save only happens after a successful load.

## Limitations (honest list)

- **Placeholder product ids.** Every Developer Product id is 0, so Robux prompts are disabled and show a toast. Set real ids in `src/shared/Products.luau` after creating the products.
- **No Studio playtest yet.** Everything is verified by static checks and the Luau harness only. A9 (guardian chase) and A24 (mobile) are BLOCKED-RUNTIME in `qa.md`.
- **No Halloween guardian.** The event has decor, shop, dig spot, night rewards and quests, but no special guardian.
- **Instant Grow fallback.** The target tile is not saved with the purchase intent. If it is lost (for example, a rejoin before the receipt), the grant goes to the plant with the most time left, or becomes a credit if nothing is growing.
- **Pacing ignores growth time.** `pacing.md` counts income time only. It leaves out growth time, refilling slots, and money sinks (house tiers, water, makers), so real progression is slower than the table.
- Most sound ids are 0 (no sound) until library ids are picked; they all live in `src/shared/Sounds.luau`.
- Settings are per session and not saved to the profile.
