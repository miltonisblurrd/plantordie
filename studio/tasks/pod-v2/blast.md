# pod-v2 — blast radius

Researcher. 2026-10-17. Citations against the v1 tree in `src/`.

## Remotes

- GitHub: `https://github.com/miltonisblurrd/plantordie` (empty at intake; owner supplied it). Branch `main`.
- Rojo project `default.project.json` maps `src/shared` → ReplicatedStorage.Shared, `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client. Rojo 7.7.1 via `rokit.toml`. Layout is kept.

## Files touched

Every v1 file is replaced or rewritten. v1 is roll/gems/quests and does not match the spec loop.

| v1 file | Fate | Reason |
| --- | --- | --- |
| `src/server/DataService.luau` | Rewrite | Line 52–78: a failed `GetAsync` falls through to a default profile, and the next `save` (85–104) writes it over real data. That breaks spec §15. No session lock, no retries, and the `UpdateAsync` transform ignores the stored value. |
| `src/server/ReceiptService.luau` | Rewrite | `ProcessReceipt` (126–158) has no PurchaseId ledger, so a receipt replayed after a save failure grants twice. Products are roll/gems, not spec products. |
| `src/server/Net.luau` | Rewrite | Single generic `Action` remote with no per-action rate limit. |
| `src/server/PlayerActions.luau` | Replace | Roll-based actions. |
| `src/server/CombatService.luau`, `Modes.luau` | Replace | Free-roam monsters and raid/boss modes; the spec wants lane zombies plus separate biome guardians. |
| `src/server/MapBuilder.luau` | Replace | Single map; the spec needs a hub, plots, and 15 biomes. |
| `src/server/PlantVisuals.luau` | Replace | Needs growth stages, sizes, and Neon/Mega effects. |
| `src/server/DayNightService.luau` | Rework | Keep the phase-broadcast idea. |
| `src/server/Main.server.luau`, `State.luau`, `ProfileUtil.luau` | Replace | Boot, profile helpers. |
| `src/shared/*` | Replace | New config tables per §16. |
| `src/client/Main.client.luau` | Replace | Single 408-line UI file; split into controllers. |

## Features in reach

The spec has 18 sections. All of them are new code. Nothing in v1 covers lanes, digging, biomes, guardians, fusion machines, offline progress, or the event system.

## Risks

- No Studio runtime in the agent environment. QA is code review plus static checks (owner choice at intake). `qa.md` must say so, and runtime acceptance rows stay BLOCKED until the owner playtests.
- Developer Product and Game Pass IDs are placeholders (owner choice). Purchases cannot be tested end to end until real IDs exist.
- All 15 biomes are built from parts in code, so server start-up build time and part count need a budget.
