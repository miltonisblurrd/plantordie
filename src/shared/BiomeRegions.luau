--!strict
-- Biome placement and region bounds from Config alone, so server and client agree on where
-- each biome is. Biomes sit in a line in front of the plot row (+Z); -Z faces the plots.

local Config = require(script.Parent.Config)
local BiomeData = require(script.Parent.Biomes)

local W = Config.World
local B = Config.Biome
local P = Config.Plot

local HALF = B.Size / 2 + 1
local MIN_Y, MAX_Y = -20, 120

local BiomeRegions = {}

-- Front edge of the plot row (world +Z).
function BiomeRegions.plotFrontZ(): number
	return P.Depth / 2
end

function BiomeRegions.centerZ(biomeIndex: number): number
	local step = B.Size + B.Gap
	return BiomeRegions.plotFrontZ() + B.FrontGap + B.Size / 2 + (biomeIndex - 1) * step
end

function BiomeRegions.cframe(biomeIndex: number): CFrame
	local pos = Vector3.new(0, W.GroundY, BiomeRegions.centerZ(biomeIndex))
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

BiomeRegions.HalfSize = HALF

local cframes: { [string]: CFrame } = {}
for _, b in BiomeData.List do
	cframes[b.Id] = BiomeRegions.cframe(b.Index)
end

function BiomeRegions.cframeOf(biomeId: string): CFrame?
	return cframes[biomeId]
end

-- Studs inside the nearest edge; negative when outside. Y band counts as an edge too.
function BiomeRegions.distanceInside(biomeId: string, pos: Vector3): number
	local cf = cframes[biomeId]
	if not cf then
		return -math.huge
	end
	local lp = cf:PointToObjectSpace(pos)
	return math.min(HALF - math.abs(lp.X), HALF - math.abs(lp.Z), lp.Y - MIN_Y, MAX_Y - lp.Y)
end

function BiomeRegions.inRegion(biomeId: string, pos: Vector3): boolean
	local cf = cframes[biomeId]
	if not cf then
		return false
	end
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) <= HALF and math.abs(lp.Z) <= HALF and lp.Y > MIN_Y and lp.Y < MAX_Y
end

function BiomeRegions.regionOf(pos: Vector3): string?
	for _, b in BiomeData.List do
		if BiomeRegions.inRegion(b.Id, pos) then
			return b.Id
		end
	end
	return nil
end

return BiomeRegions
