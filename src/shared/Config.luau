-- Flip Debug to true for a short cycle while testing alone in Studio.
local Debug = false

return {
	Debug = Debug,
	GameName = "PLANT or DIE",
	DataStoreName = "PlantOrDie_v2",
	GrowSeconds = { Common = 30, Rare = 60, Epic = 90, Legendary = 120 },
	EvolveCost = { Common = 8, Rare = 16, Epic = 28, Legendary = 45 },

	DayLength = Debug and 75 or 240,
	WarningLength = Debug and 15 or 20,
	NightLength = Debug and 45 or 120,

	StartingCoins = 300,
	RollCost = 100,
	MaxFollowers = 3,
	PlotCount = 6,
	TileCount = 5,
	FifthTileHouseLevel = 2,
	MaxHouseLevel = 5,
	StunSeconds = 60,
	IncomeInterval = 1,
	AutosaveInterval = 60,

	-- Cost to reach this house level. Index is the level you are buying.
	UpgradeCost = {
		[2] = 250,
		[3] = 750,
		[4] = 2000,
		[5] = 5000,
	},
	IncomeMultiplier = {
		[1] = 1,
		[2] = 1.5,
		[3] = 2,
		[4] = 3,
		[5] = 4,
	},
	HouseHealth = {
		[1] = 100,
		[2] = 160,
		[3] = 230,
		[4] = 320,
		[5] = 450,
	},
}
