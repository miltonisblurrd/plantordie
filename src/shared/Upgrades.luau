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
	Color: Color3,
}

local shovels: { Shovel } = {
	{ Tier = 1, Name = "Rusty Shovel", Cost = 0, DigSeconds = 3, LuckBonus = 0, ToughTier = 1, Color = Color3.fromHex("#8B6B4A") },
	{ Tier = 2, Name = "Iron Shovel", Cost = 10_000, DigSeconds = 2.2, LuckBonus = 0.05, ToughTier = 2, Color = Color3.fromHex("#B0B6BE") },
	{ Tier = 3, Name = "Golden Shovel", Cost = 1_000_000, DigSeconds = 1.5, LuckBonus = 0.12, ToughTier = 3, Color = Color3.fromHex("#FFC83D") },
	{ Tier = 4, Name = "Crystal Shovel", Cost = 30_000_000, DigSeconds = 1, LuckBonus = 0.25, ToughTier = 4, Color = Color3.fromHex("#5CE1E6") },
	{ Tier = 5, Name = "Void Shovel", Cost = 150_000_000, DigSeconds = 0.7, LuckBonus = 0.4, ToughTier = 4, Color = Color3.fromHex("#C77DFF") },
}

return {
	Shovels = shovels,
	Water = {
		Channel = { Cost = 50_000, GrowthMultiplier = 1.15 },
		Sprinkler = { Cost = 2_000_000, GrowthMultiplier = 1.35 },
		Pond = { Cost = 75_000_000, GrowthMultiplier = 1.6 },
	},
}
