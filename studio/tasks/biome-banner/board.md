# biome-banner — board

- Opened: 2026-10-19 · From: owner (chat) · Task 4 of 8. Built on `cursor/shops-trails-shovels-dee5`.

## Original ask (quoted, key lines)

> Create a biome detection UI for Plant or Die, inspired by the reference image. The UI must automatically recognize which of the 15 biomes a player is currently inside and display the biome name and recommended Speed at the top of the screen.
> Position the biome UI at the top-center ... large, bold, colorful text with a thick dark outline or shadow ... biome-themed emoji beside the name ... Recommended: 👟 [Speed Amount] Speed ... blue shoe or Speed icon ... compact enough that it does not obstruct gameplay.
> 🌱 Green Meadows — 100 · 🍄 Mushroom Forest — 10K · 🌵 Cactus Canyon — 100K · 🔥 Inferno Jungle — 1M · ❄️ Frostbite Garden — 10M · 🌳 Enchanted Grove — 100M · 🌴 Tropical Paradise — 1B · 🪸 Coral Kingdom — 5B · 🍂 Autumn Woods — 10B · ☁️ Sky Islands — 25B · 💎 Crystal Caverns — 50B · ☣️ Toxic Swamp — 100B · 🏛️ Ancient Wilds — 250B · 🌌 Cosmic Garden — 500T · 🌺 Forbidden Bloom — 1 QA
> Define a separate region or trigger zone for each biome ... immediately update ... always represents the player's current location ... Prevent the UI from flickering ... Hide or change the biome banner appropriately when the player is in their base or the central safe area ... Recommendations are not automatic entry restrictions ... configurable ... client-side UI updates ... Optimize detection so it does not repeatedly create UI elements ... Test transitions between every biome, including edge cases around biome boundaries and respawning.

Full rows: `studio/tasks/intake-2026-10-19.md` section 4.
