--!strict
-- The one shared Safe Zone: an axis-aligned box over the hub plaza and the whole plot row, with
-- its front edge on a line across the full home entrance. Every guardian, the bat and the HUD
-- read this module; no biome has a safe area of its own.

local Config = require(script.Parent.Config)

local W = Config.World
local P = Config.Plot
local S = Config.SafeZone

local MIN_Y, MAX_Y = -20, 120

local SafeZone = {}

local halfRow = (W.PlotCount * (P.Width + W.PlotGap) - W.PlotGap) / 2
local hubZ = -70

SafeZone.MinX = -halfRow - S.SideMargin
SafeZone.MaxX = halfRow + S.SideMargin
SafeZone.MinZ = math.min(hubZ - W.HubRadius, -P.Depth / 2) - S.BackMargin
SafeZone.MaxZ = P.Depth / 2 + S.FrontInset

assert(SafeZone.MaxZ < P.Depth / 2 + Config.Biome.FrontGap, "Safe Zone must end before biome 1")

function SafeZone.bounds(): (number, number, number, number)
	return SafeZone.MinX, SafeZone.MaxX, SafeZone.MinZ, SafeZone.MaxZ
end

function SafeZone.contains(pos: Vector3): boolean
	return pos.X >= SafeZone.MinX and pos.X <= SafeZone.MaxX
		and pos.Z >= SafeZone.MinZ and pos.Z <= SafeZone.MaxZ
		and pos.Y > MIN_Y and pos.Y < MAX_Y
end

-- Nearest point just outside the box (Clearance studs past the closest edge).
function SafeZone.pushOut(pos: Vector3): Vector3
	if not SafeZone.contains(pos) then
		return pos
	end
	local c = S.Clearance
	local options = {
		{ pos.X - SafeZone.MinX, Vector3.new(SafeZone.MinX - c, pos.Y, pos.Z) },
		{ SafeZone.MaxX - pos.X, Vector3.new(SafeZone.MaxX + c, pos.Y, pos.Z) },
		{ pos.Z - SafeZone.MinZ, Vector3.new(pos.X, pos.Y, SafeZone.MinZ - c) },
		{ SafeZone.MaxZ - pos.Z, Vector3.new(pos.X, pos.Y, SafeZone.MaxZ + c) },
	}
	local best = options[1]
	for i = 2, #options do
		if options[i][1] < best[1] then
			best = options[i]
		end
	end
	return best[2]
end

-- Clamps a move from `from` toward `to` so it never ends inside the box. A mover already inside
-- is pushed straight out.
function SafeZone.keepOut(from: Vector3, to: Vector3): Vector3
	if not SafeZone.contains(to) then
		return to
	end
	if SafeZone.contains(from) then
		return SafeZone.pushOut(from)
	end
	local c = S.Clearance
	local x, z = to.X, to.Z
	if from.Z > SafeZone.MaxZ then
		z = SafeZone.MaxZ + c
	elseif from.Z < SafeZone.MinZ then
		z = SafeZone.MinZ - c
	elseif from.X > SafeZone.MaxX then
		x = SafeZone.MaxX + c
	else
		x = SafeZone.MinX - c
	end
	return Vector3.new(x, to.Y, z)
end

return SafeZone
