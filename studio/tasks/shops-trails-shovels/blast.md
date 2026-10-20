# shops-trails-shovels — blast radius

Base: `cursor/speed-treadmill-ef77`.

- `src/server/World/Builders/Hub.luau`: hub around (0, −70) behind the plot row; Neon and Mega machines at (±22, −70); fountain bank; spawn at (0, −70). The two stalls go in clear space here.
- `src/server/World/Builders/Events/Halloween.luau`: event shack and pumpkin patch in the hub, so stalls must not overlap them.
- `src/shared/Upgrades.luau`: `Shovels`, 5 tiers bought in order (`Tier, Name, Cost, DigSeconds, LuckBonus, ToughTier, Damage, Color`). Gets replaced by 10.
- `src/server/Shop.luau:107` `buyShovel`: buys the next tier only, and `profile.shovelTier` drives everything.
- Readers of `shovelTier`: `server/Dig.luau:72`, `server/Tools.luau`, `client/Shovel.luau:68,186,201`, `client/Feedback.luau:29`, `server/Sync.luau:127`.
- `src/client/Shovel.luau:151-207`: the old "Upgrade Shovel" panel and action-bar button, replaced by the shop.
- `src/shared/Treadmill.luau`: `Trails` stub plus `multiplierFor`. Task 2 saves `trails = { owned, equipped }`.
- `src/server/Data/Schema.luau`: v7. A shovel owned set needs v8.
- `src/client/Ui.luau`: panels, buttons, `confirm`, `screen`.
- `src/client/Settings.luau`: reduced effects.
