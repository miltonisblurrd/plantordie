# Architecture map

Living map. Researcher updates this after every merge. Chat memory is not the map.

Rojo project `PlantOrDie` (`default.project.json`, Rojo 7.7.1 via `rokit.toml`). Lint: `selene.toml` (`std = "roblox"`).

| Place | Path | Role |
| --- | --- | --- |
| ReplicatedStorage.Shared | `src/shared` | Data tables both sides read. No game logic is duplicated. |
| ServerScriptService.Server | `src/server` | Authority over every number |
| StarterPlayerScripts.Client | `src/client` | Renders the state it receives |

Phases 1 (Foundation), 2 (Planting), 3 (Exploration) and 4 (Defense) of cut v1 are built on branch `cursor/p1-foundation-cc3f`. The v1 prototype (roll/gems/quests) has been deleted.

## Shared (`src/shared`)

- `Config`: tuning for data, start values, world layout, plot grid, garden (tick, distance, offline cap and rate, refund, starter pack), day/night, and sync
- `Rarities`: Common to Divine, with multipliers and brand colours
- `Sizes`: Small ×1 to Giant ×25, with roll weights and visual scale (capped at 1.8)
- `Lanes`: lane prices (1-3 free, 4-7 paid)
- `Houses`: 5 tiers with cost, max HP, required biome, plant slots, and model params
- `Biomes`: the 15 biomes in order, with unlock cost, palette, `Released`, `DigStyle` and `ToughTier`
- `Products`: Developer Products (placeholder IDs are 0)
- `Remotes`: every remote, with its kind, rate, and burst
- `Format`: money, clock and duration strings
- `Sounds`: **the only place sound ids live** (Dig, Discover, Plant, Buy, Click, Error, NightWarning, WaveClear, FusionDone, GuardianWarning, Music). `uri(name)` returns nil for id 0, so playback no-ops.
- `Discovery`: the collection set shown in the index, derived from the saved `collection` plus held seeds, bag, inventory and planted plants. `best(set, species)` gives the highest variant.
- `Plants`: full §4 definitions (income, grow time, optional size weights, model recipe, optional combat block, water flag) plus `Variants` from `Config.Economy.VariantMultiplier` (Normal ×1, Neon ×3, Mega ×8). Event plants (biome `halloween`, 7 species) come from the event roster. 60 species (4 per biome) from a `roster` table. Pacing formulas are in `studio/tasks/pod-v2/pacing.md`.
- `Economy`: **the only income and growth maths.** Provides `incomeOf` (base × rarity × size × variant × bonuses), `growthMultiplier`, `growth` (stages 1-4), `rollSize`, and `offlineEarnings`.
- `DropTables`: rarity weights per biome, exclusive to that biome. `weighted(biome, luck)` and `roll(biome, luck, r01)`. Luck is clamped by `Config.Dig.MaxLuck`.
- `Upgrades`: 5 shovels (Rusty, Iron, Golden, Crystal, Void) with price, DigSeconds, LuckBonus and ToughTier; water tiers (Channel $50K, Sprinkler $2M, Pond $75M) with growth multiplier and the water plant each unlocks (`waterAllows`, `nextWater`)
- `Guardians`: 15 guardians (`List`, `ByBiome`) with shape, speeds, detect range, leash, catch range, path recompute interval and prediction
- `Zombies`: 6 lane types plus the Rot King boss (every 5th night). `stats` scales by highest biome and night, `waveSize` scales by lanes, and `compose` builds a wave.
- `Combat`: night stats for a planted record (role, damage, rate, range in studs, HP) from the `Plants` combat field, with size and variant power
- `Fusion`: Neon and Mega maker definitions (input/output variant, per-rarity seconds, unlock cost, skip product, pad)
- `Events`: config-driven events. `Halloween2026` has its window, currency (Candy), decor key, dig and night rewards, pack odds (sum 100%), and 3 quests, plus a `Guardian` zone (centre and radius) in the hub. `active(now)`, `guardianEvent(now)`, `odds`, `roll`
- `Products`: also `ByKey`, `ById` (non-zero only) and `enabled(key)`; Id 0 means disabled

## Server (`src/server`)

- `Boot.server`: start order. Net, then the world (Hub, Biomes, Plots), then Sync, DayNight, and Data.
- `Net`: creates the remotes from `Remotes`. `on` and `onInvoke` wrap every handler with three checks: the player's profile is loaded, the player is within their rate limit for that remote, and the argument types are valid. Also provides `fire`, `fireAll`, and `notify`.
- `Data/init`: player sessions. Loads use `UpdateAsync` with a session lock (`{jobId, time}`, stolen if older than 30 minutes or from the same job), 3 retries with backoff, and a kick on failure. A save only happens if the load succeeded. Autosave runs every 60s, a save runs on leave, and `BindToClose` flushes everything. Also the `onLoaded`, `onReleasing`, `onChanged`, and `update` hooks.
- `Data/Schema`: the `Profile` type, defaults, migrations (v2 stacks seeds by species and adds `lastSeen` and `starterGranted`; v3 adds `expedition`, the saved unbanked bag; v4 resets `fusion` to slots and adds `event.questsDone`, `credits`, `receiptLedger.pending`), and reconcile
- `Data/Store`: the DataStore backend, or an in-memory fallback in Studio without API access (warns loudly). Setting the `DebugFailDataStore` attribute in Studio injects failures.
- `Plots`: assigns one plot per player for the session. Provides `ownerOf(tile|plot)`, `isOwner(player, plot)`, `plotOf`, `plotAt`, `refresh` (lanes and house), the spawn location, and `onAssigned` / `onReleased` hooks.
- `Biomes`: builds the gates, the 15 biomes and the trails. Provides `isUnlocked`, `highestUnlocked`, `info`, `regionOf`, `inRegion`, `inSafeZone`, `canEnter`, and `HubSpawn`. Its 0.5s enforcement loop sends anyone in a biome they can't enter back to the hub.
- `Expedition`: the unbanked bag. Provides `add`, `lose` (clears only the bag), and `bank`. A loop banks the bag at the player's own plot or by the fountain.
- `Dig`: the `Dig` remote. Checks the spot, distance, region access, equipped shovel, tough tier and cooldown, then rolls the drop, respawns the spot later, and fires `DigResult`.
- `Tools`: gives the Shovel tool on spawn
- `GuardianAI`: one Heartbeat loop for every guardian (Patrol, Chase, Cooldown). Throttled off-thread PathfindingService with a direct-move fallback, a stuck reset, and loss on leash, safe zone or leaving the region. A catch clears the bag and sends the player home. Guardians in empty biomes sleep. Each guardian carries its own zone functions (region, safe zone, clamp). `setEventGuardian(id?)`, called from `Event.apply`, spawns the event's guardian (`Guardians.Event[id]`) over the event zone and removes it when the event ends.
- `DayNight`: the synced cycle. Broadcasts `(phase, endsAt, duration, night)` and moves `Lighting.ClockTime`. Provides an `onPhaseChanged` hook for P4.
- `Garden` also provides `onPlantChanged`, `isGrown`, `setWilted` and `wiltedKeys`. Wilted plants earn nothing until dawn or a repair.
- `Garden`: planting, placing and removing plants (`PlantSeed`, `PlacePlant`, `RemovePlant`), plant models rebuilt from `profile.planted`, the 1s income and stage tick, offline earnings, and the starter pack. `incomeOf` feeds Sync.
- `Defense/Core`: the pure lane simulation for one plot (plain tables, no instances). Covers plant roles, zombie movement and attacks, jump, ranged, traps, the house hit, stuck and timeout cleanup, and dawn. The harness runs it directly.
- `Defense` (init): one loop for every plot. It builds a wave at nightfall, spawns at the right edge of an unlocked lane, steps `Core`, mirrors the result onto anchored zombie models with PivotTo, and batches `CombatFx`. It also handles wilting, house HP, wave loss with its penalty, the dawn reward, the pre-night warning, and the `Repair`, `UseTrap` and `HitZombie` remotes. Spawning pauses while the owner is in a biome.
- `Shop`: `BuyLane` (in order), `BuyHouse` (biome-gated), `UnlockBiome` (released, in order, saved), and `BuyShovel` (next tier)
- `Fusion/Core`: pure maker state machine (`status`, `matching`, `start` removes 4 atomically, `claim` idempotent by runId, `skip`). Status is derived from timestamps, so offline runs finish on their own. `Fusion` (init): unlock/start/claim remotes and pad billboards.
- `Purchases/Core`: pure receipt ledger. Write PurchaseId + pending grant, save, grant only if saved; failed save rolls back to NotProcessedYet; `recover` applies pending grants on load. `Purchases` (init): `ProcessReceipt`, `apply` per product (unbankable grants become credits), `UseCredit`, `PurchaseIntent` (Instant Grow saves the target plant's uid in `profile.purchaseIntent`; the receipt finishes only that plant, or banks one credit if it is gone), and the Studio-only `ServerStorage.DebugGrant` bindable (`debugGrant(player, key)`).
- `Event`: the event manager. Every `CheckSeconds` it builds or removes `World/Builders/Events/<Decor>` and the fog, handles `EventBuyPack` (Candy or HalloweenPack product) and `EventDig`, awards Candy per night survived, and tracks quests.
- `World/Builders/Machine`: maker pad with status billboard and `FusionPrompt`. `Plot.setWater` places channel, sprinklers and pond.
- `Sync`: sends the HUD snapshot (`StateSync`, which includes a `defense` block) and tracks each player's area. `houseHp` and `setHouseHp` serve Defense. `setIncomeProvider` is the hook for P2 Garden.
- `World/Parts`: the part factory, plus tree, rock, and surface-text helpers
- `World/Layout`: placement maths. Plots sit on a ring at 45° steps. Gates sit 2 per sector between plot paths. Biomes are 240×240 squares on ring radius 760, two per plot gap. Each trail has 5 points (`biomePath`).
- `World/BiomeKit`: the shared biome skeleton (ground, walls, entrance, safe zone, patrol, danger zones, dig spots) and prop helpers. `World/Builders/Biomes/<Id>`: one builder per biome. `World/Builders/GuardianRig`: guardian models.
- `World/Builders/ZombieModel`: a 5-7 part zombie with its pivot at the feet
- `World/Builders/Hub`, `Gate` (with `UnlockBiomePrompt`), `Plot`, `House`, `PlantModel`: models built from parts. `PlantModel` builds per stage and variant: Neon gets a light and particles, Mega gets the `MegaPlant` tag and sparkles. Lane signs carry a `BuyLanePrompt`. `House.build(tier, …)` swaps the house model when the tier changes.

## Client (`src/client`)

- `Boot.client`: starts the controllers and the action bar (a horizontal ScrollingFrame, capped at 820 px, that scrolls on narrow screens)
- `State`: the only inbound data path (`StateSync`, `DayNight`)
- `Ui`: brand primitives and a `ScreenGui` with safe-area insets (respects the top bar) and a `UIScale`. On touch screens every fixed-offset button is grown to at least 44 px after scaling.
- `Hud`: money, income/sec, area (the current biome, safe zone or trail), the bag, the day/night countdown, house HP, and the event slot
- `Notifications`: toasts from the `Notify` remote
- `Camera`: the elevated lane view on your own plot (toggle with the C key or the button)
- `Gates`: per-player gate signs, local barrier collision, and the unlock prompt with an order and price confirm
- `Shovel`: tool hook, nearest spot, swing tween, `Dig` request, dig VFX, and the shovel shop panel
- `Danger`: the guardian warning banner and sound
- `Atmosphere`: a colour tint per biome
- `Defense`: the attack countdown and wave banner, zombie health billboards, click or tap to hit, `CombatFx` effects, the Repair, Spikes and Freeze buttons, and the night tint
- `Placement`: tile raycast with a green/red preview. Mouse: click to plant. Touch: tap to preview, tap again to plant. With nothing selected, a click opens Inspect.
- `Inspect`: the plant popup (species, rarity colour, size, variant, timer, income, and a confirmed dig-up)
- `Inventory`: the seeds and plants panel. Picking an entry selects it in Placement.
- `Shops`: the upgrades panel (house and next lane) and lane-sign prompts, all with a price confirm
- `GardenView`: plant billboard text, the Mega rainbow (off under reduced effects), and the pop-in for new plant models (covers planting and each growth stage, since the server rebuilds the model per stage)
- `Purchases`: `offer(key)` confirm → `PurchaseIntent` → prompt; disabled products only toast
- `FusionPanel`: Neon/Mega panels (build, fuse groups of 4, progress, claim, skip)
- `EventShop`: Halloween shop with countdown, Candy balance, odds table, quests, dig prompt
- `Collection`: the index of every species grouped by biome (event last). Discovered species show head colour, rarity colour and best variant; locked ones show a dark silhouette and "???".
- `Settings` / `SettingsPanel`: music and SFX volume, camera mode (lane view or follow), reduced effects. Per session, client only.
- `Sfx`: 2D playback by name through the `Sfx`/`Music` SoundGroups.
- `Effects`: reduced effects (disables every ParticleEmitter, Sparkles, Fire, Smoke and Trail, including ones spawned later) and the shared 0.25 s pop tween.
- `Feedback`: sounds and pops derived from state changes (Buy, NightWarning, WaveClear, FusionDone, the claim pop on the maker core), so feedback only fires for what the server did.
- `Ui.confirm`: the modal used for every purchase or destructive action

## Remotes

Server to client: `StateSync`, `DayNight`, `Notify`, `DigResult`, `Danger`, `CombatFx`.
Client to server: `RequestState`, `PlantSeed`, `PlacePlant`, `RemovePlant`, `BuyLane`, `BuyHouse`, `UnlockBiome`, `BuyShovel`, `Dig`, `Repair`, `UseTrap`, `HitZombie`, `BuyWater`, `FusionUnlock`, `FusionStart`, `FusionClaim`, `PurchaseIntent`, `UseCredit`, `EventBuyPack`, `EventDig`.

## Part and effect budget

- **Boot:** about 3,100 parts (harness "Part counts"): hub 63, 8 plots 776 (97 each, including the tier-1 house and maker pads), 15 gates 105, 15 biomes with guardians 2,108, trails 60. While active, the Halloween decor adds 86 (harness). Planted plant models add 3 to 8 parts each at runtime, capped by house slots.
- **Zombies:** each model is 5 to 7 anchored parts, moved with PivotTo. `Config.Defense.MaxPerPlot = 18` alive per plot, so at most about 126 per plot and about 1,000 across 8 plots during a night. Stuck zombies despawn after 8 s, every zombie after 100 s, all at dawn.
- **Particles:** only Neon plants (1 slow ParticleEmitter and a PointLight), Mega plants (Sparkles plus the client rainbow) and the sprinkler spray emit. Combat VFX are short tweened parts cleaned up by Debris. Under reduced effects, the client disables every emitter, sparkle, fire, smoke and trail (restored when turned off), skips the rainbow cycle and the pop tweens. Lights stay.

## Rules for later phases

- Every mutation goes through `Data.update(player, fn)` so the HUD stays in sync.
- Every plot or tile action checks `Plots.isOwner` first.
- New remotes are added to `Shared/Remotes` and handled with `Net.on`.
