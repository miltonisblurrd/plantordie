# pod-v2 — QA, Phase 5 (cut v1, checks A14–A20)

Status: harness PASS. Studio play-test is PENDING (QA needs to run it on the preview). CI green is not a pass.

## Studio setup

- Product ids are all 0, so live prompts are disabled and only show a toast. Use DebugGrant to test grants.
- DebugGrant exists only in Studio. Run it from the server command bar:
  `game.ServerStorage.DebugGrant:Invoke(game.Players:GetPlayers()[1], "Skip")`
  Keys: `InstantGrow`, `Skip`, `GrowthBoost`, `HalloweenPack`. An optional third argument is a PurchaseId; reusing one must grant only once.
- To test a failed save, set `workspace:SetAttribute("DebugFailDataStore", true)` and then invoke DebugGrant. Expected result: NotProcessedYet and nothing granted. Clear the attribute and invoke again with the same PurchaseId; it should grant once.

## Checks

| Check | How | Harness | Studio |
| --- | --- | --- | --- |
| A14 Four Normal → one Neon | Build the Neon maker ($250K), fuse 4 same-species, same-size Normals, wait, then claim | PASS (start removes exactly 4, claim adds 1 Neon) | PENDING |
| A15 Four Neon → one Mega | Build the Mega maker ($25M, needs Neon), fuse 4 Neons | PASS (same Core path, Input = Neon) | PENDING |
| A16 Offline progress | Start a fusion, leave, and rejoin after endsAt; it shows Ready. Growth offline uses Phase 2 timestamps | PASS (status is ready at endsAt + 1h) | PENDING |
| A17 No double claim | Double-click Claim, or fire FusionClaim twice with the same runId | PASS (second claim granted = false, same item, 1 Neon) | PENDING |
| A18 Failed or cancelled purchases grant nothing | Cancel a prompt; use DebugFailDataStore plus DebugGrant | PASS (failed and erroring saves give NotProcessedYet, 0 grants, ledger rolled back) | PENDING |
| A19 Receipts grant once | DebugGrant twice with the same PurchaseId | PASS (same pid twice grants 1, 1 save; grant happens only after the ledger write; recover applies pending once) | PENDING |
| A20 Halloween plants persist | Get an event plant, end the event (edit the `Events` window), rejoin | Code: plants are ordinary inventory records, and the event check only gates the shop, decor and dig | PENDING |

Also checked by the harness: 7 Halloween plants, pack odds sum to 100.00%, 3 quests, and every enabled product has a non-zero id.
