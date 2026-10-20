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
	{ Name = "DigResult", Kind = "Event", Rate = 0, Burst = 0 },
	{ Name = "Chase", Kind = "Event", Rate = 0, Burst = 0 },
	{ Name = "CombatFx", Kind = "Event", Rate = 0, Burst = 0 },
	{ Name = "SpeedGain", Kind = "Event", Rate = 0, Burst = 0 },
	-- client -> server
	{ Name = "RequestState", Kind = "Event", Rate = 1, Burst = 3 },
	{ Name = "PlantSeed", Kind = "Event", Rate = 5, Burst = 8 },
	{ Name = "PlacePlant", Kind = "Event", Rate = 5, Burst = 8 },
	{ Name = "RemovePlant", Kind = "Event", Rate = 4, Burst = 6 },
	{ Name = "BuyLane", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "BuyHouse", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "UnlockBiome", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "BuyShovel", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "EquipShovel", Kind = "Event", Rate = 2, Burst = 4 },
	{ Name = "BuyTrail", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "EquipTrail", Kind = "Event", Rate = 2, Burst = 4 },
	{ Name = "Dig", Kind = "Event", Rate = 4, Burst = 6 },
	{ Name = "Repair", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "UseTrap", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "HitZombie", Kind = "Event", Rate = 5, Burst = 8 },
	{ Name = "BuyWater", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "BuyPortal", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "FusionUnlock", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "FusionStart", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "FusionClaim", Kind = "Event", Rate = 2, Burst = 4 },
	{ Name = "PurchaseIntent", Kind = "Event", Rate = 2, Burst = 4 },
	{ Name = "UseCredit", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "EventBuyPack", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "EventDig", Kind = "Event", Rate = 1, Burst = 2 },
	{ Name = "UpgradeTreadmill", Kind = "Event", Rate = 2, Burst = 3 },
	{ Name = "DropSeed", Kind = "Event", Rate = 1, Burst = 2 },
}

local byName: { [string]: RemoteDef } = {}
for _, r in list do
	byName[r.Name] = r
end

return {
	List = list,
	ByName = byName,
}
