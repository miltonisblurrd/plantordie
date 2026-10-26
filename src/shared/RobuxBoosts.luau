--!strict
-- Robux Speed and Luck tracks. Buying the next tier replaces the multiplier. Tiers are not
-- multiplied together. Prices are the Developer Product prices; Ids live in Products.

export type Tier = {
	Tier: number,
	Track: "Speed" | "Luck",
	Key: string,
	Multiplier: number,
	Price: number,
	Benefit: string,
}

local SPEED_MULT = { 2, 4, 6, 8, 10, 12, 15, 20 }
local SPEED_PRICE = { 3, 9, 17, 35, 59, 89, 129, 199 }
local LUCK_MULT = { 2, 4, 6, 8, 10, 12, 15, 20 }
local LUCK_PRICE = { 6, 12, 24, 49, 79, 119, 169, 249 }

local function build(track: "Speed" | "Luck", mults: { number }, prices: { number }): { Tier }
	local out = {}
	for i, mult in mults do
		local key = `{track}Robux{i}`
		table.insert(out, {
			Tier = i,
			Track = track,
			Key = key,
			Multiplier = mult,
			Price = prices[i],
			Benefit = `Replace your {track} multiplier with x{mult}.`,
		})
	end
	return out
end

local speed = build("Speed", SPEED_MULT, SPEED_PRICE)
local luck = build("Luck", LUCK_MULT, LUCK_PRICE)

local byKey: { [string]: Tier } = {}
for _, t in speed do
	byKey[t.Key] = t
end
for _, t in luck do
	byKey[t.Key] = t
end

local Boosts = {
	Speed = speed,
	Luck = luck,
	ByKey = byKey,
	MaxTier = 8,
}

function Boosts.multiplier(track: "Speed" | "Luck", tier: number): number
	local list = if track == "Speed" then speed else luck
	local row = list[tier]
	return if row then row.Multiplier else 1
end

function Boosts.next(track: "Speed" | "Luck", tier: number): Tier?
	local list = if track == "Speed" then speed else luck
	return list[tier + 1]
end

return Boosts
