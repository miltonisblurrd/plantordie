--!strict
-- Plant definitions (spec §4). Every biome gets 3+ species; P3 adds the rest per biome.
-- Rule of thumb: higher rarity = higher BaseIncome and longer GrowSeconds.

export type Shape = "Ball" | "Block" | "Cylinder" | "Wedge"
export type Accent = "Leaves" | "Petals" | "Spikes" | "Cap" | "None"

export type ModelRecipe = {
	StemShape: "Cylinder" | "Block",
	StemColor: Color3,
	StemHeight: number, -- studs at Medium size, grown
	HeadShape: Shape,
	HeadColor: Color3,
	HeadSize: number,
	Accent: Accent,
	AccentColor: Color3,
}

export type Combat = {
	Role: "Projectile" | "Rapid" | "AoE" | "Slow" | "Burn" | "Wall" | "Income",
	Damage: number,
	AttackRate: number, -- attacks per second (0 for walls)
	Range: number, -- tiles along the lane
	Ability: string?,
	WallHp: number?,
}

export type Plant = {
	Id: string,
	Name: string,
	Biome: string,
	Rarity: string,
	BaseIncome: number, -- $/sec before multipliers
	GrowSeconds: number,
	SizeWeights: { [string]: number }?, -- overrides Sizes weights when present
	Model: ModelRecipe,
	Combat: Combat?,
	WaterDependent: boolean,
	Description: string,
}

export type Variant = {
	Id: string,
	IncomeMultiplier: number,
	Neon: boolean, -- Neon head + PointLight + slow particle
	Rainbow: boolean, -- client hue cycle + sparkles
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Plant } = {
	-- Green Meadows
	{
		Id = "Sunpetal", Name = "Sunpetal", Biome = "GreenMeadows", Rarity = "Common",
		BaseIncome = 2, GrowSeconds = 30, WaterDependent = false,
		Description = "A cheerful money flower. Pure income.",
		Model = {
			StemShape = "Cylinder", StemColor = rgb(62, 142, 65), StemHeight = 3,
			HeadShape = "Ball", HeadColor = rgb(255, 224, 102), HeadSize = 2,
			Accent = "Petals", AccentColor = rgb(255, 160, 40),
		},
		Combat = { Role = "Income", Damage = 0, AttackRate = 0, Range = 0 },
	},
	{
		Id = "PeaPopper", Name = "Pea Popper", Biome = "GreenMeadows", Rarity = "Common",
		BaseIncome = 1, GrowSeconds = 45, WaterDependent = false,
		Description = "Fires peas down its lane at night.",
		Model = {
			StemShape = "Cylinder", StemColor = rgb(52, 130, 60), StemHeight = 3.2,
			HeadShape = "Ball", HeadColor = rgb(120, 220, 90), HeadSize = 2.2,
			Accent = "Leaves", AccentColor = rgb(40, 110, 50),
		},
		Combat = { Role = "Projectile", Damage = 5, AttackRate = 1, Range = 9 },
	},
	{
		Id = "Thornwall", Name = "Thornwall", Biome = "GreenMeadows", Rarity = "Uncommon",
		BaseIncome = 3, GrowSeconds = 75, WaterDependent = false,
		Description = "A thorny hedge that stalls zombies.",
		Model = {
			StemShape = "Block", StemColor = rgb(90, 70, 40), StemHeight = 1.2,
			HeadShape = "Block", HeadColor = rgb(60, 130, 50), HeadSize = 3.4,
			Accent = "Spikes", AccentColor = rgb(230, 230, 200),
		},
		Combat = { Role = "Wall", Damage = 1, AttackRate = 0.5, Range = 0, WallHp = 120, Ability = "Thorns" },
	},
	{
		Id = "CloverCharm", Name = "Clover Charm", Biome = "GreenMeadows", Rarity = "Rare",
		BaseIncome = 9, GrowSeconds = 150, WaterDependent = false,
		Description = "Lucky four-leaf clover. Big income, slow to grow.",
		Model = {
			StemShape = "Cylinder", StemColor = rgb(40, 150, 70), StemHeight = 3.6,
			HeadShape = "Cylinder", HeadColor = rgb(70, 220, 110), HeadSize = 2.4,
			Accent = "Leaves", AccentColor = rgb(58, 141, 255),
		},
		Combat = { Role = "Income", Damage = 0, AttackRate = 0, Range = 0 },
	},
	-- Mushroom Forest (P3 completes this biome's roster)
	{
		Id = "Capshroom", Name = "Capshroom", Biome = "MushroomForest", Rarity = "Rare",
		BaseIncome = 25, GrowSeconds = 180, WaterDependent = false,
		Description = "Releases a spore burst that hits nearby zombies.",
		Model = {
			StemShape = "Cylinder", StemColor = rgb(255, 243, 224), StemHeight = 2.4,
			HeadShape = "Cylinder", HeadColor = rgb(255, 77, 77), HeadSize = 3,
			Accent = "Cap", AccentColor = rgb(255, 255, 255),
		},
		Combat = { Role = "AoE", Damage = 8, AttackRate = 0.5, Range = 2 },
	},
}

local byId: { [string]: Plant } = {}
local byBiome: { [string]: { Plant } } = {}
for _, plant in list do
	byId[plant.Id] = plant
	byBiome[plant.Biome] = byBiome[plant.Biome] or {}
	table.insert(byBiome[plant.Biome], plant)
end

local variants: { [string]: Variant } = {
	Normal = { Id = "Normal", IncomeMultiplier = 1, Neon = false, Rainbow = false },
	Neon = { Id = "Neon", IncomeMultiplier = 3, Neon = true, Rainbow = false },
	Mega = { Id = "Mega", IncomeMultiplier = 10, Neon = true, Rainbow = true },
}

return {
	List = list,
	ById = byId,
	ByBiome = byBiome,
	Variants = variants,
}
