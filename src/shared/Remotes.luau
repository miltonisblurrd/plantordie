--!strict
-- Every remote in the game. Net creates these on the server; nothing else creates remotes.
-- Rate = sustained calls/second allowed from one player; Burst = bucket size.
export type RemoteDef = {
	Name: string,
	Kind: "Event" | "Function",
	Rate: number,
	Burst: number,
}

local list: { RemoteDef } = {
	-- server -> client
	{ Name = "StateSync", Kind = "Event", Rate = 0, Burst = 0 },
	{ Name = "DayNight", Kind = "Event", Rate = 0, Burst = 0 },
	{ Name = "Notify", Kind = "Event", Rate = 0, Burst = 0 },
	-- client -> server
	{ Name = "RequestState", Kind = "Event", Rate = 1, Burst = 3 },
	{ Name = "PlantSeed", Kind = "Event", Rate = 5, Burst = 8 }, -- P2
	{ Name = "BuyLane", Kind = "Event", Rate = 1, Burst = 2 }, -- P2
	{ Name = "BuyHouse", Kind = "Event", Rate = 1, Burst = 2 }, -- P2
	{ Name = "UnlockBiome", Kind = "Event", Rate = 1, Burst = 2 }, -- P3
	{ Name = "Dig", Kind = "Event", Rate = 4, Burst = 6 }, -- P3
	{ Name = "FusionStart", Kind = "Event", Rate = 1, Burst = 2 }, -- P5
	{ Name = "FusionClaim", Kind = "Event", Rate = 1, Burst = 2 }, -- P5
}

local byName: { [string]: RemoteDef } = {}
for _, r in list do
	byName[r.Name] = r
end

return {
	List = list,
	ByName = byName,
}
