--!strict
-- Per-biome dig rolls (P3). Weights are relative.
export type Drop = { Plant: string, Weight: number }

return {
	GreenMeadows = {
		{ Plant = "Sunpetal", Weight = 70 },
		{ Plant = "PeaPopper", Weight = 25 },
		{ Plant = "Thornwall", Weight = 5 },
	},
	MushroomForest = {
		{ Plant = "Capshroom", Weight = 100 },
	},
} :: { [string]: { Drop } }
