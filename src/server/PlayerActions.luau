local PlantData = require(game.ReplicatedStorage.Shared.PlantData)
local Config = require(game.ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local ProfileUtil = require(script.Parent.ProfileUtil)
local Net = require(script.Parent.Net)
local PlantVisuals = require(script.Parent.PlantVisuals)

local PlayerActions = {}

local function push(player)
	local profile = State.profiles[player]
	local plot = State.byPlayer[player]
	if not profile then
		return
	end
	if plot then
		plot.houseLabel.Text = player.DisplayName
		plot.hpLabel.Text = math.floor(profile.houseHp) .. " / " .. Config.HouseHealth[profile.houseLevel]
		if plot.hpFill then
			local maxHp = Config.HouseHealth[profile.houseLevel]
			plot.hpFill.Size = UDim2.fromScale(math.clamp(profile.houseHp / maxHp, 0, 1), 1)
		end
		plot.house.Color = Color3.fromRGB(230, 210, 170)
	end
	PlantVisuals.sync(player)
	Net.push(player, ProfileUtil.view(profile, plot and plot.index))
end

PlayerActions.push = push

function PlayerActions.roll(player)
	local profile = State.profiles[player]
	if not profile then
		return { ok = false, message = "No profile" }
	end
	if profile.coins < Config.RollCost then
		return { ok = false, message = "Need " .. Config.RollCost .. " coins" }
	end
	local function pick()
		local roll = math.random(1, 1000)
		local cursor = 0
		local pickedId = PlantData.Order[1]
		for _, id in PlantData.Order do
			cursor += PlantData.Plants[id].chance
			if roll <= cursor then
				pickedId = id
				break
			end
		end
		return pickedId
	end
	local picked = pick()
	if profile.extraLuck then
		local second = pick()
		local firstRank = PlantData.RarityRank[PlantData.Plants[picked].rarity] or 1
		local secondRank = PlantData.RarityRank[PlantData.Plants[second].rarity] or 1
		if secondRank > firstRank then
			picked = second
		end
	end
	profile.coins -= Config.RollCost
	if profile.quest == 1 then
		profile.quest = 2
	end
	local plant = ProfileUtil.addPlant(profile, picked)
	push(player)
	local def = PlantData.Plants[picked]
	return {
		ok = true,
		id = picked,
		name = def.name,
		rarity = def.rarity,
		uid = plant.uid,
	}
end

local function clearUid(profile, uid)
	for index, placed in profile.tiles do
		if placed == uid then
			profile.tiles[index] = nil
		end
	end
	for i = #profile.followers, 1, -1 do
		if profile.followers[i] == uid then
			table.remove(profile.followers, i)
		end
	end
end

function PlayerActions.handle(player, action, a, b)
	local profile = State.profiles[player]
	if not profile then
		return
	end
	if action == "Place" then
		local tileIndex = tonumber(a)
		local uid = b
		local plant = ProfileUtil.findPlant(profile, uid)
		if not plant or not tileIndex or tileIndex < 1 or tileIndex > Config.TileCount then
			Net.announce(player, "Can't place that plant.")
			return
		end
		if tileIndex == 5 and profile.houseLevel < Config.FifthTileHouseLevel then
			Net.announce(player, "Upgrade the house to level 2 to unlock tile 5.")
			return
		end
		if ProfileUtil.isStunned(plant) then
			Net.announce(player, "That plant is stunned.")
			return
		end
		clearUid(profile, uid)
		local previous = profile.tiles[tostring(tileIndex)]
		if previous then
			profile.tiles[tostring(tileIndex)] = nil
		end
		profile.tiles[tostring(tileIndex)] = uid
		local def = PlantData.Plants[plant.id]
		if plant.growLeft == nil and def then
			plant.growLeft = Config.GrowSeconds[def.rarity] or 30
		end
		if (plant.growLeft or 0) > 0 then
			Net.announce(player, def.name .. " is growing for " .. plant.growLeft .. "s")
		else
			Net.announce(player, def.name .. " planted on tile " .. tileIndex)
		end
		if profile.quest == 2 then
			profile.quest = 3
		end
	elseif action == "Pickup" then
		local tileIndex = tostring(tonumber(a))
		profile.tiles[tileIndex] = nil
	elseif action == "Equip" then
		local plant = ProfileUtil.findPlant(profile, a)
		if not plant then
			return
		end
		if ProfileUtil.isStunned(plant) then
			Net.announce(player, "That plant is stunned.")
			return
		end
		if #profile.followers >= Config.MaxFollowers then
			Net.announce(player, "Only " .. Config.MaxFollowers .. " plants can follow you.")
			return
		end
		if not ProfileUtil.isFollower(profile, plant.uid) then
			clearUid(profile, plant.uid)
			table.insert(profile.followers, plant.uid)
		end
	elseif action == "Unequip" then
		for i = #profile.followers, 1, -1 do
			if profile.followers[i] == a then
				table.remove(profile.followers, i)
			end
		end
	elseif action == "Upgrade" then
		local nextLevel = profile.houseLevel + 1
		local cost = Config.UpgradeCost[nextLevel]
		if not cost then
			Net.announce(player, "House is max level.")
			return
		end
		if profile.coins < cost then
			Net.announce(player, "Need " .. cost .. " coins to upgrade.")
			return
		end
		profile.coins -= cost
		profile.houseLevel = nextLevel
		profile.houseHp = Config.HouseHealth[nextLevel]
		Net.announce(player, "House upgraded to level " .. nextLevel)
	elseif action == "Evolve" then
		local plant = ProfileUtil.findPlant(profile, a)
		local def = plant and PlantData.Plants[plant.id]
		local nextId = def and def.evolvesInto
		local nextDef = nextId and PlantData.Plants[nextId]
		local cost = def and Config.EvolveCost[def.rarity]
		if not nextDef or not cost then
			Net.announce(player, "This plant cannot evolve.")
			return
		end
		if profile.loot < cost then
			Net.announce(player, "Need " .. cost .. " loot to evolve.")
			return
		end
		profile.loot -= cost
		plant.id = nextId
		plant.hp = nextDef.health
		plant.growLeft = 0
		PlantVisuals.clear(plant.uid)
		Net.announce(player, def.name .. " evolved into " .. nextDef.name)
	elseif action == "BuyGemPlant" then
		local Shop = require(game.ReplicatedStorage.Shared.Shop)
		if (profile.gems or 0) < Shop.GemPlantCost then
			Net.announce(player, "Need " .. Shop.GemPlantCost .. " gems. Gems drop from raids, defense, and surviving the night.")
			return
		end
		profile.gems -= Shop.GemPlantCost
		ProfileUtil.addPlant(profile, "GemBloom")
		Net.announce(player, "Gem Bloom joined your garden.")
	elseif action == "QueueGrow" then
		profile.pendingGrow = a
	elseif action == "QueueRevive" then
		profile.pendingRevive = a
	elseif action == "Revive" then
		local plant = ProfileUtil.findPlant(profile, a)
		if plant and ProfileUtil.isStunned(plant) then
			profile.pendingRevive = a
			Net.announce(player, "Select Instant revive in the shop.")
		end
	end
	push(player)
end

function PlayerActions.grant(player, coins, loot)
	local profile = State.profiles[player]
	if not profile then
		return
	end
	profile.coins += coins
	profile.loot += loot or 0
	if State.phase ~= "Day" then
		profile.nightEarnings += coins
	end
	push(player)
end

function PlayerActions.tickIncome()
	for player, profile in State.profiles do
		if player.Parent then
			for _, plant in profile.plants do
				if (plant.growLeft or 0) > 0 and ProfileUtil.tileOf(profile, plant.uid) then
					plant.growLeft -= 1
					if plant.growLeft <= 0 then
						plant.growLeft = 0
						local def = PlantData.Plants[plant.id]
						Net.announce(player, (def and def.name or "A plant") .. " finished growing.")
						if profile.quest == 3 then
							profile.quest = 4
						end
					end
				end
			end
			local gain = ProfileUtil.incomePerSecond(profile)
			if gain > 0 then
				profile.coins += gain
				if State.phase ~= "Day" then
					profile.nightEarnings += gain
				end
				push(player)
			end
		end
	end
end

function PlayerActions.unstunSweep()
	for player, profile in State.profiles do
		local changed = false
		for _, plant in profile.plants do
			if plant.stunnedUntil > 0 and plant.stunnedUntil <= os.time() then
				local def = PlantData.Plants[plant.id]
				plant.stunnedUntil = 0
				plant.hp = def and def.health or 40
				changed = true
			end
		end
		if changed then
			push(player)
			Net.announce(player, "A stunned plant recovered.")
		end
	end
end

return PlayerActions
