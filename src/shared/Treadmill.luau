--!strict
-- Treadmill levels. Levels[L].Cost is the price to go from L - 1 to L (level 1 is free).
-- Trail multipliers live in Shared.Trails.

local Trails = require(script.Parent.Trails)

export type Level = { Level: number, SpeedPerSec: number, Cost: number }

-- Two segments (pacing in studio/tasks/balance-pass/pacing.md). Levels 1..CURVE_BREAK pace
-- biomes 1-13; the levels above it are the cosmic tier, where speed/s climbs far faster than price
-- because Cosmic Garden asks for 2000x Ancient Wilds' recommended speed.
local MAX_LEVEL = 60
local CURVE_BREAK = 50
local RATE_LOW, RATE_HIGH = 1.35, 2.3
local COST_BASE, COST_LOW, COST_HIGH = 100, 1.52, 1.05

local levels: { Level } = {}
for l = 1, MAX_LEVEL do
	local low, high = math.min(l, CURVE_BREAK) - 1, math.max(0, l - CURVE_BREAK)
	local prev = levels[l - 1]
	levels[l] = {
		Level = l,
		SpeedPerSec = math.max(if prev then prev.SpeedPerSec + 1 else 1, math.round(RATE_LOW ^ low * RATE_HIGH ^ high)),
		Cost = if l == 1 then 0 else math.round(COST_BASE * COST_LOW ^ low * COST_HIGH ^ high),
	}
end

local Treadmill = {
	Levels = levels,
	MaxLevel = MAX_LEVEL,
}

function Treadmill.speedPerSec(level: number): number
	local l = levels[math.clamp(math.floor(level), 1, MAX_LEVEL)]
	return l.SpeedPerSec
end

-- Speed earned per tick on the belt. speedBonus comes from claimed biome indexes (0.10 each).
function Treadmill.gain(level: number, trailId: string?, speedBonus: number, speedMult: number?): number
	return Treadmill.speedPerSec(level) * Treadmill.multiplierFor(trailId) * (1 + math.max(0, speedBonus)) * (speedMult or 1)
end

-- Price of the next level, or nil at max.
function Treadmill.nextCost(level: number): number?
	local l = levels[level + 1]
	return if l then l.Cost else nil
end

function Treadmill.multiplierFor(equippedId: string?): number
	local t = equippedId and Trails.ById[equippedId]
	return if t then t.Multiplier else 1
end

return Treadmill
