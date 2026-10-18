--!strict
-- Neon / Mega makers (P5). 4 identical plants in, 1 upgraded variant out.
return {
	InputCount = 4,
	Machines = {
		Neon = { Variant = "Neon", Seconds = 15 * 60, IncomeMultiplier = 3, Input = "Normal" },
		Mega = { Variant = "Mega", Seconds = 60 * 60, IncomeMultiplier = 10, Input = "Neon" },
	},
}
