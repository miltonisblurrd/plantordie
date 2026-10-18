--!strict
-- Developer Products (spec §14). Id 0 = not created yet: the client never prompts it and the
-- server's receipt handler cannot match it, but the full receipt path is live.
-- Benefit is the exact text shown in the confirm dialog before Roblox's own price prompt.
export type Product = {
	Key: string,
	Id: number,
	PriceRobux: number, -- reference only; Roblox shows the real price
	Benefit: string,
	Seconds: number?, -- GrowthBoost duration
	Event: string?, -- HalloweenPack: Events id whose pack table is rolled
}

local list: { Product } = {
	{ Key = "InstantGrow", Id = 0, PriceRobux = 25, Benefit = "Instantly finish growing the plant you picked. If it has already grown, your longest-growing plant finishes instead." },
	{ Key = "NeonSkip", Id = 0, PriceRobux = 49, Benefit = "Finish your current Neon Maker fusion now. With no fusion running, you keep a skip to use later." },
	{ Key = "MegaSkip", Id = 0, PriceRobux = 99, Benefit = "Finish your current Mega Maker fusion now. With no fusion running, you keep a skip to use later." },
	{ Key = "GrowthBoost", Id = 0, PriceRobux = 79, Benefit = "2x growth speed for every plant for 30 minutes (stacks time if already active).", Seconds = 30 * 60 },
	{ Key = "HalloweenPack", Id = 0, PriceRobux = 149, Benefit = "One Halloween Seed Pack: 1 seed rolled from the odds table shown.", Event = "Halloween2026" },
}

local byKey: { [string]: Product } = {}
local byId: { [number]: Product } = {}
for _, prod in list do
	byKey[prod.Key] = prod
	if prod.Id ~= 0 then
		byId[prod.Id] = prod
	end
end

local Products = {
	List = list,
	ByKey = byKey,
	ById = byId,
}

function Products.enabled(key: string): boolean
	local p = byKey[key]
	return p ~= nil and p.Id ~= 0
end

return Products
