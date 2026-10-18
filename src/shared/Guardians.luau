--!strict
-- One guardian per biome (P3).
export type Guardian = { Biome: string, Name: string, WalkSpeed: number, ChaseSpeed: number, DetectRange: number, LeashRange: number }

return {
	{ Biome = "GreenMeadows", Name = "Scarecrow Sentinel", WalkSpeed = 8, ChaseSpeed = 14, DetectRange = 40, LeashRange = 120 },
	{ Biome = "MushroomForest", Name = "Spore Brute", WalkSpeed = 8, ChaseSpeed = 15, DetectRange = 45, LeashRange = 120 },
} :: { Guardian }
