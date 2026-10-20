# biome-banner — cut v1 (frozen)

## In scope
1. **Data.** `src/shared/Biomes.luau` gets `Emoji` and `RecommendedSpeed` for each biome, exactly as listed by the owner: 100, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 5e9, 1e10, 2.5e10, 5e10, 1e11, 2.5e11, 5e14, 1e15. Both are configurable in that one table.
2. **Shared region helper.** `src/shared/BiomeRegions.luau` computes each biome's region box from Config and Layout math (move or share `Layout.biomeCFrame` so client and server use the same numbers). It also exposes `regionOf(pos)` and `inSafeZone(biomeId, pos)`. The server `Biomes.luau` uses it too, so there's one source of truth.
3. **Client banner** (`src/client/BiomeBanner.luau`).
   - **Layout and style:**
     - Top-center, below the Roblox top bar, clear of the existing money panel. Move or stack the money panel if they collide.
     - Line 1: emoji plus biome name, large and bold, in the biome's accent color with a thick dark stroke.
     - Line 2: `Recommended: 👟 10K Speed` with a blue shoe.
     - Compact: at most about 90 px tall on phones, scaled with UIScale for small screens.
   - **Building:** the GUI is built once; only text and colors change.
   - **Detection:**
     - Polls about 5×/s from the character's root position.
     - Hysteresis: switches to a new biome only after being inside it 1 stud past the edge, or for 0.3 s.
     - Leaving all biomes hides the banner with a short fade.
     - Respawn re-evaluates immediately.
   - **Hidden:** in the hub or central safe area, on any plot, and in the trail gaps between biomes. The banner shows only inside a biome region.
   - **Animation:** a short pop or slide when the biome changes.
4. The recommendation is display-only. Access stays with the server unlock rules.
5. The existing HUD "Area" panel stays.

## Out of scope
Guardian speed from RecommendedSpeed (task 5), everything else.

## Acceptance checks
- D1. All 15 biomes show the right emoji, name and short Speed value. Mushroom Forest reads "🍄 Mushroom Forest / Recommended: 👟 10K Speed"; Forbidden Bloom reads "… 👟 1 QA Speed".
- D2. Crossing from biome N into N+1 updates within 0.5 s. Standing on a boundary doesn't flicker.
- D3. Hidden at hub, plots and trail gaps. Shown again on re-entry. Correct after respawn.
- D4. No GUI instances created after the first build (static: no Instance.new in the update path).
- D5. Server and client use the same region math (harness: for sample points, server `regionOf` equals the shared helper).
- D6. Readable on phone sizes and doesn't collide with the money panel or the RUN banner slot.
- D7. rojo build and harness clean (except the known assert).
