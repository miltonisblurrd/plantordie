# index-rewards — cut v1 (frozen)

## In scope
1. **Permanent discoveries.**
   - Whenever a player gains a plant or seed by any path (bank, garden harvest to inventory, fusion, purchase grant, event grant, starter grant), the server writes `collection["species|variant"] = true`.
   - On load, the current derived set is folded into `collection` once.
   - Selling, fusing or losing an item never removes an entry.
   - Server is the only writer.
2. **Required collection per biome.**
   - Config `src/shared/IndexRewards.luau`. Each biome's required list defaults to every species in `Plants.ByBiome[biome]` (Normal variant), including Secret-rarity plants that belong to that biome.
   - Variants (Neon, Mega, Giant if present) are tracked and shown, but not required.
3. **Rewards per biome** (configurable in the same file):
   - **Cash:** one-time, rising steeply. Default: 2 × the next biome's unlock cost, and 2 × own cost × 10 for the last biome. Minimum $5,000.
   - **Permanent Speed bonus:** a multiplier added to treadmill gains (default +10% per completed biome). Stored separately and never reset.
   - **Bat skin:**
     - Green Meadows: Leafy Bat
     - Mushroom Forest: Mushroom Bat
     - Cactus Canyon: Cactus Bat
     - Inferno Jungle: Lava Bat
     - Frostbite Garden: Ice Bat
     - Enchanted Grove: Enchanted Bat
     - Tropical Paradise: Palm Bat
     - Coral Kingdom: Coral Bat
     - Autumn Woods: Autumn Bat
     - Sky Islands: Cloud Bat
     - Crystal Caverns: Crystal Bat
     - Toxic Swamp: Toxic Bat
     - Ancient Wilds: Ancient Bat
     - Cosmic Garden: Galaxy Bat
     - Forbidden Bloom: Divine Bloom Bat

     Each has a name, colors and look data for task 7. They're cosmetic only.
4. **Claim.**
   - When a biome's required set is complete, a "Claim rewards" button lights up in the Index.
   - Claiming goes through a server remote. The server re-checks completion, checks `indexClaimed[biome]` isn't set, then grants all three rewards at once and sets the flag.
   - Idempotent: rejoining or double-clicking can't grant twice.
   - Auto-claim isn't required; the button gives the payoff moment.
5. **Data (schema v10):**
   - `indexClaimed: { [biomeId]: true }`
   - `batSkins: { owned: { [id]: true }, equipped: string? }`
   - `speedBonus: number` (sum of permanent bonus fractions)

   Rebirth doesn't exist yet. These fields and `collection` are documented as rebirth-exempt in Schema comments and `studio/ARCHITECTURE.md`, so a future rebirth must not reset them.
6. **Treadmill:** gain = SpeedPerSec × trail multiplier × (1 + speedBonus), computed on the server.
7. **Index UI** (`client/Collection.luau`).
   - Each biome section shows:
     - "x / y plants" and a completion percentage with a progress bar.
     - The three rewards, visible from the start: the cash amount, "+10% Speed forever", and the bat skin name with a color swatch.
     - The Claim button, or "Claimed ✓".
   - Undiscovered plants show as silhouettes with "???", and Secret entries show as "Secret".
   - Variant badges (Neon, Mega) are shown per plant.
   - Mobile-friendly scrolling.
8. A toast and sound when a biome's set completes ("Green Meadows Index complete! Claim your rewards").

## Out of scope
Using bats or equipping skins in combat (task 7), building a rebirth system, balance pass.

## Acceptance checks
- F1. A newly obtained species is recorded at once. Selling or fusing it keeps it recorded.
- F2. Each biome section shows x / y, a percentage and its three rewards from the start.
- F3. Completing a biome lights up Claim. Claiming grants the exact cash, +speedBonus and the bat skin once. A second claim or a rejoin grants nothing.
- F4. Variants are shown but not required. Secret plants in a biome's list are required.
- F5. The treadmill gain includes (1 + speedBonus) (harness math check).
- F6. v9 → v10 migration folds the derived discoveries into `collection` and adds the new fields.
- F7. The claim remote can't be triggered for an incomplete biome (server re-check). rojo build and harness clean (except the known assert).
