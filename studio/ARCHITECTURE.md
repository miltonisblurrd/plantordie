# Architecture map

Living map. Researcher updates this after every merge. Chat memory is not the map.

Rojo project `PlantOrDie` (`default.project.json`):

| Place | Path | Role |
| --- | --- | --- |
| ReplicatedStorage.Shared | `src/shared` | Data the client and server both require |
| ServerScriptService.Server | `src/server` | Authority: state, combat, map, day/night, receipts |
| StarterPlayerScripts.Client | `src/client` | ScreenGui built in code. Remotes: Action, State, Vfx, Announce, Roll |

## Shared

- `Config.luau` — tuning
- `PlantData.luau` — plant definitions
- `MonsterData.luau` — monster definitions
- `Shop.luau` — shop catalog
- `Quests.luau` — quest definitions

## Server

- `Main.server.luau` — boot
- `Net.luau` — remotes
- `State.luau` / `ProfileUtil.luau` / `DataService.luau` — player profile
- `PlayerActions.luau` — client Action remote
- `MapBuilder.luau` / `PlantVisuals.luau` — world and plant meshes
- `DayNightService.luau` / `Modes.luau` — cycle and modes
- `CombatService.luau` — nights, monsters, plant defense. Requires PlantData, MonsterData, Config, State, ProfileUtil, PlantVisuals, PlayerActions, Net
- `ReceiptService.luau` — purchases

## Client

- `Main.client.luau` — coins, loot, gems, income, clock, quests, roll / plants / upgrade bar. Reads PlantData, Config, Shop, Quests.

## Not in repo yet

No git remote. No CI. No playtest capture path. Chief cannot land a pull request until this folder is a GitHub repo.
