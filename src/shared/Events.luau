--!strict
-- Limited-time events (P5, spec §12). Windows are UTC unix seconds. A future event is another
-- entry in List: the event service reads everything (decor, shop, currency, quests) from here.
export type Odds = { Plant: string, Weight: number }
export type Quest = { Id: string, Name: string, Stat: "dig" | "nights" | "fuse", Goal: number, Reward: number }
export type Event = {
	Id: string,
	Name: string,
	StartsAt: number,
	EndsAt: number,
	Currency: string,
	Biome: string, -- Plants.Biome tag of the event species
	Decor: string, -- World/Builders/Events/<Decor>
	CurrencyPerNight: number, -- paid at dawn for a survived night while active
	DigReward: number, -- pumpkin dig spot
	DigCooldown: number,
	Pack: { Name: string, Cost: number, Seeds: number, Product: string, Odds: { Odds } },
	Quests: { Quest },
}

local Events = {
	List = {
		-- 2026-10-17 00:00 PT (07:00 UTC) through 2026-11-02 23:59:59 PT (2026-11-03 07:59:59 UTC)
		{
			Id = "Halloween2026",
			Name = "Halloween",
			StartsAt = 1792220400,
			EndsAt = 1793692799,
			Currency = "Candy",
			Biome = "halloween",
			Decor = "Halloween",
			CurrencyPerNight = 25,
			DigReward = 5,
			DigCooldown = 60,
			Pack = {
				Name = "Halloween Seed Pack",
				Cost = 150,
				Seeds = 1,
				Product = "HalloweenPack",
				Odds = {
					{ Plant = "PumpkinSprout", Weight = 40 },
					{ Plant = "GhostBlossom", Weight = 25 },
					{ Plant = "CandyCornPlant", Weight = 15 },
					{ Plant = "HauntedThornbush", Weight = 10 },
					{ Plant = "JackOLanternTree", Weight = 6 },
					{ Plant = "PhantomLily", Weight = 3 },
					{ Plant = "HeadlessHarvest", Weight = 1 },
				},
			},
			Quests = {
				{ Id = "dig", Name = "Dig 10 pumpkins", Stat = "dig", Goal = 10, Reward = 50 },
				{ Id = "nights", Name = "Survive 3 nights", Stat = "nights", Goal = 3, Reward = 75 },
				{ Id = "fuse", Name = "Claim 1 fusion", Stat = "fuse", Goal = 1, Reward = 100 },
			},
		},
	} :: { Event },
	ById = {} :: { [string]: Event },
}

for _, e in Events.List do
	Events.ById[e.Id] = e
end

function Events.active(now: number): Event?
	for _, e in Events.List do
		if now >= e.StartsAt and now <= e.EndsAt then
			return e
		end
	end
	return nil
end

-- Percent per plant, in table order; sums to 100.
function Events.odds(pack: { Odds: { Odds } }): { { Plant: string, Percent: number } }
	local total = 0
	for _, o in pack.Odds do
		total += o.Weight
	end
	local out = {}
	for _, o in pack.Odds do
		table.insert(out, { Plant = o.Plant, Percent = o.Weight / total * 100 })
	end
	return out
end

-- u in [0, 1). The server passes its own RNG roll; the client never rolls.
function Events.roll(pack: { Odds: { Odds } }, u: number): string
	local total = 0
	for _, o in pack.Odds do
		total += o.Weight
	end
	local pick = u * total
	for _, o in pack.Odds do
		pick -= o.Weight
		if pick < 0 then
			return o.Plant
		end
	end
	return pack.Odds[#pack.Odds].Plant
end

function Events.questKey(eventId: string, questId: string): string
	return eventId .. "|" .. questId
end

return Events
