--!strict
-- Neon / Mega makers (P5, spec §11). 4 identical fully grown plants in, 1 upgraded variant out.
-- "Identical" = same species AND same size AND the machine's input variant; rarity follows the
-- species, so it always matches. Species, rarity and size carry over to the result.
-- Ingredients come from the plant inventory (dig a grown plant up to fuse it).

export type Machine = {
	Id: "Neon" | "Mega",
	Name: string,
	Input: string, -- required ingredient variant
	Output: string, -- result variant
	Seconds: { [string]: number }, -- fusion time by rarity
	UnlockCost: number, -- one-time money cost to build the machine on its pad
	SkipProduct: string, -- Products key
	Pad: string, -- plot pad name
	Color: Color3,
}

local neon: Machine = {
	Id = "Neon",
	Name = "Neon Maker",
	Input = "Normal",
	Output = "Neon",
	Seconds = { Common = 30, Uncommon = 120, Rare = 300, Epic = 900, Legendary = 1800, Mythical = 3600, Divine = 3 * 3600 },
	UnlockCost = 250_000,
	SkipProduct = "NeonSkip",
	Pad = "NeonMakerPad",
	Color = Color3.fromRGB(80, 255, 220),
}

local mega: Machine = {
	Id = "Mega",
	Name = "Mega Maker",
	Input = "Neon",
	Output = "Mega",
	Seconds = { Common = 120, Uncommon = 300, Rare = 900, Epic = 1800, Legendary = 3600, Mythical = 3 * 3600, Divine = 8 * 3600 },
	UnlockCost = 25_000_000,
	SkipProduct = "MegaSkip",
	Pad = "MegaMakerPad",
	Color = Color3.fromRGB(255, 90, 220),
}

return {
	InputCount = 4,
	RequireSameSize = true,
	Machines = { Neon = neon, Mega = mega } :: { [string]: Machine },
	Order = { neon, mega },
}
