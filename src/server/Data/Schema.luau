--!strict
-- Profile shape, defaults, and migrations. Bump Config.Data.SchemaVersion and add a step to
-- `migrations` whenever the saved shape changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

export type PlantedTile = {
	species: string,
	rarity: string,
	size: string,
	variant: string, -- "Normal" | "Neon" | "Mega"
	plantedAt: number, -- os.time() on server
	matured: boolean?, -- placed back from inventory already grown
	uid: string?, -- unique per planting (from nextItemId); purchase intents target this
}

export type PlantItem = {
	id: string, -- unique per profile
	species: string,
	rarity: string,
	size: string,
	variant: string,
}

-- Fusion state machine (spec §11): "empty" -> "fusing" -> "ready" -> claimed (back to "empty").
-- "ready" is pure timestamp math (os.time() >= endsAt), so offline fusions finish on their own.
-- `last` remembers the most recent claim so a duplicate claim returns it instead of a new plant.
export type FusionSlot = {
	unlocked: boolean,
	state: string, -- "empty" | "fusing" | "ready"
	runId: number, -- increments on every start
	species: string?,
	rarity: string?,
	size: string?,
	startedAt: number, -- server os.time()
	endsAt: number,
	ingredients: { PlantItem }?,
	last: { runId: number, itemId: string, claimed: boolean }?,
}

export type PendingGrant = { key: string, arg: string? }

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
	shovelTier: number, -- mirror of shovels.equipped for older readers
	-- owned is keyed by tostring(tier): DataStores reject sparse number-keyed maps.
	shovels: { owned: { [string]: boolean }, equipped: number },
	portalTier: number,
	speed: number,
	treadmillLevel: number,
	trails: { owned: { [string]: boolean }, equipped: string },
	-- Legacy unbanked bag, always empty since v9 (banked into `seeds` by the migration).
	expedition: { [string]: number },
	water: { channel: boolean, sprinkler: boolean, pond: boolean },
	fusion: { Neon: FusionSlot, Mega: FusionSlot },
	collection: { [string]: boolean }, -- "species|variant" discovered
	event: {
		currency: { [string]: number },
		inventory: { [string]: number },
		quests: { [string]: number }, -- "eventId|questId" -> progress
		questsDone: { [string]: boolean },
	},
	credits: { [string]: number }, -- Robux products granted with nothing to apply to yet
	-- Saved target of the product the player is about to buy (InstantGrow -> plant uid). The
	-- receipt reads it from here, so the grant can only ever finish that plant.
	purchaseIntent: { [string]: string },
	growthBoostEndsAt: number,
	lastSeen: number, -- os.time() of the last successful save; drives offline earnings
	starterGranted: boolean,
	-- PurchaseIds already processed (capped). `pending` holds grants whose ledger entry is saved
	-- but whose effect is not yet applied; they are applied on the next load.
	receiptLedger: { order: { string }, seen: { [string]: boolean }, pending: { [string]: PendingGrant } },
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
	return { unlocked = false, state = "empty", runId = 0, startedAt = 0, endsAt = 0 }
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
		shovels = { owned = { [tostring(Config.Start.ShovelTier)] = true }, equipped = Config.Start.ShovelTier },
		portalTier = 1,
		speed = 0,
		treadmillLevel = 1,
		trails = { owned = { Starter = true }, equipped = "Starter" },
		expedition = {},
		water = { channel = false, sprinkler = false, pond = false },
		fusion = { Neon = idleSlot(), Mega = idleSlot() },
		collection = {},
		event = { currency = {}, inventory = {}, quests = {}, questsDone = {} },
		credits = {},
		purchaseIntent = {},
		growthBoostEndsAt = 0,
		lastSeen = 0,
		starterGranted = false,
		receiptLedger = { order = {}, seen = {}, pending = {} },
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
	[2] = function(d)
		-- v3 adds the expedition bag; reconcile fills it with an empty map.
		d.version = 3
		return d
	end,
	[3] = function(d)
		-- v4 replaces the unused fusion stub with the real state machine; reconcile refills it.
		d.fusion = nil
		d.version = 4
		return d
	end,
	[4] = function(d)
		-- v5 gives every planted plant a uid so purchase intents can target it.
		if type(d.planted) == "table" then
			local nextId = if type(d.nextItemId) == "number" then d.nextItemId else 1
			for _, rec in d.planted do
				if type(rec) == "table" and rec.uid == nil then
					rec.uid = tostring(nextId)
					nextId += 1
				end
			end
			d.nextItemId = nextId
		end
		d.version = 5
		return d
	end,
	[5] = function(d)
		d.portalTier = 1
		d.version = 6
		return d
	end,
	[6] = function(d)
		-- v7 adds speed, the treadmill level and trails. A non-table `trails` would block reconcile.
		if type(d.trails) ~= "table" then
			d.trails = nil
		elseif type(d.trails.owned) ~= "table" then
			d.trails.owned = nil
		end
		d.version = 7
		return d
	end,
	[7] = function(d)
		-- v8 owns shovels individually; every tier up to the old one stays owned and equipped.
		local tier = if type(d.shovelTier) == "number" then math.clamp(math.floor(d.shovelTier), 1, #Upgrades.Shovels) else 1
		local owned = {}
		for t = 1, tier do
			owned[tostring(t)] = true
		end
		d.shovels = { owned = owned, equipped = tier }
		d.version = 8
		return d
	end,
	[8] = function(d)
		-- v9 carries one seed at a time and never saves it; the old bag is banked into seeds.
		if type(d.expedition) == "table" then
			if type(d.seeds) ~= "table" then
				d.seeds = {}
			end
			for species, c in d.expedition do
				if type(species) == "string" and type(c) == "number" and c > 0 then
					d.seeds[species] = (if type(d.seeds[species]) == "number" then d.seeds[species] else 0) + math.floor(c)
				end
			end
		end
		d.expedition = {}
		d.version = 9
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
	-- reconcile recursed into the non-empty owned map, which only ever adds Starter (always owned).
	if type(data.trails.equipped) ~= "string" or not data.trails.owned[data.trails.equipped] then
		data.trails.equipped = "Starter"
	end
	if type(data.shovels) ~= "table" then
		data.shovels = { owned = { ["1"] = true }, equipped = 1 }
	elseif type(data.shovels.owned) ~= "table" then
		data.shovels.owned = { ["1"] = true }
	end
	local eq = data.shovels.equipped
	if type(eq) ~= "number" or not Upgrades.Shovels[eq] or not data.shovels.owned[tostring(eq)] then
		data.shovels.equipped = 1
	end
	data.shovelTier = data.shovels.equipped
	return data :: Profile, nil
end

return Schema
