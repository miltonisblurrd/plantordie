local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(game.ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Net = require(script.Parent.Net)
local CombatService = require(script.Parent.CombatService)

local DayNightService = {}

local function setPhase(phase, seconds)
	State.phase = phase
	State.timeLeft = seconds
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("TimeLeft", seconds)
	ReplicatedStorage:SetAttribute("NightCount", State.nightCount)
end

function DayNightService.syncPlayersAtNightStart()
	for player, plot in State.byPlayer do
		local profile = State.profiles[player]
		if profile then
			profile.nightEarnings = 0
			profile.houseDown = false
			profile.houseHp = Config.HouseHealth[profile.houseLevel]
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if profile.quest == 5 and root and (root.Position - plot.spawn.Position).Magnitude < 40 then
				profile.quest = 6
				Net.announce(player, "You made it home. Survive the night.")
			end
			CombatService.startNight(plot, player, State.nightCount)
		end
	end
end

function DayNightService.dawn()
	CombatService.clearMode("night")
	local PlayerActions = require(script.Parent.PlayerActions)
	for player, profile in State.profiles do
		if not profile.houseDown then
			profile.gems = (profile.gems or 0) + 2
		end
		profile.houseDown = false
		profile.houseHp = Config.HouseHealth[profile.houseLevel]
		profile.nightEarnings = 0
		PlayerActions.push(player)
	end
	Net.announceAll("Dawn. The meadow is open.")
end

function DayNightService.start()
	setPhase("Day", Config.DayLength)
	task.spawn(function()
		while true do
			task.wait(1)
			State.timeLeft -= 1
			ReplicatedStorage:SetAttribute("TimeLeft", math.max(0, State.timeLeft))
			if State.timeLeft > 0 then
				continue
			end
			if State.phase == "Day" then
				setPhase("Warning", Config.WarningLength)
				require(script.Parent.Modes).ejectAll()
				Net.announceAll("Night is coming. Get back to your house.")
			elseif State.phase == "Warning" then
				State.nightCount += 1
				setPhase("Night", Config.NightLength)
				CombatService.clearMode("meadow")
				Net.announceAll("Night " .. State.nightCount .. ". Monsters are attacking the houses.")
				DayNightService.syncPlayersAtNightStart()
			else
				DayNightService.dawn()
				setPhase("Day", Config.DayLength)
			end
		end
	end)

	task.spawn(function()
		while true do
			local phase = State.phase
			local clock = phase == "Night" and 0 or (phase == "Warning" and 18.2 or 14)
			Lighting.ClockTime = clock
			if phase == "Night" then
				Lighting.Ambient = Color3.fromRGB(40, 20, 70)
				Lighting.OutdoorAmbient = Color3.fromRGB(50, 30, 90)
				Lighting.Brightness = 1
				Lighting.FogColor = Color3.fromRGB(30, 10, 50)
				Lighting.FogEnd = 280
			elseif phase == "Warning" then
				Lighting.Ambient = Color3.fromRGB(90, 60, 40)
				Lighting.OutdoorAmbient = Color3.fromRGB(120, 70, 40)
				Lighting.Brightness = 1.5
				Lighting.FogEnd = 500
			else
				Lighting.Ambient = Color3.fromRGB(140, 140, 140)
				Lighting.OutdoorAmbient = Color3.fromRGB(170, 170, 170)
				Lighting.Brightness = 2.4
				Lighting.FogColor = Color3.fromRGB(180, 220, 255)
				Lighting.FogEnd = 900
			end
			task.wait(0.5)
		end
	end)
end

return DayNightService
