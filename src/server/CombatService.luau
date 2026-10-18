local Players = game:GetService("Players")

local MonsterData = require(game.ReplicatedStorage.Shared.MonsterData)
local PlantData = require(game.ReplicatedStorage.Shared.PlantData)
local Config = require(game.ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local ProfileUtil = require(script.Parent.ProfileUtil)
local PlantVisuals = require(script.Parent.PlantVisuals)
local PlayerActions = require(script.Parent.PlayerActions)
local Net = require(script.Parent.Net)

local CombatService = {}

local function hpBar(part, name, hp, color)
	part.Color = color
	local gui = part:FindFirstChild("Hp")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Hp"
		gui.Size = UDim2.fromOffset(80, 36)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		gui.Parent = part
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextStrokeTransparency = 0.4
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Parent = gui
	end
	local text = gui:FindFirstChild("Text")
	if text then
		text.Text = name .. " " .. math.ceil(hp)
	end
end

local function spawnMonster(defId, position, mode, plot, owner)
	local def = MonsterData[defId]
	local part = Instance.new("Part")
	part.Name = def.name
	part.Size = def.flying and Vector3.new(3, 1.2, 3) or Vector3.new(3, 5, 3)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(position)
	part.Parent = workspace.World
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = def.flying and Vector3.new(2.2, 0.8, 2.2) or Vector3.new(2, 2, 2)
	head.Color = def.color:Lerp(Color3.new(0, 0, 0), 0.35)
	head.Anchored = false
	head.CanCollide = false
	head.CFrame = part.CFrame * CFrame.new(0, 2, 0)
	head.Parent = part
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = head
	weld.Parent = head
	local monster = {
		part = part,
		def = def,
		hp = def.health,
		mode = mode,
		plot = plot,
		owner = owner,
		slowUntil = 0,
		nextHit = 0,
	}
	hpBar(part, def.name, monster.hp, def.color)
	table.insert(State.monsters, monster)
	return monster
end

local Biomes = {
	{ id = "meadow", center = Vector3.new(0, 4, 180), pool = { "Shambler", "BrainrotRunner" }, cap = 6 },
	{ id = "hollow", center = Vector3.new(280, 4, 180), pool = { "VampireBat", "HollowStalker" }, cap = 5 },
	{ id = "crater", center = Vector3.new(-280, 4, 180), pool = { "AlienDrone", "Shambler" }, cap = 5 },
}

function CombatService.spawnWorld()
	if State.phase ~= "Day" then
		return
	end
	for _, biome in Biomes do
		local count = 0
		for _, monster in State.monsters do
			if monster.biome == biome.id then
				count += 1
			end
		end
		if count < biome.cap then
			local id = biome.pool[math.random(1, #biome.pool)]
			local pos = biome.center + Vector3.new(math.random(-36, 36), 0, math.random(-36, 36))
			local monster = spawnMonster(id, pos, "meadow", nil, nil)
			monster.biome = biome.id
		end
	end
end

function CombatService.spawnDirected(defId, position, mode, owner, goal)
	local monster = spawnMonster(defId, position, mode, nil, owner)
	monster.goal = goal
	return monster
end

function CombatService.startNight(plot, player, nightCount)
	local list = {}
	local n = 3 + nightCount
	for i = 1, n do
		table.insert(list, "Shambler")
	end
	if nightCount >= 2 then
		for i = 1, nightCount do
			table.insert(list, "BrainrotRunner")
		end
	end
	if nightCount >= 3 then
		table.insert(list, "VampireBat")
	end
	task.spawn(function()
		for _, id in list do
			if State.phase == "Day" or State.byPlayer[player] ~= plot then
				return
			end
			local profile = State.profiles[player]
			if not profile or profile.houseDown then
				return
			end
			spawnMonster(id, plot.monsterSpawn + Vector3.new(math.random(-4, 4), 0, 0), "night", plot, player)
			task.wait(1.6)
		end
	end)
end

function CombatService.clearMode(mode)
	for i = #State.monsters, 1, -1 do
		local monster = State.monsters[i]
		if monster.mode == mode then
			monster.part:Destroy()
			table.remove(State.monsters, i)
		end
	end
end

local function killMonster(index, attacker)
	local monster = State.monsters[index]
	if not monster then
		return
	end
	local rewardPlayer = attacker or monster.owner
	if rewardPlayer and rewardPlayer.Parent and monster.mode ~= "raid" and monster.mode ~= "td" then
		PlayerActions.grant(rewardPlayer, monster.def.coins, monster.def.loot)
		Net.announce(rewardPlayer, "+" .. monster.def.coins .. " coins, +" .. monster.def.loot .. " loot")
	end
	if State.onMonsterKilled then
		State.onMonsterKilled(monster)
	end
	monster.part:Destroy()
	table.remove(State.monsters, index)
end

local function damagePlant(plant, amount, player)
	plant.hp -= amount
	if plant.hp <= 0 then
		plant.hp = 0
		plant.stunnedUntil = os.time() + Config.StunSeconds
		Net.announce(player, PlantData.Plants[plant.id].name .. " was stunned for " .. Config.StunSeconds .. "s")
		PlayerActions.push(player)
	else
		PlantVisuals.refresh(plant)
	end
end

local function defenders(player, profile, plot)
	local list = {}
	for index, uid in profile.tiles do
		local tileIndex = tonumber(index)
		if tileIndex == 5 and profile.houseLevel < Config.FifthTileHouseLevel then
			continue
		end
		local plant = ProfileUtil.findPlant(profile, uid)
		local tile = plot.tiles[tileIndex]
		if plant and tile and not ProfileUtil.isStunned(plant) and plant.hp > 0 and (plant.growLeft or 0) <= 0 then
			table.insert(list, {
				plant = plant,
				position = tile.Position,
				tileIndex = tileIndex,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.tileIndex > b.tileIndex
	end)
	return list
end

local function followerDefs(player, profile)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return {}
	end
	local list = {}
	for _, uid in profile.followers do
		local plant = ProfileUtil.findPlant(profile, uid)
		local model = PlantVisuals.models[uid]
		if plant and model and model.PrimaryPart and not ProfileUtil.isStunned(plant) and plant.hp > 0 and (plant.growLeft or 0) <= 0 then
			table.insert(list, { plant = plant, position = model.PrimaryPart.Position, owner = player })
		end
	end
	return list
end

local function attack(fromPos, def, monster)
	Net.vfx({
		kind = "shot",
		attack = def.attack,
		from = fromPos,
		to = monster.part.Position,
		color = def.color,
	})
	Net.vfx({
		kind = "damage",
		position = monster.part.Position,
		amount = def.damage,
		color = def.color,
	})
	local damage = def.damage
	if def.slow then
		monster.slowUntil = os.clock() + 2
	end
	if def.attack == "lightning" then
		monster.hp -= damage
		return
	end
	monster.hp -= damage
end

function CombatService.step(dt)
	local now = os.clock()
	for index = #State.monsters, 1, -1 do
		local monster = State.monsters[index]
		if not monster.part.Parent then
			table.remove(State.monsters, index)
			continue
		end
		local speed = monster.def.speed
		if monster.slowUntil > now then
			speed *= 0.45
		end
		local pos = monster.part.Position
		if monster.mode == "meadow" then
			local nearest, nearestDist = nil, 80
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - pos).Magnitude
					if dist < nearestDist and root.Position.Z > 100 then
						nearest = root
						nearestDist = dist
					end
				end
			end
			local goal
			if nearest then
				goal = nearest.Position
			else
				goal = pos + Vector3.new(math.sin(now + index), 0, math.cos(now * 0.7 + index))
			end
			local flat = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
			if flat.Magnitude > 0.1 then
				monster.part.CFrame = CFrame.new(pos + flat.Unit * math.min(speed * dt, flat.Magnitude))
			end
		elseif monster.mode == "night" then
			local plot = monster.plot
			local profile = monster.owner and State.profiles[monster.owner]
			if not plot or not profile or profile.houseDown or State.phase == "Day" then
				monster.part:Destroy()
				table.remove(State.monsters, index)
				continue
			end
			local housePos = plot.house.Position
			local flat = Vector3.new(housePos.X - pos.X, 0, housePos.Z - pos.Z)
			local step = math.min(speed * dt, flat.Magnitude)
			if flat.Magnitude > 0.1 then
				local moved = pos + flat.Unit * step
				local height = monster.def.flying and 8 or 3
				monster.part.CFrame = CFrame.new(moved.X, height, moved.Z)
			end
			local plants = defenders(monster.owner, profile, plot)
			if monster.def.flying and #plants > 0 then
				table.remove(plants, 1)
			end
			local victim = nil
			local victimDist = 7
			for _, entry in plants do
				local dist = (entry.position - monster.part.Position).Magnitude
				if dist < victimDist then
					victim = entry
					victimDist = dist
				end
			end
			if victim and monster.nextHit <= now then
				monster.nextHit = now + 1
				damagePlant(victim.plant, monster.def.damage, monster.owner)
			end
			if (Vector3.new(housePos.X, 0, housePos.Z) - Vector3.new(monster.part.Position.X, 0, monster.part.Position.Z)).Magnitude < 9 then
				profile.houseHp -= monster.def.damage
				monster.part:Destroy()
				table.remove(State.monsters, index)
				PlayerActions.push(monster.owner)
				if profile.houseHp <= 0 then
					profile.houseHp = 0
					profile.houseDown = true
					local loss = math.floor(profile.nightEarnings / 2)
					profile.coins = math.max(0, profile.coins - loss)
					profile.nightEarnings = 0
					Net.announce(monster.owner, "Your house fell. Lost " .. loss .. " coins from tonight.")
					PlayerActions.push(monster.owner)
				end
				continue
			end
		elseif monster.mode == "raid" or monster.mode == "td" then
			local goal = monster.goal
			local session = monster.owner and State.sessions[monster.owner]
			if not goal or not session then
				monster.part:Destroy()
				table.remove(State.monsters, index)
				continue
			end
			local flat = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
			if flat.Magnitude > 0.1 then
				local moved = pos + flat.Unit * math.min(speed * dt, flat.Magnitude)
				local height = monster.def.flying and 8 or 3
				monster.part.CFrame = CFrame.new(moved.X, height, moved.Z)
			end
			if flat.Magnitude < 8 then
				session.baseHp -= monster.def.damage
				if State.onMonsterKilled then
					State.onMonsterKilled(monster)
				end
				monster.part:Destroy()
				table.remove(State.monsters, index)
				if State.onSessionHit then
					State.onSessionHit(monster.owner)
				end
				continue
			end
		end

		if monster.hp > 0 and monster.part.Parent then
			hpBar(monster.part, monster.def.name, monster.hp, monster.def.color)
		end
	end

	local function consider(def, from, owner)
		local best, bestDist, bestIndex
		for i, monster in State.monsters do
			if monster.part.Parent then
				local dist = (monster.part.Position - from).Magnitude
				if dist <= def.range and (not bestDist or dist < bestDist) then
					if monster.mode == "night" and monster.owner ~= owner then
						continue
					end
					best = monster
					bestDist = dist
					bestIndex = i
				end
			end
		end
		if best then
			best.credit = owner
			attack(from, def, best)
		end
	end

	for player, profile in State.profiles do
		local plot = State.byPlayer[player]
		if plot and not profile.houseDown then
			for _, entry in defenders(player, profile, plot) do
				local def = PlantData.Plants[entry.plant.id]
				entry.plant.nextShot = entry.plant.nextShot or 0
				if def and entry.plant.nextShot <= now then
					entry.plant.nextShot = now + def.cooldown
					consider(def, entry.position + Vector3.new(0, 2, 0), player)
				end
			end
		end
		for _, entry in followerDefs(player, profile) do
			local def = PlantData.Plants[entry.plant.id]
			entry.plant.nextShot = entry.plant.nextShot or 0
			if def and entry.plant.nextShot <= now then
				entry.plant.nextShot = now + def.cooldown
				consider(def, entry.position, player)
			end
		end
		local session = State.sessions[player]
		if session and session.defenders then
			for _, entry in session.defenders do
				local def = PlantData.Plants[entry.plant.id]
				entry.plant.nextShot = entry.plant.nextShot or 0
				if def and entry.plant.nextShot <= now and (entry.plant.growLeft or 0) <= 0 and not ProfileUtil.isStunned(entry.plant) then
					entry.plant.nextShot = now + def.cooldown
					consider(def, entry.position, player)
				end
			end
		end
	end

	for index = #State.monsters, 1, -1 do
		local monster = State.monsters[index]
		if monster.hp <= 0 and monster.part.Parent then
			killMonster(index, monster.credit or monster.owner)
		end
	end
end

return CombatService
