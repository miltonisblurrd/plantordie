--!strict
-- Server entry point. Order matters: remotes exist before anything listens; the world exists
-- before profiles load (plots are assigned on load); Data starts last among the stateful services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(script.Parent.Net)
local Data = require(script.Parent.Data)
local Plots = require(script.Parent.Plots)
local Biomes = require(script.Parent.Biomes)
local DayNight = require(script.Parent.DayNight)
local Sync = require(script.Parent.Sync)
local Garden = require(script.Parent.Garden)
local Shop = require(script.Parent.Shop)
local Hub = require(script.Parent.World.Builders.Hub)

Net.setProfileGate(Data.isLoaded)

local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace

Hub.build(world)
Biomes.start(world)
Plots.start(world)
Sync.start()
Sync.setIncomeProvider(Garden.incomeOf)
Garden.start()
Shop.start()
DayNight.start()

Data.onLoaded(function(player)
	DayNight.sendTo(player)
	if Data.mode() == "Memory" then
		Net.notify(player, "Studio test mode: progress is NOT saved.", "warn")
	end
end)

Data.start()

ReplicatedStorage:SetAttribute("ServerReady", true)
print(`[Boot] PLANT OR DIE server ready ({Data.mode()} profiles, {#Players:GetPlayers()} players)`)
