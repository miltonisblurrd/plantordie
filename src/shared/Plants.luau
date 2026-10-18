--!strict
-- Plant definitions. P2 fills all spec §4 fields for every species; these are seeds for wiring.
export type Plant = {
	Id: string,
	Name: string,
	Biome: string,
	Rarity: string,
	BaseIncome: number, -- $/sec at Small, Common multiplier applied separately
	GrowSeconds: number,
	Role: string, -- "Projectile" | "Rapid" | "AoE" | "Slow" | "Burn" | "Wall" | "Income"
	NeedsWater: boolean,
	StemColor: Color3,
	HeadColor: Color3,
	HeadShape: "Ball" | "Block" | "Cylinder",
}

local list: { Plant } = {
	{ Id = "Sunpetal", Name = "Sunpetal", Biome = "GreenMeadows", Rarity = "Common", BaseIncome = 1, GrowSeconds = 30, Role = "Income", NeedsWater = false, StemColor = Color3.fromRGB(62, 142, 65), HeadColor = Color3.fromRGB(255, 224, 102), HeadShape = "Ball" },
	{ Id = "PeaPopper", Name = "Pea Popper", Biome = "GreenMeadows", Rarity = "Common", BaseIncome = 0.5, GrowSeconds = 45, Role = "Projectile", NeedsWater = false, StemColor = Color3.fromRGB(62, 142, 65), HeadColor = Color3.fromRGB(120, 220, 90), HeadShape = "Ball" },
	{ Id = "Thornwall", Name = "Thornwall", Biome = "GreenMeadows", Rarity = "Uncommon", BaseIncome = 0.5, GrowSeconds = 60, Role = "Wall", NeedsWater = false, StemColor = Color3.fromRGB(90, 70, 40), HeadColor = Color3.fromRGB(60, 120, 50), HeadShape = "Block" },
	{ Id = "Capshroom", Name = "Capshroom", Biome = "MushroomForest", Rarity = "Rare", BaseIncome = 6, GrowSeconds = 120, Role = "AoE", NeedsWater = false, StemColor = Color3.fromRGB(255, 243, 224), HeadColor = Color3.fromRGB(255, 77, 77), HeadShape = "Cylinder" },
}

local byId: { [string]: Plant } = {}
for _, plant in list do
	byId[plant.Id] = plant
end

return {
	List = list,
	ById = byId,
}
