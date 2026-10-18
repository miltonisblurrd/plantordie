--!strict
export type HouseTier = {
	Tier: number,
	Name: string,
	Cost: number,
	MaxHp: number,
	RequiredBiome: number, -- index into Biomes.List that must be unlocked
	Size: Vector3, -- footprint (X along lanes, Y wall height, Z across lanes)
	WallColor: Color3,
	RoofColor: Color3,
	TrimColor: Color3,
	Towers: number,
}

local list: { HouseTier } = {
	{
		Tier = 1, Name = "Starter Shack", Cost = 0, MaxHp = 100, RequiredBiome = 1,
		Size = Vector3.new(16, 10, 22),
		WallColor = Color3.fromRGB(196, 140, 86), RoofColor = Color3.fromRGB(176, 64, 52),
		TrimColor = Color3.fromRGB(110, 74, 44), Towers = 0,
	},
	{
		Tier = 2, Name = "Reinforced Cottage", Cost = 25_000, MaxHp = 300, RequiredBiome = 2,
		Size = Vector3.new(18, 12, 26),
		WallColor = Color3.fromRGB(226, 214, 190), RoofColor = Color3.fromRGB(58, 98, 170),
		TrimColor = Color3.fromRGB(120, 120, 128), Towers = 0,
	},
	{
		Tier = 3, Name = "Fortified Estate", Cost = 1_000_000, MaxHp = 900, RequiredBiome = 4,
		Size = Vector3.new(20, 14, 30),
		WallColor = Color3.fromRGB(150, 150, 160), RoofColor = Color3.fromRGB(70, 70, 80),
		TrimColor = Color3.fromRGB(63, 191, 74), Towers = 2,
	},
	{
		Tier = 4, Name = "Advanced Botanical House", Cost = 40_000_000, MaxHp = 2_500, RequiredBiome = 7,
		Size = Vector3.new(22, 16, 34),
		WallColor = Color3.fromRGB(240, 248, 240), RoofColor = Color3.fromRGB(63, 191, 74),
		TrimColor = Color3.fromRGB(58, 141, 255), Towers = 2,
	},
	{
		Tier = 5, Name = "Botanical Fortress", Cost = 500_000_000, MaxHp = 7_500, RequiredBiome = 11,
		Size = Vector3.new(24, 18, 38),
		WallColor = Color3.fromRGB(46, 58, 50), RoofColor = Color3.fromRGB(255, 176, 32),
		TrimColor = Color3.fromRGB(166, 77, 255), Towers = 4,
	},
}

return {
	List = list,
	MaxTier = #list,
}
