--!strict
-- In-game money purchases: lanes (in order) and house tiers (in order, biome-gated).
-- The client shows a confirm with the exact benefit and price; the server re-checks everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Houses = require(ReplicatedStorage.Shared.Houses)
local Lanes = require(ReplicatedStorage.Shared.Lanes)
local Biomes = require(script.Parent.Biomes)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local Sync = require(script.Parent.Sync)

local Shop = {}

local function buyLane(player: Player)
	local session = Data.get(player)
	if not session or not Plots.plotOf(player) then
		return
	end
	local d = session.data
	local lane = d.lanesUnlocked + 1
	local price = Lanes.price(lane)
	if lane > Config.Plot.Lanes or not price then
		Net.notify(player, "All lanes are already unlocked.", "warn")
		return
	end
	if d.money < price then
		Net.notify(player, `Not enough money. Lane {lane} costs {Format.money(price)}.`, "error")
		return
	end
	Data.update(player, function(p)
		p.money -= price
		p.lanesUnlocked = lane
	end)
	Plots.refresh(player)
	Net.notify(player, `Lane {lane} unlocked!`)
end

local function buyHouse(player: Player)
	local session = Data.get(player)
	if not session or not Plots.plotOf(player) then
		return
	end
	local d = session.data
	local nextDef = Houses.List[d.houseTier + 1]
	if not nextDef then
		Net.notify(player, "Your house is already max tier.", "warn")
		return
	end
	local required = BiomeData.List[nextDef.RequiredBiome]
	if required and not Biomes.isUnlocked(d, required.Id) then
		Net.notify(player, `{nextDef.Name} requires {required.Name} to be unlocked.`, "error")
		return
	end
	if d.money < nextDef.Cost then
		Net.notify(player, `Not enough money. {nextDef.Name} costs {Format.money(nextDef.Cost)}.`, "error")
		return
	end
	Data.update(player, function(p)
		p.money -= nextDef.Cost
		p.houseTier = nextDef.Tier
	end)
	Plots.refresh(player)
	Sync.resetHouseHp(player)
	Net.notify(player, `Upgraded to {nextDef.Name}! Max HP {nextDef.MaxHp}, {nextDef.Slots} plant slots.`)
end

function Shop.start()
	Net.on("BuyLane", {}, buyLane)
	Net.on("BuyHouse", {}, buyHouse)
end

return Shop
