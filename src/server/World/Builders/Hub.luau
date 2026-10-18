--!strict
-- Central plaza: bright grass disc, stone ring for the gates, chunky trees, geometric rocks,
-- a fountain, a hub spawn, a world baseplate, and paths out to every plot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parent.Parts)
local Layout = require(script.Parent.Parent.Layout)

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

	local outer = W.PlotRingRadius + Config.Plot.Depth
	Parts.make({
		Name = "Baseplate", Parent = m, Color = Color3.fromRGB(78, 176, 70), Material = Enum.Material.Grass,
		Size = Vector3.new(outer * 2 + 200, 2, outer * 2 + 200), CFrame = CFrame.new(0, W.GroundY - 1.2, 0),
	})
	disc("GateRing", W.GateRingRadius + 14, W.GroundY + 0.1, 1, Color3.fromRGB(196, 186, 168), nil, m)
	disc("Plaza", W.HubRadius, W.GroundY + 0.2, 1, Color3.fromRGB(110, 222, 92), Enum.Material.Grass, m)

	-- Fountain centrepiece.
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
	Parts.surfaceText(title, Enum.NormalId.Front, "PLANT OR DIE", Color3.fromHex("#3FBF4A"))
	Parts.surfaceText(title, Enum.NormalId.Back, "PLANT OR DIE", Color3.fromHex("#3FBF4A"))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, W.GroundY + 0.7, 28)
	spawn.Color = Color3.fromHex("#3FBF4A")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = m

	-- Paths from the gate ring to every plot's front edge.
	local pathLen = W.PlotRingRadius - Config.Plot.Depth / 2 - (W.GateRingRadius + 14) + 2
	local pathMid = W.GateRingRadius + 14 + pathLen / 2 - 1
	for i = 1, W.PlotCount do
		local a = math.rad(Layout.plotAngle(i))
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = dir * pathMid + Vector3.new(0, W.GroundY - 0.05, 0)
		Parts.make({
			Name = "PlotPath", Parent = m, Color = Color3.fromRGB(196, 186, 168),
			Size = Vector3.new(12, 0.3, pathLen), CFrame = CFrame.lookAt(pos, pos + dir),
		})
	end

	-- Deterministic decoration ring between the fountain and the gates.
	local rng = Random.new(7)
	local leafColors = {
		Color3.fromRGB(46, 170, 70), Color3.fromRGB(80, 200, 90), Color3.fromRGB(30, 140, 80),
	}
	for i = 1, 18 do
		local a = (i / 18) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(55, W.HubRadius - 12)
		local cf = CFrame.new(math.cos(a) * r, W.GroundY + 0.2, math.sin(a) * r)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		if i % 3 == 0 then
			Parts.rock(cf, rng:NextNumber(0.8, 1.4), m)
		else
			Parts.tree(cf, rng:NextNumber(0.9, 1.3), leafColors[rng:NextInteger(1, #leafColors)], m)
		end
	end

	return m
end

return Hub
