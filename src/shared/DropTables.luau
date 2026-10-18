--!strict
-- Per-biome dig rolls (spec §5). Each biome only drops its own species. Weights come from the
-- species' rarity so Divine stays exceptionally rare (0.05 vs Common 60, i.e. well under 0.1%).
-- Shovel luck tilts weights toward rarer drops but is clamped by Config.Dig.MaxLuck, so even
-- the best shovel at most quadruples Divine odds.

local Config = require(script.Parent.Config)
local Plants = require(script.Parent.Plants)
local Rarities = require(script.Parent.Rarities)

export type Drop = { Plant: string, Rarity: string, Weight: number }

local RARITY_WEIGHT: { [string]: number } =
	{ Common = 60, Uncommon = 30, Rare = 12, Epic = 5, Legendary = 1.5, Mythical = 0.4, Divine = 0.05 }

local tables: { [string]: { Drop } } = {}
for biomeId, plants in Plants.ByBiome do
	local t: { Drop } = {}
	for _, plant in plants do
		table.insert(t, { Plant = plant.Id, Rarity = plant.Rarity, Weight = RARITY_WEIGHT[plant.Rarity] or 1 })
	end
	tables[biomeId] = t
end

local DropTables = {}
DropTables.ByBiome = tables
DropTables.RarityWeight = RARITY_WEIGHT

-- Weights after luck. Rarity order 1 (Common) is untouched; each rarer step gains `luck`.
function DropTables.weighted(biomeId: string, luck: number): { Drop }
	local l = math.clamp(luck, 0, Config.Dig.MaxLuck)
	local out: { Drop } = {}
	local base: { Drop } = tables[biomeId] or {}
	for _, d in base do
		local order = (Rarities.ById[d.Rarity] and Rarities.ById[d.Rarity].Order) or 1
		table.insert(out, { Plant = d.Plant, Rarity = d.Rarity, Weight = d.Weight * (1 + l * (order - 1)) })
	end
	return out
end

-- `roll01` is a number in [0, 1) supplied by the caller (server Random).
function DropTables.roll(biomeId: string, luck: number, roll01: number): Drop?
	local list = DropTables.weighted(biomeId, luck)
	local total = 0
	for _, d in list do
		total += d.Weight
	end
	if total <= 0 then
		return nil
	end
	local pick = roll01 * total
	for _, d in list do
		pick -= d.Weight
		if pick < 0 then
			return d
		end
	end
	return list[#list]
end

return DropTables
