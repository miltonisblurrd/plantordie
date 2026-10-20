--!strict
-- Speed stat -> Humanoid.WalkSpeed. Shared so guardians can scale against the same curve.

local Config = require(script.Parent.Config)

local Speed = {}

Speed.Base = 16
Speed.Bonus = 24 -- reached at Speed.FullAt
Speed.FullAt = 15 -- log10 of speed for the full bonus (1e15)

function Speed.walkSpeedFor(speed: number): number
	local t = math.clamp(math.log10(1 + math.max(0, speed)) / Speed.FullAt, 0, 1)
	return Speed.Base + Speed.Bonus * t
end

-- A player trained to the biome's recommended speed (and not carrying) just outruns it.
function Speed.guardianSpeedFor(recommendedSpeed: number): number
	return Speed.walkSpeedFor(recommendedSpeed) * Config.Guardian.SpeedFactor
end

return Speed
