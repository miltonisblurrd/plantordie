--!strict
-- Low-poly scenery pieces for biome builders. Each piece is a handful of primitives with shape
-- variants picked from the biome's seeded rng, so repeats never look copy-pasted.
-- `cf` is the ground point (floor top) and the piece's yaw; `s` scales the whole piece.

local Kit = require(script.Parent.BiomeKit)

type Ctx = Kit.Ctx

local part = Kit.part
local UPRIGHT = Kit.UPRIGHT
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local S = {}

local function lift(cf: CFrame): CFrame
	return cf * CFrame.new(0, Kit.FLOOR_TOP, 0)
end

local function shade(c: Color3, t: number): Color3
	return if t >= 0 then c:Lerp(WHITE, t) else c:Lerp(BLACK, -t)
end

-- Trees -----------------------------------------------------------------------------------------

-- Chunky stacked-block tree; three silhouettes.
function S.blockTree(ctx: Ctx, cf: CFrame, s: number, leaf: Color3, trunk: Color3)
	cf = lift(cf)
	local v = ctx.rng:NextInteger(1, 3)
	local h = (if v == 3 then 12 else 8) * s
	part(ctx, "Trunk", Vector3.new(2.6 * s, h, 2.6 * s), cf * CFrame.new(0, h / 2, 0), trunk, { Material = Enum.Material.Wood })
	if v == 1 then
		part(ctx, "Canopy", Vector3.new(11, 7, 11) * s, cf * CFrame.new(0, h + 2.5 * s, 0) * CFrame.Angles(0, 0.6, 0), leaf)
		part(ctx, "CanopyTop", Vector3.new(7, 5, 7) * s, cf * CFrame.new(0.8 * s, h + 8 * s, -0.5 * s) * CFrame.Angles(0, 0.2, 0), shade(leaf, 0.12))
	elseif v == 2 then
		part(ctx, "Canopy", Vector3.new(9, 6, 9) * s, cf * CFrame.new(-1.5 * s, h + 2 * s, 0), leaf)
		part(ctx, "CanopySide", Vector3.new(7, 5, 7) * s, cf * CFrame.new(3 * s, h + 1 * s, 2 * s) * CFrame.Angles(0, 0.7, 0), shade(leaf, -0.1))
		part(ctx, "CanopyTop", Vector3.new(6, 4, 6) * s, cf * CFrame.new(0, h + 6 * s, 0) * CFrame.Angles(0, 0.4, 0), shade(leaf, 0.15))
	else
		for i = 0, 2 do
			local w = (10 - i * 3) * s
			part(ctx, "Canopy", Vector3.new(w, 3.5 * s, w), cf * CFrame.new(0, h - 2 * s + i * 3.6 * s, 0) * CFrame.Angles(0, i * 0.5, 0), shade(leaf, i * 0.07))
		end
	end
end

-- Rounded tree with two or three offset crowns.
function S.roundTree(ctx: Ctx, cf: CFrame, s: number, leaf: Color3, trunk: Color3)
	cf = lift(cf)
	local h = ctx.rng:NextNumber(7, 10) * s
	part(ctx, "Trunk", Vector3.new(h, 2.2 * s, 2.2 * s), cf * CFrame.new(0, h / 2, 0) * UPRIGHT, trunk, { Shape = CYL, Material = Enum.Material.Wood })
	part(ctx, "Crown", Vector3.one * 10 * s, cf * CFrame.new(0, h + 3 * s, 0), leaf, { Shape = BALL })
	for i = 1, ctx.rng:NextInteger(1, 2) do
		local a = ctx.rng:NextNumber(0, math.pi * 2)
		part(ctx, "Crown", Vector3.one * ctx.rng:NextNumber(5.5, 7.5) * s,
			cf * CFrame.new(math.cos(a) * 4.5 * s, h + (1 + i * 1.5) * s, math.sin(a) * 4.5 * s), shade(leaf, 0.06 * i), { Shape = BALL })
	end
end

-- Conifer of stacked turned slabs. `snow` adds white caps.
function S.pine(ctx: Ctx, cf: CFrame, s: number, leaf: Color3, trunk: Color3, snow: Color3?)
	cf = lift(cf)
	local tiers = ctx.rng:NextInteger(3, 4)
	part(ctx, "Trunk", Vector3.new(2 * s, 5 * s, 2 * s), cf * CFrame.new(0, 2.5 * s, 0), trunk, { Material = Enum.Material.Wood })
	for i = 0, tiers - 1 do
		local w = (11 - i * 2.6) * s
		local y = (5 + i * 4) * s
		part(ctx, "Tier", Vector3.new(w, 3.6 * s, w), cf * CFrame.new(0, y, 0) * CFrame.Angles(0, i * math.rad(45), 0), shade(leaf, i * 0.05))
		if snow and i < tiers - 1 then
			part(ctx, "Snow", Vector3.new(w * 0.8, 0.8 * s, w * 0.8), cf * CFrame.new(0, y + 2 * s, 0) * CFrame.Angles(0, i * math.rad(45), 0), snow,
				{ Material = Enum.Material.Snow, Shadow = false })
		end
	end
	part(ctx, "Tip", Vector3.new(2.4, 3, 2.4) * s, cf * CFrame.new(0, (5 + tiers * 4) * s, 0), snow or shade(leaf, 0.1),
		{ Material = if snow then Enum.Material.Snow else nil })
end

-- Tall trunk with a flat layered umbrella crown (jungle and savanna).
function S.umbrellaTree(ctx: Ctx, cf: CFrame, s: number, leaf: Color3, trunk: Color3)
	cf = lift(cf)
	local h = ctx.rng:NextNumber(14, 18) * s
	local lean = ctx.rng:NextNumber(-0.08, 0.08)
	part(ctx, "Trunk", Vector3.new(2 * s, h, 2 * s), cf * CFrame.Angles(lean, 0, lean) * CFrame.new(0, h / 2, 0), trunk, { Material = Enum.Material.Wood })
	local top = cf * CFrame.Angles(lean, 0, lean) * CFrame.new(0, h, 0)
	part(ctx, "Crown", Vector3.new(16, 2.5, 13) * s, top, leaf)
	part(ctx, "CrownTop", Vector3.new(10, 2.5, 9) * s, top * CFrame.new(1 * s, 2.2 * s, 0) * CFrame.Angles(0, 0.5, 0), shade(leaf, 0.1))
end

-- Huge old tree with buttress roots; optional glowing root tips.
function S.giantTree(ctx: Ctx, cf: CFrame, s: number, leaf: Color3, trunk: Color3, glow: Color3?)
	cf = lift(cf)
	local h = 26 * s
	part(ctx, "Trunk", Vector3.new(h, 7 * s, 7 * s), cf * CFrame.new(0, h / 2, 0) * UPRIGHT, trunk, { Shape = CYL, Material = Enum.Material.Wood })
	for i = 0, 3 do
		local root = cf * CFrame.Angles(0, i * math.pi / 2 + 0.4, 0) * CFrame.new(0, 2.5 * s, 5 * s)
		part(ctx, "Root", Vector3.new(2.5 * s, 5 * s, 7 * s), root, shade(trunk, -0.1), { Wedge = true, Material = Enum.Material.Wood })
		if glow then
			part(ctx, "RootGlow", Vector3.new(1.2, 1.2, 1.2) * s, root * CFrame.new(0, -1.8 * s, 3.4 * s), glow,
				{ Material = NEON, Shape = BALL, Decor = true })
		end
	end
	part(ctx, "Crown", Vector3.one * 24 * s, cf * CFrame.new(0, h + 6 * s, 0), leaf, { Shape = BALL })
	part(ctx, "CrownL", Vector3.one * 15 * s, cf * CFrame.new(-11 * s, h + 1 * s, 3 * s), shade(leaf, -0.08), { Shape = BALL })
	part(ctx, "CrownR", Vector3.one * 14 * s, cf * CFrame.new(10 * s, h + 3 * s, -4 * s), shade(leaf, 0.08), { Shape = BALL })
end

-- Bare twisted tree (swamp, inferno, forbidden).
function S.deadTree(ctx: Ctx, cf: CFrame, s: number, bark: Color3)
	cf = lift(cf)
	local h = ctx.rng:NextNumber(10, 14) * s
	local bend = ctx.rng:NextNumber(-0.25, 0.25)
	part(ctx, "Trunk", Vector3.new(2.2 * s, h, 2.2 * s), cf * CFrame.Angles(0, 0, bend * 0.5) * CFrame.new(0, h / 2, 0), bark, { Material = Enum.Material.Wood })
	for i = 1, 3 do
		local y = h * (0.45 + i * 0.15)
		local a = i * 2.2 + ctx.rng:NextNumber(-0.4, 0.4)
		local len = ctx.rng:NextNumber(5, 8) * s
		part(ctx, "Branch", Vector3.new(len, 1.1 * s, 1.1 * s),
			cf * CFrame.Angles(0, 0, bend * 0.5) * CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0.6) * CFrame.new(len / 2, 0, 0), bark,
			{ Material = Enum.Material.Wood })
	end
end

-- Curved palm: three leaning trunk segments, six fronds, coconuts.
function S.palm(ctx: Ctx, cf: CFrame, s: number, leaf: Color3, trunk: Color3)
	cf = lift(cf)
	local seg = 5 * s
	local at = cf
	local lean = ctx.rng:NextNumber(0.08, 0.16)
	for i = 0, 2 do
		at = at * CFrame.Angles(lean, 0, 0)
		part(ctx, "PalmTrunk", Vector3.new(2 * s - i * 0.2 * s, seg, 2 * s - i * 0.2 * s), at * CFrame.new(0, seg / 2, 0), shade(trunk, i * 0.06),
			{ Material = Enum.Material.Wood })
		at = at * CFrame.new(0, seg, 0)
	end
	for i = 0, 5 do
		part(ctx, "Frond", Vector3.new(11 * s, 0.6, 3 * s),
			at * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(4.5 * s, -0.4, 0) * CFrame.Angles(0, 0, -0.35), shade(leaf, (i % 2) * 0.08))
	end
	part(ctx, "Coconuts", Vector3.one * 1.8 * s, at * CFrame.new(0.6 * s, -1.2 * s, 0), Color3.fromRGB(110, 72, 40), { Shape = BALL })
end

-- Swamp willow: trunk, flat crown, hanging strands.
function S.willow(ctx: Ctx, cf: CFrame, s: number, leaf: Color3, trunk: Color3)
	cf = lift(cf)
	local h = 11 * s
	part(ctx, "Trunk", Vector3.new(2.6 * s, h, 2.6 * s), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, 0.06), trunk, { Material = Enum.Material.Wood })
	part(ctx, "Crown", Vector3.new(14, 4, 14) * s, cf * CFrame.new(0, h + 1 * s, 0), leaf)
	Kit.decor(ctx, function()
		for i = 0, 5 do
			local a = i * math.pi / 3
			part(ctx, "Strand", Vector3.new(1.2 * s, 7 * s, 1.2 * s), cf * CFrame.new(math.cos(a) * 6 * s, h - 3.5 * s, math.sin(a) * 6 * s), shade(leaf, -0.12))
		end
	end)
end

-- Plants -----------------------------------------------------------------------------------------

function S.bush(ctx: Ctx, cf: CFrame, s: number, color: Color3, berry: Color3?)
	cf = lift(cf)
	part(ctx, "Bush", Vector3.new(6, 4.5, 5.5) * s, cf * CFrame.new(0, 1.6 * s, 0), color, { Shape = BALL })
	part(ctx, "BushSide", Vector3.new(4, 3.4, 4) * s, cf * CFrame.new(2.6 * s, 1.2 * s, 1 * s), shade(color, 0.08), { Shape = BALL })
	if berry then
		Kit.decor(ctx, function()
			part(ctx, "Berry", Vector3.one * 0.9 * s, cf * CFrame.new(-1 * s, 3.4 * s, 1.5 * s), berry, { Shape = BALL })
		end)
	end
end

-- Walk-through dressing --------------------------------------------------------------------------

function S.tuft(ctx: Ctx, cf: CFrame, s: number, color: Color3)
	cf = lift(cf)
	Kit.decor(ctx, function()
		part(ctx, "Tuft", Vector3.new(0.3, 1.6, 1.8) * s, cf * CFrame.new(0, 0.8 * s, 0) * CFrame.Angles(0, 0, 0.2), color, { Wedge = true })
		part(ctx, "Tuft", Vector3.new(0.3, 1.2, 1.4) * s, cf * CFrame.Angles(0, 1.7, 0) * CFrame.new(0.4 * s, 0.6 * s, 0), shade(color, 0.1), { Wedge = true })
	end)
end

function S.flower(ctx: Ctx, cf: CFrame, s: number, petal: Color3)
	cf = lift(cf)
	Kit.decor(ctx, function()
		part(ctx, "Stem", Vector3.new(0.35, 2, 0.35) * s, cf * CFrame.new(0, s, 0), Color3.fromRGB(62, 142, 65))
		part(ctx, "Bloom", Vector3.new(1.6, 0.8, 1.6) * s, cf * CFrame.new(0, 2.1 * s, 0) * CFrame.Angles(0, math.rad(45), 0), petal)
	end)
end

function S.leafPile(ctx: Ctx, cf: CFrame, s: number, a: Color3, b: Color3)
	cf = lift(cf)
	Kit.decor(ctx, function()
		part(ctx, "Leaves", Vector3.new(5, 0.8, 4) * s, cf * CFrame.new(0, 0.3, 0), a, { Shape = BALL })
		part(ctx, "Leaves", Vector3.new(3, 0.7, 3) * s, cf * CFrame.new(1.8 * s, 0.35, 1 * s), b, { Shape = BALL })
	end)
end

-- Neon crack in the floor (lava, toxic, cosmic seams).
function S.crack(ctx: Ctx, cf: CFrame, s: number, color: Color3)
	cf = lift(cf)
	Kit.decor(ctx, function()
		part(ctx, "Crack", Vector3.new(0.6 * s, 0.12, 9 * s), cf * CFrame.new(0, 0.06, 0), color, { Material = NEON })
		part(ctx, "Crack", Vector3.new(0.5 * s, 0.12, 5 * s), cf * CFrame.new(1.5 * s, 0.06, 5 * s) * CFrame.Angles(0, 0.7, 0), color, { Material = NEON })
	end)
end

function S.pebbles(ctx: Ctx, cf: CFrame, s: number, color: Color3)
	cf = lift(cf)
	Kit.decor(ctx, function()
		for i = 0, 2 do
			part(ctx, "Pebble", Vector3.new(1.4, 0.7, 1.1) * s * (1 - i * 0.2),
				cf * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(1.4 * s, 0.25, 0) * CFrame.Angles(0, i, 0), shade(color, i * 0.06))
		end
	end)
end

-- Fungi, cacti, crystals, coral ---------------------------------------------------------------

function S.mushroom(ctx: Ctx, cf: CFrame, s: number, cap: Color3, stem: Color3, glow: boolean?)
	cf = lift(cf)
	local h = ctx.rng:NextNumber(5, 8) * s
	local tilt = ctx.rng:NextNumber(-0.12, 0.12)
	local base = cf * CFrame.Angles(tilt, 0, tilt)
	part(ctx, "Stem", Vector3.new(h, 2.2 * s, 2.2 * s), base * CFrame.new(0, h / 2, 0) * UPRIGHT, stem, { Shape = CYL })
	local capPart = part(ctx, "Cap", Vector3.new(2.5 * s, 10 * s, 10 * s), base * CFrame.new(0, h + s, 0) * UPRIGHT, cap,
		{ Shape = CYL, Material = if glow then NEON else nil })
	part(ctx, "CapTop", Vector3.new(6, 2.4, 6) * s, base * CFrame.new(0, h + 2.4 * s, 0), shade(cap, 0.15), { Shape = BALL })
	Kit.decor(ctx, function()
		part(ctx, "Spot", Vector3.new(1.4, 0.5, 1.4) * s, base * CFrame.new(2 * s, h + 3.1 * s, 1 * s), WHITE)
		part(ctx, "Spot", Vector3.new(1.1, 0.5, 1.1) * s, base * CFrame.new(-1.6 * s, h + 3.2 * s, -1.4 * s), WHITE)
	end)
	if glow then
		Kit.light(ctx, capPart, cap, 22, 1)
	end
end

function S.mushroomPatch(ctx: Ctx, cf: CFrame, s: number, cap: Color3, stem: Color3)
	cf = lift(cf)
	Kit.decor(ctx, function()
		for i = 0, 2 do
			local o = cf * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(1.5 * s, 0, 0)
			local h = (1 + i * 0.5) * s
			part(ctx, "Stem", Vector3.new(0.5, h, 0.5) * s, o * CFrame.new(0, h / 2, 0), stem)
			part(ctx, "Cap", Vector3.new(1.8, 0.7, 1.8) * s, o * CFrame.new(0, h, 0), cap, { Shape = BALL })
		end
	end)
end

function S.cactus(ctx: Ctx, cf: CFrame, s: number, color: Color3, bloom: Color3?)
	cf = lift(cf)
	local h = ctx.rng:NextNumber(8, 13) * s
	part(ctx, "Cactus", Vector3.new(2.6 * s, h, 2.6 * s), cf * CFrame.new(0, h / 2, 0), color)
	for _, side in { -1, 1 } do
		if ctx.rng:NextNumber() < 0.8 then
			local y = h * ctx.rng:NextNumber(0.35, 0.6)
			local up = ctx.rng:NextNumber(3, 5) * s
			part(ctx, "ArmOut", Vector3.new(3 * s, 1.6 * s, 1.6 * s), cf * CFrame.new(side * 2.2 * s, y, 0), color)
			part(ctx, "ArmUp", Vector3.new(1.6 * s, up, 1.6 * s), cf * CFrame.new(side * 3 * s, y + up / 2, 0), shade(color, 0.05))
		end
	end
	if bloom then
		Kit.decor(ctx, function()
			part(ctx, "Bloom", Vector3.one * 1.4 * s, cf * CFrame.new(0, h + 0.4 * s, 0), bloom, { Shape = BALL })
		end)
	end
end

function S.barrelCactus(ctx: Ctx, cf: CFrame, s: number, color: Color3, bloom: Color3)
	cf = lift(cf)
	part(ctx, "Barrel", Vector3.new(3.5, 3, 3.5) * s, cf * CFrame.new(0, 1.3 * s, 0), color, { Shape = BALL })
	Kit.decor(ctx, function()
		part(ctx, "Bloom", Vector3.one * 1.1 * s, cf * CFrame.new(0, 2.9 * s, 0), bloom, { Shape = BALL })
	end)
end

function S.crystals(ctx: Ctx, cf: CFrame, s: number, color: Color3, glow: boolean?)
	cf = lift(cf)
	local n = ctx.rng:NextInteger(3, 5)
	local first: BasePart? = nil
	for i = 1, n do
		local h = ctx.rng:NextNumber(5, 11) * s * (if i == 1 then 1.4 else 1)
		local w = ctx.rng:NextNumber(1.6, 2.8) * s
		local o = cf * CFrame.Angles(0, i * 2.4, 0) * CFrame.new(if i == 1 then 0 else 2.2 * s, 0, 0)
			* CFrame.Angles(ctx.rng:NextNumber(-0.35, 0.35), 0, ctx.rng:NextNumber(-0.35, 0.35))
		local c = shade(color, (i % 3) * 0.1)
		local p = part(ctx, "Crystal", Vector3.new(w, h, w), o * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), c,
			{ Material = if glow and i == 1 then NEON else Enum.Material.Glass, Transparency = if glow and i == 1 then 0 else 0.15 })
		part(ctx, "CrystalTip", Vector3.new(w, w, w), o * CFrame.new(0, h + w * 0.35, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), shade(c, 0.25),
			{ Material = Enum.Material.Glass, Decor = true })
		first = first or p
	end
	if glow and first then
		Kit.light(ctx, first, color, 24, 1.4)
	end
end

function S.iceSpike(ctx: Ctx, cf: CFrame, s: number, color: Color3)
	cf = lift(cf)
	local h = ctx.rng:NextNumber(8, 16) * s
	part(ctx, "Ice", Vector3.new(3 * s, h, 3 * s), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0.1, 0.4, -0.08), color,
		{ Material = Enum.Material.Ice, Transparency = 0.1 })
	part(ctx, "Ice", Vector3.new(2 * s, h * 0.6, 2 * s), cf * CFrame.new(2 * s, h * 0.3, 1 * s) * CFrame.Angles(-0.2, 0, 0.25), shade(color, 0.2),
		{ Material = Enum.Material.Ice, Transparency = 0.1 })
end

function S.coral(ctx: Ctx, cf: CFrame, s: number, color: Color3)
	cf = lift(cf)
	for i = 0, 3 do
		local h = (4 + i * 1.6) * s
		local root = cf * CFrame.Angles(0, i * 1.6, 0) * CFrame.new(1.2 * s, 0, 0) * CFrame.Angles(0, 0, 0.3 * (i - 1.5))
		part(ctx, "Branch", Vector3.new(1.5 * s, h, 1.5 * s), root * CFrame.new(0, h / 2, 0), shade(color, i * 0.05))
		part(ctx, "Tip", Vector3.one * 2 * s, root * CFrame.new(0, h, 0), shade(color, 0.3), { Shape = BALL, Decor = true })
	end
end

function S.fanCoral(ctx: Ctx, cf: CFrame, s: number, color: Color3)
	cf = lift(cf)
	part(ctx, "Fan", Vector3.new(0.6, 9 * s, 10 * s), cf * CFrame.new(0, 4.5 * s, 0) * UPRIGHT * CFrame.Angles(math.pi / 2, 0, 0), color,
		{ Shape = CYL, Transparency = 0.1 })
end

function S.kelp(ctx: Ctx, cf: CFrame, s: number, color: Color3)
	cf = lift(cf)
	Kit.decor(ctx, function()
		local at = cf
		for i = 0, 3 do
			at = at * CFrame.Angles(0.12 * (if i % 2 == 0 then 1 else -1), 0.5, 0)
			part(ctx, "Kelp", Vector3.new(1.4 * s, 4 * s, 0.4), at * CFrame.new(0, 2 * s, 0), shade(color, i * 0.06))
			at = at * CFrame.new(0, 4 * s, 0)
		end
	end)
end

function S.shell(ctx: Ctx, cf: CFrame, s: number, color: Color3)
	cf = lift(cf)
	for i = -2, 2 do
		part(ctx, "Rib", Vector3.new(2.2 * s, 7 * s, 1.4 * s),
			cf * CFrame.Angles(0, 0, i * 0.32) * CFrame.new(0, 3.5 * s, 0), shade(color, (i % 2) * 0.12), { Wedge = true })
	end
	part(ctx, "Hinge", Vector3.new(3, 2, 2) * s, cf * CFrame.new(0, 1 * s, 0), shade(color, -0.1))
end

-- Rocks and wood ----------------------------------------------------------------------------------

function S.rocks(ctx: Ctx, cf: CFrame, s: number, color: Color3, material: Enum.Material?)
	cf = lift(cf)
	local mat = material or Enum.Material.Slate
	local n = ctx.rng:NextInteger(2, 4)
	for i = 1, n do
		local sz = Vector3.new(ctx.rng:NextNumber(3, 7), ctx.rng:NextNumber(2.5, 6), ctx.rng:NextNumber(3, 6)) * s * (if i == 1 then 1.3 else 0.8)
		local o = cf * CFrame.Angles(0, i * 2.3, 0) * CFrame.new(if i == 1 then 0 else 3.5 * s, sz.Y * 0.4, 0)
			* CFrame.Angles(ctx.rng:NextNumber(-0.25, 0.25), ctx.rng:NextNumber(0, 3), ctx.rng:NextNumber(-0.25, 0.25))
		part(ctx, "Rock", sz, o, shade(color, (i - 1) * 0.06), { Material = mat, Wedge = i == n and n > 2 })
	end
end

function S.boulder(ctx: Ctx, cf: CFrame, s: number, color: Color3, material: Enum.Material?)
	cf = lift(cf)
	part(ctx, "Boulder", Vector3.new(9, 7, 8) * s, cf * CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(0.2, 0.4, 0.1), color,
		{ Material = material or Enum.Material.Slate })
	part(ctx, "BoulderTop", Vector3.new(5, 4, 5) * s, cf * CFrame.new(1 * s, 5.8 * s, 0.5 * s) * CFrame.Angles(0.5, 1.1, 0.3), shade(color, 0.08),
		{ Material = material or Enum.Material.Slate })
end

function S.log(ctx: Ctx, cf: CFrame, s: number, bark: Color3, moss: Color3?)
	cf = lift(cf)
	local len = ctx.rng:NextNumber(9, 14) * s
	part(ctx, "Log", Vector3.new(len, 2.4 * s, 2.4 * s), cf * CFrame.new(0, 1.1 * s, 0), bark, { Shape = CYL, Material = Enum.Material.Wood })
	part(ctx, "LogEnd", Vector3.new(0.3, 2, 2) * s, cf * CFrame.new(len / 2 + 0.05, 1.1 * s, 0), shade(bark, 0.35), { Shape = CYL, Decor = true })
	part(ctx, "Branch", Vector3.new(1, 3, 1) * s, cf * CFrame.new(len * 0.2, 2.6 * s, 0) * CFrame.Angles(0, 0, -0.5), bark, { Decor = true })
	if moss then
		part(ctx, "Moss", Vector3.new(len * 0.5, 0.6, 2) * s, cf * CFrame.new(-len * 0.15, 2.3 * s, 0), moss,
			{ Material = Enum.Material.Grass, Decor = true })
	end
end

function S.stump(ctx: Ctx, cf: CFrame, s: number, bark: Color3)
	cf = lift(cf)
	part(ctx, "Stump", Vector3.new(2.4, 3.2, 3.2) * s, cf * CFrame.new(0, 1.2 * s, 0) * UPRIGHT, bark, { Shape = CYL, Material = Enum.Material.Wood })
	part(ctx, "Rings", Vector3.new(0.2, 2.6, 2.6) * s, cf * CFrame.new(0, 2.45 * s, 0) * UPRIGHT, shade(bark, 0.4), { Shape = CYL, Decor = true })
end

-- Structures -------------------------------------------------------------------------------------

function S.pillar(ctx: Ctx, cf: CFrame, s: number, color: Color3, broken: boolean?)
	cf = lift(cf)
	local h = (if broken then ctx.rng:NextNumber(6, 12) else 18) * s
	part(ctx, "PillarBase", Vector3.new(5, 1.5, 5) * s, cf * CFrame.new(0, 0.75 * s, 0), shade(color, -0.1), { Material = Enum.Material.Limestone })
	part(ctx, "Pillar", Vector3.new(h, 3.2 * s, 3.2 * s), cf * CFrame.new(0, 1.5 * s + h / 2, 0) * UPRIGHT, color,
		{ Shape = CYL, Material = Enum.Material.Limestone })
	if broken then
		part(ctx, "Chunk", Vector3.new(3, 3, 4) * s, cf * CFrame.new(3.5 * s, 1.5 * s, 1 * s) * CFrame.Angles(0.3, 0.7, 0.2), color,
			{ Material = Enum.Material.Limestone })
	else
		part(ctx, "Capital", Vector3.new(5, 1.5, 5) * s, cf * CFrame.new(0, 1.5 * s + h + 0.75 * s, 0), shade(color, 0.1), { Material = Enum.Material.Limestone })
	end
end

function S.arch(ctx: Ctx, cf: CFrame, s: number, color: Color3, material: Enum.Material?)
	cf = lift(cf)
	local mat = material or Enum.Material.Limestone
	local w, h = 20 * s, 18 * s
	for _, side in { -1, 1 } do
		part(ctx, "ArchLeg", Vector3.new(4 * s, h, 4 * s), cf * CFrame.new(side * w / 2, h / 2, 0), color, { Material = mat })
	end
	part(ctx, "ArchTop", Vector3.new(w + 6 * s, 4 * s, 5 * s), cf * CFrame.new(0, h + 2 * s, 0), shade(color, 0.08), { Material = mat })
end

function S.statue(ctx: Ctx, cf: CFrame, s: number, color: Color3, moss: Color3?)
	cf = lift(cf)
	local mat = Enum.Material.Limestone
	part(ctx, "Plinth", Vector3.new(8, 4, 8) * s, cf * CFrame.new(0, 2 * s, 0), shade(color, -0.15), { Material = mat })
	part(ctx, "Legs", Vector3.new(4, 6, 2.4) * s, cf * CFrame.new(0, 7 * s, 0), color, { Material = mat })
	part(ctx, "Torso", Vector3.new(5, 6, 2.8) * s, cf * CFrame.new(0, 13 * s, 0), color, { Material = mat })
	part(ctx, "Head", Vector3.new(3, 3, 3) * s, cf * CFrame.new(0, 17.5 * s, 0), shade(color, 0.05), { Material = mat })
	part(ctx, "Arm", Vector3.new(1.6, 6, 1.6) * s, cf * CFrame.new(3.3 * s, 14 * s, 0) * CFrame.Angles(0, 0, -0.5), color, { Material = mat })
	if moss then
		part(ctx, "Moss", Vector3.new(8.4, 0.8, 8.4) * s, cf * CFrame.new(0, 4.2 * s, 0), moss, { Material = Enum.Material.Grass, Decor = true })
	end
end

function S.lantern(ctx: Ctx, cf: CFrame, s: number, post: Color3, glow: Color3)
	cf = lift(cf)
	part(ctx, "Post", Vector3.new(0.8, 9, 0.8) * s, cf * CFrame.new(0, 4.5 * s, 0), post)
	local lamp = part(ctx, "Lamp", Vector3.new(1.8, 2.2, 1.8) * s, cf * CFrame.new(0, 9.8 * s, 0), glow, { Material = NEON, Decor = true })
	Kit.light(ctx, lamp, glow, 20, 1.2)
end

function S.fence(ctx: Ctx, cf: CFrame, s: number, wood: Color3, length: number)
	cf = lift(cf)
	local posts = math.max(2, math.floor(length / 6) + 1)
	for i = 0, posts - 1 do
		part(ctx, "FencePost", Vector3.new(1, 4, 1) * s, cf * CFrame.new(-length / 2 + i * length / (posts - 1), 2 * s, 0), wood, { Material = Enum.Material.Wood })
	end
	for _, y in { 1.6, 3.2 } do
		part(ctx, "FenceRail", Vector3.new(length, 0.6 * s, 0.5 * s), cf * CFrame.new(0, y * s, 0), shade(wood, 0.1), { Material = Enum.Material.Wood })
	end
end

-- Water and ground features ---------------------------------------------------------------------

-- Pond with a ring of rim stones. Water is walk-through; the stones collide.
function S.pond(ctx: Ctx, cf: CFrame, r: number, water: Color3, rim: Color3, neon: boolean?)
	cf = lift(cf)
	part(ctx, "Water", Vector3.new(0.3, r * 2, r * 2 * 0.75), cf * CFrame.new(0, 0.12, 0) * UPRIGHT, water,
		{ Shape = CYL, Material = if neon then NEON else Enum.Material.Glass, Transparency = if neon then 0.1 else 0.25, Decor = true })
	part(ctx, "Bed", Vector3.new(0.2, r * 2 - 1, r * 1.5 - 1), cf * CFrame.new(0, 0.02, 0) * UPRIGHT, shade(water, -0.4),
		{ Shape = CYL, Decor = true })
	local stones = math.floor(r / 2.2)
	for i = 0, stones - 1 do
		local a = i * math.pi * 2 / stones
		part(ctx, "RimStone", Vector3.new(3, 1.4, 2.4) * ctx.rng:NextNumber(0.8, 1.3),
			cf * CFrame.new(math.cos(a) * r, 0.5, math.sin(a) * r * 0.75) * CFrame.Angles(0, -a + ctx.rng:NextNumber(-0.3, 0.3), 0), shade(rim, (i % 3) * 0.06),
			{ Material = Enum.Material.Slate })
	end
end

-- Layered mesa / canyon stack: wide base, stepped shelves, flat top.
function S.mesa(ctx: Ctx, cf: CFrame, w: number, h: number, colors: { Color3 }, material: Enum.Material?)
	cf = lift(cf)
	local layers = #colors
	local y = 0
	for i, c in colors do
		local lh = h / layers
		local lw = w * (1 - (i - 1) * 0.16)
		part(ctx, "Layer", Vector3.new(lw, lh, lw * 0.8), cf * CFrame.new((i % 2) * 1.5, y + lh / 2, 0) * CFrame.Angles(0, (i - 1) * 0.12, 0), c,
			{ Material = material or Enum.Material.Sandstone })
		y += lh
	end
end

-- Stepped volcanic cone with a glowing crater and a lava run down one face.
function S.volcano(ctx: Ctx, cf: CFrame, s: number, rock: Color3, lava: Color3)
	cf = lift(cf)
	for i = 0, 3 do
		local d = (40 - i * 8) * s
		part(ctx, "Cone", Vector3.new(7 * s, d, d), cf * CFrame.new(0, 3.5 * s + i * 7 * s, 0) * UPRIGHT, shade(rock, i * 0.05),
			{ Shape = CYL, Material = Enum.Material.Basalt })
	end
	local crater = part(ctx, "Crater", Vector3.new(1, 12 * s, 12 * s), cf * CFrame.new(0, 28.6 * s, 0) * UPRIGHT, lava,
		{ Shape = CYL, Material = NEON, Decor = true })
	part(ctx, "LavaRun", Vector3.new(3 * s, 0.6, 20 * s), cf * CFrame.new(0, 14 * s, 12 * s) * CFrame.Angles(-0.85, 0, 0), lava,
		{ Material = NEON, Decor = true })
	Kit.light(ctx, crater, lava, 40, 2)
end

-- Sky ---------------------------------------------------------------------------------------------

function S.cloud(ctx: Ctx, cf: CFrame, s: number, color: Color3?)
	local c = color or WHITE
	Kit.decor(ctx, function()
		part(ctx, "Cloud", Vector3.new(14, 6, 9) * s, cf, c, { Shape = BALL, Material = Enum.Material.SmoothPlastic })
		part(ctx, "Cloud", Vector3.new(9, 5, 7) * s, cf * CFrame.new(6 * s, 1 * s, 1 * s), shade(c, -0.04), { Shape = BALL })
		part(ctx, "Cloud", Vector3.new(8, 4.5, 6) * s, cf * CFrame.new(-6 * s, 0.5 * s, -1 * s), shade(c, -0.02), { Shape = BALL })
	end)
end

-- Floating grassy island with a hanging rock root. Decor: nothing up there to stand on.
function S.floatingIsland(ctx: Ctx, cf: CFrame, w: number, top: Color3, under: Color3, leaf: Color3?)
	Kit.decor(ctx, function()
		part(ctx, "IslandTop", Vector3.new(w, 2.5, w * 0.8), cf, top, { Material = Enum.Material.Grass })
		part(ctx, "IslandDirt", Vector3.new(w * 0.9, 3, w * 0.72), cf * CFrame.new(0, -2.6, 0), shade(under, 0.1), { Material = Enum.Material.Ground })
		part(ctx, "IslandRoot", Vector3.new(w * 0.6, w * 0.55, w * 0.5), cf * CFrame.new(0, -4 - w * 0.27, 0) * CFrame.Angles(math.pi, 0, 0), under,
			{ Wedge = true, Material = Enum.Material.Slate })
		if leaf then
			part(ctx, "IslandTree", Vector3.one * w * 0.35, cf * CFrame.new(w * 0.15, w * 0.3, 0), leaf, { Shape = BALL })
			part(ctx, "IslandTrunk", Vector3.new(1.2, w * 0.25, 1.2), cf * CFrame.new(w * 0.15, w * 0.12, 0), Color3.fromRGB(110, 72, 44))
		end
	end)
end

function S.planet(ctx: Ctx, cf: CFrame, r: number, color: Color3, ring: Color3?)
	Kit.decor(ctx, function()
		part(ctx, "Planet", Vector3.one * r * 2, cf, color, { Shape = BALL })
		if ring then
			part(ctx, "Ring", Vector3.new(0.4, r * 3.4, r * 3.4), cf * CFrame.Angles(0.4, 0, math.rad(90) + 0.3), ring,
				{ Shape = CYL, Material = NEON, Transparency = 0.35 })
		end
	end)
end

function S.orb(ctx: Ctx, cf: CFrame, s: number, color: Color3, withLight: boolean?)
	local p: BasePart? = nil
	Kit.decor(ctx, function()
		p = part(ctx, "Orb", Vector3.one * 1.8 * s, cf, color, { Shape = BALL, Material = NEON })
	end)
	if withLight and p then
		Kit.light(ctx, p, color, 16, 1)
	end
end

-- Giant flower: thick stem, five petals, glowing heart.
function S.giantFlower(ctx: Ctx, cf: CFrame, s: number, petal: Color3, heart: Color3, stem: Color3, glow: boolean?)
	cf = lift(cf)
	local h = ctx.rng:NextNumber(10, 16) * s
	part(ctx, "Stem", Vector3.new(h, 1.8 * s, 1.8 * s), cf * CFrame.new(0, h / 2, 0) * UPRIGHT, stem, { Shape = CYL })
	part(ctx, "Leaf", Vector3.new(6, 0.5, 2.4) * s, cf * CFrame.new(2.6 * s, h * 0.35, 0) * CFrame.Angles(0, 0, 0.4), shade(stem, 0.1))
	local head = cf * CFrame.new(0, h, 0) * CFrame.Angles(0.25, 0, 0)
	for i = 0, 4 do
		part(ctx, "Petal", Vector3.new(4.5, 0.8, 7) * s,
			head * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0, 4 * s) * CFrame.Angles(-0.35, 0, 0), shade(petal, (i % 2) * 0.1))
	end
	local core = part(ctx, "Heart", Vector3.one * 4 * s, head * CFrame.new(0, 0.8 * s, 0), heart,
		{ Shape = BALL, Material = if glow then NEON else nil })
	if glow then
		Kit.light(ctx, core, heart, 24, 1.3)
	end
end

return S
