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
local Carry = require(script.Parent.Carry)
local Dig = require(script.Parent.Dig)
local Tools = require(script.Parent.Tools)
local TrailFx = require(script.Parent.TrailFx)
local GuardianAI = require(script.Parent.GuardianAI)
local Defense = require(script.Parent.Defense)
local Fusion = require(script.Parent.Fusion)
local Event = require(script.Parent.Event)
local Purchases = require(script.Parent.Purchases)
local Treadmill = require(script.Parent.Treadmill)
local Index = require(script.Parent.Index)
local Bat = require(script.Parent.Bat)
local Parts = require(script.Parent.World.Parts)
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
Carry.start()
Dig.start()
Tools.start()
TrailFx.start()
GuardianAI.start(world)
Defense.start()
Fusion.start()
Event.start(world)
Purchases.start()
Treadmill.start()
Index.start()
Bat.start()
DayNight.start()

Data.onLoaded(function(player)
	DayNight.sendTo(player)
	if Data.mode() == "Memory" then
		Net.notify(player, "Studio test mode: progress is NOT saved.", "warn")
	end
end)

Data.start()

ReplicatedStorage:SetAttribute("ServerReady", true)
print(`[Boot] PLANT OR DIE server ready ({Data.mode()} profiles, {#Players:GetPlayers()} players, {Parts.count()} world parts, {Dig.count()} dig spots)`)
