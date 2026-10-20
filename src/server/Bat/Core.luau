--!strict
-- Bat hit rules with no Roblox calls so the harness can drive them. Positions are root
-- positions; safe/alive/los flags are computed by the caller from the server's view.

export type Rules = {
	Cooldown: number,
	Range: number,
	ConeDot: number,
	KnockH: number,
	KnockUp: number,
	MaxVel: number,
}
export type Attacker = {
	pos: Vector3,
	look: Vector3,
	alive: boolean,
	safe: boolean,
	lastSwing: number,
}
export type Target = {
	key: any,
	pos: Vector3,
	alive: boolean,
	safe: boolean,
	los: boolean,
}

local Core = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Refusals that happen before any target is considered; nil when the swing may proceed.
-- "cooldown" refusals must not restart the cooldown; every other swing does.
function Core.swingRefusal(a: Attacker, now: number, rules: Rules): string?
	if not a.alive then
		return "dead"
	end
	if now - a.lastSwing < rules.Cooldown then
		return "cooldown"
	end
	if a.safe then
		return "safe"
	end
	return nil
end

-- Nearest valid target, or nil and the best reason the closest candidate was refused.
function Core.pick(a: Attacker, targets: { Target }, now: number, rules: Rules): (Target?, string?)
	local refusal = Core.swingRefusal(a, now, rules)
	if refusal then
		return nil, refusal
	end
	local look = flat(a.look)
	look = if look.Magnitude > 1e-6 then look.Unit else Vector3.new(0, 0, -1)
	local best: Target? = nil
	local bestD = math.huge
	local why = "range"
	for _, t in targets do
		local d = (t.pos - a.pos).Magnitude
		if d > rules.Range or d >= bestD then
			continue
		end
		local dir = flat(t.pos - a.pos)
		local dot = if dir.Magnitude > 1e-6 then look.X * dir.Unit.X + look.Z * dir.Unit.Z else 1
		if not t.alive then
			why = "dead"
		elseif dot <= rules.ConeDot then
			why = "cone"
		elseif t.safe then
			why = "target safe"
		elseif not t.los then
			why = "los"
		else
			best, bestD = t, d
		end
	end
	if best then
		return best, nil
	end
	return nil, why
end

-- Victim velocity: away from the attacker horizontally, plus up, clamped to MaxVel.
function Core.knock(from: Vector3, to: Vector3, look: Vector3, rules: Rules): Vector3
	local dir = flat(to - from)
	if dir.Magnitude < 1e-6 then
		dir = flat(look)
	end
	dir = if dir.Magnitude > 1e-6 then dir.Unit else Vector3.new(0, 0, -1)
	local v = dir * rules.KnockH + Vector3.new(0, rules.KnockUp, 0)
	if v.Magnitude > rules.MaxVel then
		v = v.Unit * rules.MaxVel
	end
	return v
end

return Core
