local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local DataService = {}
local store = nil
local board = nil

pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
pcall(function()
	board = DataStoreService:GetOrderedDataStore("PlantOrDieCoins")
end)

local function defaultProfile()
	return {
		coins = Config.StartingCoins,
		loot = 0,
		gems = 0,
		quest = 1,
		doubleCoins = false,
		extraLuck = false,
		hasExclusive = false,
		houseLevel = 1,
		plants = {},
		tiles = {},
		followers = {},
		nightEarnings = 0,
	}
end

function DataService.snapshot(profile)
	return {
		coins = profile.coins,
		loot = profile.loot,
		gems = profile.gems,
		quest = profile.quest,
		doubleCoins = profile.doubleCoins,
		extraLuck = profile.extraLuck,
		hasExclusive = profile.hasExclusive,
		houseLevel = profile.houseLevel,
		plants = profile.plants,
		tiles = profile.tiles,
		followers = profile.followers,
	}
end

function DataService.load(player)
	local profile = defaultProfile()
	if store then
		local ok, data = pcall(function()
			return store:GetAsync("Player_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			profile.coins = tonumber(data.coins) or profile.coins
			profile.loot = tonumber(data.loot) or 0
			profile.gems = tonumber(data.gems) or 0
			profile.quest = tonumber(data.quest) or 1
			profile.doubleCoins = data.doubleCoins == true
			profile.extraLuck = data.extraLuck == true
			profile.hasExclusive = data.hasExclusive == true
			profile.houseLevel = math.clamp(tonumber(data.houseLevel) or 1, 1, Config.MaxHouseLevel)
			if type(data.plants) == "table" then
				profile.plants = data.plants
			end
			if type(data.tiles) == "table" then
				profile.tiles = data.tiles
			end
			if type(data.followers) == "table" then
				profile.followers = data.followers
			end
		elseif not ok then
			warn("[PLANT or DIE] Could not load save for", player.Name, data)
		end
	end
	profile.nightEarnings = 0
	profile.houseHp = Config.HouseHealth[profile.houseLevel]
	State.profiles[player] = profile
	return profile
end

function DataService.save(player)
	local profile = State.profiles[player]
	if not profile or not store then
		return
	end
	local payload = DataService.snapshot(profile)
	local ok, err = pcall(function()
		store:UpdateAsync("Player_" .. player.UserId, function()
			return payload
		end)
	end)
	if not ok then
		warn("[PLANT or DIE] Save failed for", player.Name, err)
	end
	if board then
		pcall(function()
			board:SetAsync(tostring(player.UserId), math.floor(profile.coins))
		end)
	end
end

function DataService.topCoins()
	if not board then
		return {}
	end
	local ok, pages = pcall(function()
		return board:GetSortedAsync(false, 8)
	end)
	if not ok or not pages then
		return {}
	end
	return pages:GetCurrentPage()
end

function DataService.saveAll()
	for _, player in Players:GetPlayers() do
		DataService.save(player)
	end
end

return DataService
