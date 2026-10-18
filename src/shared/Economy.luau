--!strict
-- The only place income and growth are computed. The server uses these as the authority;
-- the client may call them for display (timers, labels) but never to decide money.

local Config = require(script.Parent.Config)
local Plants = require(script.Parent.Plants)
local Rarities = require(script.Parent.Rarities)
local Sizes = require(script.Parent.Sizes)
local Upgrades = require(script.Parent.Upgrades)

export type PlantRecord = {
	species: string,
	rarity: string,
	size: string,
	variant: string,
	plantedAt: number?,
	matured: boolean?, -- true when moved back from inventory already grown
	uid: string?,
}

export type PlantIdentity = { species: string, rarity: string, size: string, variant: string }

export type Bonuses = { incomeMultiplier: number? }

export type GrowthProfile = {
	water: { channel: boolean, sprinkler: boolean, pond: boolean },
	growthBoostEndsAt: number,
}

local Economy = {}

Economy.STAGES = { "Seed", "Sprout", "Young", "Grown" }

-- income/sec = base x rarity x size x variant x bonuses
function Economy.incomeOf(record: PlantIdentity, bonuses: Bonuses?): number
	local def = Plants.ById[record.species]
	if not def then
		return 0
	end
	local rarity = Rarities.ById[record.rarity]
	local size = Sizes.ById[record.size]
	local variant = Plants.Variants[record.variant]
	local mult = (rarity and rarity.Multiplier or 1)
		* (size and size.Multiplier or 1)
		* (variant and variant.IncomeMultiplier or 1)
		* (bonuses and bonuses.incomeMultiplier or 1)
	return def.BaseIncome * mult
end

-- Water upgrades stack multiplicatively; the 2x boost product doubles on top.
function Economy.growthMultiplier(profile: GrowthProfile?, now: number): number
	if not profile then
		return 1
	end
	local m = 1
	local w = Upgrades.Water
	if profile.water.channel then
		m *= w.Channel.GrowthMultiplier
	end
	if profile.water.sprinkler then
		m *= w.Sprinkler.GrowthMultiplier
	end
	if profile.water.pond then
		m *= w.Pond.GrowthMultiplier
	end
	if profile.growthBoostEndsAt > now then
		m *= Config.Garden.BoostGrowthMultiplier
	end
	return m
end

function Economy.effectiveGrowSeconds(record: PlantRecord, growthMult: number): number
	local def = Plants.ById[record.species]
	local base = if def then def.GrowSeconds else 60
	return base / math.max(growthMult, 0.01)
end

-- Returns progress 0..1 and stage index 1..4 (4 = Grown).
function Economy.growth(record: PlantRecord, now: number, growthMult: number): (number, number)
	if record.matured then
		return 1, 4
	end
	local total = Economy.effectiveGrowSeconds(record, growthMult)
	local p = math.clamp((now - (record.plantedAt or now)) / total, 0, 1)
	if p >= 1 then
		return 1, 4
	end
	return p, math.min(3, math.floor(p * 3) + 1)
end

function Economy.isGrown(record: PlantRecord, now: number, growthMult: number): boolean
	local _, stage = Economy.growth(record, now, growthMult)
	return stage == 4
end

-- Server-side size roll using the plant's weights, else Sizes weights.
function Economy.rollSize(speciesId: string, rng: Random): string
	local def = Plants.ById[speciesId]
	local weights = def and def.SizeWeights
	local total = 0
	for _, s in Sizes.List do
		total += if weights then (weights[s.Id] or 0) else s.Weight
	end
	local pick = rng:NextNumber() * total
	for _, s in Sizes.List do
		pick -= if weights then (weights[s.Id] or 0) else s.Weight
		if pick <= 0 then
			return s.Id
		end
	end
	return Sizes.List[1].Id
end

-- Money earned while offline: each grown plant earns for the part of the (capped) offline
-- window after it finished growing, at Config.Garden.OfflineRate.
function Economy.offlineEarnings(
	planted: { [string]: PlantRecord },
	lastSeen: number,
	now: number,
	growthMult: number
): (number, number)
	if lastSeen <= 0 or now <= lastSeen then
		return 0, 0
	end
	local windowEnd = math.min(now, lastSeen + Config.Garden.OfflineCapHours * 3600)
	local total = 0
	for _, rec in planted do
		local doneAt = if rec.matured
			then lastSeen
			else (rec.plantedAt or now) + Economy.effectiveGrowSeconds(rec, growthMult)
		local earnFrom = math.max(lastSeen, doneAt)
		if windowEnd > earnFrom then
			total += Economy.incomeOf(rec) * (windowEnd - earnFrom)
		end
	end
	return math.floor(total * Config.Garden.OfflineRate), windowEnd - lastSeen
end

return Economy
