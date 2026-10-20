--!strict
-- Treadmill levels. Levels[L].Cost is the price to go from L - 1 to L (level 1 is free).
-- Trail multipliers live in Shared.Trails.

local Trails = require(script.Parent.Trails)

export type Level = { Level: number, SpeedPerSec: number, Cost: number }

local MAX_LEVEL = 30

local levels: { Level } = {}
for l = 1, MAX_LEVEL do
	levels[l] = {
		Level = l,
		SpeedPerSec = math.round(1.9 ^ (l - 1)),
		Cost = if l == 1 then 0 else math.round(100 * 2.3 ^ (l - 1)),
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
function Treadmill.gain(level: number, trailId: string?, speedBonus: number): number
	return Treadmill.speedPerSec(level) * Treadmill.multiplierFor(trailId) * (1 + math.max(0, speedBonus))
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
