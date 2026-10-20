--!strict
-- Pushes the HUD-facing snapshot of server state to each client and tracks which area each
-- player stands in. The client renders this; it never computes money or income itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Discovery = require(ReplicatedStorage.Shared.Discovery)
local Config = require(ReplicatedStorage.Shared.Config)
local Houses = require(ReplicatedStorage.Shared.Houses)
local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Plots = require(script.Parent.Plots)
local Biomes = require(script.Parent.Biomes)
local DayNight = require(script.Parent.DayNight)

local Sync = {}

type Runtime = { area: string, areaBiome: string, houseHp: number }
local runtime: { [Player]: Runtime } = {}

-- Income/sec is owned by Garden (P2). Until then it is always 0.
local incomeProvider: (Player) -> number = function(_player: Player)
	return 0
end

function Sync.setIncomeProvider(fn: (Player) -> number)
	incomeProvider = fn
end

-- Night wave HUD block, owned by Defense (P4).
local defenseProvider: (Player) -> { [string]: any }? = function(_player: Player)
	return nil
end

function Sync.setDefenseProvider(fn: (Player) -> { [string]: any }?)
	defenseProvider = fn
end

-- Limited-time event HUD block, owned by Event (P5).
local eventProvider: (Player) -> { [string]: any }? = function(_player: Player)
	return nil
end

function Sync.setEventProvider(fn: (Player) -> { [string]: any }?)
	eventProvider = fn
end

function Sync.houseHp(player: Player): number
	local rt = runtime[player]
	return if rt then rt.houseHp else 0
end

function Sync.setHouseHp(player: Player, hp: number)
	local rt = runtime[player]
	if rt then
		rt.houseHp = math.max(0, hp)
		Sync.push(player)
	end
end

-- Returns the HUD area name and the biome id ("" outside biomes).
local function areaFor(player: Player): (string, string)
	local root = Biomes.rootOf(player)
	if not root then
		return "Hub", ""
	end
	local pos = root.Position
	local idx = Plots.plotAt(pos)
	if idx then
		if Plots.isOwner(player, idx) then
			return "Your Plot", ""
		end
		local owner = Plots.ownerOf(idx)
		return if owner then `{owner.Name}'s Plot` else "Empty Plot", ""
	end
	local flat = Vector3.new(pos.X, 0, pos.Z)
	if flat.Magnitude <= Config.World.GateRingRadius + 20 then
		return "Hub", ""
	end
	local biomeId = Biomes.regionOf(pos)
	if biomeId then
		local b = BiomeData.ById[biomeId]
		local safe = Biomes.inSafeZone(biomeId, pos)
		return if safe then `{b.Name} (Safe)` else b.Name, biomeId
	end
	return "Trail", ""
end

function Sync.resetHouseHp(player: Player)
	local session = Data.get(player)
	local rt = runtime[player]
	if session and rt then
		rt.houseHp = (Houses.List[session.data.houseTier] or Houses.List[1]).MaxHp
		Sync.push(player)
	end
end

function Sync.push(player: Player)
	local session = Data.get(player)
	local rt = runtime[player]
	if not session or not rt then
		return
	end
	local d = session.data
	local house = Houses.List[d.houseTier] or Houses.List[1]
	local planted = 0
	for _ in d.planted do
		planted += 1
	end
	Net.fire("StateSync", player, {
		money = d.money,
		incomePerSec = incomeProvider(player),
		houseTier = d.houseTier,
		houseName = house.Name,
		houseHp = rt.houseHp,
		houseMaxHp = house.MaxHp,
		houseSlots = house.Slots,
		plantedCount = planted,
		seeds = d.seeds,
		plants = d.plants,
		lanesUnlocked = d.lanesUnlocked,
		biomesUnlocked = d.biomesUnlocked,
		plotIndex = Plots.plotOf(player) or 0,
		area = rt.area,
		areaBiome = rt.areaBiome,
		shovelTier = d.shovels.equipped,
		shovels = d.shovels,
		bag = d.expedition,
		defense = defenseProvider(player),
		event = eventProvider(player),
		water = d.water,
		fusion = d.fusion,
		credits = d.credits,
		collection = Discovery.of(d :: any),
		growthBoostEndsAt = d.growthBoostEndsAt,
		speed = d.speed,
		treadmillLevel = d.treadmillLevel,
		trails = d.trails,
		persistent = Data.mode() == "DataStore",
	})
end

function Sync.start()
	Data.onLoaded(function(player, session)
		local house = Houses.List[session.data.houseTier] or Houses.List[1]
		runtime[player] = { area = "Hub", areaBiome = "", houseHp = house.MaxHp }
		-- Plot assignment runs in its own onLoaded callback; let it settle first.
		task.defer(Sync.push, player)
	end)
	Data.onChanged(function(player)
		Sync.push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		runtime[player] = nil
	end)
	Net.on("RequestState", {}, function(player)
		Sync.push(player)
		DayNight.sendTo(player)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Sync.AreaCheckSeconds)
			for player, rt in runtime do
				local area, biomeId = areaFor(player)
				if area ~= rt.area then
					rt.area = area
					rt.areaBiome = biomeId
					Sync.push(player)
				end
			end
		end
	end)
end

return Sync
