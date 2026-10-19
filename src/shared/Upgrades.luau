--!strict
-- Shovel and water upgrades (P3 / P5).
-- DigSeconds doubles as the per-player dig cooldown. ToughTier is the highest tough-soil tier
-- the shovel can break (dig spots carry a RequiredTier of 1-4).
export type Shovel = {
	Tier: number,
	Name: string,
	Cost: number,
	DigSeconds: number,
	LuckBonus: number,
	ToughTier: number,
	Damage: number, -- HP removed from a dirt mound per dig
	Color: Color3,
}

-- Water tiers are bought in order. Each multiplies growth speed (they stack) and unlocks the
-- water-dependent species listed; owning a later tier implies the earlier ones.
export type WaterTier = {
	Key: "channel" | "sprinkler" | "pond", -- profile.water field
	Name: string,
	Cost: number,
	GrowthMultiplier: number,
	Unlocks: { string },
	Description: string,
}

local shovels: { Shovel } = {
	{ Tier = 1, Name = "Rusty Shovel", Cost = 0, DigSeconds = 3, LuckBonus = 0, ToughTier = 1, Damage = 2, Color = Color3.fromHex("#8B6B4A") },
	{ Tier = 2, Name = "Iron Shovel", Cost = 10_000, DigSeconds = 2.2, LuckBonus = 0.05, ToughTier = 2, Damage = 5, Color = Color3.fromHex("#B0B6BE") },
	{ Tier = 3, Name = "Golden Shovel", Cost = 1_000_000, DigSeconds = 1.5, LuckBonus = 0.12, ToughTier = 3, Damage = 10, Color = Color3.fromHex("#FFC83D") },
	{ Tier = 4, Name = "Crystal Shovel", Cost = 30_000_000, DigSeconds = 1, LuckBonus = 0.25, ToughTier = 4, Damage = 18, Color = Color3.fromHex("#5CE1E6") },
	{ Tier = 5, Name = "Void Shovel", Cost = 150_000_000, DigSeconds = 0.7, LuckBonus = 0.4, ToughTier = 5, Damage = 30, Color = Color3.fromHex("#C77DFF") },
}

-- Each plot's portal. Higher tiers raise garden income and the strength of monsters that walk out.
export type PortalTier = { Tier: number, Name: string, Cost: number, IncomeMultiplier: number, Strength: number }
local portals: { PortalTier } = {
	{ Tier = 1, Name = "Spark Portal", Cost = 0, IncomeMultiplier = 1, Strength = 1 },
	{ Tier = 2, Name = "Ember Portal", Cost = 5_000, IncomeMultiplier = 1.35, Strength = 1.25 },
	{ Tier = 3, Name = "Storm Portal", Cost = 80_000, IncomeMultiplier = 1.8, Strength = 1.6 },
	{ Tier = 4, Name = "Void Portal", Cost = 2_000_000, IncomeMultiplier = 2.5, Strength = 2.1 },
	{ Tier = 5, Name = "Myth Portal", Cost = 40_000_000, IncomeMultiplier = 3.5, Strength = 2.8 },
}

local channel: WaterTier = {
	Key = "channel", Name = "Water Channel", Cost = 50_000, GrowthMultiplier = 1.15, Unlocks = { "KelpRibbon" },
	Description = "A stone channel behind your garden.",
}
local sprinkler: WaterTier = {
	Key = "sprinkler", Name = "Sprinklers", Cost = 2_000_000, GrowthMultiplier = 1.35, Unlocks = { "AnemoneBloom" },
	Description = "Sprinkler heads along the channel.",
}
local pond: WaterTier = {
	Key = "pond", Name = "Garden Pond", Cost = 75_000_000, GrowthMultiplier = 1.6, Unlocks = { "ToxicVine" },
	Description = "A deep pond behind the channel.",
}
local waterOrder: { WaterTier } = { channel, sprinkler, pond }

type WaterState = { channel: boolean, sprinkler: boolean, pond: boolean }

local Upgrades = {
	Shovels = shovels,
	Portals = portals,
	Water = { Channel = channel, Sprinkler = sprinkler, Pond = pond },
	WaterOrder = waterOrder,
}

function Upgrades.portalOf(tier: number): PortalTier
	return portals[tier] or portals[1]
end

function Upgrades.nextWater(water: WaterState): WaterTier?
	for _, t in waterOrder do
		if not water[t.Key] then
			return t
		end
	end
	return nil
end

-- The tier that unlocks a water-dependent species (nil = any water tier works).
function Upgrades.waterTierFor(speciesId: string): WaterTier?
	for _, t in waterOrder do
		if table.find(t.Unlocks, speciesId) then
			return t
		end
	end
	return nil
end

function Upgrades.waterAllows(water: WaterState, speciesId: string, waterDependent: boolean): boolean
	if not waterDependent then
		return true
	end
	local tier = Upgrades.waterTierFor(speciesId)
	if tier then
		return water[tier.Key]
	end
	return water.channel or water.sprinkler or water.pond
end

return Upgrades
