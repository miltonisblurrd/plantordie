# Architecture map

Living map. Researcher updates this after every merge. Chat memory is not the map.

Rojo project `PlantOrDie` (`default.project.json`, Rojo 7.7.1 via `rokit.toml`). Lint: `selene.toml` (`std = "roblox"`).

| Place | Path | Role |
| --- | --- | --- |
| ReplicatedStorage.Shared | `src/shared` | Data tables both sides read. No game logic is duplicated. |
| ServerScriptService.Server | `src/server` | Authority over every number |
| StarterPlayerScripts.Client | `src/client` | Renders the state it receives |

Phases 1 (Foundation) and 2 (Planting) of cut v1 are built on branch `cursor/p1-foundation-cc3f`. The v1 prototype (roll/gems/quests) has been deleted.

## Shared (`src/shared`)

- `Config`: tuning for data, start values, world layout, plot grid, garden (tick, distance, offline cap and rate, refund, starter pack), day/night, and sync
- `Rarities`: Common to Divine, with multipliers and brand colours
- `Sizes`: Small ×1 to Giant ×25, with roll weights and visual scale (capped at 1.8)
- `Lanes`: lane prices (1-3 free, 4-7 paid)
- `Houses`: 5 tiers with cost, max HP, required biome, plant slots, and model params
- `Biomes`: the 15 biomes in order, with unlock cost and palette (ground, 2 accents, prop)
- `Products`: Developer Products (placeholder IDs are 0)
- `Remotes`: every remote, with its kind, rate, and burst
- `Format`: money and clock strings
- `Plants`: full §4 definitions (income, grow time, optional size weights, model recipe, optional combat block, water flag) plus `Variants` (Normal ×1, Neon ×3, Mega ×10). Green Meadows has 4 species; Mushroom Forest has 1 so far.
- `Economy`: **the only income and growth maths.** Provides `incomeOf` (base × rarity × size × variant × bonuses), `growthMultiplier`, `growth` (stages 1-4), `rollSize`, and `offlineEarnings`.
- Stubs that later phases fill: `DropTables`, `Zombies`, `Guardians`, `Fusion`, `Upgrades`, `Events` (Halloween window and `active()`)

## Server (`src/server`)

- `Boot.server`: start order. Net, then the world (Hub, Biomes, Plots), then Sync, DayNight, and Data.
- `Net`: creates the remotes from `Remotes`. `on` and `onInvoke` wrap every handler with three checks: the player's profile is loaded, the player is within their rate limit for that remote, and the argument types are valid. Also provides `fire`, `fireAll`, and `notify`.
- `Data/init`: player sessions. Loads use `UpdateAsync` with a session lock (`{jobId, time}`, stolen if older than 30 minutes or from the same job), 3 retries with backoff, and a kick on failure. A save only happens if the load succeeded. Autosave runs every 60s, a save runs on leave, and `BindToClose` flushes everything. Also: the receipt ledger (`recordReceipt`), and the `onLoaded`, `onReleasing`, `onChanged`, and `update` hooks.
- `Data/Schema`: the `Profile` type, defaults, migrations (v2 stacks seeds by species and adds `lastSeen` and `starterGranted`), and reconcile
- `Data/Store`: the DataStore backend, or an in-memory fallback in Studio without API access (warns loudly). Setting the `DebugFailDataStore` attribute in Studio injects failures.
- `Plots`: assigns one plot per player for the session. Provides `ownerOf(tile|plot)`, `isOwner(player, plot)`, `plotOf`, `plotAt`, `refresh` (lanes and house), the spawn location, and `onAssigned` / `onReleased` hooks.
- `Biomes`: builds the gates and the P3 biome anchors. Provides `isUnlocked`, `highestUnlocked`, and `anchor`.
- `DayNight`: the synced cycle. Broadcasts `(phase, endsAt, duration, night)` and moves `Lighting.ClockTime`. Provides an `onPhaseChanged` hook for P4.
- `Garden`: planting, placing and removing plants (`PlantSeed`, `PlacePlant`, `RemovePlant`), plant models rebuilt from `profile.planted`, the 1s income and stage tick, offline earnings, and the starter pack. `incomeOf` feeds Sync.
- `Shop`: `BuyLane` (in order) and `BuyHouse` (biome-gated). Both rebuild the plot visuals.
- `Sync`: sends the HUD snapshot (`StateSync`) and tracks each player's area. `setIncomeProvider` is the hook for P2 Garden.
- `World/Parts`: the part factory, plus tree, rock, and surface-text helpers
- `World/Layout`: placement maths. Plots sit on a ring at 45° steps. Gates sit 2 per sector between plot paths. Biome anchors are at radius 1400.
- `World/Builders/Hub`, `Gate`, `Plot`, `House`, `PlantModel`: models built from parts. `PlantModel` builds per stage and variant: Neon gets a light and particles, Mega gets the `MegaPlant` tag and sparkles. Lane signs carry a `BuyLanePrompt`. `House.build(tier, …)` swaps the house model when the tier changes.

## Client (`src/client`)

- `Boot.client`: starts the controllers
- `State`: the only inbound data path (`StateSync`, `DayNight`)
- `Ui`: brand primitives and a `ScreenGui` with safe-area insets and a `UIScale`
- `Hud`: money, income/sec, area, the day/night countdown, house HP, and the event slot
- `Notifications`: toasts from the `Notify` remote
- `Camera`: the elevated lane view on your own plot (toggle with the C key or the button)
- `Gates`: per-player gate signs and local barrier collision
- `Placement`: tile raycast with a green/red preview. Mouse: click to plant. Touch: tap to preview, tap again to plant. With nothing selected, a click opens Inspect.
- `Inspect`: the plant popup (species, rarity colour, size, variant, timer, income, and a confirmed dig-up)
- `Inventory`: the seeds and plants panel. Picking an entry selects it in Placement.
- `Shops`: the upgrades panel (house and next lane) and lane-sign prompts, all with a price confirm
- `GardenView`: plant billboard text and the Mega rainbow
- `Ui.confirm`: the modal used for every purchase or destructive action

## Remotes

Server to client: `StateSync`, `DayNight`, `Notify`.
Client to server: `RequestState`, `PlantSeed`, `PlacePlant`, `RemovePlant`, `BuyLane`, `BuyHouse`. These are declared but not handled yet: `UnlockBiome`, `Dig` (P3), `FusionStart`, `FusionClaim` (P5).

## Rules for later phases

- Every mutation goes through `Data.update(player, fn)` so the HUD stays in sync.
- Every plot or tile action checks `Plots.isOwner` first.
- New remotes are added to `Shared/Remotes` and handled with `Net.on`.
