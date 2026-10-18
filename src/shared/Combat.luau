--!strict
-- Night combat stats for one planted record. Pure data, so the server and the harness agree.
-- Size and variant make a plant tougher and hit harder, but far less than they raise income.

local Config = require(script.Parent.Config)
local Plants = require(script.Parent.Plants)
local Sizes = require(script.Parent.Sizes)

export type Role = "Projectile" | "Rapid" | "AoE" | "Slow" | "Burn" | "Wall" | "Income"

export type PlantStats = {
	role: Role,
	damage: number, -- per attack
	rate: number, -- attacks/sec
	range: number, -- studs (lane distance ahead, or splash radius for AoE)
	hp: number,
	ability: string?,
}

local VARIANT_POWER: { [string]: number } = { Normal = 1, Neon = 1.5, Mega = 2.5 }

local Combat = {
	SlowFactor = 0.5,
	SlowSeconds = 2,
	BurnSeconds = 3,
	FreezeOnHitSeconds = 1.5, -- walls with the Freeze ability
}

function Combat.plantStats(species: string, size: string, variant: string): PlantStats?
	local def = Plants.ById[species]
	local c = def and def.Combat
	if not c then
		return nil
	end
	local s = Sizes.ById[size]
	local power = (if s then s.VisualScale else 1) * (VARIANT_POWER[variant] or 1)
	return {
		role = c.Role,
		damage = c.Damage * power,
		rate = c.AttackRate,
		range = c.Range * Config.Plot.TileSize,
		hp = math.floor(c.Hp * power),
		ability = c.Ability,
	}
end

return Combat
