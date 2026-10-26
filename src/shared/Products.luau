--!strict
-- Product ids (owner step): create each Developer Product on this experience in the Creator
-- Dashboard and paste its numeric id here. Never grant from the client; grants happen only in
-- the server's ProcessReceipt. Id 0 keeps the product's prompt disabled.
--
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
	{ Key = "InstantGrow", Id = 3719421531, PriceRobux = 27, Benefit = "Instantly finish growing the plant you picked. If that plant is gone or grown by the time the purchase completes, you keep an Instant Grow credit to use on any growing plant." },
	{ Key = "NeonSkip", Id = 3719421808, PriceRobux = 27, Benefit = "Finish your current Neon Maker fusion now. With no fusion running, you keep a skip to use later." },
	{ Key = "MegaSkip", Id = 3719422040, PriceRobux = 39, Benefit = "Finish your current Mega Maker fusion now. With no fusion running, you keep a skip to use later." },
	{ Key = "GrowthBoost", Id = 3719422286, PriceRobux = 4, Benefit = "2x growth speed for every plant for 30 minutes (stacks time if already active).", Seconds = 30 * 60 },
	{ Key = "HalloweenPack", Id = 3719422493, PriceRobux = 149, Benefit = "One Halloween Seed Pack: 1 seed rolled from the odds table shown.", Event = "Halloween2026" },
	{ Key = "Unstun", Id = 3719797623, PriceRobux = 11, Benefit = "Instantly wakes the stunned plant you picked. It can attack again and starts earning money right away." },
	{ Key = "TreadmillLevel", Id = 0, PriceRobux = 499, Benefit = "Upgrade your treadmill by one level." },
}

local Boosts = require(script.Parent.RobuxBoosts)
for _, tier in Boosts.Speed do
	table.insert(list, { Key = tier.Key, Id = 0, PriceRobux = tier.Price, Benefit = tier.Benefit })
end
for _, tier in Boosts.Luck do
	table.insert(list, { Key = tier.Key, Id = 0, PriceRobux = tier.Price, Benefit = tier.Benefit })
end


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
