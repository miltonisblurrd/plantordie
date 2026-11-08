--!strict
-- Plots sit in a walled U around the hub. Biomes sit in a line in front of the base (+Z).
-- Walk forward out of the base to biome 1, then the next, and so on.
-- Plot local frame is unchanged: -Z faces the hub, zombies enter from +X.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BiomeRegions = require(ReplicatedStorage.Shared.BiomeRegions)

local W = Config.World
local B = Config.Biome
local P = Config.Plot

local Layout = {}

function Layout.plotSpan(): number
	return P.Width + W.PlotGap
end

-- Plots form a U around the hub: 1-2 on the left arm (front to back), 3-4 across the back,
-- 5-6 on the right arm (back to front). Plots touch; the open end faces biome 1 (+Z).
local FRONT_Z = P.Depth / 2
local ARM_X = W.ArmInnerX + P.Depth / 2
local BACK_ROW_Z = FRONT_Z - 2 * P.Width - P.Depth / 2

local PLOT_SPOTS: { { pos: Vector3, look: Vector3 } } = {
	{ pos = Vector3.new(-ARM_X, 0, FRONT_Z - P.Width / 2), look = Vector3.new(1, 0, 0) },
	{ pos = Vector3.new(-ARM_X, 0, FRONT_Z - P.Width * 1.5), look = Vector3.new(1, 0, 0) },
	{ pos = Vector3.new(-P.Width / 2, 0, BACK_ROW_Z), look = Vector3.new(0, 0, 1) },
	{ pos = Vector3.new(P.Width / 2, 0, BACK_ROW_Z), look = Vector3.new(0, 0, 1) },
	{ pos = Vector3.new(ARM_X, 0, FRONT_Z - P.Width * 1.5), look = Vector3.new(-1, 0, 0) },
	{ pos = Vector3.new(ARM_X, 0, FRONT_Z - P.Width / 2), look = Vector3.new(-1, 0, 0) },
}
assert(#PLOT_SPOTS == W.PlotCount, "Layout has one spot per plot")

function Layout.plotCFrame(index: number): CFrame
	local spot = PLOT_SPOTS[index]
	local pos = spot.pos + Vector3.new(0, W.GroundY, 0)
	return CFrame.lookAt(pos, pos + spot.look)
end

-- Inside faces of the base walls: X in [-halfX, halfX], Z in [backZ, frontZ].
function Layout.baseBounds(): (number, number, number)
	return W.ArmInnerX + P.Depth + W.BaseBackGap, FRONT_Z - 2 * P.Width - P.Depth - W.BaseBackGap, W.BaseFrontZ
end

function Layout.plotAngle(_index: number): number
	return 0
end

-- Front edge of the plot row (world +Z).
Layout.plotFrontZ = BiomeRegions.plotFrontZ
Layout.biomeCenterZ = BiomeRegions.centerZ
-- Biome centre. -Z faces the plots.
Layout.biomeCFrame = BiomeRegions.cframe

function Layout.biomeAngle(_biomeIndex: number): number
	return 90
end

function Layout.gateAngle(biomeIndex: number): number
	return biomeIndex
end

function Layout.gapAngle(biomeIndex: number): number
	return biomeIndex
end

-- Gate sits just in front of the biome entrance, facing further into the line.
function Layout.gateCFrame(biomeIndex: number): CFrame
	local entranceZ = Layout.biomeCenterZ(biomeIndex) - B.Size / 2 - 6
	local pos = Vector3.new(0, W.GroundY, entranceZ)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
end

function Layout.biomePath(biomeIndex: number): { Vector3 }
	local fromZ = if biomeIndex == 1
		then Layout.plotFrontZ() + 6
		else Layout.biomeCenterZ(biomeIndex - 1) + B.Size / 2
	local toZ = Layout.biomeCenterZ(biomeIndex) - B.Size / 2
	return {
		Vector3.new(0, W.GroundY, fromZ),
		Vector3.new(0, W.GroundY, toZ),
	}
end

function Layout.mapExtent(): Vector3
	local width = (W.ArmInnerX + P.Depth + W.BaseBackGap) * 2 + 200
	local depth = Layout.biomeCenterZ(15) + B.Size
	return Vector3.new(width, 0, depth)
end

return Layout
