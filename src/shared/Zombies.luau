--!strict
-- Lane zombies (P4, spec §9). Base stats are for biome 1, night 1. `stats` scales them by the
-- player's highest unlocked biome and the night number; `compose` builds one player's wave.

local Config = require(script.Parent.Config)

export type Ability = "Jump" | "Ranged" | "Boss"

export type Zombie = {
	Id: string,
	Name: string,
	Hp: number,
	Armor: number, -- absorbs damage before HP (the bucket)
	Speed: number, -- studs/sec
	Damage: number, -- per hit
	AttackRate: number, -- hits/sec
	Range: number, -- studs; Ranged attacks plants from this far
	Ability: Ability?,
	Bounty: number, -- x Config.Defense.BountyIncomeSeconds
	MinBiome: number, -- appears once the player owns this biome...
	MinNight: number, -- ...or from this night, whichever comes first
	Weight: number,
	Scale: number,
	Color: Color3,
	HeadColor: Color3,
}

export type Stats = {
	hp: number,
	armor: number,
	speed: number,
	damage: number,
	rate: number,
	range: number,
	ability: Ability?,
	bounty: number,
}

local D = Config.Defense

local list: { Zombie } = {
	{ Id = "Walker", Name = "Walker", Hp = 20, Armor = 0, Speed = 2, Damage = 5, AttackRate = 1, Range = 0,
		Bounty = 1, MinBiome = 1, MinNight = 1, Weight = 10, Scale = 1,
		Color = Color3.fromRGB(110, 160, 90), HeadColor = Color3.fromRGB(150, 190, 120) },
	{ Id = "Runner", Name = "Runner", Hp = 12, Armor = 0, Speed = 4, Damage = 4, AttackRate = 1.2, Range = 0,
		Bounty = 1, MinBiome = 1, MinNight = 2, Weight = 5, Scale = 0.85,
		Color = Color3.fromRGB(200, 120, 60), HeadColor = Color3.fromRGB(170, 200, 120) },
	{ Id = "Bucket", Name = "Buckethead", Hp = 20, Armor = 30, Speed = 1.8, Damage = 5, AttackRate = 1, Range = 0,
		Bounty = 2, MinBiome = 2, MinNight = 4, Weight = 4, Scale = 1,
		Color = Color3.fromRGB(96, 130, 150), HeadColor = Color3.fromRGB(150, 190, 120) },
	{ Id = "Tank", Name = "Tank", Hp = 80, Armor = 0, Speed = 1.2, Damage = 12, AttackRate = 0.7, Range = 0,
		Bounty = 3, MinBiome = 3, MinNight = 6, Weight = 2, Scale = 1.5,
		Color = Color3.fromRGB(90, 70, 110), HeadColor = Color3.fromRGB(130, 170, 110) },
	{ Id = "Jumper", Name = "Pole Jumper", Hp = 18, Armor = 0, Speed = 2.6, Damage = 5, AttackRate = 1, Range = 0,
		Ability = "Jump", Bounty = 2, MinBiome = 4, MinNight = 8, Weight = 3, Scale = 0.95,
		Color = Color3.fromRGB(220, 200, 70), HeadColor = Color3.fromRGB(150, 190, 120) },
	{ Id = "Spitter", Name = "Spitter", Hp = 16, Armor = 0, Speed = 1.8, Damage = 4, AttackRate = 0.6, Range = 20,
		Ability = "Ranged", Bounty = 2, MinBiome = 5, MinNight = 10, Weight = 3, Scale = 0.9,
		Color = Color3.fromRGB(120, 200, 70), HeadColor = Color3.fromRGB(190, 240, 90) },
}

local boss: Zombie = {
	Id = "RotKing", Name = "Rot King", Hp = 400, Armor = 100, Speed = 1, Damage = 25, AttackRate = 0.6, Range = 0,
	Ability = "Boss", Bounty = 30, MinBiome = 1, MinNight = 1, Weight = 0, Scale = 2.2,
	Color = Color3.fromRGB(70, 40, 60), HeadColor = Color3.fromRGB(120, 160, 90),
}

local byId: { [string]: Zombie } = { [boss.Id] = boss }
for _, z in list do
	byId[z.Id] = z
end

local Zombies = {
	BossEveryNights = 5,
	List = list,
	Boss = boss,
	ById = byId,
}

function Zombies.available(night: number, biomeIndex: number): { Zombie }
	local out = {}
	for _, z in list do
		if biomeIndex >= z.MinBiome or night >= z.MinNight then
			table.insert(out, z)
		end
	end
	return out
end

function Zombies.stats(id: string, biomeIndex: number, night: number): Stats
	local z = byId[id]
	local n = math.min(math.max(night, 1), D.NightScaleCap) - 1
	local hpMult = (1 + D.HpPerBiome * (biomeIndex - 1)) * (1 + D.HpPerNight * n)
	local dmgMult = 1 + D.DamagePerBiome * (biomeIndex - 1)
	return {
		hp = math.floor(z.Hp * hpMult),
		armor = math.floor(z.Armor * hpMult),
		speed = z.Speed,
		damage = z.Damage * dmgMult,
		rate = z.AttackRate,
		range = z.Range,
		ability = z.Ability,
		bounty = z.Bounty,
	}
end

function Zombies.waveSize(night: number, lanes: number): number
	local perLane = D.PerLaneBase + D.PerLaneGrowth * (math.min(night, D.PerLaneNightCap) - 1)
	return math.min(D.WaveCap, math.ceil(lanes * perLane))
end

-- Spawn order of type ids for one player's wave. Every 5th night adds the boss mid-wave.
function Zombies.compose(night: number, biomeIndex: number, lanes: number, rng: Random): { string }
	local pool = Zombies.available(night, biomeIndex)
	local total = 0
	for _, z in pool do
		total += z.Weight
	end
	local out = {}
	for _ = 1, Zombies.waveSize(night, lanes) do
		local r = rng:NextNumber() * total
		local pick = pool[1]
		for _, z in pool do
			r -= z.Weight
			if r <= 0 then
				pick = z
				break
			end
		end
		table.insert(out, pick.Id)
	end
	if night % Zombies.BossEveryNights == 0 then
		table.insert(out, math.max(1, math.floor(#out / 2)), boss.Id)
	end
	return out
end

return Zombies
