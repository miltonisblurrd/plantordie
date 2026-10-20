--!strict
export type Palette = {
	Ground: Color3,
	Accent1: Color3,
	Accent2: Color3,
	Prop: Color3,
}

export type Biome = {
	Index: number,
	Id: string,
	Name: string,
	Emoji: string,
	RecommendedSpeed: number, -- display-only hint on the biome banner
	Cost: number,
	Palette: Palette,
	Released: boolean, -- false = gate shown but region always bounces players (A7)
	DigStyle: DigStyle,
	ToughTier: number, -- shovel tier needed for this biome's tough-soil spots
}

export type DigStyle = "Mound" | "Rock" | "Glow" 

local function p(g: string, a1: string, a2: string, prop: string): Palette
	return {
		Ground = Color3.fromHex(g),
		Accent1 = Color3.fromHex(a1),
		Accent2 = Color3.fromHex(a2),
		Prop = Color3.fromHex(prop),
	}
end

-- Order is gameplay order. Costs track garden income and the shovel ladder: free, $50K, then
-- x3-x12 per biome to $4.5T (studio/tasks/balance-pass/pacing.md). Must strictly increase.
-- Adjacent biomes never share a ground colour (brand.md).
local list: { Biome } = ({
	{ Index = 1, Id = "GreenMeadows", Name = "Green Meadows", Emoji = "🌱", RecommendedSpeed = 100, Cost = 0, Palette = p("#5BD15B", "#FFE066", "#FF8FB1", "#3E8E41") },
	{ Index = 2, Id = "MushroomForest", Name = "Mushroom Forest", Emoji = "🍄", RecommendedSpeed = 10_000, Cost = 50_000, Palette = p("#6B4F8C", "#FF4D4D", "#FFF3E0", "#8B5A2B") },
	{ Index = 3, Id = "CactusCanyon", Name = "Cactus Canyon", Emoji = "🌵", RecommendedSpeed = 100_000, Cost = 1_200_000, Palette = p("#E8B86D", "#3FA34D", "#D9643A", "#A0522D") },
	{ Index = 4, Id = "InfernoJungle", Name = "Inferno Jungle", Emoji = "🔥", RecommendedSpeed = 1e6, Cost = 10_000_000, Palette = p("#3D2B1F", "#FF5A1F", "#FFC300", "#1F7A3A") },
	{ Index = 5, Id = "FrostbiteGarden", Name = "Frostbite Garden", Emoji = "❄️", RecommendedSpeed = 1e7, Cost = 100_000_000, Palette = p("#E6F4FF", "#7FD3FF", "#B9A8FF", "#4A90C2") },
	{ Index = 6, Id = "EnchantedGrove", Name = "Enchanted Grove", Emoji = "🌳", RecommendedSpeed = 1e8, Cost = 350_000_000, Palette = p("#2E8B57", "#C77DFF", "#7CFFCB", "#5A3E85") },
	{ Index = 7, Id = "TropicalParadise", Name = "Tropical Paradise", Emoji = "🌴", RecommendedSpeed = 1e9, Cost = 450_000_000, Palette = p("#F7E1A0", "#00C2A8", "#FF6F61", "#2DAA4F") },
	{ Index = 8, Id = "CoralKingdom", Name = "Coral Kingdom", Emoji = "🪸", RecommendedSpeed = 5e9, Cost = 1_350_000_000, Palette = p("#2A9DF4", "#FF7F50", "#FFD1DC", "#F4A261") },
	{ Index = 9, Id = "AutumnWoods", Name = "Autumn Woods", Emoji = "🍂", RecommendedSpeed = 1e10, Cost = 4_200_000_000, Palette = p("#B5651D", "#FF8C00", "#C0392B", "#6B3E26") },
	{ Index = 10, Id = "SkyIslands", Name = "Sky Islands", Emoji = "☁️", RecommendedSpeed = 2.5e10, Cost = 11_000_000_000, Palette = p("#9FE870", "#FFFFFF", "#8EC9FF", "#C2B280") },
	{ Index = 11, Id = "CrystalCaverns", Name = "Crystal Caverns", Emoji = "💎", RecommendedSpeed = 5e10, Cost = 40_000_000_000, Palette = p("#3B3B58", "#5CE1E6", "#FF66C4", "#8A7FFF") },
	{ Index = 12, Id = "ToxicSwamp", Name = "Toxic Swamp", Emoji = "☣️", RecommendedSpeed = 1e11, Cost = 125_000_000_000, Palette = p("#4B5D2A", "#A6FF00", "#8E44AD", "#2F3B1C") },
	{ Index = 13, Id = "AncientWilds", Name = "Ancient Wilds", Emoji = "🏛️", RecommendedSpeed = 2.5e11, Cost = 350_000_000_000, Palette = p("#8F9779", "#D4A373", "#6A994E", "#5C4033") },
	{ Index = 14, Id = "CosmicGarden", Name = "Cosmic Garden", Emoji = "🌌", RecommendedSpeed = 5e14, Cost = 1_100_000_000_000, Palette = p("#1B1035", "#FFD6FF", "#4CC9F0", "#7209B7") },
	{ Index = 15, Id = "ForbiddenBloom", Name = "Forbidden Bloom", Emoji = "🌺", RecommendedSpeed = 1e15, Cost = 4_500_000_000_000, Palette = p("#2B0A12", "#FF1E56", "#FFD700", "#5E0B15") },
} :: any)

local DIG_STYLE: { [string]: DigStyle } = {
	GreenMeadows = "Mound", MushroomForest = "Mound", CactusCanyon = "Rock", InfernoJungle = "Rock",
	FrostbiteGarden = "Glow", EnchantedGrove = "Glow", TropicalParadise = "Mound", CoralKingdom = "Rock",
	AutumnWoods = "Mound", SkyIslands = "Glow", CrystalCaverns = "Glow", ToxicSwamp = "Mound",
	AncientWilds = "Rock", CosmicGarden = "Glow", ForbiddenBloom = "Glow",
}

local byId: { [string]: Biome } = {}
for _, b in list do
	b.Released = true
	b.DigStyle = DIG_STYLE[b.Id] or "Mound"
	b.ToughTier = if b.Index <= 5 then 2 elseif b.Index <= 10 then 3 else 4
	byId[b.Id] = b
end

return {
	List = list,
	ById = byId,
	Count = #list,
}
