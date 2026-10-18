--!strict
-- Neon / Mega makers on each plot's reserved pads (spec §11). All state lives in
-- profile.fusion and is saved with the profile, so a disconnect mid-fusion loses nothing and
-- an offline fusion is simply "ready" on return (timestamp math in Core.status).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FusionData = require(ReplicatedStorage.Shared.Fusion)
local Format = require(ReplicatedStorage.Shared.Format)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Core = require(script.Core)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local Machine = require(script.Parent.World.Builders.Machine)

local Fusion = {}

local claimedCallbacks: { (Player, string, string) -> () } = {}

-- Fires once per real claim (not for duplicates): player, machineId, itemId.
function Fusion.onClaimed(cb: (Player, string, string) -> ())
	table.insert(claimedCallbacks, cb)
end

function Fusion.refresh(player: Player)
	local session = Data.get(player)
	local idx = Plots.plotOf(player)
	local refs = idx and Plots.refs(idx)
	if not session or not refs then
		return
	end
	local slots = session.data.fusion :: any
	for id, m in refs.machines do
		Machine.apply(m, slots[id])
	end
end

-- Skip product grant. Returns false when nothing is fusing (caller banks a credit).
function Fusion.skip(profile: Data.Profile, machineId: string, now: number): boolean
	return Core.skip(profile :: any, machineId, now)
end

local function unlock(player: Player, machineId: string)
	local session = Data.get(player)
	local def = FusionData.Machines[machineId]
	if not session or not def or not Plots.plotOf(player) then
		return
	end
	local slot = (session.data.fusion :: any)[machineId] :: Core.Slot
	if slot.unlocked then
		return
	end
	if machineId == "Mega" and not session.data.fusion.Neon.unlocked then
		Net.notify(player, "Build the Neon Maker first.", "error")
		return
	end
	if session.data.money < def.UnlockCost then
		Net.notify(player, `Not enough money. The {def.Name} costs {Format.money(def.UnlockCost)}.`, "error")
		return
	end
	Data.update(player, function(p)
		p.money -= def.UnlockCost
		local slots = p.fusion :: any
		slots[machineId].unlocked = true
	end)
	Fusion.refresh(player)
	Net.notify(player, `{def.Name} built! Put 4 identical {def.Input} plants in to fuse.`)
end

local function start(player: Player, machineId: string, species: string, size: string)
	local session = Data.get(player)
	if not session or not FusionData.Machines[machineId] or not Plots.plotOf(player) then
		return
	end
	local ok, reason = false, nil :: string?
	-- Core.start checks and removes the ingredients with no yield in between.
	Data.update(player, function(p)
		ok, reason = Core.start(p :: any, machineId, species, size, os.time())
	end)
	if not ok then
		Net.notify(player, reason or "Can't fuse that.", "error")
		return
	end
	Fusion.refresh(player)
	local slot = (session.data.fusion :: any)[machineId] :: Core.Slot
	local def = FusionData.Machines[machineId]
	Net.notify(player, `{def.Name}: fusing 4 {Plants.ById[species].Name} ({size}). Ready in {Format.clock(slot.endsAt - slot.startedAt)}.`)
end

local function claim(player: Player, machineId: string, runId: number)
	local session = Data.get(player)
	local def = FusionData.Machines[machineId]
	if not session or not def then
		return
	end
	local itemId, granted, reason = nil :: string?, false, nil :: string?
	Data.update(player, function(p)
		itemId, granted, reason = Core.claim(p :: any, machineId, runId, os.time())
	end)
	if not itemId then
		Net.notify(player, reason or "Nothing to claim.", "warn")
		return
	end
	local item = session.data.plants[itemId :: string]
	local name = if item and Plants.ById[item.species] then `{def.Output} {Plants.ById[item.species].Name} ({item.size})` else `{def.Output} plant`
	if granted then
		Fusion.refresh(player)
		Net.notify(player, `{name} added to your plant inventory!`)
		for _, cb in claimedCallbacks do
			task.spawn(cb, player, machineId, itemId :: string)
		end
	else
		Net.notify(player, `Already claimed: {name}.`, "info")
	end
end

function Fusion.start()
	Plots.onAssigned(function(player)
		Fusion.refresh(player)
	end)
	Plots.onReleased(function(_player, idx)
		local refs = Plots.refs(idx)
		if refs then
			for _, m in refs.machines do
				Machine.apply(m, nil)
			end
		end
	end)
	Net.on("FusionUnlock", { "string" }, unlock)
	Net.on("FusionStart", { "string", "string", "string" }, start)
	Net.on("FusionClaim", { "string", "number" }, claim)
end

return Fusion
