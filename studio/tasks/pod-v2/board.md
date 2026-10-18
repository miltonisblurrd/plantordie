# pod-v2 — Plant or Die, full build to spec

Opened: 2026-10-17. Sent by: owner. Step: intake.

## Original ask (quoted)

> BUILD A COMPLETE ROBLOX GAME: PLANT OR DIE
> Act as a senior Roblox game developer, gameplay systems engineer, UI designer, 3D environment artist, and multiplayer systems architect. Build a complete, playable Roblox game called PLANT OR DIE.
>
> Sections 1–18: identity and low-poly style; multiplayer hub and personal plots; Plants vs. Zombies lane grid (3 to 7+ lanes); plant definitions, growth, sizes; seven rarities and the income formula; shovel digging and drop tables; fifteen biomes with unlock costs; biome guardians and chases; day/night zombie defense; house tiers and water systems; Neon Maker and Mega Maker; Halloween event; UI; economy and monetization; DataStore saving and security; technical architecture; build order in six phases; 25 acceptance tests.
>
> "Build Plant or Die as an integrated, playable Roblox game, not merely a collection of visual mockups. ... If the environment cannot implement the entire game in one pass, complete the foundation first, preserve the architecture, and continue implementing the remaining systems incrementally."

The full spec text is in the owner's chat message of 2026-10-17 and is the source for `cut.md`.

## Starting point

v1 lives in `src/` (about 3,000 lines of Luau, Rojo project). Its design is roll, gems, and quests, not lanes, digging, and biomes. No git repo, no remote, no CI.

## Sub-tasks (run 2 at a time, one per phase)

| Id | Phase | Covers spec sections |
| --- | --- | --- |
| pod-v2-p1 | Foundation | 1, 2, 3 (grid), 13 (HUD), 15, 16 |
| pod-v2-p2 | Planting | 4, 5, 10 (lanes, house tiers) |
| pod-v2-p3 | Exploration | 6, 7, 8 |
| pod-v2-p4 | Defense | 9, 10 (traps, house HP) |
| pod-v2-p5 | Advanced | 11, 12, 14, offline progress |
| pod-v2-p6 | Polish and test | 17 phase 6, 18 acceptance |
