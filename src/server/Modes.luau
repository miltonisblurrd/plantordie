local State = require(script.Parent.State)
local Net = require(script.Parent.Net)
local ProfileUtil = require(script.Parent.ProfileUtil)
local PlantData = require(game.ReplicatedStorage.Shared.PlantData)
local CombatService = require(script.Parent.CombatService)

local Modes = {}

local RAID_RETURN_OFFSET = Vector3.new(0, 6, 500)
local TD_LANE_Z = -430

local function matureCount(profile)
	local count = 0
	for _, plant in profile.plants do
		if (plant.growLeft or 0) <= 0 then
			count += 1
		end
	end
	return count
end

local function teleport(player, cf)
	local character = player.Character
	if character then
		character:PivotTo(cf)
	end
end

local function clearOwned(player, mode)
	for index = #State.monsters, 1, -1 do
		local monster = State.monsters[index]
		if monster.owner == player and monster.mode == mode then
			if monster.part then
				monster.part:Destroy()
			end
			table.remove(State.monsters, index)
		end
	end
end

function Modes.finish(player, won)
	local session = State.sessions[player]
	if not session or session.closing then
		return
	end
	session.closing = true
	clearOwned(player, session.kind)
	local profile = State.profiles[player]
	if profile then
		if won then
			profile.coins += session.rewardCoins
			profile.loot += session.rewardLoot
			profile.gems = (profile.gems or 0) + (session.gems or 0)
			Net.announce(player, "Cleared. +" .. session.rewardCoins .. " coins, +" .. session.rewardLoot .. " loot, +" .. (session.gems or 0) .. " gems")
		else
			Net.announce(player, "The run failed. You kept what you already earned outside it.")
		end
	end
	State.sessions[player] = nil
	local plot = State.byPlayer[player]
	if plot then
		teleport(player, plot.spawn)
	end
	local PlayerActions = require(script.Parent.PlayerActions)
	PlayerActions.push(player)
end

function Modes.advance(player)
	local session = State.sessions[player]
	if not session or session.closing then
		return
	end
	session.wave += 1
	local waves = session.waves
	local wave = waves[session.wave]
	if not wave then
		Modes.finish(player, true)
		return
	end
	session.expected = #wave
	session.killed = 0
	Net.announce(player, session.label .. " wave " .. session.wave)
	task.spawn(function()
		for _, id in wave do
			if State.sessions[player] ~= session then
				return
			end
			local jitter = Vector3.new(math.random(-6, 6), 0, 0)
			CombatService.spawnDirected(id, session.spawn + jitter, session.kind, player, session.goal)
			task.wait(1.2)
		end
	end)
end

function Modes.beginRaid(player)
	if State.phase ~= "Day" then
		Net.announce(player, "Raids open during the day.")
		return
	end
	if State.sessions[player] then
		return
	end
	local profile = State.profiles[player]
	if not profile or matureCount(profile) < 1 then
		Net.announce(player, "Grow at least one plant, then bring it with you.")
		return
	end
	State.sessions[player] = {
		kind = "raid",
		label = "Raid",
		wave = 0,
		remaining = 0,
		baseHp = 140,
		goal = Vector3.new(0, 4, 460),
		spawn = Vector3.new(0, 4, 540),
		rewardCoins = 250,
		rewardLoot = 20,
		gems = 8,
		waves = {
			{ "Shambler", "Shambler", "Shambler", "BrainrotRunner" },
			{ "BrainrotRunner", "BrainrotRunner", "VampireBat", "HollowStalker" },
			{ "RotKing" },
		},
	}
	teleport(player, CFrame.new(RAID_RETURN_OFFSET))
	Modes.advance(player)
end

function Modes.beginBoss(player)
	if State.phase ~= "Day" then
		Net.announce(player, "Boss rush opens during the day.")
		return
	end
	if State.sessions[player] then
		return
	end
	local profile = State.profiles[player]
	if not profile then
		return
	end
	local grown = 0
	for _, plant in profile.plants do
		if (plant.growLeft or 0) <= 0 then
			grown += 1
		end
	end
	if grown < 4 then
		Net.announce(player, "Boss rush needs 4 grown plants.")
		return
	end
	State.sessions[player] = {
		kind = "raid",
		label = "Boss rush",
		wave = 0,
		baseHp = 180,
		goal = Vector3.new(0, 4, 460),
		spawn = Vector3.new(0, 4, 540),
		rewardCoins = 300,
		rewardLoot = 24,
		gems = 15,
		waves = {
			{ "AlienQueen" },
			{ "RotKing", "HollowStalker", "HollowStalker" },
		},
	}
	teleport(player, CFrame.new(0, 6, 500))
	Modes.advance(player)
end

function Modes.beginDefense(player)
	if State.phase ~= "Day" then
		Net.announce(player, "Tower defense opens during the day.")
		return
	end
	if State.sessions[player] then
		return
	end
	local profile = State.profiles[player]
	if not profile then
		return
	end
	local defenders = {}
	local placed = 0
	for _, plant in profile.plants do
		if placed >= 5 then
			break
		end
		if (plant.growLeft or 0) <= 0 and not ProfileUtil.isStunned(plant) then
			placed += 1
			table.insert(defenders, {
				plant = plant,
				position = Vector3.new(0, 3, TD_LANE_Z + placed * 12),
			})
		end
	end
	if #defenders == 0 then
		Net.announce(player, "Grow a plant before starting tower defense.")
		return
	end
	State.sessions[player] = {
		kind = "td",
		label = "Defense",
		wave = 0,
		remaining = 0,
		baseHp = 160,
		goal = Vector3.new(0, 4, -470),
		spawn = Vector3.new(0, 4, -370),
		rewardCoins = 180,
		rewardLoot = 12,
		gems = 5,
		defenders = defenders,
		waves = {
			{ "Shambler", "Shambler", "Shambler", "Shambler" },
			{ "BrainrotRunner", "BrainrotRunner", "Shambler", "VampireBat" },
			{ "HollowStalker", "AlienDrone", "AlienDrone" },
		},
	}
	for _, entry in defenders do
		local def = PlantData.Plants[entry.plant.id]
		local marker = Instance.new("Part")
		marker.Name = def and def.name or "Plant"
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(3, 3, 3)
		marker.Anchored = true
		marker.CanCollide = false
		marker.Color = def and def.color or Color3.new(0, 1, 0)
		marker.CFrame = CFrame.new(entry.position)
		marker.Parent = workspace.World
		entry.marker = marker
	end
	teleport(player, CFrame.new(0, 6, -450))
	Modes.advance(player)
end

function Modes.noteDeath(monster)
	local session = monster.owner and State.sessions[monster.owner]
	if not session or session.closing or monster.mode ~= session.kind then
		return
	end
	session.killed = (session.killed or 0) + 1
	if session.expected and session.killed >= session.expected and not session.advancing then
		session.advancing = true
		local owner = monster.owner
		task.delay(1.5, function()
			session.advancing = false
			if State.sessions[owner] == session and not session.closing then
				Modes.advance(owner)
			end
		end)
	end
end

function Modes.onBaseHit(player)
	local session = State.sessions[player]
	if not session or session.closing then
		return
	end
	Net.announce(player, session.label .. " core " .. math.max(0, math.floor(session.baseHp)))
	if session.baseHp <= 0 then
		Modes.finish(player, false)
	end
end

function Modes.ejectAll()
	for player, session in State.sessions do
		if session and not session.closing then
			Net.announce(player, "Night is starting. The portal run ended.")
			Modes.finish(player, false)
		end
	end
end

function Modes.cleanupMarkers(player)
	local session = State.sessions[player]
	if not session or not session.defenders then
		return
	end
	for _, entry in session.defenders do
		if entry.marker then
			entry.marker:Destroy()
		end
	end
end

local finishOriginal = Modes.finish
function Modes.finish(player, won)
	Modes.cleanupMarkers(player)
	finishOriginal(player, won)
end

return Modes
