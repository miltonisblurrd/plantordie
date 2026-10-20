--!strict
-- Speed trails sold at the hub Trails Shop. Multiplier scales treadmill Speed gain.
-- Colors run along the Trail; Particle drives the themed ParticleEmitter on the root part.

export type Particle = {
	Texture: string,
	Colors: { Color3 },
	Rate: number,
	LightEmission: number,
	Size: number,
	Lifetime: number,
	Speed: number,
}

export type Trail = {
	Id: string,
	Order: number,
	Name: string,
	Price: number,
	Multiplier: number,
	Colors: { Color3 },
	Kind: string,
	LightEmission: number,
	Width: number,
	Particle: Particle?,
}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function hex(...: string): { Color3 }
	local out = {}
	for _, h in { ... } do
		table.insert(out, Color3.fromHex(h))
	end
	return out
end

local list: { Trail } = {
	{
		Id = "Starter", Order = 1, Name = "Starter Trail", Price = 0, Multiplier = 1,
		Colors = hex("#FFFFFF", "#DDE6EE"), Kind = "A simple white streak.", LightEmission = 0.2, Width = 1.2,
	},
	{
		Id = "Nature", Order = 2, Name = "Nature Trail", Price = 5_000, Multiplier = 2,
		Colors = hex("#4CD964", "#1E9E3C"), Kind = "Green leaves with glowing particles.", LightEmission = 0.4, Width = 1.4,
		Particle = { Texture = SPARKLE, Colors = hex("#7CFF4F", "#2EAA46"), Rate = 14, LightEmission = 0.6, Size = 0.5, Lifetime = 0.9, Speed = 1.5 },
	},
	{
		Id = "Lightning", Order = 3, Name = "Lightning Trail", Price = 50_000, Multiplier = 4,
		Colors = hex("#7FD8FF", "#1F6BFF"), Kind = "Blue electrical sparks.", LightEmission = 0.9, Width = 1.4,
		Particle = { Texture = SPARKLE, Colors = hex("#E0F6FF", "#3FA9FF"), Rate = 22, LightEmission = 1, Size = 0.45, Lifetime = 0.35, Speed = 6 },
	},
	{
		Id = "Inferno", Order = 4, Name = "Inferno Trail", Price = 250_000, Multiplier = 6,
		Colors = hex("#FFB020", "#FF4A12"), Kind = "Orange flames and embers.", LightEmission = 0.8, Width = 1.6,
		Particle = { Texture = FIRE, Colors = hex("#FFD34A", "#FF3A0A"), Rate = 20, LightEmission = 0.9, Size = 0.9, Lifetime = 0.6, Speed = 2.5 },
	},
	{
		Id = "Mystic", Order = 5, Name = "Mystic Trail", Price = 1_000_000, Multiplier = 8,
		Colors = hex("#C77DFF", "#6A1FD0"), Kind = "Purple magical particles.", LightEmission = 0.8, Width = 1.6,
		Particle = { Texture = SPARKLE, Colors = hex("#E6B8FF", "#8A2BE2"), Rate = 18, LightEmission = 0.9, Size = 0.6, Lifetime = 1, Speed = 1.5 },
	},
	{
		Id = "Rainbow", Order = 6, Name = "Rainbow Trail", Price = 5_000_000, Multiplier = 12,
		Colors = hex("#FF3B3B", "#FFB020", "#FFF23B", "#3BE23B", "#2FB5FF", "#8A2BE2"), Kind = "Color-changing neon streaks.",
		LightEmission = 1, Width = 1.8,
		Particle = { Texture = SPARKLE, Colors = hex("#FF3B3B", "#FFF23B", "#3BE23B", "#2FB5FF", "#C77DFF"), Rate = 20, LightEmission = 1, Size = 0.55, Lifetime = 0.9, Speed = 2 },
	},
	{
		Id = "Golden", Order = 7, Name = "Golden Trail", Price = 25_000_000, Multiplier = 18,
		Colors = hex("#FFE27A", "#E0A800"), Kind = "Golden sparks and shimmering light.", LightEmission = 1, Width = 1.8,
		Particle = { Texture = SPARKLE, Colors = hex("#FFF6C8", "#FFC83D"), Rate = 26, LightEmission = 1, Size = 0.6, Lifetime = 0.8, Speed = 3 },
	},
	{
		Id = "Galaxy", Order = 8, Name = "Galaxy Trail", Price = 100_000_000, Multiplier = 25,
		Colors = hex("#1B1464", "#6A1FD0", "#FF5CC8"), Kind = "Cosmic dust, stars and nebula.", LightEmission = 0.9, Width = 2,
		Particle = { Texture = SPARKLE, Colors = hex("#FFFFFF", "#9C7BFF", "#FF5CC8"), Rate = 24, LightEmission = 1, Size = 0.5, Lifetime = 1.4, Speed = 1 },
	},
	{
		Id = "Void", Order = 9, Name = "Void Trail", Price = 500_000_000, Multiplier = 35,
		Colors = hex("#7A0019", "#14000A"), Kind = "Dark crimson energy with a distorted aura.", LightEmission = 0.4, Width = 2.2,
		Particle = { Texture = SMOKE, Colors = hex("#B0002A", "#1A0008"), Rate = 16, LightEmission = 0.3, Size = 1.4, Lifetime = 1.2, Speed = 1 },
	},
	{
		Id = "Divine", Order = 10, Name = "Divine Trail", Price = 2_500_000_000, Multiplier = 50,
		Colors = hex("#FFFFFF", "#FFE27A", "#FFC83D"), Kind = "Radiant white-and-gold energy with rainbow sparkles.", LightEmission = 1, Width = 2.4,
		Particle = { Texture = SPARKLE, Colors = hex("#FFFFFF", "#FF7AD9", "#7FD8FF", "#FFE27A"), Rate = 30, LightEmission = 1, Size = 0.7, Lifetime = 1.1, Speed = 2.5 },
	},
}

local byId: { [string]: Trail } = {}
for _, t in list do
	byId[t.Id] = t
end

return {
	List = list,
	ById = byId,
	DefaultId = "Starter",
}
