--!strict
-- Developer Product IDs. Placeholders (0) until the owner creates real products.
export type Product = {
	Key: string,
	Id: number,
	PriceRobux: number,
	Benefit: string,
}

local list: { Product } = {
	{ Key = "InstantGrow", Id = 0, PriceRobux = 25, Benefit = "Instantly finish growing every plant in your garden." },
	{ Key = "NeonSkip", Id = 0, PriceRobux = 49, Benefit = "Finish the current Neon Maker fusion now." },
	{ Key = "MegaSkip", Id = 0, PriceRobux = 99, Benefit = "Finish the current Mega Maker fusion now." },
	{ Key = "GrowthBoost", Id = 0, PriceRobux = 79, Benefit = "2x growth speed for 30 minutes." },
	{ Key = "HalloweenPack", Id = 0, PriceRobux = 149, Benefit = "Halloween seed bundle plus event currency." },
}

local byKey: { [string]: Product } = {}
for _, prod in list do
	byKey[prod.Key] = prod
end

return {
	List = list,
	ByKey = byKey,
}
