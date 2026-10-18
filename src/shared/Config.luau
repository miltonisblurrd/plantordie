--!strict
-- Global tuning. Every number the server uses lives here or in a sibling data table.

local Config = {
	Data = {
		StoreName = "PlantOrDie_Profiles_v2",
		KeyPrefix = "player_",
		SchemaVersion = 4,
		AutosaveSeconds = 60,
		LockStaleSeconds = 30 * 60,
		Retries = 3,
		RetryBaseDelay = 1, -- seconds; doubles each attempt
		ReceiptLedgerCap = 200,
		BindToCloseTimeout = 25,
		KickMessage = "We couldn't load your garden safely, so we stopped before anything was lost. Please rejoin in a minute!",
	},

	-- Income multiplier per variant (spec §11). Applied on top of rarity x size, so a Mega Divine
	-- stays far above a Mega Common (25x rarity gap is preserved).
	Economy = {
		VariantMultiplier = { Normal = 1, Neon = 3, Mega = 8 },
	},

	Event = {
		CheckSeconds = 10, -- how often the event manager re-reads the window
		DigRange = 14, -- studs from the pumpkin patch
		FogColor = Color3.fromRGB(70, 30, 100),
		FogStart = 60,
		FogEnd = 700,
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
		GroundY = 0,
	},

	-- Biome areas sit on an outer ring, two per gap between plots, each a square region whose
	-- -Z side (the entrance) faces the hub. Baseplate covers out to BiomeRingRadius + Size/2.
	Biome = {
		RingRadius = 760,
		Size = 240,
		SafeRadius = 18, -- safe zone circle just inside the entrance
		DigSpots = 10,
		ToughSpots = 3,
		EnforceSeconds = 0.5, -- locked-region check interval
		PathWidth = 10,
	},

	Dig = {
		Range = 12, -- studs from character to spot
		RespawnSeconds = 45,
		MaxLuck = 0.5,
	},

	Bank = {
		HubRadius = 26, -- fountain bank point; your own plot also banks
		CheckSeconds = 0.5,
	},

	Guardian = {
		TickSeconds = 0.1,
		StuckSeconds = 3, -- no progress toward the target for this long -> give up, patrol
		StuckMinProgress = 1.5,
		CooldownSeconds = 3, -- idle after a catch or a loss
		HipHeight = 3,
		DangerZoneCount = 2,
		DangerZoneRadius = 22,
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

	-- Night waves (P4). Money amounts are "income seconds" (x the player's income/sec) with a floor,
	-- so rewards, costs and penalties stay proportional at every stage of the game.
	Defense = {
		TickSeconds = 0.1,
		WarningSeconds = 30, -- incoming-attack banner and toast before night
		MaxPerPlot = 18, -- alive at once on one plot
		MaxPerServer = 100, -- alive at once on the server
		SpawnWindow = 0.7, -- a wave spawns over this fraction of the night
		MaxLifeSeconds = 100, -- timeout cleanup
		StuckSeconds = 8, -- no progress while not attacking -> despawn
		MeleeReach = 5, -- studs between zombie and plant to start chewing
		HouseHitMultiplier = 3, -- a zombie reaching the house hits once for Damage x this, then leaves
		LaneSpawnJitter = 4, -- studs of random extra spawn distance so zombies don't stack
		-- Wave size per unlocked lane, so players with fewer lanes face the same density.
		PerLaneBase = 1.5,
		PerLaneGrowth = 0.25, -- per night
		PerLaneNightCap = 12, -- nights after which growth stops
		WaveCap = 40,
		-- Stat scaling by the player's highest unlocked biome (k) and night number (n).
		HpPerBiome = 0.6, -- x(1 + 0.6(k-1)), matching plant damage scaling
		DamagePerBiome = 0.5,
		HpPerNight = 0.04,
		NightScaleCap = 20,
		-- Rewards, granted once at dawn only if the house survived.
		SurviveBonusIncomeSeconds = 30,
		SurviveBonusMin = 50,
		BountyIncomeSeconds = 1, -- x each type's Bounty
		BountyMin = 5,
		-- Loss: the wave reward is forfeited and a small capped penalty applies. Plants are never lost.
		LossPenaltyFraction = 0.05, -- of current money
		LossPenaltyIncomeSeconds = 120, -- cap
		-- Player actions.
		RepairCooldown = 20,
		RepairIncomeSeconds = 15, -- cost of a full house repair
		RepairMin = 25,
		RepairPlantIncomeSeconds = 3, -- per wilted plant revived by the same repair
		AssistRange = 45,
		AssistDamageFraction = 0.05, -- of the zombie's max HP per click
		AssistMinDamage = 2,
		Traps = {
			Spikes = { Cooldown = 30, Seconds = 15, Dps = 6, HalfWidth = 3, CostIncomeSeconds = 5, CostMin = 20 },
			Freeze = { Cooldown = 45, Seconds = 3, Radius = 14, Damage = 15, ArmSeconds = 20, CostIncomeSeconds = 8, CostMin = 30 },
		} :: { [string]: { [string]: number } },
	},
}

return Config
