# pod-v2 — Acceptance walk A1–A25 (cut v1, Phase 6)

QA mode from `cut.md`:
- **PASS** means the code path was read and verified and the static checks are clean. Where a harness case exists, it is cited.
- **FAIL** means the check does not hold.
- **BLOCKED-RUNTIME** means it needs the owner's Studio playtest.

No Studio playtest has happened yet. CI green is not a pass.

## Static checks (Phase 6 head)

| Check | Result |
| --- | --- |
| `rojo build -o /tmp/b.rbxlx` | builds |
| `selene src` | 0 errors, 0 warnings |
| `luau-lsp analyze` (strict, Roblox defs, sourcemap) | 0 diagnostics |
| `python3 studio/tools/world_harness.py` | exit 0; every assert passes |

## Walk

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| A1 | A new player joins and gets a unique plot | PASS | `server/Plots.luau` `assign` takes the first free index and maps owner to index both ways; `release` frees it on leave. Harness "Part counts" builds all 8 plots. |
| A2 | Plant a seed in a valid tile | PASS | `server/Garden.luau` `checkTile` (owner, lane unlocked, tile free), `checkPlantable` (house slots), `waterOk`, then `plantSeed` decrements the seed inside `Data.update`. Client `Placement.luau` keeps the two-tap flow on touch. |
| A3 | Plant grows and earns the correct money/s | PASS | Harness "Economy": income = base × rarity × size × variant exactly. "Offline growth": stages 1→2→4 by timestamp. `Garden` tick pays `Economy.incomeOf`. |
| A4 | Larger plant earns more than a smaller one | PASS | Harness "Economy": income is strictly increasing across every size, Small to Giant. |
| A5 | Buy a lane and keep it after rejoining | PASS | `server/Shop.luau` `buyLane` (in order, money check, `Data.update`). Saved by `Data.save`. Harness "Save data" shows `lanesUnlocked` survives migration. A rejoin against a real DataStore needs Studio with API access. |
| A6 | Dig in a biome and get a valid reward | PASS | `server/Dig.luau` checks spot, distance, region, shovel, tough tier and cooldown. Harness "Drop odds": every table holds only its own biome's species, odds are exact, luck clamp holds. |
| A7 | Cannot enter an unreleased or locked biome | PASS | Harness "Biome access": a locked biome is refused, and an unreleased one is refused even when owned. `Biomes` runs a 0.5 s enforcement loop that bounces trespassers. |
| A8 | Buy a biome and keep access | PASS | Harness "Biome access": after buying, entry is allowed through `biomesUnlocked`. `Shop.unlockBiome` saves in order. Migration keeps it (harness "Save data"). |
| A9 | Guardian detects, chases and loses the player | BLOCKED-RUNTIME | `server/GuardianAI.luau` (Patrol/Chase/Cooldown, leash, safe zone, stuck reset). Pathfinding and Humanoid movement only run in Studio. |
| A10 | Caught player loses only unbanked seeds | PASS | `server/Expedition.luau` `lose` only sets `p.expedition = {}`. Seeds, plants and money are untouched. `GuardianAI` catch calls only `Expedition.lose` and sends the player home. |
| A11 | Zombies use the correct lanes and the correct garden | PASS | Harness "Defense wave simulation" asserts lanes ok, left-only, and max alive ≤ cap. "Isolation": plot B never fires at plot A's zombie. |
| A12 | Defensive plants damage zombies | PASS | Harness "Role checks" runs each role against a Walker for 10 s; "Jumper/Spitter" covers vault and range. |
| A13 | A zombie reaching the house damages it | PASS | Harness wave report counts house hits and the HP removed; `Defense/Core` handles the house hit. |
| A14 | Four Normal plants make one Neon | PASS | Harness "Fusion state machine": start removes exactly 4 same-size plants, claim adds 1 Neon. |
| A15 | Four Neon plants make one Mega | PASS | Same `Fusion/Core` path with Input = Neon. Harness "Duplication guards": the Mega maker refuses Normal inputs. |
| A16 | Growth and fusion progress offline | PASS | Harness "Offline growth": stages advance by timestamp, offline pay starts only after growth, the window is capped. "Fusion": status is ready an hour after the end time. |
| A17 | A completed fusion cannot be claimed twice | PASS | Harness "Fusion": the second claim returns granted = false and the same item, leaving 1 Neon. "Duplication guards": a forged runId or an empty slot grants nothing. |
| A18 | Failed or cancelled purchases grant nothing | PASS | Harness "Receipt ledger": a save that returns false or errors gives NotProcessedYet with 0 grants and rolls the ledger back. `client/Purchases.luau`: a cancel only shows a toast, and grants happen only in `ProcessReceipt`. |
| A19 | Verified receipts grant exactly once | PASS (ledger) | Harness "Receipt ledger": the same PurchaseId twice gives 1 grant and 1 save, the grant comes only after the ledger write, and `recover` applies a pending grant once. Live receipts need real product ids (all are 0); test with `ServerStorage.DebugGrant` (RUN.md). |
| A20 | Halloween plants stay after the event | PASS | Event plants are ordinary `plants`/`planted` records. `server/Event.luau` only gates decor, shop, dig and quests on `Events.active`. Harness "Collection index data": held items count as discovered regardless of event state. |
| A21 | Two players don't affect each other | PASS | Every plot and tile remote checks `Plots.isOwner` (`Garden`, `Defense`, `Fusion`). Harness "Isolation" covers defense fields. Profiles are per-player sessions in `Data`. A two-client Studio test (Test > Clients: 2) is still recommended. |
| A22 | No duplication through client requests | PASS | `Net.on` validates types and rate limits. All checks and writes happen inside one `Data.update` with no yields. Harness "Duplication guards": short, mixed-size and wrong-tier fusion starts remove nothing; empty or forged claims grant nothing. Plus the receipt idempotency above. |
| A23 | All 15 biomes exist and are reachable | PASS | Harness "Part counts" builds all 15 biomes, each with its guardian and 10 dig spots; "Roster" lists 4 species each. 15/15 released. "Pacing" shows each biome is affordable in order. |
| A24 | Playable with mobile controls | BLOCKED-RUNTIME | Code: `Ui.screen` (safe insets, respects the top bar, UIScale 0.65–1.25); on touch screens every fixed-size button grows to at least 44 px after scaling. `Boot.client` action bar scrolls sideways when narrow. Two-tap plant in `Placement`. Needs the Studio device emulator (see RUN.md). |
| A25 | Save failures and disconnects don't wipe progress | PASS | Harness "Save data": a v1 record migrates and keeps money, seeds, lanes and biomes; newer or corrupt records are refused, not overwritten. `Data`: session lock, 3 retries, no save unless the load succeeded, `BindToClose` flush. Fault injection: `DebugFailDataStore` (RUN.md). |

## Summary

- 23 PASS. A19 passes on the receipt ledger; live receipts are untested because every product id is 0.
- 0 FAIL.
- 2 BLOCKED-RUNTIME: A9 (guardian pathfinding) and A24 (mobile).
- Rows that need a Studio confirm even though they are PASS: A5 (real DataStore rejoin), A21 (two clients) and A25 (DebugFailDataStore run).

## Bugs fixed in this pass

- The collection index only counted species once they were planted (`Garden.plantSeed`). Seeds from digs, banked seeds, event packs and the starter pack never showed as discovered, and older profiles had nothing. Fix: `Shared/Discovery.of` derives the set from the saved collection plus seeds, bag, inventory and planted plants, and `Sync` sends that set. Covered by the harness.
- Sound ids were split across `Config.Sounds` and a server-to-client remote argument. Now `Shared/Sounds` is the only table; the `Danger` remote no longer carries a sound id.
- On phones, UIScale shrank 44 px buttons to about 29 px. Fixed in `Ui.screen`, on touch screens only.
- The 620 px action bar overflowed narrow screens. It is now a horizontal ScrollingFrame capped at 820 px.
