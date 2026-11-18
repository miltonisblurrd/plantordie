--!strict
-- Speed stat -> Humanoid.WalkSpeed. Shared so guardians can scale against the same curve.

local Config = require(script.Parent.Config)

local Speed = {}

Speed.Base = 24
Speed.Bonus = 76 -- reached at Speed.FullAt
Speed.FullAt = 12 -- log10 of speed for the full bonus (1e12)

function Speed.walkSpeedFor(speed: number): number
	local t = math.clamp(math.log10(1 + math.max(0, speed)) / Speed.FullAt, 0, 1)
	return Speed.Base + Speed.Bonus * t
end

-- Hub uses walkSpeedFor. Biomes multiply it by how much speed the treadmill has banked.
function Speed.fieldMultiplier(speed: number): number
	local mult = 1 + Config.Treadmill.FieldLog * math.log10(1 + math.max(0, speed))
	return math.clamp(mult, 1, Config.Treadmill.FieldMax)
end

function Speed.walkSpeedForZone(speed: number, inSafeZone: boolean): number
	local base = Speed.walkSpeedFor(speed)
	if inSafeZone then
		return base
	end
	return base * Speed.fieldMultiplier(speed)
end

-- A player trained to the biome's recommended speed (and not carrying) just outruns it.
function Speed.guardianSpeedFor(recommendedSpeed: number): number
	return Speed.walkSpeedFor(recommendedSpeed) * Config.Guardian.SpeedFactor
end

return Speed
