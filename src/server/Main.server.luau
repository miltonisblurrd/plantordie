local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerActions = require(script.Parent.PlayerActions)
local PlantVisuals = require(script.Parent.PlantVisuals)
local CombatService = require(script.Parent.CombatService)
local DayNightService = require(script.Parent.DayNightService)
local Modes = require(script.Parent.Modes)
local ReceiptService = require(script.Parent.ReceiptService)

print("[PLANT or DIE] Server starting")

Net.setup()
local world = MapBuilder.build()
State.plots = world.plots
State.onMonsterKilled = Modes.noteDeath
State.onSessionHit = Modes.onBaseHit

world.raidPortal.RaidPrompt.Triggered:Connect(function(player)
	Modes.beginRaid(player)
end)
world.defensePortal.DefensePrompt.Triggered:Connect(function(player)
	Modes.beginDefense(player)
end)
world.bossPortal.BossPrompt.Triggered:Connect(function(player)
	Modes.beginBoss(player)
end)
ReceiptService.start()

local function assignPlot(player)
	for _, plot in State.plots do
		if plot.owner == nil then
			plot.owner = player
			State.byPlayer[player] = plot
			plot.houseLabel.Text = player.DisplayName
			return plot
		end
	end
	return nil
end

local function spawnAtPlot(player)
	local plot = State.byPlayer[player]
	local character = player.Character
	if plot and character then
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			character:PivotTo(plot.spawn)
		end
	end
end

local function onPlayer(player)
	DataService.load(player)
	ReceiptService.applyPasses(player)
	local plot = assignPlot(player)
	if not plot then
		Net.announce(player, "This server is full. Try another server.")
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		spawnAtPlot(player)
	end)
	if player.Character then
		task.defer(spawnAtPlot, player)
	end
	PlayerActions.push(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	DataService.save(player)
	PlantVisuals.clearPlayer(player)
	local plot = State.byPlayer[player]
	if plot then
		plot.owner = nil
		plot.houseLabel.Text = "Empty plot"
		plot.hpLabel.Text = ""
	end
	State.byPlayer[player] = nil
	State.profiles[player] = nil
end)

game:BindToClose(function()
	DataService.saveAll()
	task.wait(1)
end)

State.remotes.Roll.OnServerInvoke = function(player)
	return PlayerActions.roll(player)
end

State.remotes.Action.OnServerEvent:Connect(function(player, action, a, b)
	if type(action) ~= "string" then
		return
	end
	PlayerActions.handle(player, action, a, b)
end)

task.spawn(function()
	while true do
		task.wait(Config.IncomeInterval)
		PlayerActions.tickIncome()
		PlayerActions.unstunSweep()
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		DataService.saveAll()
	end
end)

task.spawn(function()
	while true do
		task.wait(4)
		CombatService.spawnWorld()
	end
end)

local function grownCount(player)
	local profile = State.profiles[player]
	local count = 0
	if profile then
		for _, plant in profile.plants do
			if (plant.growLeft or 0) <= 0 then
				count += 1
			end
		end
	end
	return count
end

RunService.Heartbeat:Connect(function(dt)
	for player in State.profiles do
		if player.Parent then
			PlantVisuals.sync(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and not State.sessions[player] then
				local pos = root.Position
				local blocked = nil
				local back = nil
				if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(280, 0, 180)).Magnitude < 62 and grownCount(player) < 2 then
					blocked = "Vampire Hollow needs 2 grown plants."
					back = CFrame.new(150, 5, 180)
				elseif (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(-280, 0, 180)).Magnitude < 62 and grownCount(player) < 4 then
					blocked = "Alien Crater needs 4 grown plants."
					back = CFrame.new(-150, 5, 180)
				end
				local profile = State.profiles[player]
				if profile and profile.quest == 4 and pos.Z > 130 and math.abs(pos.X) < 90 then
					profile.quest = 5
					Net.announce(player, "Meadow reached. Go home before night.")
					PlayerActions.push(player)
				end
				if blocked and (player:GetAttribute("GateAt") or 0) + 2 < os.clock() then
					player:SetAttribute("GateAt", os.clock())
					player.Character:PivotTo(back)
					Net.announce(player, blocked)
				end
			end
		end
	end
	CombatService.step(dt)
end)

task.spawn(function()
	while true do
		task.wait(30)
		local lines = {}
		for _, entry in DataService.topCoins() do
			local name = "Player"
			pcall(function()
				name = Players:GetNameFromUserIdAsync(tonumber(entry.key))
			end)
			table.insert(lines, name .. "  " .. tostring(entry.value))
		end
		if world.leaderboard then
			world.leaderboard.Text = #lines > 0 and table.concat(lines, "\n") or "Ranks appear after the first save"
		end
	end
end)

DayNightService.start()
print("[PLANT or DIE] Ready. Debug cycle:", Config.Debug)
