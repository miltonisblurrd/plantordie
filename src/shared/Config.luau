--!strict
-- Global tuning. Every number the server uses lives here or in a sibling data table.

local Config = {
	Data = {
		StoreName = "PlantOrDie_Profiles_v2",
		KeyPrefix = "player_",
		SchemaVersion = 1,
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
