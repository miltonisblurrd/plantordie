--!strict
-- Global tuning. Every number the server uses lives here or in a sibling data table.

local Config = {
	Data = {
		StoreName = "PlantOrDie_Profiles_v2",
		KeyPrefix = "player_",
		SchemaVersion = 9,
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
		HubRadius = 42,
		GateRingRadius = 0, -- unused; biomes are a line in front of the plots
		PlotRingRadius = 0,
		PlotCount = 8,
		PlotGap = 10,
		GroundY = 0,
	},

	-- Biomes sit in one line in front of the plot row. Walk +Z to the next one.
	Biome = {
		RingRadius = 0,
		Size = 112,
		Gap = 12,
		FrontGap = 28, -- studs from the plot row's front edge to biome 1
		SafeRadius = 10,
		DigSpots = 10,
		ToughSpots = 3,
		EnforceSeconds = 0.5,
		PathWidth = 8,
		-- Dirt HP = Index * this. Tough mounds use the tough multiplier.
		DirtHpPerIndex = 4,
		ToughHpMultiplier = 2.5,
	},

	Dig = {
		Range = 12, -- studs from character to spot
		RespawnSeconds = 45,
		MaxLuck = 0.5,
	},

	-- Hub market stalls. Walking onto a stall's circle opens its menu; buying needs BuyRange.
	Shops = {
		Trails = Vector3.new(-50, 0, -70),
		Shovels = Vector3.new(50, 0, -70),
		Radius = 9,
		BuyRange = 30,
	},

	Bank = {
		HubRadius = 26, -- hub safe area around the fountain; guardians give up a chase here
		CheckSeconds = 0.5,
	},

	-- One carried seed per player. Only your own plot banks it.
	Carry = {
		SpeedFactor = 0.9, -- WalkSpeed multiplier while carrying
		RevealSeconds = 20, -- a dug seed waits this long on its dirt spot
		DropSeconds = 20, -- a dropped seed's countdown
		PickupRange = 10,
		TouchRange = 4, -- walking over a seed picks it up
		CheckSeconds = 0.25,
	},

	Guardian = {
		TickSeconds = 0.1,
		SpeedFactor = 0.97, -- chase speed = walkSpeedFor(biome RecommendedSpeed) x this
		PatrolFactor = 0.5, -- patrol speed = chase speed x this
		MaxChaseSeconds = 60,
		StuckSeconds = 3, -- no progress toward the target for this long -> give up, return
		StuckMinProgress = 1.5,
		CooldownSeconds = 3, -- no catches for this long after a catch
		KnockbackHorizontal = 50,
		KnockbackUp = 35,
		StunSeconds = 1.5,
		HipHeight = 3,
		DangerZoneCount = 2,
		DangerZoneRadius = 22,
	},

	Plot = {
		Width = 78,
		Depth = 64,
		TileSize = 6,
		Lanes = 7,
		Columns = 9,
		GardenOriginX = -24,
		HouseX = -32,
		ZombieSpawnX = 34,
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
		DaySeconds = 300, -- 5 minutes between nights
		NightSeconds = 150, -- 2:30 of night; portals only spawn then
		DayClockStart = 6.5,
		DayClockEnd = 18.5,
		NightClockEnd = 30.5, -- wraps past midnight to 06:30
	},

	Treadmill = {
		TickSeconds = 1,
		HeightTolerance = 6, -- studs above the belt top the root part may be
		WalkSpeedMinDelta = 0.25, -- skip WalkSpeed writes smaller than this
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
