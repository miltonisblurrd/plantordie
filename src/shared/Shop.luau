-- Paste real asset ids here after you create them on the published test place.
-- 0 means the button explains that the id is missing instead of charging anyone.
return {
	GemPlantCost = 40,
	Ids = {
		Gems = 0,
		InstantGrow = 0,
		InstantRevive = 0,
		Weekly1 = 0,
		Weekly3 = 0,
		Weekly10 = 0,
		PaidRoll = 0,
		PassCoins = 0,
		PassLuck = 0,
		PassExclusive = 0,
	},
	Weekly = { "WeekBloom", "WeekThorn", "WeekSpore" },
	Offers = {
		{ id = "Gems", name = "80 Gems", kind = "product", detail = "Spend gems on plants coins cannot buy." },
		{ id = "InstantGrow", name = "Instant grow", kind = "product", detail = "Finishes the growing plant you select." },
		{ id = "InstantRevive", name = "Instant revive", kind = "product", detail = "Clears the stun on the plant you select." },
		{ id = "Weekly1", name = "Weekly pack x1", kind = "product", detail = "One plant from this week's set." },
		{ id = "Weekly3", name = "Weekly pack x3", kind = "product", detail = "Three of this week's plant." },
		{ id = "Weekly10", name = "Weekly pack x10", kind = "product", detail = "Ten of this week's plant." },
		{ id = "PaidRoll", name = "Robux roll", kind = "product", detail = "Same odds as the coin roll. Hidden where paid random items are blocked." },
		{ id = "PassCoins", name = "2x coins", kind = "pass", detail = "Doubles plant income." },
		{ id = "PassLuck", name = "Extra luck", kind = "pass", detail = "Rolls twice and keeps the rarer plant." },
		{ id = "PassExclusive", name = "Crown Fern", kind = "pass", detail = "Grants the exclusive Crown Fern." },
		{ id = "GemBloom", name = "Gem Bloom", kind = "gems", detail = "40 gems. Not in the coin roll." },
	},
}
