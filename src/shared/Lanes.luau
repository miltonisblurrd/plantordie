--!strict
-- Lane unlock prices. Index = lane number (1 = top row). Price 0 = free at start.
local Lanes = {
	Prices = { 0, 0, 0, 5_000, 50_000, 500_000, 5_000_000 } :: { number },
}

function Lanes.price(lane: number): number?
	return Lanes.Prices[lane]
end

return Lanes
