--!strict
-- One unique guardian per biome (spec §6). Later biomes recompute their path more often and lead
-- their target (Predict = seconds of velocity look-ahead). Speed is not stored here: chase speed
-- comes from the biome's RecommendedSpeed via Speed.guardianSpeedFor.
export type Shape = "Scarecrow" | "Brute" | "Spiky" | "Squat" | "Tall" | "Floating" | "Crab" | "Golem"
export type Guardian = {
	Biome: string,
	Name: string,
	Shape: Shape,
	Body: Color3,
	Trim: Color3,
	Eyes: Color3,
	Scale: number,
	CatchRange: number,
	RecomputeSeconds: number,
	Predict: number,
	RecommendedSpeed: number?, -- event guardians only; biome guardians use their biome's
}

local function g(
	biome: string, name: string, shape: Shape, body: string, trim: string, eyes: string, scale: number,
	recompute: number, predict: number
): Guardian
	return {
		Biome = biome, Name = name, Shape = shape, Scale = scale,
		Body = Color3.fromHex(body), Trim = Color3.fromHex(trim), Eyes = Color3.fromHex(eyes),
		CatchRange = 4 + scale, RecomputeSeconds = recompute, Predict = predict,
	}
end

local list: { Guardian } = {
	g("GreenMeadows", "Scarecrow Sentinel", "Scarecrow", "#C9A15B", "#3E8E41", "#FF3B3B", 1.0, 1.2, 0),
	g("MushroomForest", "Fungal Brute", "Brute", "#6B4F8C", "#FF4D4D", "#7CFFCB", 1.1, 1.15, 0),
	g("CactusCanyon", "Thornback Coyote", "Spiky", "#D9A066", "#3FA34D", "#FFC300", 1.0, 1.1, 0),
	g("InfernoJungle", "Magma Golem", "Golem", "#3D2B1F", "#FF5A1F", "#FFC300", 1.3, 1.05, 0),
	g("FrostbiteGarden", "Frost Yeti", "Brute", "#E6F4FF", "#7FD3FF", "#4A90C2", 1.3, 1.0, 0.2),
	g("EnchantedGrove", "Thorn Witch", "Tall", "#5A3E85", "#C77DFF", "#7CFFCB", 1.1, 0.95, 0.25),
	g("TropicalParadise", "Tiki Stomper", "Squat", "#A0522D", "#00C2A8", "#FF6F61", 1.2, 0.9, 0.3),
	g("CoralKingdom", "Reef Crab King", "Crab", "#FF7F50", "#FFD1DC", "#2A9DF4", 1.2, 0.85, 0.35),
	g("AutumnWoods", "Pumpkin Lord", "Scarecrow", "#FF7518", "#6B3E26", "#FFE066", 1.2, 0.8, 0.4),
	g("SkyIslands", "Storm Wisp", "Floating", "#8EC9FF", "#FFFFFF", "#FFF35C", 1.1, 0.75, 0.45),
	g("CrystalCaverns", "Shard Sentinel", "Golem", "#8A7FFF", "#5CE1E6", "#FF66C4", 1.3, 0.7, 0.5),
	g("ToxicSwamp", "Bog Lurker", "Squat", "#4B5D2A", "#A6FF00", "#8E44AD", 1.2, 0.65, 0.55),
	g("AncientWilds", "Raptor Warden", "Spiky", "#8F9779", "#D4A373", "#FFB000", 1.2, 0.6, 0.6),
	g("CosmicGarden", "Star Devourer", "Floating", "#1B1035", "#4CC9F0", "#FFD6FF", 1.3, 0.55, 0.7),
	g("ForbiddenBloom", "The Gardener Below", "Tall", "#2B0A12", "#FF1E56", "#FFD700", 1.4, 0.5, 0.8),
}

-- Event guardians, keyed by Events id. Only exist while that event is active. Slightly faster
-- than Green Meadows's but far from endgame.
local event: { [string]: Guardian } = {
	Halloween2026 = g("halloween", "Headless Haunt", "Floating", "#2E1A47", "#FF7518", "#B6FF3B", 1.1, 1.1, 0.1),
}
event.Halloween2026.RecommendedSpeed = 1000

local byBiome: { [string]: Guardian } = {}
for _, gd in list do
	byBiome[gd.Biome] = gd
end

return {
	List = list,
	ByBiome = byBiome,
	Event = event,
}
