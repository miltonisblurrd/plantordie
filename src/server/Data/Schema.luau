--!strict
-- Profile shape, defaults, and migrations. Bump Config.Data.SchemaVersion and add a step to
-- `migrations` whenever the saved shape changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Biomes = require(ReplicatedStorage.Shared.Biomes)

export type PlantedTile = {
	species: string,
	rarity: string,
	size: string,
	variant: string, -- "Normal" | "Neon" | "Mega"
	plantedAt: number, -- os.time() on server
	matured: boolean?, -- placed back from inventory already grown
}

export type PlantItem = {
	id: string, -- unique per profile
	species: string,
	rarity: string,
	size: string,
	variant: string,
}

export type FusionSlot = {
	state: string, -- "Idle" | "Running" | "Ready"
	species: string?,
	rarity: string?,
	size: string?,
	startedAt: number,
	endsAt: number,
}

export type Profile = {
	version: number,
	money: number,
	plotIndex: number, -- reassigned every session
	houseTier: number,
	lanesUnlocked: number,
	biomesUnlocked: { [string]: boolean },
	seeds: { [string]: number }, -- species id -> count
	plants: { [string]: PlantItem }, -- inventory of grown/fused plants by item id
	nextItemId: number,
	planted: { [string]: PlantedTile }, -- tile key "lane_col" -> plant
	shovelTier: number,
	water: { channel: boolean, sprinkler: boolean, pond: boolean },
	fusion: { Neon: FusionSlot, Mega: FusionSlot },
	collection: { [string]: boolean }, -- "species|variant" discovered
	event: {
		currency: { [string]: number },
		inventory: { [string]: number },
		quests: { [string]: number },
	},
	growthBoostEndsAt: number,
	lastSeen: number, -- os.time() of the last successful save; drives offline earnings
	starterGranted: boolean,
	receiptLedger: { order: { string }, seen: { [string]: boolean } },
	stats: {
		firstJoin: number,
		lastJoin: number,
		joins: number,
		playSeconds: number,
		moneyEarned: number,
		seedsDug: number,
		plantsPlanted: number,
		zombiesKilled: number,
		nightsSurvived: number,
	},
	lock: { jobId: string, time: number }?,
}

local Schema = {}

local function idleSlot(): FusionSlot
	return { state = "Idle", startedAt = 0, endsAt = 0 }
end

function Schema.default(): Profile
	local now = os.time()
	return {
		version = Config.Data.SchemaVersion,
		money = Config.Start.Money,
		plotIndex = 0,
		houseTier = Config.Start.HouseTier,
		lanesUnlocked = Config.Start.LanesUnlocked,
		biomesUnlocked = { [Biomes.List[1].Id] = true },
		seeds = {},
		plants = {},
		nextItemId = 1,
		planted = {},
		shovelTier = Config.Start.ShovelTier,
		water = { channel = false, sprinkler = false, pond = false },
		fusion = { Neon = idleSlot(), Mega = idleSlot() },
		collection = {},
		event = { currency = {}, inventory = {}, quests = {} },
		growthBoostEndsAt = 0,
		lastSeen = 0,
		starterGranted = false,
		receiptLedger = { order = {}, seen = {} },
		stats = {
			firstJoin = now,
			lastJoin = now,
			joins = 0,
			playSeconds = 0,
			moneyEarned = 0,
			seedsDug = 0,
			plantsPlanted = 0,
			zombiesKilled = 0,
			nightsSurvived = 0,
		},
		lock = nil,
	}
end

-- Fills keys missing from `data` with defaults, recursing into tables that are records
-- (not maps keyed by player content such as seeds/planted, whose default is empty).
local function reconcile(data: { [any]: any }, defaults: { [any]: any })
	for k, v in defaults do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

-- migrations[n] upgrades a record from version n to n + 1.
local migrations: { [number]: (any) -> any } = {
	[0] = function(d)
		-- Unversioned record: keep any fields we recognise, defaults fill the rest.
		d.version = 1
		return d
	end,
	[1] = function(d)
		-- v1 keyed seeds by "species|rarity|size"; v2 stacks by species.
		local seeds = {}
		if type(d.seeds) == "table" then
			for key, count in d.seeds do
				if type(key) == "string" and type(count) == "number" then
					local species = string.match(key, "^[^|]+") or key
					seeds[species] = (seeds[species] or 0) + count
				end
			end
		end
		d.seeds = seeds
		d.version = 2
		return d
	end,
}

-- Returns a migrated, reconciled copy, or nil + reason if the record must not be touched.
function Schema.migrate(old: any): (Profile?, string?)
	if old == nil then
		return Schema.default(), nil
	end
	if type(old) ~= "table" then
		return nil, "corrupt record"
	end
	local data = old
	local v = if type(data.version) == "number" then data.version else 0
	if v > Config.Data.SchemaVersion then
		return nil, `record schema v{v} is newer than server v{Config.Data.SchemaVersion}`
	end
	while v < Config.Data.SchemaVersion do
		local step = migrations[v]
		if not step then
			return nil, `no migration from v{v}`
		end
		data = step(data)
		v = data.version
	end
	reconcile(data, Schema.default() :: any)
	return data :: Profile, nil
end

return Schema
