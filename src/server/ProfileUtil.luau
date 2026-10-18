local HttpService = game:GetService("HttpService")
local PlantData = require(game.ReplicatedStorage.Shared.PlantData)
local Config = require(game.ReplicatedStorage.Shared.Config)

local ProfileUtil = {}

function ProfileUtil.findPlant(profile, uid)
	for _, plant in profile.plants do
		if plant.uid == uid then
			return plant
		end
	end
	return nil
end

function ProfileUtil.addPlant(profile, id)
	local def = PlantData.Plants[id]
	if not def then
		return nil
	end
	local plant = {
		uid = HttpService:GenerateGUID(false),
		id = id,
		hp = def.health,
		stunnedUntil = 0,
	}
	table.insert(profile.plants, plant)
	return plant
end

function ProfileUtil.isStunned(plant)
	return plant.stunnedUntil and plant.stunnedUntil > os.time()
end

function ProfileUtil.tileOf(profile, uid)
	for index, placed in profile.tiles do
		if placed == uid then
			return tonumber(index)
		end
	end
	return nil
end

function ProfileUtil.isFollower(profile, uid)
	for _, id in profile.followers do
		if id == uid then
			return true
		end
	end
	return false
end

function ProfileUtil.incomePerSecond(profile)
	local mult = Config.IncomeMultiplier[profile.houseLevel] or 1
	local total = 0
	for index, uid in profile.tiles do
		local tileIndex = tonumber(index)
		if tileIndex == 5 and profile.houseLevel < Config.FifthTileHouseLevel then
			continue
		end
		local plant = ProfileUtil.findPlant(profile, uid)
		if plant and not ProfileUtil.isStunned(plant) and (plant.growLeft or 0) <= 0 then
			local def = PlantData.Plants[plant.id]
			if def then
				total += def.income
			end
		end
	end
	if profile.doubleCoins then
		total *= 2
	end
	return math.floor(total * mult * 10) / 10
end

function ProfileUtil.view(profile, plotIndex)
	local plants = {}
	for _, plant in profile.plants do
		local def = PlantData.Plants[plant.id]
		table.insert(plants, {
			uid = plant.uid,
			id = plant.id,
			name = def and def.name or plant.id,
			rarity = def and def.rarity or "Common",
			income = def and def.income or 0,
			hp = plant.hp,
			maxHp = def and def.health or 1,
			stunnedUntil = plant.stunnedUntil or 0,
			growLeft = plant.growLeft or 0,
			evolveCost = def and def.evolvesInto and (Config.EvolveCost[def.rarity] or 0) or nil,
			evolvesInto = def and def.evolvesInto or nil,
			tile = ProfileUtil.tileOf(profile, plant.uid),
			follower = ProfileUtil.isFollower(profile, plant.uid),
		})
	end
	return {
		coins = profile.coins,
		loot = profile.loot,
		gems = profile.gems or 0,
		quest = profile.quest or 1,
		doubleCoins = profile.doubleCoins == true,
		extraLuck = profile.extraLuck == true,
		houseLevel = profile.houseLevel,
		houseHp = profile.houseHp,
		houseMax = Config.HouseHealth[profile.houseLevel],
		income = ProfileUtil.incomePerSecond(profile),
		plants = plants,
		tiles = profile.tiles,
		followers = profile.followers,
		plot = plotIndex,
		upgradeCost = Config.UpgradeCost[profile.houseLevel + 1],
	}
end

return ProfileUtil
