# pod-v2 — brand pin

Design Lead. UI is in the cut.

## World

- Low-poly, blocky, classic simulator. Parts only: Block, Wedge, Cylinder, Ball. Materials: SmoothPlastic and Neon. Grass may use Grass material.
- Saturated palette. Each biome gets 1 ground, 2 accent, and 1 prop color in `Biomes.luau`. Two adjacent biomes never share a ground color.
- Plants read at a distance: 1 stem, 1 head shape, 1 accent. The Giant size is at most 1.8× the tile visually so lanes stay readable.
- Neon: Neon material on the head plus a PointLight and a slow particle. Mega: a rainbow hue cycle on the client plus sparkles.
- Zombies and guardians: blocky rigs, one strong color, glowing eyes.

## UI

- Font: FredokaOne for titles, GothamBold for body.
- Primary green `#3FBF4A`, dark panel `#1E2A22` at 0.15 transparency, 12 px UICorner, 2 px UIStroke.
- Rarity colors: Common `#B0B0B0`, Uncommon `#4CD964`, Rare `#3A8DFF`, Epic `#A64DFF`, Legendary `#FFB020`, Mythical `#FF4D6D`, Divine `#FFFFFF` with a gold stroke.
- Touch targets at least 44 px; HUD scales with UIScale and is safe-area aware.
- Every purchase prompt states the exact benefit and price before the Roblox prompt opens.
