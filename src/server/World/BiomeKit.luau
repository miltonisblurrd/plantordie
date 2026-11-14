--!strict
-- Template helpers for biome builders. A builder adds ground detail, scenery and landmarks; the
-- kit builds the shared skeleton (floor, layered walls, shared border, dig spots, patrol points,
-- danger zones) so every biome plays the same way and stays inside the part budget. Biomes are
-- never safe; the only Safe Zone is the shared home area (Shared/SafeZone).
-- Coordinates are biome-local: X across, Z from entrance (-length/2) to back (+length/2).
--
-- Zones: the core is the middle CoreFraction of the width, full length. It holds dig spots,
-- guardian patrols and only non-colliding ground decor. Everything large sits in the side bands
-- between the core and the walls, against the walls, or outside them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local B = Config.Biome
local WALL_H = B.WallHeight
local DOOR_HALF = B.Doorway / 2
local CORE_HALF = B.Width * B.CoreFraction / 2
local SPOT_GAP = 20
local SPOT_PROP_CLEAR = 6 -- extra studs between a dig spot and any registered prop footprint
local ENTRY_CLEAR = 30 -- no dig spots this close to the entrance border
local MAX_LIGHTS = 6
local FLOOR_TOP = 0.1

local Kit = {}
Kit.PART_BUDGET = 900
Kit.CORE_HALF = CORE_HALF
Kit.FLOOR_TOP = FLOOR_TOP

export type Ctx = {
	biome: BiomeData.Biome,
	cf: CFrame,
	size: number,
	width: number,
	length: number,
	model: Model,
	props: Model,
	rng: Random,
	pal: BiomeData.Palette,
	occupied: { { x: number, z: number, r: number } },
	deco: boolean, -- while true, parts are non-colliding, unqueryable and shadowless
	lights: number,
}

export type DigSpot = { id: string, cf: CFrame, requiredTier: number, model: Model }
export type Skeleton = {
	patrol: { Vector3 },
	danger: { { center: Vector3, radius: number } },
	spots: { DigSpot },
}

local function part(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, opts: { [string]: any }?): BasePart
	local o: { [string]: any } = opts or {}
	local deco = ctx.deco or o.Decor == true
	return Parts.make({
		Name = name, Parent = o.Parent or ctx.props, Size = size, CFrame = cf, Color = color,
		Material = o.Material, Shape = o.Shape, Wedge = o.Wedge,
		CanCollide = if deco then false else o.CanCollide,
		Transparency = o.Transparency,
		CastShadow = if o.Shadow ~= nil then o.Shadow elseif deco then false else nil,
		Decor = deco,
	})
end
Kit.part = part

local NEON = Enum.Material.Neon
local CYL = Enum.PartType.Cylinder
Kit.UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders point along X; this stands them up
local UPRIGHT = Kit.UPRIGHT

function Kit.at(ctx: Ctx, x: number, z: number, yaw: number?): CFrame
	return ctx.cf * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
end

-- Runs `fn` with deco mode on: everything it builds is walk-through ground dressing.
function Kit.decor(ctx: Ctx, fn: () -> ())
	local was = ctx.deco
	ctx.deco = true
	fn()
	ctx.deco = was
end

function Kit.newCtx(biome: BiomeData.Biome, cf: CFrame, parent: Instance): Ctx
	local model = Parts.model("Biome_" .. biome.Id, parent)
	model:SetAttribute("BiomeId", biome.Id)
	model:SetAttribute("BiomeIndex", biome.Index)
	model:SetAttribute("Tint", biome.Palette.Ground:Lerp(Color3.new(1, 1, 1), 0.65))
	local props = Parts.model("Props", model)
	return {
		biome = biome, cf = cf, size = B.Size, width = B.Width, length = B.Size,
		model = model, props = props, rng = Random.new(biome.Index * 7919), pal = biome.Palette,
		occupied = {}, deco = false, lights = 0,
	}
end

-- Placement ----------------------------------------------------------------------------------

function Kit.reserve(ctx: Ctx, x: number, z: number, r: number)
	table.insert(ctx.occupied, { x = x, z = z, r = r })
end

function Kit.isFree(ctx: Ctx, x: number, z: number, r: number): boolean
	for _, o in ctx.occupied do
		local dx, dz = o.x - x, o.z - z
		if dx * dx + dz * dz < (o.r + r) ^ 2 then
			return false
		end
	end
	return true
end

local function inBand(ctx: Ctx, x: number, z: number, r: number): boolean
	local ax = math.abs(x)
	return ax >= CORE_HALF + r * 0.5 and ax <= ctx.width / 2 - 4 - r and math.abs(z) <= ctx.length / 2 - 4 - r
end

-- A free point in a side band (between the open core and the side walls), or nil.
function Kit.edgePoint(ctx: Ctx, r: number, side: number?): (number?, number?)
	for _ = 1, 30 do
		local s = side or (if ctx.rng:NextNumber() < 0.5 then -1 else 1)
		local lo, hi = CORE_HALF + r * 0.5, ctx.width / 2 - 4 - r
		if hi < lo then
			return nil, nil
		end
		local x = s * ctx.rng:NextNumber(lo, hi)
		local z = ctx.rng:NextNumber(-ctx.length / 2 + 4 + r, ctx.length / 2 - 4 - r)
		if Kit.isFree(ctx, x, z, r) then
			return x, z
		end
	end
	return nil, nil
end

-- Big scenery in the side bands. `r` is the footprint radius kept clear of other props.
function Kit.edgeScatter(ctx: Ctx, count: number, r: number, fn: (CFrame, Random, number) -> ())
	for i = 1, count do
		local x, z = Kit.edgePoint(ctx, r)
		if x and z then
			Kit.reserve(ctx, x, z, r)
			fn(Kit.at(ctx, x, z, ctx.rng:NextNumber(0, math.pi * 2)), ctx.rng, i)
		end
	end
end

-- Groups of scenery: a few anchors in the side bands, members packed loosely around each.
function Kit.clusters(ctx: Ctx, groups: number, perGroup: number, r: number, spread: number, fn: (CFrame, Random, number) -> ())
	local n = 0
	for _ = 1, groups do
		local cx, cz = Kit.edgePoint(ctx, r)
		if cx and cz then
			for _ = 1, perGroup do
				for _ = 1, 8 do
					local x = cx + ctx.rng:NextNumber(-spread, spread)
					local z = cz + ctx.rng:NextNumber(-spread, spread)
					if inBand(ctx, x, z, r) and Kit.isFree(ctx, x, z, r) then
						Kit.reserve(ctx, x, z, r)
						n += 1
						fn(Kit.at(ctx, x, z, ctx.rng:NextNumber(0, math.pi * 2)), ctx.rng, n)
						break
					end
				end
			end
		end
	end
end

-- A row hugging both side walls, with jittered spacing, so the wall foot reads as planted.
function Kit.wallRow(ctx: Ctx, spacing: number, r: number, fn: (CFrame, Random, number) -> ())
	local n = 0
	for _, side in { -1, 1 } do
		local z = -ctx.length / 2 + r + 6
		while z < ctx.length / 2 - r - 4 do
			local x = side * (ctx.width / 2 - 4 - r - ctx.rng:NextNumber(0, 6))
			if Kit.isFree(ctx, x, z, r) then
				Kit.reserve(ctx, x, z, r)
				n += 1
				fn(Kit.at(ctx, x, z, ctx.rng:NextNumber(0, math.pi * 2)), ctx.rng, n)
			end
			z += spacing * ctx.rng:NextNumber(0.75, 1.3)
		end
	end
end

-- Landmark slot in a side band. `t` runs -1 (entrance) to 1 (back). Reserves the footprint.
function Kit.landmark(ctx: Ctx, side: number, t: number, r: number): CFrame
	local x = side * math.max(CORE_HALF + r * 0.6, ctx.width / 2 - 6 - r)
	local z = math.clamp(t * ctx.length / 2, -ctx.length / 2 + r + 6, ctx.length / 2 - r - 6)
	Kit.reserve(ctx, x, z, r)
	return Kit.at(ctx, x, z, if side < 0 then math.pi / 2 else -math.pi / 2)
end

-- Small walk-through dressing anywhere on the floor, the core included.
function Kit.coreScatter(ctx: Ctx, count: number, fn: (CFrame, Random, number) -> ())
	Kit.decor(ctx, function()
		for i = 1, count do
			for _ = 1, 10 do
				local x = ctx.rng:NextNumber(-ctx.width / 2 + 8, ctx.width / 2 - 8)
				local z = ctx.rng:NextNumber(-ctx.length / 2 + 8, ctx.length / 2 - 8)
				if Kit.isFree(ctx, x, z, 3) then
					Kit.reserve(ctx, x, z, 2)
					fn(Kit.at(ctx, x, z, ctx.rng:NextNumber(0, math.pi * 2)), ctx.rng, i)
					break
				end
			end
		end
	end)
end

-- Silhouettes just outside the side walls: depth for the skyline, nothing to walk into.
function Kit.outside(ctx: Ctx, count: number, fn: (CFrame, Random, number) -> ())
	Kit.decor(ctx, function()
		for i = 1, count do
			local side = if i % 2 == 0 then -1 else 1
			local x = side * (ctx.width / 2 + ctx.rng:NextNumber(14, 70))
			local z = ctx.rng:NextNumber(-ctx.length / 2, ctx.length / 2)
			fn(Kit.at(ctx, x, z, ctx.rng:NextNumber(0, math.pi * 2)), ctx.rng, i)
		end
	end)
end

function Kit.light(ctx: Ctx, host: BasePart, color: Color3, range: number?, brightness: number?)
	if ctx.lights >= MAX_LIGHTS then
		return
	end
	ctx.lights += 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 18
	light.Brightness = brightness or 1.2
	light.Shadows = false
	light.Parent = host
end

-- Lighting the client blends to while the player is in this biome (client/Atmosphere).
export type Mood = {
	haze: Color3, -- Atmosphere.Color
	decay: Color3, -- Atmosphere.Decay
	density: number,
	tint: Color3?,
	saturation: number?,
	contrast: number?,
	brightness: number?,
}

function Kit.mood(ctx: Ctx, m: Mood)
	local model = ctx.model
	model:SetAttribute("AtmoColor", m.haze)
	model:SetAttribute("AtmoDecay", m.decay)
	model:SetAttribute("AtmoDensity", m.density)
	model:SetAttribute("Tint", m.tint or Color3.new(1, 1, 1))
	model:SetAttribute("Saturation", m.saturation or 0.1)
	model:SetAttribute("Contrast", m.contrast or 0.05)
	model:SetAttribute("Brightness", m.brightness or 0)
end

-- Ground ---------------------------------------------------------------------------------------

-- Flat, walk-through ground patches (discs) laid over the floor. Overlaps stagger in height.
function Kit.patches(ctx: Ctx, count: number, minR: number, maxR: number, colors: { Color3 }, material: Enum.Material?, coreOnly: boolean?)
	Kit.decor(ctx, function()
		for i = 1, count do
			local r = ctx.rng:NextNumber(minR, maxR)
			local limX = if coreOnly then CORE_HALF - r * 0.5 else ctx.width / 2 - r * 0.6
			local x = ctx.rng:NextNumber(-limX, limX)
			local z = ctx.rng:NextNumber(-ctx.length / 2 + r * 0.6, ctx.length / 2 - r * 0.6)
			local y = FLOOR_TOP + 0.02 + (i % 7) * 0.012
			local c = colors[(i - 1) % #colors + 1]
			local stretch = ctx.rng:NextNumber(0.6, 1)
			part(ctx, "GroundPatch", Vector3.new(0.1, r * 2, r * 2 * stretch),
				Kit.at(ctx, x, z, ctx.rng:NextNumber(0, math.pi)) * CFrame.new(0, y, 0) * UPRIGHT, c,
				{ Shape = CYL, Material = material, Parent = ctx.model })
		end
	end)
end

-- Low rounded rise against the walls. Never in the core.
function Kit.mound(ctx: Ctx, cf: CFrame, w: number, h: number, color: Color3, material: Enum.Material?)
	part(ctx, "Mound", Vector3.new(w, h * 2, w * 0.8), cf, color, { Shape = Enum.PartType.Ball, Material = material or Enum.Material.Grass })
end

type WallLook = { body: Color3, mat: Enum.Material, cap: Color3, capMat: Enum.Material, trim: Color3? }
local GRASS_MAT, SMOOTH = Enum.Material.Grass, Enum.Material.SmoothPlastic
local WALL_LOOKS: { [string]: WallLook } = {
	GreenMeadows = { body = Color3.fromRGB(196, 128, 96), mat = Enum.Material.Cobblestone, cap = Color3.fromRGB(98, 200, 72), capMat = GRASS_MAT, trim = Color3.fromRGB(150, 98, 70) },
	MushroomForest = { body = Color3.fromRGB(96, 66, 132), mat = Enum.Material.Slate, cap = Color3.fromRGB(255, 77, 77), capMat = SMOOTH, trim = Color3.fromRGB(255, 243, 224) },
	CactusCanyon = { body = Color3.fromRGB(214, 140, 76), mat = Enum.Material.Sandstone, cap = Color3.fromRGB(236, 190, 120), capMat = Enum.Material.Sandstone, trim = Color3.fromRGB(176, 96, 52) },
	InfernoJungle = { body = Color3.fromRGB(34, 28, 30), mat = Enum.Material.Basalt, cap = Color3.fromRGB(255, 90, 31), capMat = NEON, trim = Color3.fromRGB(90, 30, 18) },
	FrostbiteGarden = { body = Color3.fromRGB(150, 205, 245), mat = Enum.Material.Glacier, cap = Color3.fromRGB(245, 250, 255), capMat = Enum.Material.Snow, trim = Color3.fromRGB(110, 170, 225) },
	EnchantedGrove = { body = Color3.fromRGB(70, 82, 64), mat = Enum.Material.Cobblestone, cap = Color3.fromRGB(70, 150, 80), capMat = GRASS_MAT, trim = Color3.fromRGB(124, 255, 203) },
	TropicalParadise = { body = Color3.fromRGB(226, 200, 150), mat = Enum.Material.Sandstone, cap = Color3.fromRGB(45, 170, 79), capMat = GRASS_MAT, trim = Color3.fromRGB(0, 170, 150) },
	CoralKingdom = { body = Color3.fromRGB(36, 110, 190), mat = Enum.Material.Pebble, cap = Color3.fromRGB(255, 127, 80), capMat = SMOOTH, trim = Color3.fromRGB(255, 209, 220) },
	AutumnWoods = { body = Color3.fromRGB(120, 90, 70), mat = Enum.Material.Cobblestone, cap = Color3.fromRGB(230, 120, 30), capMat = GRASS_MAT, trim = Color3.fromRGB(110, 62, 38) },
	SkyIslands = { body = Color3.fromRGB(235, 242, 255), mat = SMOOTH, cap = Color3.fromRGB(150, 230, 110), capMat = GRASS_MAT, trim = Color3.fromRGB(142, 201, 255) },
	CrystalCaverns = { body = Color3.fromRGB(45, 45, 70), mat = Enum.Material.Slate, cap = Color3.fromRGB(92, 225, 230), capMat = NEON, trim = Color3.fromRGB(255, 102, 196) },
	ToxicSwamp = { body = Color3.fromRGB(60, 72, 38), mat = Enum.Material.Mud, cap = Color3.fromRGB(166, 255, 0), capMat = NEON, trim = Color3.fromRGB(40, 48, 26) },
	AncientWilds = { body = Color3.fromRGB(176, 158, 120), mat = Enum.Material.Limestone, cap = Color3.fromRGB(106, 153, 78), capMat = GRASS_MAT, trim = Color3.fromRGB(140, 120, 90) },
	CosmicGarden = { body = Color3.fromRGB(36, 20, 74), mat = Enum.Material.Slate, cap = Color3.fromRGB(180, 120, 255), capMat = NEON, trim = Color3.fromRGB(76, 201, 240) },
	ForbiddenBloom = { body = Color3.fromRGB(43, 10, 18), mat = Enum.Material.Slate, cap = Color3.fromRGB(255, 30, 86), capMat = NEON, trim = Color3.fromRGB(255, 215, 0) },
}

-- One wall run from local (x0, z0) to (x1, z1) along a single axis: plinth, body, trim band,
-- cap, and buttresses that break the skyline. `inward` is the local direction facing the floor.
local function wallRun(ctx: Ctx, name: string, x0: number, z0: number, x1: number, z1: number, inward: Vector3, look: WallLook)
	local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
	local len = if alongX then math.abs(x1 - x0) else math.abs(z1 - z0)
	if len < 1 then
		return
	end
	local mid = ctx.cf * CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
	local function box(thick: number, h: number, y: number): Vector3
		return if alongX then Vector3.new(len, h, thick) else Vector3.new(thick, h, len)
	end
	local opts = { Parent = ctx.model, Material = look.mat }
	local trim = look.trim or look.body:Lerp(Color3.new(0, 0, 0), 0.3)
	part(ctx, name .. "Plinth", box(7, 5, 0), mid * CFrame.new(0, 2.5, 0), look.body:Lerp(Color3.new(0, 0, 0), 0.25), opts)
	part(ctx, name, box(4, WALL_H, 0), mid * CFrame.new(0, WALL_H / 2, 0), look.body, opts)
	part(ctx, name .. "Trim", box(4.8, 2, 0), mid * CFrame.new(0, WALL_H * 0.62, 0), trim, { Parent = ctx.model, Material = SMOOTH, Shadow = false })
	part(ctx, name .. "Cap", box(6, 2.5, 0), mid * CFrame.new(0, WALL_H + 1.25, 0), look.cap, { Parent = ctx.model, Material = look.capMat })
	local count = math.max(1, math.floor(len / 38))
	for i = 0, count do
		local t = -len / 2 + i * len / count
		local offset = if alongX then Vector3.new(t, 0, 0) else Vector3.new(0, 0, t)
		local h = WALL_H + (if i % 2 == 0 then 8 else 3)
		local base = mid * CFrame.new(offset + inward * 2.5)
		part(ctx, name .. "Buttress", Vector3.new(8, h, 8), base * CFrame.new(0, h / 2, 0), look.body:Lerp(trim, 0.35), opts)
		part(ctx, name .. "ButtressCap", Vector3.new(9.5, 2.5, 9.5), base * CFrame.new(0, h + 1.25, 0), look.cap,
			{ Parent = ctx.model, Material = look.capMat, Shadow = false })
	end
end

-- Floor, layered side walls, the shared entrance border (stubs either side of the doorway, ground
-- seam strip) and, in the last biome only, a closed back wall. Every other back edge is the next
-- biome's entrance border, so there is exactly one border between any two biomes.
function Kit.ground(ctx: Ctx, color: Color3?, material: Enum.Material?)
	local w, len = ctx.width, ctx.length
	local floor = part(ctx, "Floor", Vector3.new(w, 1, len), ctx.cf * CFrame.new(0, FLOOR_TOP - 0.5, 0), color or ctx.pal.Ground,
		{ Material = material or Enum.Material.Grass, Parent = ctx.model })
	floor:SetAttribute("BiomeFloor", true)
	local look = WALL_LOOKS[ctx.biome.Id] or WALL_LOOKS.GreenMeadows
	wallRun(ctx, "WallLeft", -w / 2, -len / 2, -w / 2, len / 2, Vector3.new(1, 0, 0), look)
	wallRun(ctx, "WallRight", w / 2, -len / 2, w / 2, len / 2, Vector3.new(-1, 0, 0), look)

	-- The base front wall already closes the sides of biome 1's entrance.
	if ctx.biome.Index > 1 then
		wallRun(ctx, "BorderLeft", -w / 2, -len / 2, -DOOR_HALF - 4, -len / 2, Vector3.new(0, 0, 1), look)
		wallRun(ctx, "BorderRight", DOOR_HALF + 4, -len / 2, w / 2, -len / 2, Vector3.new(0, 0, 1), look)
	end
	local prev = BiomeData.List[ctx.biome.Index - 1]
	local prevGround = if prev then prev.Palette.Ground else Color3.fromRGB(78, 176, 70)
	Kit.decor(ctx, function()
		part(ctx, "BorderSeam", Vector3.new(w, 0.2, 3), ctx.cf * CFrame.new(0, FLOOR_TOP + 0.08, -len / 2 + 1.5),
			prevGround:Lerp(ctx.pal.Ground, 0.5):Lerp(Color3.new(0, 0, 0), 0.2), { Parent = ctx.model })
		part(ctx, "BorderTrim", Vector3.new(w, 0.2, 1), ctx.cf * CFrame.new(0, FLOOR_TOP + 0.1, -len / 2 + 3.5),
			ctx.pal.Accent1, { Parent = ctx.model, Material = SMOOTH })
	end)
	if ctx.biome.Index >= BiomeData.Count then
		wallRun(ctx, "WallBack", -w / 2, len / 2, w / 2, len / 2, Vector3.new(0, 0, -1), look)
	end
end

-- Skeleton -----------------------------------------------------------------------------------

-- Open floor test shared with the boot layout check: inside the core, off the entrance border.
function Kit.spotIsOpen(biomeCf: CFrame, worldPos: Vector3): boolean
	local lp = biomeCf:PointToObjectSpace(worldPos)
	return math.abs(lp.X) <= CORE_HALF - 6 and lp.Z >= -B.Size / 2 + ENTRY_CLEAR - 0.01 and lp.Z <= B.Size / 2 - 16
end

local function digSpotModel(ctx: Ctx, id: string, cf: CFrame, tier: number, parent: Instance): Model
	local m = Parts.model("DigSpot", parent)
	m:SetAttribute("SpotId", id)
	m:SetAttribute("BiomeId", ctx.biome.Id)
	m:SetAttribute("RequiredTier", tier)
	m:SetAttribute("Available", true)
	local style = ctx.biome.DigStyle
	local tough = tier > 1
	local base = if tough then Color3.fromRGB(96, 96, 104) else Color3.fromRGB(120, 84, 52)
	local opts = { Parent = m }
	part(ctx, "DirtRim", Vector3.new(0.2, 7.8, 7.8), cf * CFrame.new(0, 0.15, 0) * UPRIGHT, Color3.fromHex("#5C3B24"),
		{ Parent = m, Shape = CYL, CanCollide = false })
	part(ctx, "DirtCircle", Vector3.new(0.2, 7, 7), cf * CFrame.new(0, 0.2, 0) * UPRIGHT, Color3.fromHex("#784F31"),
		{ Parent = m, Shape = CYL, CanCollide = false })
	if style == "Rock" or tough then
		part(ctx, "Body", Vector3.new(5, 2.4, 4.4), cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0.4, 0.08), base, opts)
		part(ctx, "Crack", Vector3.new(0.4, 2.6, 3.2), cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0.4, 0), ctx.pal.Accent1,
			{ Parent = m, Material = NEON, CanCollide = false })
	else
		part(ctx, "Body", Vector3.new(2.4, 5.5, 5.5), cf * CFrame.new(0, 0.4, 0) * UPRIGHT, base, { Parent = m, Shape = CYL })
		part(ctx, "Top", Vector3.new(2.6, 1.4, 2.6), cf * CFrame.new(0, 1.4, 0), base:Lerp(Color3.new(0, 0, 0), 0.15), opts)
	end
	local marker = part(ctx, "Marker", Vector3.one * 1.2, cf * CFrame.new(0, 4.5, 0),
		if style == "Glow" then ctx.pal.Accent2 else ctx.pal.Accent1, { Parent = m, Shape = Enum.PartType.Ball, Material = NEON, CanCollide = false })
	if tough then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(110, 26)
		gui.StudsOffset = Vector3.new(0, 1.6, 0)
		gui.MaxDistance = 60
		gui.Parent = marker
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = `Tough soil · Tier {tier}`
		label.Parent = gui
	end
	m.PrimaryPart = m:FindFirstChild("Body") :: BasePart
	return m
end

-- Builders run first, so every prop footprint is already reserved when spots are placed.
function Kit.skeleton(ctx: Ctx): Skeleton
	local len = ctx.length
	local patrol: { Vector3 } = {}
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5 + ctx.rng:NextNumber(-0.2, 0.2)
		table.insert(patrol, Kit.at(ctx, math.cos(a) * CORE_HALF * 0.6, math.sin(a) * len * 0.28 + len * 0.06).Position)
	end

	local spotFolder = Instance.new("Folder")
	spotFolder.Name = "DigSpots"
	spotFolder.Parent = ctx.model
	local spots: { DigSpot } = {}
	local minZ, maxZ = -len / 2 + ENTRY_CLEAR, len / 2 - 16
	local limX = CORE_HALF - 6
	for i = 1, B.DigSpots do
		local tough = i > B.DigSpots - B.ToughSpots
		local x, z = 0, 0
		for attempt = 1, 60 do
			x = ctx.rng:NextNumber(-limX, limX)
			-- Tough spots sit deeper in the biome, near the guardian's beat.
			z = if tough then ctx.rng:NextNumber(len * 0.1, maxZ) else ctx.rng:NextNumber(minZ, maxZ)
			local ok = Kit.isFree(ctx, x, z, 4 + SPOT_PROP_CLEAR)
			local gap = if attempt > 40 then SPOT_GAP / 2 else SPOT_GAP
			for _, other in spots do
				local lp = ctx.cf:PointToObjectSpace(other.cf.Position)
				if ok and (Vector2.new(lp.X, lp.Z) - Vector2.new(x, z)).Magnitude < gap then
					ok = false
				end
			end
			if ok then
				break
			end
		end
		Kit.reserve(ctx, x, z, 4)
		local cf = Kit.at(ctx, x, z)
		local tier = if tough then ctx.biome.ToughTier else 1
		local id = `{ctx.biome.Id}_{i}`
		table.insert(spots, { id = id, cf = cf, requiredTier = tier, model = digSpotModel(ctx, id, cf, tier, spotFolder) })
	end

	local danger: { { center: Vector3, radius: number } } = {}
	for i = 1, Config.Guardian.DangerZoneCount do
		local spot = spots[#spots - (i - 1)]
		local center = spot.cf.Position
		table.insert(danger, { center = center, radius = Config.Guardian.DangerZoneRadius })
		local zone = part(ctx, "DangerZone", Vector3.new(0.2, Config.Guardian.DangerZoneRadius * 2, Config.Guardian.DangerZoneRadius * 2),
			CFrame.new(center + Vector3.new(0, 0.27, 0)) * UPRIGHT, Color3.fromHex("#FF4D6D"),
			{ Parent = ctx.model, Shape = CYL, CanCollide = false, Transparency = 0.82, Shadow = false })
		zone.CanQuery = false
	end

	return { patrol = patrol, danger = danger, spots = spots }
end

return Kit
