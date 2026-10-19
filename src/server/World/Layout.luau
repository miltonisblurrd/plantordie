--!strict
-- Plots sit in one tight row. Biomes sit in a line in front of that row (+Z).
-- Walk forward from the plots to biome 1, then the next, and so on.
-- Plot local frame is unchanged: -Z faces the hub (behind the row), zombies enter from +X.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local W = Config.World
local B = Config.Biome
local P = Config.Plot

local Layout = {}

function Layout.plotSpan(): number
	return P.Width + W.PlotGap
end

function Layout.plotCFrame(index: number): CFrame
	local x = (index - (W.PlotCount + 1) / 2) * Layout.plotSpan()
	local pos = Vector3.new(x, W.GroundY, 0)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

function Layout.plotAngle(_index: number): number
	return 0
end

-- Front edge of the plot row (world +Z).
function Layout.plotFrontZ(): number
	return P.Depth / 2
end

function Layout.biomeCenterZ(biomeIndex: number): number
	local step = B.Size + B.Gap
	return Layout.plotFrontZ() + B.FrontGap + B.Size / 2 + (biomeIndex - 1) * step
end

-- Biome centre. -Z faces the plots.
function Layout.biomeCFrame(biomeIndex: number): CFrame
	local pos = Vector3.new(0, W.GroundY, Layout.biomeCenterZ(biomeIndex))
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

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
	local width = Layout.plotSpan() * W.PlotCount + 80
	local depth = Layout.biomeCenterZ(15) + B.Size
	return Vector3.new(width, 0, depth)
end

return Layout
