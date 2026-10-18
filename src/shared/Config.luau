--!strict
-- Global tuning. Every number the server uses lives here or in a sibling data table.

local Config = {
	Data = {
		StoreName = "PlantOrDie_Profiles_v2",
		KeyPrefix = "player_",
		SchemaVersion = 2,
		AutosaveSeconds = 60,
		LockStaleSeconds = 30 * 60,
		Retries = 3,
		RetryBaseDelay = 1, -- seconds; doubles each attempt
		ReceiptLedgerCap = 200,
		BindToCloseTimeout = 25,
		KickMessage = "We couldn't load your garden safely, so we stopped before anything was lost. Please rejoin in a minute!",
	},

	Start = {
		Money = 100,
		HouseTier = 1,
		LanesUnlocked = 3,
		ShovelTier = 1,
	},

	World = {
		HubRadius = 95,
		GateRingRadius = 118,
		PlotRingRadius = 300,
		PlotCount = 8,
		BiomeAnchorRadius = 1400,
		GroundY = 0,
	},

	Plot = {
		Width = 170, -- along lanes (local X)
		Depth = 110, -- across lanes (local Z)
		TileSize = 8,
		Lanes = 7,
		Columns = 9,
		GardenOriginX = -42, -- local X of column 1's left edge
		HouseX = -66, -- local X of house centre
		ZombieSpawnX = 70,
	},

	Garden = {
		TickSeconds = 1,
		MaxPlantDistance = 60, -- studs from character to tile
		OfflineCapHours = 4,
		OfflineRate = 0.5, -- fraction of live income paid while offline
		BoostGrowthMultiplier = 2,
		-- Removing a plant: grown plants go to the plant inventory (keeps size/variant for fusion);
		-- unripe plants are destroyed and refund this many seeds (0 = none).
		UnripeSeedRefund = 0,
		StarterSeeds = { Sunpetal = 5, PeaPopper = 3, Thornwall = 1 } :: { [string]: number },
	},

	DayNight = {
		DaySeconds = 240,
		NightSeconds = 120,
		DayClockStart = 6.5,
		DayClockEnd = 18.5,
		NightClockEnd = 30.5, -- wraps past midnight to 06:30
	},

	Sync = {
		AreaCheckSeconds = 0.5,
	},
}

return Config
