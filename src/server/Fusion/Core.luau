--!strict
-- Pure fusion state machine over a profile table. No yields, no Roblox services, so the
-- harness drives it directly and every check-then-write below is atomic on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Discovery = require(ReplicatedStorage.Shared.Discovery)
local FusionData = require(ReplicatedStorage.Shared.Fusion)
local Plants = require(ReplicatedStorage.Shared.Plants)

export type Item = { id: string, species: string, rarity: string, size: string, variant: string }
export type Slot = {
	unlocked: boolean,
	state: string,
	runId: number,
	species: string?,
	rarity: string?,
	size: string?,
	startedAt: number,
	endsAt: number,
	ingredients: { Item }?,
	last: { runId: number, itemId: string, claimed: boolean }?,
}
-- The subset of Data.Profile the core touches.
export type ProfileLike = {
	plants: { [string]: Item },
	nextItemId: number,
	collection: { [string]: boolean },
	fusion: { [string]: Slot },
}

local Core = {}

-- "empty" | "fusing" | "ready". Derived from timestamps; never trusts a stored "ready".
function Core.status(slot: Slot, now: number): string
	if slot.state == "empty" then
		return "empty"
	end
	return if now >= slot.endsAt then "ready" else "fusing"
end

-- Inventory items matching a recipe, sorted by id so removal is deterministic.
function Core.matching(profile: ProfileLike, machineId: string, species: string, size: string): { string }
	local m = FusionData.Machines[machineId]
	local ids = {}
	if not m then
		return ids
	end
	for id, item in profile.plants do
		if item.species == species and item.variant == m.Input and (item.size == size or not FusionData.RequireSameSize) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return ids
end

-- Validates and starts a fusion: removes exactly InputCount items and snapshots them.
-- Returns ok, reason.
function Core.start(profile: ProfileLike, machineId: string, species: string, size: string, now: number): (boolean, string?)
	local m = FusionData.Machines[machineId]
	local slot = profile.fusion[machineId]
	local def = Plants.ById[species]
	if not m or not slot or not def then
		return false, "Unknown machine or plant."
	end
	if not slot.unlocked then
		return false, `Build the {m.Name} first.`
	end
	if slot.state ~= "empty" then
		return false, `The {m.Name} is busy. Claim it first.`
	end
	local ids = Core.matching(profile, machineId, species, size)
	if #ids < FusionData.InputCount then
		return false, `Needs {FusionData.InputCount} {m.Input} {def.Name} ({size}). You have {#ids}.`
	end
	local snapshot: { Item } = {}
	for i = 1, FusionData.InputCount do
		local id = ids[i]
		table.insert(snapshot, table.clone(profile.plants[id]))
		profile.plants[id] = nil
	end
	slot.state = "fusing"
	slot.runId += 1
	slot.species = species
	slot.rarity = def.Rarity
	slot.size = size
	slot.startedAt = now
	slot.endsAt = now + (m.Seconds[def.Rarity] or 60)
	slot.ingredients = snapshot
	return true, nil
end

-- Claims a ready fusion exactly once. A repeat for the same runId returns the item from the
-- first claim with granted = false. Returns itemId?, granted, reason?.
function Core.claim(profile: ProfileLike, machineId: string, runId: number, now: number): (string?, boolean, string?)
	local m = FusionData.Machines[machineId]
	local slot = profile.fusion[machineId]
	if not m or not slot then
		return nil, false, "Unknown machine."
	end
	local last = slot.last
	if last and last.runId == runId and last.claimed then
		return last.itemId, false, nil
	end
	if slot.state == "empty" or slot.runId ~= runId then
		return nil, false, "Nothing to claim."
	end
	if Core.status(slot, now) ~= "ready" then
		return nil, false, "Still fusing."
	end
	local species, rarity, size = slot.species :: string, slot.rarity :: string, slot.size :: string
	local id = tostring(profile.nextItemId)
	profile.nextItemId += 1
	profile.plants[id] = { id = id, species = species, rarity = rarity, size = size, variant = m.Output }
	Discovery.record(profile, species, m.Output)
	-- The slot empties only after the result plant exists.
	slot.last = { runId = runId, itemId = id, claimed = true }
	slot.state = "empty"
	slot.species, slot.rarity, slot.size, slot.ingredients = nil, nil, nil, nil
	slot.startedAt, slot.endsAt = 0, 0
	return id, true, nil
end

-- Skip product: finishes a running fusion now. Returns false if nothing is fusing.
function Core.skip(profile: ProfileLike, machineId: string, now: number): boolean
	local slot = profile.fusion[machineId]
	if not slot or Core.status(slot, now) ~= "fusing" then
		return false
	end
	slot.endsAt = now
	return true
end

return Core
