--!strict
-- Per-biome index: which species complete it and what claiming pays. Completion reads only the
-- saved permanent `collection` ("species|variant"); Normal is required, Neon/Mega are display only.

local Biomes = require(script.Parent.Biomes)
local Plants = require(script.Parent.Plants)

export type Skin = {
	Id: string,
	Name: string,
	Primary: Color3,
	Secondary: Color3,
	Material: string, -- Enum.Material name hint for the bat model (task 7)
	Effect: string?, -- particle/light hint for the bat model (task 7)
}

export type Reward = {
	Cash: number,
	SpeedBonus: number, -- added to profile.speedBonus; treadmill gain x (1 + speedBonus)
	Skin: string, -- Skins id
}

export type ClaimProfile = {
	money: number,
	speedBonus: number,
	collection: { [string]: boolean },
	indexClaimed: { [string]: boolean },
	batSkins: { owned: { [string]: boolean }, equipped: string },
	stats: { moneyEarned: number },
}

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

local SPEED_BONUS = 0.10
local MIN_CASH = 5_000
local LAST_MULT = 20
local DEFAULT_SKIN = "Wooden"

local skins: { Skin } = {
	{ Id = "Wooden", Name = "Wooden Bat", Primary = hx("#B07A45"), Secondary = hx("#6B4423"), Material = "Wood" },
	{ Id = "Leafy", Name = "Leafy Bat", Primary = hx("#5BD15B"), Secondary = hx("#3E8E41"), Material = "Grass", Effect = "Leaves" },
	{ Id = "Mushroom", Name = "Mushroom Bat", Primary = hx("#FF4D4D"), Secondary = hx("#FFF3E0"), Material = "SmoothPlastic", Effect = "Spores" },
	{ Id = "Cactus", Name = "Cactus Bat", Primary = hx("#3FA34D"), Secondary = hx("#E8B86D"), Material = "Grass", Effect = "Spikes" },
	{ Id = "Lava", Name = "Lava Bat", Primary = hx("#FF5A1F"), Secondary = hx("#3D2B1F"), Material = "CrackedLava", Effect = "Embers" },
	{ Id = "Ice", Name = "Ice Bat", Primary = hx("#7FD3FF"), Secondary = hx("#E6F4FF"), Material = "Ice", Effect = "Frost" },
	{ Id = "Enchanted", Name = "Enchanted Bat", Primary = hx("#C77DFF"), Secondary = hx("#7CFFCB"), Material = "Neon", Effect = "Sparkles" },
	{ Id = "Palm", Name = "Palm Bat", Primary = hx("#2DAA4F"), Secondary = hx("#F7E1A0"), Material = "Wood" },
	{ Id = "Coral", Name = "Coral Bat", Primary = hx("#FF7F50"), Secondary = hx("#FFD1DC"), Material = "Pebble", Effect = "Bubbles" },
	{ Id = "Autumn", Name = "Autumn Bat", Primary = hx("#FF8C00"), Secondary = hx("#C0392B"), Material = "Wood", Effect = "Leaves" },
	{ Id = "Cloud", Name = "Cloud Bat", Primary = hx("#FFFFFF"), Secondary = hx("#8EC9FF"), Material = "SmoothPlastic", Effect = "Mist" },
	{ Id = "Crystal", Name = "Crystal Bat", Primary = hx("#5CE1E6"), Secondary = hx("#FF66C4"), Material = "Glass", Effect = "Shine" },
	{ Id = "Toxic", Name = "Toxic Bat", Primary = hx("#A6FF00"), Secondary = hx("#4B5D2A"), Material = "Neon", Effect = "Drips" },
	{ Id = "Ancient", Name = "Ancient Bat", Primary = hx("#D4A373"), Secondary = hx("#5C4033"), Material = "Slate" },
	{ Id = "Galaxy", Name = "Galaxy Bat", Primary = hx("#7209B7"), Secondary = hx("#4CC9F0"), Material = "Neon", Effect = "Stars" },
	{ Id = "DivineBloom", Name = "Divine Bloom Bat", Primary = hx("#FFD700"), Secondary = hx("#FF1E56"), Material = "Neon", Effect = "Petals" },
}

local SKIN_FOR: { [string]: string } = {
	GreenMeadows = "Leafy", MushroomForest = "Mushroom", CactusCanyon = "Cactus", InfernoJungle = "Lava",
	FrostbiteGarden = "Ice", EnchantedGrove = "Enchanted", TropicalParadise = "Palm", CoralKingdom = "Coral",
	AutumnWoods = "Autumn", SkyIslands = "Cloud", CrystalCaverns = "Crystal", ToxicSwamp = "Toxic",
	AncientWilds = "Ancient", CosmicGarden = "Galaxy", ForbiddenBloom = "DivineBloom",
}

-- Per-biome replacement for the default required list (every species of the biome).
local REQUIRED_OVERRIDE: { [string]: { string } } = {}

local skinById: { [string]: Skin } = {}
for _, s in skins do
	skinById[s.Id] = s
end

local required: { [string]: { string } } = {}
local rewards: { [string]: Reward } = {}
for i, b in Biomes.List do
	local ids = REQUIRED_OVERRIDE[b.Id]
	if not ids then
		ids = {}
		for _, def in Plants.ByBiome[b.Id] or {} do
			table.insert(ids, def.Id)
		end
	end
	required[b.Id] = ids
	local nextBiome = Biomes.List[i + 1]
	local cash = if nextBiome then nextBiome.Cost * 2 else b.Cost * LAST_MULT
	rewards[b.Id] = { Cash = math.max(MIN_CASH, cash), SpeedBonus = SPEED_BONUS, Skin = SKIN_FOR[b.Id] or DEFAULT_SKIN }
end

local IndexRewards = {
	Skins = skins,
	SkinById = skinById,
	DefaultSkin = DEFAULT_SKIN,
	Required = required,
	Rewards = rewards,
}

function IndexRewards.isSecret(species: string): boolean
	local def = Plants.ById[species]
	return def ~= nil and def.Rarity == "Secret"
end

function IndexRewards.progress(collection: { [string]: boolean }, biomeId: string): (number, number)
	local ids = required[biomeId]
	if not ids then
		return 0, 0
	end
	local have = 0
	for _, id in ids do
		if collection[id .. "|Normal"] then
			have += 1
		end
	end
	return have, #ids
end

function IndexRewards.isComplete(collection: { [string]: boolean }, biomeId: string): boolean
	local have, total = IndexRewards.progress(collection, biomeId)
	return total > 0 and have >= total
end

-- Pure check-then-grant. Returns the reward on success, nil + reason otherwise.
function IndexRewards.claim(p: ClaimProfile, biomeId: string): (Reward?, string?)
	local r = rewards[biomeId]
	if not r then
		return nil, "Unknown biome."
	end
	if p.indexClaimed[biomeId] then
		return nil, "Already claimed."
	end
	if not IndexRewards.isComplete(p.collection, biomeId) then
		return nil, "Discover every plant in this biome first."
	end
	p.money += r.Cash
	p.stats.moneyEarned += r.Cash
	p.speedBonus += r.SpeedBonus
	p.batSkins.owned[r.Skin] = true
	p.indexClaimed[biomeId] = true
	return r, nil
end

return IndexRewards
