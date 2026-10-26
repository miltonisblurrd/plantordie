# safe-zone — board

- Opened: 2026-10-25 · From: owner (chat) · Checklist: `canvases/safe-zone-fix.canvas.tsx` (164 rows).

## Original ask (quoted, key lines)

> I noticed the zones where too small and there was big walls and a narrow walk way thru each zone which inst function and doesnt look like the pictures. so lets fix that
> PLANT or DIE — Safe Zone System and Guardian Chase Fix
> There must be exactly one shared Safe Zone for the entire game world. The Safe Zone must not be recreated inside individual biomes.
> Players should not need to enter their individual plot to become safe. They become safe as soon as they cross into the shared Safe Zone.
> Remove or disable the unintended biome-level Safe Zones ... Do not remove the biome boundaries, perimeter walls, zone entrances, or player plot walls when fixing the issue. Only correct the Safe Zone logic.
> The Guardian must not enter the Safe Zone to pursue a player ... Cancel the active chase target immediately ... Prevent the Guardian from reacquiring that player while they remain inside the Safe Zone.
> The server should determine whether a player is inside the Safe Zone ... Do not rely exclusively on client-side UI or local scripts.
> When a player leaves the Safe Zone and re-enters a dangerous biome ... they can once again be detected and chased by Guardians.
> The boundary should extend across the full entrance to the home area, not just a small section of the path.
> Guardians should stop at the Safe Zone boundary rather than following players all the way to their plots. They should abandon the chase even if they are already very close to the entrance.

Owner instruction (2026-10-25 18:58): "start with safe zone fix. build out everything step by step from that canvas".

The zone size and walkway layout complaint is tracked separately in `canvases/zone-layout.canvas.tsx` and is not part of this task.
