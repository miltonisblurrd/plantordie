# speed-treadmill — blast radius

Base: `cursor/fix-basics-fd5f` (task 1 build) on top of `origin/main` 9b8a0ba.

- `src/server/World/Builders/Plot.luau`: plot layout. `PlotRefs` (line 23); house at `HouseX = -32` (Config.Plot), spawn at `cf * (HouseX, 4, -40)` (line 137). The treadmill model and upgrade sign go here.
- `src/server/Plots.luau`: assignment and `onAssigned`; plot ownership checks (`isOwner`, `plotAt`).
- `src/server/Data/Schema.luau`: profile shape, `SchemaVersion = 6` in `Config.Data`. Needs new fields and a v6→v7 migration.
- `src/server/Sync.luau` and `src/client/State.luau`: the snapshot carries new fields to the client.
- `src/client/Hud.luau`: Speed stat display.
- `src/shared/Format.luau`: suffixes `K M B T Qa Qi`; the owner wants `QA` for quadrillion.
- `src/shared/Products.luau` and `src/server/Purchases/*`: Robux receipt ledger for an optional treadmill-level product (id 0 until the owner creates it).
- `src/server/Shop.luau`: existing money purchases with server validation (pattern to follow).
- `src/client/Effects.luau` and `src/client/Sfx.luau`: popups and sounds.
- No code sets `Humanoid.WalkSpeed` today (grep). Movement from Speed is new.
- `src/shared/Guardians.luau`: guardian WalkSpeed/ChaseSpeed are fixed. Untouched here; task 5 scales them from Recommended Speed.
