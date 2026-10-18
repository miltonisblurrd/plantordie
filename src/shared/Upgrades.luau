--!strict
-- Shovel and water upgrades (P3 / P5).
return {
	Shovels = {
		{ Tier = 1, Name = "Rusty Shovel", Cost = 0, DigSeconds = 3, LuckBonus = 0 },
		{ Tier = 2, Name = "Iron Shovel", Cost = 10_000, DigSeconds = 2.2, LuckBonus = 0.05 },
		{ Tier = 3, Name = "Golden Shovel", Cost = 1_000_000, DigSeconds = 1.5, LuckBonus = 0.12 },
		{ Tier = 4, Name = "Crystal Shovel", Cost = 100_000_000, DigSeconds = 1, LuckBonus = 0.25 },
	},
	Water = {
		Channel = { Cost = 50_000, GrowthMultiplier = 1.15 },
		Sprinkler = { Cost = 2_000_000, GrowthMultiplier = 1.35 },
		Pond = { Cost = 75_000_000, GrowthMultiplier = 1.6 },
	},
}
