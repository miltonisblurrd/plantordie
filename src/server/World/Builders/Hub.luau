--!strict
-- Central plaza: bright grass disc, stone ring for the gates, chunky trees, geometric rocks,
-- a fountain, a hub spawn, a world baseplate, and paths out to every plot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parent.Parts)
local Layout = require(script.Parent.Parent.Layout)
local Machine = require(script.Parent.Machine)

local W = Config.World

local Hub = {}

local function disc(name: string, radius: number, y: number, thickness: number, color: Color3, material: Enum.Material?, parent: Instance): BasePart
	return Parts.make({
		Name = name, Parent = parent, Color = color, Material = material,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(0, y - thickness / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

function Hub.build(parent: Instance): Model
	local m = Parts.model("Hub", parent)

	local extent = Layout.mapExtent()
	Parts.make({
		Name = "Baseplate", Parent = m, Color = Color3.fromRGB(78, 176, 70), Material = Enum.Material.Grass,
		Size = Vector3.new(extent.X, 2, extent.Z + 120),
		CFrame = CFrame.new(0, W.GroundY - 1.2, extent.Z / 2 - 40),
	})
	disc("Plaza", W.HubRadius, W.GroundY + 0.2, 1, Color3.fromRGB(110, 222, 92), Enum.Material.Grass, m)

	-- Fountain centrepiece, behind the plot row.
	disc("FountainBase", 14, W.GroundY + 2.2, 2, Color3.fromRGB(170, 176, 186), nil, m)
	disc("FountainWater", 12, W.GroundY + 2.4, 0.4, Color3.fromRGB(90, 190, 255), Enum.Material.Neon, m)
	Parts.make({
		Name = "FountainPillar", Parent = m, Color = Color3.fromRGB(170, 176, 186),
		Size = Vector3.new(4, 8, 4), CFrame = CFrame.new(0, W.GroundY + 6, 0),
	})
	local title = Parts.make({
		Name = "TitleBoard", Parent = m, Color = Color3.fromHex("#1E2A22"),
		Size = Vector3.new(20, 5, 0.6), CFrame = CFrame.new(0, W.GroundY + 13, 0),
	})
	for _, name in { "Plaza", "FountainBase", "FountainWater", "FountainPillar", "TitleBoard" } do
		local part = m:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.CFrame = part.CFrame + Vector3.new(0, 0, -70)
		end
	end
	Parts.surfaceText(title, Enum.NormalId.Front, "PLANT OR DIE", Color3.fromHex("#3FBF4A"))
	Parts.surfaceText(title, Enum.NormalId.Back, "PLANT OR DIE", Color3.fromHex("#3FBF4A"))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, W.GroundY + 0.7, -70)
	spawn.Color = Color3.fromHex("#3FBF4A")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = m

	-- One shared path from the plaza to the middle of the plot row.
	Parts.make({
		Name = "PlotPath", Parent = m, Color = Color3.fromRGB(196, 186, 168),
		Size = Vector3.new(14, 0.3, 36),
		CFrame = CFrame.new(0, W.GroundY + 0.05, -36),
	})

	-- One Neon maker and one Mega maker for the whole server.
	local Shared = require(script.Parent.Parent.SharedMachines)
	Shared.set("Neon", Machine.build("Neon", 0, CFrame.new(-22, W.GroundY, -70), m))
	Shared.set("Mega", Machine.build("Mega", 0, CFrame.new(22, W.GroundY, -70), m))
	for _, machine in Shared.all() do
		machine:SetAttribute("Shared", true)
	end

	local rng = Random.new(7)
	local leafColors = {
		Color3.fromRGB(46, 170, 70), Color3.fromRGB(80, 200, 90), Color3.fromRGB(30, 140, 80),
	}
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		local r = rng:NextNumber(18, 34)
		local cf = CFrame.new(math.cos(a) * r, W.GroundY + 0.2, -70 + math.sin(a) * r)
		if i % 3 == 0 then
			Parts.rock(cf, rng:NextNumber(0.8, 1.2), m)
		else
			Parts.tree(cf, rng:NextNumber(0.8, 1.1), leafColors[(i % #leafColors) + 1], m)
		end
	end

	return m
end

return Hub
