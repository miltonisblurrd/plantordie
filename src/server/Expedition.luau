--!strict
-- The unbanked expedition bag (spec §5). Dig rewards land here, never straight in `seeds`.
-- Returning to your own plot or the hub fountain banks the bag into the seed inventory; a
-- guardian catch clears ONLY this bag (A10). The bag is saved, so a disconnect never wipes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Plants = require(ReplicatedStorage.Shared.Plants)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)

local Expedition = {}

function Expedition.count(profile: Data.Profile): number
	local n = 0
	for _, c in profile.expedition do
		n += c
	end
	return n
end

function Expedition.add(player: Player, species: string, amount: number): boolean
	if not Plants.ById[species] or amount <= 0 then
		return false
	end
	return Data.update(player, function(p)
		p.expedition[species] = (p.expedition[species] or 0) + amount
		p.stats.seedsDug += amount
	end)
end

-- Clears the bag and nothing else. Returns how many seeds were lost.
function Expedition.lose(player: Player): number
	local session = Data.get(player)
	if not session then
		return 0
	end
	local lost = Expedition.count(session.data)
	if lost > 0 then
		Data.update(player, function(p)
			p.expedition = {}
		end)
	end
	return lost
end

function Expedition.bank(player: Player): number
	local session = Data.get(player)
	if not session then
		return 0
	end
	local moved = Expedition.count(session.data)
	if moved == 0 then
		return 0
	end
	Data.update(player, function(p)
		for species, c in p.expedition do
			if Plants.ById[species] and c > 0 then
				p.seeds[species] = (p.seeds[species] or 0) + c
			end
		end
		p.expedition = {}
	end)
	Net.notify(player, `Banked {moved} seed{if moved == 1 then "" else "s"} into your inventory.`)
	return moved
end

local function atBankPoint(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local pos = root.Position
	local idx = Plots.plotAt(pos)
	if idx and Plots.isOwner(player, idx) then
		return true
	end
	return Vector3.new(pos.X, 0, pos.Z).Magnitude <= Config.Bank.HubRadius
end

function Expedition.start()
	task.spawn(function()
		while true do
			task.wait(Config.Bank.CheckSeconds)
			for _, player in Players:GetPlayers() do
				local session = Data.get(player)
				if session and next(session.data.expedition) ~= nil and atBankPoint(player) then
					Expedition.bank(player)
				end
			end
		end
	end)
end

return Expedition
