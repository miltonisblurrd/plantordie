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
	Color: Color3, -- blade
	Accent: Color3, -- handle collar and shop swatch trim
	Material: Enum.Material, -- blade
	Effect: string?, -- "Sparkle" | "Fire" | "Stars" | "Smoke" on the blade
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

-- Sold at the hub Shovel Shop; any owned tier can be equipped. LuckBonus tops out at Config.Dig.MaxLuck.
local SMOOTH, NEON, GLASS, METAL = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Glass, Enum.Material.Metal
local shovels: { Shovel } = {
	{ Tier = 1, Name = "Starter Shovel", Cost = 0, DigSeconds = 3, LuckBonus = 0, ToughTier = 1, Damage = 2,
		Color = Color3.fromHex("#8B6B4A"), Accent = Color3.fromHex("#6B4A2E"), Material = SMOOTH },
	{ Tier = 2, Name = "Steel Shovel", Cost = 25_000, DigSeconds = 2.5, LuckBonus = 0.05, ToughTier = 2, Damage = 5,
		Color = Color3.fromHex("#B0B6BE"), Accent = Color3.fromHex("#6E747C"), Material = METAL },
	{ Tier = 3, Name = "Crystal Shovel", Cost = 250_000, DigSeconds = 2.1, LuckBonus = 0.1, ToughTier = 3, Damage = 10,
		Color = Color3.fromHex("#5CE1E6"), Accent = Color3.fromHex("#BFF8FF"), Material = GLASS, Effect = "Sparkle" },
	{ Tier = 4, Name = "Inferno Shovel", Cost = 2_500_000, DigSeconds = 1.8, LuckBonus = 0.15, ToughTier = 4, Damage = 18,
		Color = Color3.fromHex("#FF7A1A"), Accent = Color3.fromHex("#FFD34A"), Material = NEON, Effect = "Fire" },
	{ Tier = 5, Name = "Emerald Shovel", Cost = 25_000_000, DigSeconds = 1.5, LuckBonus = 0.2, ToughTier = 5, Damage = 30,
		Color = Color3.fromHex("#2EE06A"), Accent = Color3.fromHex("#0E7A34"), Material = NEON, Effect = "Sparkle" },
	{ Tier = 6, Name = "Plasma Shovel", Cost = 250_000_000, DigSeconds = 1.2, LuckBonus = 0.25, ToughTier = 5, Damage = 50,
		Color = Color3.fromHex("#FF2FD0"), Accent = Color3.fromHex("#7A00A8"), Material = NEON, Effect = "Sparkle" },
	{ Tier = 7, Name = "Toxic Shovel", Cost = 2_500_000_000, DigSeconds = 1, LuckBonus = 0.3, ToughTier = 5, Damage = 80,
		Color = Color3.fromHex("#B6FF2E"), Accent = Color3.fromHex("#3D5A00"), Material = NEON, Effect = "Smoke" },
	{ Tier = 8, Name = "Ancient Shovel", Cost = 25_000_000_000, DigSeconds = 0.8, LuckBonus = 0.38, ToughTier = 5, Damage = 130,
		Color = Color3.fromHex("#CD7F32"), Accent = Color3.fromHex("#5A3A1A"), Material = METAL, Effect = "Sparkle" },
	{ Tier = 9, Name = "Cosmic Shovel", Cost = 250_000_000_000, DigSeconds = 0.65, LuckBonus = 0.44, ToughTier = 5, Damage = 210,
		Color = Color3.fromHex("#7A2BFF"), Accent = Color3.fromHex("#FFFFFF"), Material = NEON, Effect = "Stars" },
	{ Tier = 10, Name = "Divine Shovel", Cost = 2_500_000_000_000, DigSeconds = 0.5, LuckBonus = 0.5, ToughTier = 5, Damage = 340,
		Color = Color3.fromHex("#FFD23F"), Accent = Color3.fromHex("#FFFFFF"), Material = NEON, Effect = "Sparkle" },
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
