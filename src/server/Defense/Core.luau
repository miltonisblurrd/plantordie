--!strict
-- Pure lane simulation for one plot. No instances: positions are plot-local X along a lane
-- (zombies walk toward -X, the house is at houseX), so the harness can run real wave ticks.
-- The service applies the returned events to models, money and the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Zombies = require(ReplicatedStorage.Shared.Zombies)

local D = Config.Defense

export type Zombie = {
	id: number,
	kind: string,
	lane: number,
	x: number,
	hp: number,
	maxHp: number,
	armor: number,
	maxArmor: number,
	speed: number,
	damage: number,
	rate: number,
	range: number,
	ability: Zombies.Ability?,
	bounty: number,
	nextAttack: number,
	slowUntil: number,
	frozenUntil: number,
	burnUntil: number,
	burnDps: number,
	jumped: boolean,
	attacking: boolean,
	spawnedAt: number,
	progressX: number,
	progressAt: number,
	dead: boolean,
	reason: string?, -- "killed" | "house" | "stuck" | "timeout" | "dawn" | "lost"
}

export type Plant = {
	key: string,
	lane: number,
	x: number,
	hp: number,
	maxHp: number,
	stats: Combat.PlantStats?,
	nextAttack: number,
	wilted: boolean,
}

export type Trap = {
	kind: string, -- "Spikes" | "Freeze"
	lane: number,
	x: number,
	endsAt: number,
	triggered: boolean,
}

export type Event = {
	kind: string, -- "shot" | "splash" | "bite" | "spit" | "wilt" | "kill" | "house" | "jump" | "despawn" | "freeze"
	zombie: Zombie?,
	plant: Plant?,
	amount: number?,
	by: string?, -- what killed a zombie: a role, "burn", "thorns", "trap", "player"
	x: number?,
	lane: number?,
}

export type Field = {
	zombies: { [number]: Zombie },
	plants: { [string]: Plant },
	traps: { Trap },
	houseX: number,
	trapPower: number, -- biome scale for trap damage
}

local Core = {}

function Core.newField(houseX: number, trapPower: number): Field
	return { zombies = {}, plants = {}, traps = {}, houseX = houseX, trapPower = trapPower }
end

function Core.addZombie(f: Field, id: number, kind: string, lane: number, x: number, s: Zombies.Stats, now: number): Zombie
	local z: Zombie = {
		id = id, kind = kind, lane = lane, x = x,
		hp = s.hp, maxHp = s.hp, armor = s.armor, maxArmor = s.armor,
		speed = s.speed, damage = s.damage, rate = s.rate, range = s.range, ability = s.ability, bounty = s.bounty,
		nextAttack = 0, slowUntil = 0, frozenUntil = 0, burnUntil = 0, burnDps = 0,
		jumped = false, attacking = false, spawnedAt = now, progressX = x, progressAt = now,
		dead = false, reason = nil,
	}
	f.zombies[id] = z
	return z
end

function Core.setPlant(f: Field, key: string, lane: number, x: number, stats: Combat.PlantStats?)
	local hp = if stats then stats.hp else 1
	local old = f.plants[key]
	f.plants[key] = {
		key = key, lane = lane, x = x, hp = hp, maxHp = hp, stats = stats, nextAttack = 0,
		wilted = if old then old.wilted else false,
	}
	if old and old.wilted then
		f.plants[key].hp = 0
	end
end

function Core.removePlant(f: Field, key: string)
	f.plants[key] = nil
end

function Core.alive(f: Field): number
	local n = 0
	for _, z in f.zombies do
		if not z.dead then
			n += 1
		end
	end
	return n
end

function Core.damage(z: Zombie, amount: number, by: string, out: { Event })
	if z.dead or amount <= 0 then
		return
	end
	if z.armor > 0 then
		local absorbed = math.min(z.armor, amount)
		z.armor -= absorbed
		amount -= absorbed
	end
	z.hp -= amount
	if z.hp <= 0 then
		z.hp = 0
		z.dead = true
		z.reason = "killed"
		table.insert(out, { kind = "kill", zombie = z, by = by })
	end
end

local function despawn(z: Zombie, reason: string, out: { Event })
	z.dead = true
	z.reason = reason
	table.insert(out, { kind = "despawn", zombie = z })
end

-- Nearest live zombie in the plant's lane, ahead of it (+X), within range.
local function laneTarget(f: Field, p: Plant, range: number): Zombie?
	local best: Zombie? = nil
	for _, z in f.zombies do
		if not z.dead and z.lane == p.lane and z.x >= p.x and z.x - p.x <= range then
			if not best or z.x < best.x then
				best = z
			end
		end
	end
	return best
end

local function plantStep(f: Field, p: Plant, now: number, out: { Event })
	local s = p.stats
	if p.wilted or not s or s.role == "Income" or s.rate <= 0 or now < p.nextAttack then
		return
	end
	if s.role == "AoE" then
		local hit = false
		for _, z in f.zombies do
			if not z.dead and math.abs(z.lane - p.lane) <= 1 and math.abs(z.x - p.x) <= s.range then
				hit = true
				Core.damage(z, s.damage, "AoE", out)
			end
		end
		if hit then
			p.nextAttack = now + 1 / s.rate
			table.insert(out, { kind = "splash", plant = p, amount = s.range })
		end
		return
	end
	local range = if s.role == "Wall" then D.MeleeReach + 1 else s.range
	local z = laneTarget(f, p, range)
	if not z then
		return
	end
	p.nextAttack = now + 1 / s.rate
	if s.role == "Slow" then
		z.slowUntil = now + Combat.SlowSeconds
	elseif s.role == "Burn" then
		z.burnUntil = now + Combat.BurnSeconds
		z.burnDps = math.max(z.burnDps, s.damage)
	end
	table.insert(out, { kind = "shot", plant = p, zombie = z })
	Core.damage(z, s.damage, s.role, out)
end

local function trapStep(f: Field, t: Trap, dt: number, now: number, out: { Event }): boolean
	if now >= t.endsAt then
		return false
	end
	local spec = D.Traps[t.kind]
	if t.kind == "Spikes" then
		for _, z in f.zombies do
			if not z.dead and z.lane == t.lane and math.abs(z.x - t.x) <= spec.HalfWidth then
				Core.damage(z, spec.Dps * f.trapPower * dt, "trap", out)
			end
		end
		return true
	end
	local tripped = false
	for _, z in f.zombies do
		if not z.dead and z.lane == t.lane and math.abs(z.x - t.x) <= 2 then
			tripped = true
			break
		end
	end
	if not tripped then
		return true
	end
	for _, z in f.zombies do
		if not z.dead and math.abs(z.lane - t.lane) <= 1 and math.abs(z.x - t.x) <= spec.Radius then
			z.frozenUntil = now + spec.Seconds
			Core.damage(z, spec.Damage * f.trapPower, "trap", out)
		end
	end
	table.insert(out, { kind = "freeze", x = t.x, lane = t.lane, amount = spec.Radius })
	return false
end

local function zombieStep(f: Field, z: Zombie, dt: number, now: number, out: { Event })
	if now < z.burnUntil then
		Core.damage(z, z.burnDps * dt, "burn", out)
		if z.dead then
			return
		end
	end
	z.attacking = false
	if now - z.spawnedAt > D.MaxLifeSeconds then
		despawn(z, "timeout", out)
		return
	end
	if now < z.frozenUntil then
		z.progressAt = now
		return
	end
	local reach = if z.ability == "Ranged" then z.range else D.MeleeReach
	local target: Plant? = nil
	for _, p in f.plants do
		if not p.wilted and p.lane == z.lane and p.x <= z.x and z.x - p.x <= reach then
			if not target or p.x > target.x then
				target = p
			end
		end
	end
	if target and z.ability == "Jump" and not z.jumped then
		z.jumped = true
		z.x = target.x - D.MeleeReach - 1
		z.progressX, z.progressAt = z.x, now
		table.insert(out, { kind = "jump", zombie = z })
		return
	end
	if target then
		z.attacking = true
		z.progressAt = now
		if now >= z.nextAttack then
			z.nextAttack = now + 1 / z.rate
			target.hp -= z.damage
			table.insert(out, { kind = if z.ability == "Ranged" then "spit" else "bite", zombie = z, plant = target })
			local s = target.stats
			if s and s.role == "Wall" then
				if s.ability == "Freeze" then
					z.frozenUntil = now + Combat.FreezeOnHitSeconds
				end
				Core.damage(z, s.damage, "thorns", out)
			end
			if target.hp <= 0 then
				target.hp = 0
				target.wilted = true
				table.insert(out, { kind = "wilt", plant = target })
			end
		end
		return
	end
	local speed = z.speed * (if now < z.slowUntil then Combat.SlowFactor else 1)
	z.x -= speed * dt
	if z.x <= f.houseX then
		z.dead = true
		z.reason = "house"
		table.insert(out, { kind = "house", zombie = z, amount = z.damage * D.HouseHitMultiplier })
		return
	end
	if z.progressX - z.x >= 0.5 then
		z.progressX, z.progressAt = z.x, now
	elseif now - z.progressAt > D.StuckSeconds then
		despawn(z, "stuck", out)
	end
end

function Core.step(f: Field, dt: number, now: number, out: { Event })
	for _, p in f.plants do
		plantStep(f, p, now, out)
	end
	local keep = {}
	for _, t in f.traps do
		if trapStep(f, t, dt, now, out) then
			table.insert(keep, t)
		end
	end
	f.traps = keep
	for _, z in f.zombies do
		if not z.dead then
			zombieStep(f, z, dt, now, out)
		end
	end
end

-- Removes dead zombies and returns them so the caller can destroy their models.
function Core.sweep(f: Field): { Zombie }
	local gone = {}
	for id, z in f.zombies do
		if z.dead then
			f.zombies[id] = nil
			table.insert(gone, z)
		end
	end
	return gone
end

-- Ends the night: every zombie leaves and every wilted plant recovers.
function Core.dawn(f: Field, out: { Event })
	for _, z in f.zombies do
		if not z.dead then
			despawn(z, "dawn", out)
		end
	end
	f.traps = {}
	for _, p in f.plants do
		p.wilted = false
		p.hp = p.maxHp
	end
end

return Core
