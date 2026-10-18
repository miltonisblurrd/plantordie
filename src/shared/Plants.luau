--!strict
-- Plant definitions (spec §4): 4 exclusive species per biome, Common..Divine across progression.

local Biomes = require(script.Parent.Biomes)

export type Shape = "Ball" | "Block" | "Cylinder" | "Wedge"
export type Accent = "Leaves" | "Petals" | "Spikes" | "Cap" | "None"

export type ModelRecipe = {
	StemShape: "Cylinder" | "Block",
	StemColor: Color3,
	StemHeight: number, -- studs at Medium size, grown
	HeadShape: Shape,
	HeadColor: Color3,
	HeadSize: number,
	Accent: Accent,
	AccentColor: Color3,
}

export type Combat = {
	Role: "Projectile" | "Rapid" | "AoE" | "Slow" | "Burn" | "Wall" | "Income",
	Damage: number,
	AttackRate: number, -- attacks per second (0 for walls)
	Range: number, -- tiles along the lane
	Ability: string?,
	WallHp: number?,
}

export type Plant = {
	Id: string,
	Name: string,
	Biome: string,
	Rarity: string,
	BaseIncome: number, -- $/sec before multipliers
	GrowSeconds: number,
	SizeWeights: { [string]: number }?, -- overrides Sizes weights when present
	Model: ModelRecipe,
	Combat: Combat?,
	WaterDependent: boolean,
	Description: string,
}

export type Variant = {
	Id: string,
	IncomeMultiplier: number,
	Neon: boolean, -- Neon head + PointLight + slow particle
	Rainbow: boolean, -- client hue cycle + sparkles
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Pacing (full maths in studio/tasks/pod-v2/pacing.md). Every number below derives from two
-- per-biome curves so the roster stays balanced as a whole:
--   BaseIncome  = BIOME_INCOME[biome] x flavour        ($/s before rarity/size/variant)
--   GrowSeconds = BIOME_GROW[biome]   x RARITY_GROW[rarity]
-- Economy.incomeOf then applies rarity (1..25x) and size (1..25x). A full garden of the newest
-- biome's typical drops (avg rarity x size ~ 3.4x) earns the next biome's cost in ~6-12 minutes.
local BIOME_INCOME = { 2, 8, 52, 185, 500, 480, 640, 550, 830, 800, 540, 700, 600, 750, 900 }
local BIOME_GROW = { 30, 40, 55, 75, 100, 135, 180, 240, 320, 420, 560, 740, 980, 1300, 1700 }
local RARITY_GROW: { [string]: number } =
	{ Common = 1, Uncommon = 1.4, Rare = 2, Epic = 3, Legendary = 4.5, Mythical = 6, Divine = 9 }

type CombatRole = "Projectile" | "Rapid" | "AoE" | "Slow" | "Burn" | "Wall" | "Income"
-- Damage per hit at biome 1; scales +60% per biome index for Phase 4.
local ROLE_STATS: { [string]: { Damage: number, AttackRate: number, Range: number, WallHp: number? } } = {
	Projectile = { Damage = 5, AttackRate = 1, Range = 9 },
	Rapid = { Damage = 2, AttackRate = 3, Range = 7 },
	AoE = { Damage = 8, AttackRate = 0.5, Range = 2 },
	Slow = { Damage = 2, AttackRate = 1, Range = 6 },
	Burn = { Damage = 3, AttackRate = 0.8, Range = 6 },
	Wall = { Damage = 1, AttackRate = 0.5, Range = 0, WallHp = 120 },
	Income = { Damage = 0, AttackRate = 0, Range = 0 },
}

type Spec = {
	id: string,
	name: string,
	rarity: string,
	role: CombatRole,
	flavour: number,
	ability: string?,
	water: boolean?,
	desc: string,
	stem: Color3,
	stemShape: ("Cylinder" | "Block")?,
	stemHeight: number?,
	head: Shape,
	headColor: Color3,
	headSize: number?,
	accent: Accent,
	accentColor: Color3,
}

local function hx(h: string): Color3
	return Color3.fromHex(h)
end

local roster: { [string]: { Spec } } = {
	GreenMeadows = {
		{ id = "Sunpetal", name = "Sunpetal", rarity = "Common", role = "Income", flavour = 1, desc = "A cheerful money flower. Pure income.",
			stem = rgb(62, 142, 65), head = "Ball", headColor = rgb(255, 224, 102), accent = "Petals", accentColor = rgb(255, 160, 40) },
		{ id = "PeaPopper", name = "Pea Popper", rarity = "Common", role = "Projectile", flavour = 0.5, desc = "Fires peas down its lane at night.",
			stem = rgb(52, 130, 60), head = "Ball", headColor = rgb(120, 220, 90), headSize = 2.2, accent = "Leaves", accentColor = rgb(40, 110, 50) },
		{ id = "Thornwall", name = "Thornwall", rarity = "Uncommon", role = "Wall", flavour = 0.8, ability = "Thorns", desc = "A thorny hedge that stalls zombies.",
			stem = rgb(90, 70, 40), stemShape = "Block", stemHeight = 1.2, head = "Block", headColor = rgb(60, 130, 50), headSize = 3.4, accent = "Spikes", accentColor = rgb(230, 230, 200) },
		{ id = "CloverCharm", name = "Clover Charm", rarity = "Rare", role = "Income", flavour = 1.2, desc = "Lucky four-leaf clover. Big income, slow to grow.",
			stem = rgb(40, 150, 70), head = "Cylinder", headColor = rgb(70, 220, 110), accent = "Leaves", accentColor = rgb(58, 141, 255) },
	},
	MushroomForest = {
		{ id = "Puffcap", name = "Puffcap", rarity = "Common", role = "Slow", flavour = 0.8, ability = "Spores", desc = "Puffs sticky spores that slow zombies.",
			stem = hx("#FFF3E0"), head = "Ball", headColor = hx("#D6A2E8"), accent = "Cap", accentColor = hx("#FFFFFF") },
		{ id = "GlowShroom", name = "Glowshroom", rarity = "Uncommon", role = "Income", flavour = 1.1, desc = "Softly glowing fungus. Steady income.",
			stem = hx("#E8E0FF"), head = "Cylinder", headColor = hx("#7CFFCB"), accent = "Cap", accentColor = hx("#B8FFE8") },
		{ id = "Capshroom", name = "Capshroom", rarity = "Rare", role = "AoE", flavour = 1, desc = "Releases a spore burst that hits nearby zombies.",
			stem = rgb(255, 243, 224), stemHeight = 2.4, head = "Cylinder", headColor = rgb(255, 77, 77), headSize = 3, accent = "Cap", accentColor = rgb(255, 255, 255) },
		{ id = "Sporelord", name = "Sporelord", rarity = "Epic", role = "Burn", flavour = 1.2, ability = "Poison", desc = "A giant toadstool whose spores poison over time.",
			stem = hx("#C9B79C"), stemHeight = 4, head = "Cylinder", headColor = hx("#6B2D8C"), headSize = 3.6, accent = "Cap", accentColor = hx("#E8C547") },
	},
	CactusCanyon = {
		{ id = "PricklePear", name = "Prickle Pear", rarity = "Common", role = "Projectile", flavour = 0.7, desc = "Flings needles at anything that shambles by.",
			stem = hx("#3FA34D"), stemShape = "Block", head = "Ball", headColor = hx("#D9643A"), accent = "Spikes", accentColor = hx("#FFF6D5") },
		{ id = "DesertBloom", name = "Desert Bloom", rarity = "Uncommon", role = "Income", flavour = 1.1, desc = "A rare flower after desert rain. Good income.",
			stem = hx("#5C8A3A"), head = "Ball", headColor = hx("#FF8FB1"), accent = "Petals", accentColor = hx("#FFD166") },
		{ id = "BarrelCactus", name = "Barrel Cactus", rarity = "Rare", role = "Wall", flavour = 0.9, ability = "Thorns", desc = "A fat spiny barrel. Zombies hate chewing it.",
			stem = hx("#2F7D3A"), stemShape = "Block", stemHeight = 1, head = "Cylinder", headColor = hx("#3FA34D"), headSize = 3.4, accent = "Spikes", accentColor = hx("#FFF6D5") },
		{ id = "SunspikeAgave", name = "Sunspike Agave", rarity = "Epic", role = "Rapid", flavour = 1.2, desc = "Rattles off sun-hardened spikes in quick bursts.",
			stem = hx("#6E9B5A"), head = "Wedge", headColor = hx("#9CC27A"), headSize = 3, accent = "Spikes", accentColor = hx("#FFC300") },
	},
	InfernoJungle = {
		{ id = "EmberLily", name = "Ember Lily", rarity = "Uncommon", role = "Burn", flavour = 0.8, ability = "Burn", desc = "Its petals are hot enough to set zombies alight.",
			stem = hx("#1F7A3A"), head = "Ball", headColor = hx("#FF5A1F"), accent = "Petals", accentColor = hx("#FFC300") },
		{ id = "LavaVine", name = "Lava Vine", rarity = "Rare", role = "Slow", flavour = 1, ability = "Burn", desc = "Molten creepers that slow and singe.",
			stem = hx("#3D2B1F"), stemHeight = 4, head = "Cylinder", headColor = hx("#FF3B00"), accent = "Leaves", accentColor = hx("#FFB000") },
		{ id = "MagmaBulb", name = "Magma Bulb", rarity = "Epic", role = "AoE", flavour = 1.1, desc = "Swells, then bursts in a splash of magma.",
			stem = hx("#5A2E1A"), head = "Ball", headColor = hx("#FF7A00"), headSize = 3.2, accent = "Spikes", accentColor = hx("#2B1A12") },
		{ id = "PhoenixFlower", name = "Phoenix Flower", rarity = "Legendary", role = "Income", flavour = 1.3, desc = "Reborn from its own ashes. Huge income.",
			stem = hx("#B83A1B"), head = "Ball", headColor = hx("#FFC300"), accent = "Petals", accentColor = hx("#FF2E00") },
	},
	FrostbiteGarden = {
		{ id = "FrostFern", name = "Frost Fern", rarity = "Common", role = "Slow", flavour = 0.8, ability = "Chill", desc = "Icy fronds chill zombies to a crawl.",
			stem = hx("#4A90C2"), head = "Wedge", headColor = hx("#BFEFFF"), accent = "Leaves", accentColor = hx("#7FD3FF") },
		{ id = "IceRose", name = "Ice Rose", rarity = "Rare", role = "Income", flavour = 1.1, desc = "A rose carved from living ice.",
			stem = hx("#8FB8D8"), head = "Ball", headColor = hx("#E6F4FF"), accent = "Petals", accentColor = hx("#7FD3FF") },
		{ id = "CrystalThistle", name = "Crystal Thistle", rarity = "Epic", role = "Projectile", flavour = 1, desc = "Shoots ice shards that shatter on impact.",
			stem = hx("#6E8FB0"), head = "Block", headColor = hx("#B9A8FF"), accent = "Spikes", accentColor = hx("#FFFFFF") },
		{ id = "GlacierHeart", name = "Glacier Heart", rarity = "Legendary", role = "Wall", flavour = 1.2, ability = "Freeze", desc = "A wall of ancient ice that freezes attackers.",
			stem = hx("#4A90C2"), stemShape = "Block", stemHeight = 1.2, head = "Block", headColor = hx("#A8E6FF"), headSize = 3.6, accent = "Spikes", accentColor = hx("#E6F4FF") },
	},
	EnchantedGrove = {
		{ id = "MoonBlossom", name = "Moon Blossom", rarity = "Uncommon", role = "Income", flavour = 1, desc = "Opens only under moonlight. Pure income.",
			stem = hx("#5A3E85"), head = "Ball", headColor = hx("#F0E6FF"), accent = "Petals", accentColor = hx("#C77DFF") },
		{ id = "FaeVine", name = "Fae Vine", rarity = "Rare", role = "Slow", flavour = 0.9, ability = "Entangle", desc = "Enchanted vines that snare zombie ankles.",
			stem = hx("#2E8B57"), stemHeight = 4, head = "Cylinder", headColor = hx("#7CFFCB"), accent = "Leaves", accentColor = hx("#C77DFF") },
		{ id = "Spellbloom", name = "Spellbloom", rarity = "Epic", role = "Rapid", flavour = 1.1, desc = "Fires a stream of sparkling magic bolts.",
			stem = hx("#3F2A63"), head = "Ball", headColor = hx("#C77DFF"), accent = "Petals", accentColor = hx("#7CFFCB") },
		{ id = "StarwillowFlower", name = "Starwillow", rarity = "Legendary", role = "AoE", flavour = 1.2, desc = "Showers a whole area in falling starlight.",
			stem = hx("#6A5ACD"), stemHeight = 4.4, head = "Cylinder", headColor = hx("#FFE8FF"), accent = "Leaves", accentColor = hx("#FFD6FF") },
	},
	TropicalParadise = {
		{ id = "BananaBush", name = "Banana Bush", rarity = "Common", role = "Income", flavour = 1, desc = "Bunches of golden bananas. Easy money.",
			stem = hx("#2DAA4F"), head = "Cylinder", headColor = hx("#FFE135"), accent = "Leaves", accentColor = hx("#2DAA4F") },
		{ id = "Hibiscus", name = "Hibiscus", rarity = "Uncommon", role = "Projectile", flavour = 0.8, desc = "Spits seeds with tropical gusto.",
			stem = hx("#2DAA4F"), head = "Ball", headColor = hx("#FF6F61"), accent = "Petals", accentColor = hx("#FFD1DC") },
		{ id = "CoconutPalm", name = "Coconut Palm", rarity = "Rare", role = "AoE", flavour = 1, desc = "Drops coconuts that bonk a whole group.",
			stem = hx("#A0522D"), stemShape = "Block", stemHeight = 4.6, head = "Ball", headColor = hx("#6B4226"), accent = "Leaves", accentColor = hx("#2DAA4F") },
		{ id = "MangoBlaster", name = "Mango Blaster", rarity = "Epic", role = "Rapid", flavour = 1.2, desc = "Rapid-fires juicy mango pits.",
			stem = hx("#3C8D2F"), head = "Ball", headColor = hx("#FFB347"), accent = "Leaves", accentColor = hx("#FF6F61") },
	},
	CoralKingdom = {
		{ id = "KelpRibbon", name = "Kelp Ribbon", rarity = "Uncommon", role = "Slow", flavour = 0.9, ability = "Tangle", water = true, desc = "Swaying kelp that tangles zombies. Needs water.",
			stem = hx("#2E8B57"), stemShape = "Block", stemHeight = 4.4, head = "Block", headColor = hx("#3CB371"), accent = "Leaves", accentColor = hx("#2A9DF4") },
		{ id = "BrainCoral", name = "Brain Coral", rarity = "Rare", role = "Wall", flavour = 1, desc = "A dense coral mound. A sturdy wall.",
			stem = hx("#F4A261"), stemShape = "Block", stemHeight = 1, head = "Ball", headColor = hx("#FF7F50"), headSize = 3.4, accent = "None", accentColor = hx("#FFD1DC") },
		{ id = "AnemoneBloom", name = "Anemone Bloom", rarity = "Epic", role = "Burn", flavour = 1.1, ability = "Poison", water = true, desc = "Stinging tentacles poison zombies. Needs water.",
			stem = hx("#FF7F50"), head = "Ball", headColor = hx("#FFD1DC"), accent = "Spikes", accentColor = hx("#C04BFF") },
		{ id = "PearlLotus", name = "Pearl Lotus", rarity = "Legendary", role = "Income", flavour = 1.3, desc = "A lotus cradling a glowing pearl.",
			stem = hx("#2A9DF4"), head = "Ball", headColor = hx("#FFF8F0"), accent = "Petals", accentColor = hx("#FFD1DC") },
	},
	AutumnWoods = {
		{ id = "MapleSapling", name = "Maple Sapling", rarity = "Common", role = "Income", flavour = 1, desc = "A young maple dripping golden syrup.",
			stem = hx("#6B3E26"), head = "Block", headColor = hx("#FF8C00"), accent = "Leaves", accentColor = hx("#C0392B") },
		{ id = "AmberTree", name = "Amber Tree", rarity = "Rare", role = "Wall", flavour = 0.9, ability = "Sticky", desc = "Sap-soaked bark that zombies get stuck on.",
			stem = hx("#6B3E26"), stemShape = "Block", stemHeight = 1.4, head = "Block", headColor = hx("#FFB000"), headSize = 3.6, accent = "None", accentColor = hx("#FF8C00") },
		{ id = "PumpkinVine", name = "Pumpkin Vine", rarity = "Epic", role = "AoE", flavour = 1.1, desc = "Lobs exploding pumpkins.",
			stem = hx("#3E6B26"), stemHeight = 2, head = "Ball", headColor = hx("#FF7518"), headSize = 3.2, accent = "Leaves", accentColor = hx("#3E6B26") },
		{ id = "HarvestOak", name = "Harvest Oak", rarity = "Legendary", role = "Income", flavour = 1.3, desc = "An ancient oak heavy with golden acorns.",
			stem = hx("#5A3A22"), stemShape = "Block", stemHeight = 4.4, head = "Ball", headColor = hx("#C0392B"), headSize = 3.4, accent = "Leaves", accentColor = hx("#FFC300") },
	},
	SkyIslands = {
		{ id = "CloudPuff", name = "Cloud Puff", rarity = "Uncommon", role = "Slow", flavour = 0.9, ability = "Fog", desc = "Breathes a fog bank that slows zombies.",
			stem = hx("#C2B280"), head = "Ball", headColor = hx("#FFFFFF"), headSize = 3, accent = "None", accentColor = hx("#8EC9FF") },
		{ id = "FloatLily", name = "Float Lily", rarity = "Rare", role = "Income", flavour = 1.1, desc = "Hovers an inch above its pot.",
			stem = hx("#8EC9FF"), head = "Cylinder", headColor = hx("#E8F6FF"), accent = "Petals", accentColor = hx("#8EC9FF") },
		{ id = "SkyVine", name = "Sky Vine", rarity = "Epic", role = "Rapid", flavour = 1.1, desc = "Whips gusts of wind in rapid succession.",
			stem = hx("#9FE870"), stemHeight = 4.6, head = "Wedge", headColor = hx("#B8F5FF"), accent = "Leaves", accentColor = hx("#9FE870") },
		{ id = "ThunderBloom", name = "Thunder Bloom", rarity = "Legendary", role = "AoE", flavour = 1.2, ability = "Shock", desc = "Calls down lightning on crowds.",
			stem = hx("#5A6B8C"), head = "Ball", headColor = hx("#FFF35C"), accent = "Spikes", accentColor = hx("#8EC9FF") },
	},
	CrystalCaverns = {
		{ id = "GemFlower", name = "Gem Flower", rarity = "Rare", role = "Income", flavour = 1, desc = "Petals of cut sapphire. Pure income.",
			stem = hx("#8A7FFF"), head = "Block", headColor = hx("#5CE1E6"), accent = "Petals", accentColor = hx("#FF66C4") },
		{ id = "CrystalRoot", name = "Crystal Root", rarity = "Epic", role = "Wall", flavour = 0.9, ability = "Reflect", desc = "A wall of crystal that reflects bites.",
			stem = hx("#3B3B58"), stemShape = "Block", stemHeight = 1.2, head = "Wedge", headColor = hx("#8A7FFF"), headSize = 3.6, accent = "Spikes", accentColor = hx("#5CE1E6") },
		{ id = "LuminousFern", name = "Luminous Fern", rarity = "Legendary", role = "Projectile", flavour = 1.1, desc = "Fires beams of stored cave light.",
			stem = hx("#4B4B70"), head = "Wedge", headColor = hx("#5CE1E6"), accent = "Leaves", accentColor = hx("#B8FFFF") },
		{ id = "PrismBloom", name = "Prism Bloom", rarity = "Mythical", role = "Rapid", flavour = 1.2, desc = "Splits light into a rainbow barrage.",
			stem = hx("#8A7FFF"), head = "Ball", headColor = hx("#FF66C4"), accent = "Spikes", accentColor = hx("#5CE1E6") },
	},
	ToxicSwamp = {
		{ id = "Toadstool", name = "Toxic Toadstool", rarity = "Rare", role = "Burn", flavour = 0.9, ability = "Poison", desc = "Leaks poison into the lane.",
			stem = hx("#C9D99C"), head = "Cylinder", headColor = hx("#A6FF00"), accent = "Cap", accentColor = hx("#8E44AD") },
		{ id = "VenomPitcher", name = "Venom Pitcher", rarity = "Epic", role = "Income", flavour = 1.1, desc = "Digests swamp bugs into money.",
			stem = hx("#2F3B1C"), head = "Cylinder", headColor = hx("#8E44AD"), accent = "Leaves", accentColor = hx("#A6FF00") },
		{ id = "ToxicVine", name = "Toxic Vine", rarity = "Legendary", role = "Slow", flavour = 1, ability = "Poison", water = true, desc = "Sludgy vines that slow and poison. Needs water.",
			stem = hx("#4B5D2A"), stemHeight = 4.4, head = "Block", headColor = hx("#6B8E23"), accent = "Spikes", accentColor = hx("#A6FF00") },
		{ id = "BlightBloom", name = "Blight Bloom", rarity = "Mythical", role = "AoE", flavour = 1.2, ability = "Poison", desc = "Erupts in a toxic cloud.",
			stem = hx("#3B2F4A"), head = "Ball", headColor = hx("#A6FF00"), accent = "Petals", accentColor = hx("#8E44AD") },
	},
	AncientWilds = {
		{ id = "GiantFern", name = "Giant Fern", rarity = "Epic", role = "Wall", flavour = 0.9, desc = "Fronds the size of a car. A great wall.",
			stem = hx("#5C4033"), stemShape = "Block", stemHeight = 1.4, head = "Wedge", headColor = hx("#6A994E"), headSize = 3.8, accent = "Leaves", accentColor = hx("#A7C957") },
		{ id = "CycadKing", name = "Cycad King", rarity = "Legendary", role = "Income", flavour = 1.1, desc = "Prehistoric royalty. Rich income.",
			stem = hx("#8F6A4A"), stemShape = "Block", stemHeight = 3.6, head = "Wedge", headColor = hx("#6A994E"), accent = "Leaves", accentColor = hx("#D4A373") },
		{ id = "FossilTree", name = "Fossil Tree", rarity = "Mythical", role = "Projectile", flavour = 1.1, desc = "Hurls fossilised seeds like stones.",
			stem = hx("#D4C5A9"), stemShape = "Block", stemHeight = 4.2, head = "Block", headColor = hx("#8F9779"), accent = "Spikes", accentColor = hx("#D4A373") },
		{ id = "AmberEternal", name = "Eternal Amber", rarity = "Divine", role = "Income", flavour = 1, desc = "A bloom sealed in amber for a million years.",
			stem = hx("#5C4033"), head = "Ball", headColor = hx("#FFB000"), headSize = 2.6, accent = "Petals", accentColor = hx("#FFE29A") },
	},
	CosmicGarden = {
		{ id = "StarSprout", name = "Star Sprout", rarity = "Epic", role = "Projectile", flavour = 0.9, desc = "Shoots tiny shooting stars.",
			stem = hx("#7209B7"), head = "Ball", headColor = hx("#FFF35C"), accent = "Spikes", accentColor = hx("#FFD6FF") },
		{ id = "NebulaBloom", name = "Nebula Bloom", rarity = "Legendary", role = "Income", flavour = 1.1, desc = "Swirls with a tiny galaxy. Big income.",
			stem = hx("#4CC9F0"), head = "Ball", headColor = hx("#B5179E"), accent = "Petals", accentColor = hx("#4CC9F0") },
		{ id = "OrbitTree", name = "Orbit Tree", rarity = "Mythical", role = "AoE", flavour = 1.1, desc = "Moons orbit its crown and crash into crowds.",
			stem = hx("#3A0CA3"), stemShape = "Block", stemHeight = 4.4, head = "Ball", headColor = hx("#4CC9F0"), headSize = 3.2, accent = "Leaves", accentColor = hx("#FFD6FF") },
		{ id = "Supernova", name = "Supernova", rarity = "Divine", role = "Rapid", flavour = 1, desc = "A dying star in a flowerpot. Fires endlessly.",
			stem = hx("#1B1035"), head = "Ball", headColor = hx("#FFFFFF"), headSize = 3, accent = "Spikes", accentColor = hx("#FFD700") },
	},
	ForbiddenBloom = {
		{ id = "VoidFlower", name = "Void Flower", rarity = "Legendary", role = "Burn", flavour = 0.9, ability = "Decay", desc = "Petals of nothing. Zombies decay near it.",
			stem = hx("#2B0A12"), head = "Ball", headColor = hx("#14000A"), accent = "Petals", accentColor = hx("#FF1E56") },
		{ id = "AncientBloom", name = "Ancient Bloom", rarity = "Mythical", role = "Income", flavour = 1.1, desc = "Older than the world. Enormous income.",
			stem = hx("#5E0B15"), head = "Cylinder", headColor = hx("#FFD700"), accent = "Petals", accentColor = hx("#FF1E56") },
		{ id = "ThornOfEnd", name = "Thorn of the End", rarity = "Mythical", role = "Wall", flavour = 1, ability = "Thorns", desc = "The last wall. Nothing gets through.",
			stem = hx("#2B0A12"), stemShape = "Block", stemHeight = 1.4, head = "Wedge", headColor = hx("#5E0B15"), headSize = 3.8, accent = "Spikes", accentColor = hx("#FFD700") },
		{ id = "ForbiddenRose", name = "Forbidden Rose", rarity = "Divine", role = "AoE", flavour = 1.2, ability = "Doom", desc = "The rose nobody was meant to grow.",
			stem = hx("#14000A"), head = "Ball", headColor = hx("#FF1E56"), headSize = 2.8, accent = "Petals", accentColor = hx("#FFD700") },
	},
}

local list: { Plant } = {}
for biomeIndex, biome in Biomes.List do
	local specs: { Spec } = roster[biome.Id] or {}
	for _, s in specs do
		local role = ROLE_STATS[s.role]
		local scale = 1 + 0.6 * (biomeIndex - 1)
		table.insert(list, {
			Id = s.id,
			Name = s.name,
			Biome = biome.Id,
			Rarity = s.rarity,
			BaseIncome = BIOME_INCOME[biomeIndex] * s.flavour,
			GrowSeconds = math.floor(BIOME_GROW[biomeIndex] * RARITY_GROW[s.rarity]),
			WaterDependent = s.water == true,
			Description = s.desc,
			Model = {
				StemShape = s.stemShape or "Cylinder",
				StemColor = s.stem,
				StemHeight = s.stemHeight or 3.2,
				HeadShape = s.head,
				HeadColor = s.headColor,
				HeadSize = s.headSize or 2.4,
				Accent = s.accent,
				AccentColor = s.accentColor,
			},
			Combat = {
				Role = s.role,
				Damage = math.floor(role.Damage * scale * 10) / 10,
				AttackRate = role.AttackRate,
				Range = role.Range,
				Ability = s.ability,
				WallHp = if role.WallHp then math.floor(role.WallHp * scale) else nil,
			},
		})
	end
end

local byId: { [string]: Plant } = {}
local byBiome: { [string]: { Plant } } = {}
for _, plant in list do
	byId[plant.Id] = plant
	byBiome[plant.Biome] = byBiome[plant.Biome] or {}
	table.insert(byBiome[plant.Biome], plant)
end

local variants: { [string]: Variant } = {
	Normal = { Id = "Normal", IncomeMultiplier = 1, Neon = false, Rainbow = false },
	Neon = { Id = "Neon", IncomeMultiplier = 3, Neon = true, Rainbow = false },
	Mega = { Id = "Mega", IncomeMultiplier = 10, Neon = true, Rainbow = true },
}

return {
	List = list,
	ById = byId,
	ByBiome = byBiome,
	Variants = variants,
}
