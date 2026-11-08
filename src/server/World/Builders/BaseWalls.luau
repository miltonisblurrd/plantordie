--!strict
-- The walled home base. The left, right and back sides are raised grass plateaus whose cliff
-- faces are the walls; the front is a wall with one opening onto the trail to biome 1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parent.Parts)
local Layout = require(script.Parent.Parent.Layout)

local W = Config.World

local CLIFF = Color3.fromRGB(214, 118, 108)
local GRASS = Color3.fromRGB(98, 200, 72)
local LEAVES = { Color3.fromRGB(46, 170, 70), Color3.fromRGB(80, 200, 90), Color3.fromRGB(30, 140, 80) }

local PLATEAU = 80 -- studs of raised ground past each wall
local CAP = 2

local BaseWalls = {}

-- Solid cliff block from (x0, z0) to (x1, z1) with a grass top.
local function block(parent: Instance, name: string, x0: number, z0: number, x1: number, z1: number)
	local h = W.BaseWallHeight
	local mid = Vector3.new((x0 + x1) / 2, W.GroundY, (z0 + z1) / 2)
	local size = Vector3.new(math.abs(x1 - x0), 0, math.abs(z1 - z0))
	Parts.make({
		Name = name, Parent = parent, Color = CLIFF, Material = Enum.Material.SmoothPlastic,
		Size = size + Vector3.new(0, h, 0), CFrame = CFrame.new(mid + Vector3.new(0, h / 2, 0)),
	})
	Parts.make({
		Name = name .. "Grass", Parent = parent, Color = GRASS, Material = Enum.Material.Grass,
		Size = size + Vector3.new(0, CAP, 0), CFrame = CFrame.new(mid + Vector3.new(0, h + CAP / 2, 0)),
	})
end

function BaseWalls.build(parent: Instance): Model
	local m = Parts.model("BaseWalls", parent)
	local halfX, backZ, frontZ = Layout.baseBounds()
	local outX, outZ = halfX + PLATEAU, backZ - PLATEAU

	block(m, "WallLeft", -outX, backZ, -halfX, frontZ)
	block(m, "WallRight", halfX, backZ, outX, frontZ)
	block(m, "WallBack", -outX, outZ, outX, backZ)
	local gap = W.BaseOpening / 2
	block(m, "WallFrontLeft", -halfX, frontZ, -gap, frontZ + 4)
	block(m, "WallFrontRight", gap, frontZ, halfX, frontZ + 4)

	local rng = Random.new(11)
	local top = W.GroundY + W.BaseWallHeight + CAP
	local function plant(x: number, z: number)
		local cf = CFrame.new(x, top, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		if rng:NextNumber() < 0.25 then
			Parts.rock(cf, rng:NextNumber(0.9, 1.4), m)
		else
			Parts.tree(cf, rng:NextNumber(1, 1.4), LEAVES[rng:NextInteger(1, #LEAVES)], m)
		end
	end
	for _, side in { -1, 1 } do
		for i = 0, 6 do
			plant(side * (halfX + rng:NextNumber(14, PLATEAU - 14)), frontZ - 16 - i * (frontZ - backZ - 24) / 6)
		end
	end
	for i = 0, 7 do
		plant(-halfX + i * (2 * halfX) / 7, backZ - rng:NextNumber(14, PLATEAU - 14))
	end

	-- Open grass in the back corners, beside the back row and behind the side arms.
	local cornerZ = (backZ + Config.Plot.Depth / 2 - 2 * Config.Plot.Width) / 2
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * (halfX - 24), W.GroundY, cornerZ)
		Parts.tree(cf * CFrame.new(-8, 0, -10), 1.1, LEAVES[1], m)
		Parts.tree(cf * CFrame.new(8, 0, 12), 0.9, LEAVES[2], m)
		Parts.rock(cf * CFrame.new(10, 0, -12), 1, m)
	end

	return m
end

return BaseWalls
