--!strict
-- Template helpers for biome builders. A builder only adds terrain and props; the kit builds
-- the shared skeleton (floor, walls with an entrance, safe zone, dig spots, patrol points,
-- danger zones) so every biome plays the same way and stays inside the part budget.
-- Coordinates are biome-local: X across, Z from entrance (-Size/2) to back (+Size/2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local B = Config.Biome
local WALL_H = 12
local ENTRANCE_W = 26
local DESIGN_SIZE = 56 -- builders' scatter counts were tuned for this biome size
local SCATTER_CAP = 2 -- full area scale (4x at 112) blows the boot part budget
local SPOT_GAP = 8

export type Ctx = {
	biome: BiomeData.Biome,
	cf: CFrame,
	size: number,
	model: Model,
	props: Model,
	rng: Random,
	pal: BiomeData.Palette,
}

export type DigSpot = { id: string, cf: CFrame, requiredTier: number, model: Model }
export type Skeleton = {
	safeCenter: Vector3,
	safeRadius: number,
	patrol: { Vector3 },
	danger: { { center: Vector3, radius: number } },
	spots: { DigSpot },
}

local Kit = {}

local function part(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, opts: { [string]: any }?): BasePart
	local o: { [string]: any } = opts or {}
	return Parts.make({
		Name = name, Parent = o.Parent or ctx.props, Size = size, CFrame = cf, Color = color,
		Material = o.Material, Shape = o.Shape, Wedge = o.Wedge, CanCollide = o.CanCollide,
		Transparency = o.Transparency,
	})
end
Kit.part = part

local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local NEON = Enum.Material.Neon
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders point along X; this stands them up

function Kit.at(ctx: Ctx, x: number, z: number, yaw: number?): CFrame
	local limit = ctx.size / 2 - 4
	local ax, az = math.abs(x), math.abs(z)
	if ax > limit or az > limit then
		local s = limit / math.max(ax, az, 1)
		x *= s
		z *= s
	end
	return ctx.cf * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
end

function Kit.newCtx(biome: BiomeData.Biome, cf: CFrame, parent: Instance): Ctx
	local model = Parts.model("Biome_" .. biome.Id, parent)
	model:SetAttribute("BiomeId", biome.Id)
	model:SetAttribute("BiomeIndex", biome.Index)
	model:SetAttribute("Tint", biome.Palette.Ground:Lerp(Color3.new(1, 1, 1), 0.65))
	local props = Parts.model("Props", model)
	return { biome = biome, cf = cf, size = B.Size, model = model, props = props, rng = Random.new(biome.Index * 7919), pal = biome.Palette }
end

-- Keeps props off the entrance lane, the safe zone and the walls.
function Kit.isClear(ctx: Ctx, x: number, z: number, margin: number): boolean
	local half = ctx.size / 2 - margin
	if math.abs(x) > half or math.abs(z) > half then
		return false
	end
	local safeZ = -ctx.size / 2 + B.SafeRadius + 6
	if (Vector2.new(x, z) - Vector2.new(0, safeZ)).Magnitude < B.SafeRadius + 10 then
		return false
	end
	if math.abs(x) < 8 and z < -ctx.size / 2 + 14 then
		return false
	end
	return not (ctx.biome.Index < BiomeData.Count and math.abs(x) < 8 and z > ctx.size / 2 - 14)
end

function Kit.randomPoint(ctx: Ctx, margin: number): (number, number)
	for _ = 1, 40 do
		local x = ctx.rng:NextNumber(-ctx.size / 2, ctx.size / 2)
		local z = ctx.rng:NextNumber(-ctx.size / 2, ctx.size / 2)
		if Kit.isClear(ctx, x, z, margin) then
			return x, z
		end
	end
	return 0, 0
end

function Kit.scatter(ctx: Ctx, count: number, margin: number, fn: (CFrame, Random, number) -> ())
	local scale = math.min((ctx.size / DESIGN_SIZE) ^ 2, SCATTER_CAP)
	for i = 1, math.round(count * scale) do
		local x, z = Kit.randomPoint(ctx, margin)
		fn(Kit.at(ctx, x, z, ctx.rng:NextNumber(0, math.pi * 2)), ctx.rng, i)
	end
end

-- Floor + side walls + an entrance wall with a gap facing the hub. The back wall has a matching
-- exit gap onto the trail to the next biome, except in the last biome.
function Kit.ground(ctx: Ctx, color: Color3?, material: Enum.Material?)
	local s = ctx.size
	local floor = part(ctx, "Floor", Vector3.new(s, 1, s), ctx.cf * CFrame.new(0, -0.4, 0), color or ctx.pal.Ground,
		{ Material = material or Enum.Material.Grass, Parent = ctx.model })
	floor:SetAttribute("BiomeFloor", true)
	local wallColor = ctx.pal.Prop
	local opts = { Parent = ctx.model }
	part(ctx, "WallLeft", Vector3.new(2, WALL_H, s), ctx.cf * CFrame.new(-s / 2, WALL_H / 2, 0), wallColor, opts)
	part(ctx, "WallRight", Vector3.new(2, WALL_H, s), ctx.cf * CFrame.new(s / 2, WALL_H / 2, 0), wallColor, opts)
	local seg = (s - ENTRANCE_W) / 2
	for _, side in { -1, 1 } do
		part(ctx, "WallFront", Vector3.new(seg, WALL_H, 2),
			ctx.cf * CFrame.new(side * (ENTRANCE_W / 2 + seg / 2), WALL_H / 2, -s / 2), wallColor, opts)
	end
	local arch = part(ctx, "EntranceSign", Vector3.new(ENTRANCE_W + 4, 5, 1.2),
		ctx.cf * CFrame.new(0, WALL_H + 2, -s / 2), Color3.fromHex("#1E2A22"), opts)
	Parts.surfaceText(arch, Enum.NormalId.Back, ctx.biome.Name, ctx.pal.Accent1)
	Parts.surfaceText(arch, Enum.NormalId.Front, ctx.biome.Name, ctx.pal.Accent1)
	local nextBiome = BiomeData.List[ctx.biome.Index + 1]
	if ctx.biome.Index >= BiomeData.Count or not nextBiome then
		part(ctx, "WallBack", Vector3.new(s, WALL_H, 2), ctx.cf * CFrame.new(0, WALL_H / 2, s / 2), wallColor, opts)
		return
	end
	for _, side in { -1, 1 } do
		part(ctx, "WallBack", Vector3.new(seg, WALL_H, 2),
			ctx.cf * CFrame.new(side * (ENTRANCE_W / 2 + seg / 2), WALL_H / 2, s / 2), wallColor, opts)
	end
	local exit = part(ctx, "ExitSign", Vector3.new(ENTRANCE_W + 4, 5, 1.2),
		ctx.cf * CFrame.new(0, WALL_H + 2, s / 2), Color3.fromHex("#1E2A22"), opts)
	Parts.surfaceText(exit, Enum.NormalId.Back, `To {nextBiome.Name}`, nextBiome.Palette.Accent1)
	Parts.surfaceText(exit, Enum.NormalId.Front, `To {nextBiome.Name}`, nextBiome.Palette.Accent1)
end

-- Props -------------------------------------------------------------------------------------

function Kit.tree(ctx: Ctx, cf: CFrame, scale: number, leaf: Color3, trunk: Color3?)
	local h = 8 * scale
	part(ctx, "Trunk", Vector3.new(2.4, h, 2.4) * Vector3.new(scale, 1, scale), cf * CFrame.new(0, h / 2, 0), trunk or Color3.fromRGB(120, 80, 48))
	part(ctx, "Canopy", Vector3.new(9, 7, 9) * scale, cf * CFrame.new(0, h + 3 * scale, 0) * CFrame.Angles(0, math.rad(45), 0), leaf)
	part(ctx, "CanopyTop", Vector3.new(6, 4, 6) * scale, cf * CFrame.new(0, h + 8 * scale, 0), leaf:Lerp(Color3.new(1, 1, 1), 0.15))
end

function Kit.roundTree(ctx: Ctx, cf: CFrame, scale: number, leaf: Color3, trunk: Color3?)
	local h = 7 * scale
	part(ctx, "Trunk", Vector3.new(h, 2 * scale, 2 * scale), cf * CFrame.new(0, h / 2, 0) * UPRIGHT, trunk or Color3.fromRGB(110, 72, 44), { Shape = CYL })
	part(ctx, "Crown", Vector3.one * 9 * scale, cf * CFrame.new(0, h + 3 * scale, 0), leaf, { Shape = BALL })
end

function Kit.rock(ctx: Ctx, cf: CFrame, scale: number, color: Color3)
	part(ctx, "Rock", Vector3.new(6, 3.5, 5) * scale, cf * CFrame.new(0, 1.5 * scale, 0) * CFrame.Angles(0, 0.3, 0.1), color)
	part(ctx, "RockChip", Vector3.new(4, 3, 4) * scale, cf * CFrame.new(scale, 4 * scale, 0) * CFrame.Angles(0, -0.6, 0),
		color:Lerp(Color3.new(1, 1, 1), 0.12), { Wedge = true })
end

function Kit.mushroom(ctx: Ctx, cf: CFrame, scale: number, cap: Color3, stem: Color3, glow: boolean?)
	local h = 6 * scale
	part(ctx, "Stem", Vector3.new(h, 2.2 * scale, 2.2 * scale), cf * CFrame.new(0, h / 2, 0) * UPRIGHT, stem, { Shape = CYL })
	part(ctx, "Cap", Vector3.new(2.5 * scale, 9 * scale, 9 * scale), cf * CFrame.new(0, h + scale, 0) * UPRIGHT, cap,
		{ Shape = CYL, Material = if glow then NEON else nil })
	part(ctx, "CapTop", Vector3.new(5, 2, 5) * scale, cf * CFrame.new(0, h + 2.6 * scale, 0), cap:Lerp(Color3.new(1, 1, 1), 0.2), { Shape = BALL })
end

function Kit.cactus(ctx: Ctx, cf: CFrame, scale: number, color: Color3)
	local h = 9 * scale
	part(ctx, "Cactus", Vector3.new(2.4 * scale, h, 2.4 * scale), cf * CFrame.new(0, h / 2, 0), color)
	part(ctx, "ArmL", Vector3.new(1.6, 4, 1.6) * scale, cf * CFrame.new(-2 * scale, h * 0.6, 0), color)
	part(ctx, "ArmR", Vector3.new(1.6, 3, 1.6) * scale, cf * CFrame.new(2 * scale, h * 0.45, 0), color)
end

function Kit.crystal(ctx: Ctx, cf: CFrame, scale: number, color: Color3, neon: boolean?)
	local h = 8 * scale
	part(ctx, "Crystal", Vector3.new(2.5 * scale, h, 2.5 * scale), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0.15, 0, 0.12), color,
		{ Material = if neon then NEON else nil })
	part(ctx, "CrystalTip", Vector3.new(2.5 * scale, 2.5 * scale, 2.5 * scale), cf * CFrame.new(0, h + scale * 0.8, 0) * CFrame.Angles(0, math.rad(45), 0),
		color:Lerp(Color3.new(1, 1, 1), 0.3), { Wedge = true, Material = if neon then NEON else nil })
end

function Kit.palm(ctx: Ctx, cf: CFrame, scale: number, leaf: Color3, trunk: Color3)
	local h = 12 * scale
	part(ctx, "PalmTrunk", Vector3.new(1.8 * scale, h, 1.8 * scale), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, 0.08), trunk)
	for i = 0, 3 do
		part(ctx, "Frond", Vector3.new(10 * scale, 0.6, 3 * scale),
			cf * CFrame.new(0, h, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(4 * scale, -0.6, 0) * CFrame.Angles(0, 0, -0.25), leaf)
	end
end

function Kit.flowers(ctx: Ctx, cf: CFrame, scale: number, petal: Color3, center: Color3)
	for i = 0, 2 do
		local o = cf * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(2.2 * scale, 0, 0)
		part(ctx, "FlowerStem", Vector3.new(0.4, 2, 0.4) * scale, o * CFrame.new(0, scale, 0), Color3.fromRGB(62, 142, 65), { CanCollide = false })
		part(ctx, "Bloom", Vector3.one * 1.4 * scale, o * CFrame.new(0, 2.2 * scale, 0), if i == 1 then center else petal, { Shape = BALL, CanCollide = false })
	end
end

function Kit.pool(ctx: Ctx, cf: CFrame, radius: number, color: Color3, neon: boolean?)
	part(ctx, "Pool", Vector3.new(0.3, radius * 2, radius * 2), cf * CFrame.new(0, 0.2, 0) * UPRIGHT, color,
		{ Shape = CYL, Material = if neon then NEON else nil, CanCollide = false, Transparency = if neon then 0 else 0.2 })
end

function Kit.spire(ctx: Ctx, cf: CFrame, w: number, h: number, color: Color3, cap: Color3?)
	part(ctx, "Spire", Vector3.new(w, h, w), cf * CFrame.new(0, h / 2, 0), color)
	if cap then
		part(ctx, "SpireCap", Vector3.new(w + 1, w * 0.6, w + 1), cf * CFrame.new(0, h + w * 0.3, 0), cap, { Wedge = true })
	end
end

function Kit.island(ctx: Ctx, cf: CFrame, w: number, top: Color3, under: Color3)
	part(ctx, "IslandTop", Vector3.new(w, 2, w), cf, top, { Material = Enum.Material.Grass })
	part(ctx, "IslandRoot", Vector3.new(w * 0.7, w * 0.5, w * 0.7), cf * CFrame.new(0, -w * 0.25 - 1, 0) * CFrame.Angles(math.pi, 0, 0), under, { Wedge = true })
end

function Kit.fern(ctx: Ctx, cf: CFrame, scale: number, color: Color3)
	for i = 0, 3 do
		part(ctx, "Frond", Vector3.new(1.4 * scale, 5 * scale, 0.3),
			cf * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 2 * scale, 1.2 * scale) * CFrame.Angles(-0.5, 0, 0), color, { CanCollide = false })
	end
end

function Kit.coral(ctx: Ctx, cf: CFrame, scale: number, color: Color3)
	for i = 0, 2 do
		local h = (4 + i * 1.5) * scale
		part(ctx, "CoralBranch", Vector3.new(1.4 * scale, h, 1.4 * scale),
			cf * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(1.2 * scale, h / 2, 0) * CFrame.Angles(0, 0, 0.25 * (i - 1)), color)
	end
	part(ctx, "CoralTip", Vector3.one * 2 * scale, cf * CFrame.new(0, 6 * scale, 0), color:Lerp(Color3.new(1, 1, 1), 0.3), { Shape = BALL })
end

function Kit.hill(ctx: Ctx, cf: CFrame, w: number, h: number, color: Color3)
	part(ctx, "Hill", Vector3.new(w, h * 2, w), cf * CFrame.new(0, 0, 0), color, { Shape = BALL, Material = Enum.Material.Grass })
end

function Kit.glowOrb(ctx: Ctx, cf: CFrame, color: Color3, height: number)
	local orb = part(ctx, "GlowOrb", Vector3.one * 1.6, cf * CFrame.new(0, height, 0), color, { Shape = BALL, Material = NEON, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = orb
end

-- Skeleton -----------------------------------------------------------------------------------

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
		if style == "Glow" then ctx.pal.Accent2 else ctx.pal.Accent1, { Parent = m, Shape = BALL, Material = NEON, CanCollide = false })
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

function Kit.skeleton(ctx: Ctx): Skeleton
	local s = ctx.size
	local safeZ = -s / 2 + B.SafeRadius + 6
	local safeCenter = Kit.at(ctx, 0, safeZ).Position
	local ring = part(ctx, "SafeZone", Vector3.new(0.2, B.SafeRadius * 2, B.SafeRadius * 2),
		Kit.at(ctx, 0, safeZ) * CFrame.new(0, 0.15, 0) * UPRIGHT, Color3.fromHex("#3FBF4A"),
		{ Parent = ctx.model, Shape = CYL, Material = NEON, CanCollide = false, Transparency = 0.6 })
	ring.CanQuery = false
	local sign = part(ctx, "SafeSign", Vector3.new(10, 2.4, 0.4), Kit.at(ctx, B.SafeRadius - 2, safeZ - 4) * CFrame.new(0, 4, 0),
		Color3.fromHex("#1E2A22"), { Parent = ctx.model })
	Parts.surfaceText(sign, Enum.NormalId.Back, "SAFE ZONE", Color3.fromHex("#3FBF4A"))
	Parts.surfaceText(sign, Enum.NormalId.Front, "SAFE ZONE", Color3.fromHex("#3FBF4A"))

	local patrol: { Vector3 } = {}
	local r = s * 0.28
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5 + ctx.rng:NextNumber(-0.2, 0.2)
		table.insert(patrol, Kit.at(ctx, math.cos(a) * r, math.sin(a) * r + s * 0.08).Position)
	end

	local spotFolder = Instance.new("Folder")
	spotFolder.Name = "DigSpots"
	spotFolder.Parent = ctx.model
	local spots: { DigSpot } = {}
	for i = 1, B.DigSpots do
		local tough = i > B.DigSpots - B.ToughSpots
		-- Tough spots sit deeper in the biome, near the guardian's beat.
		local cf = Kit.at(ctx, 0, 0)
		for _ = 1, 30 do
			local x, z = Kit.randomPoint(ctx, 16)
			if tough then
				z = math.abs(z) * 0.6 + s * 0.15
			end
			cf = Kit.at(ctx, x, z)
			local ok = Kit.isClear(ctx, x, z, 16)
			for _, other in spots do
				if ok and (other.cf.Position - cf.Position).Magnitude < SPOT_GAP then
					ok = false
				end
			end
			if ok then
				break
			end
		end
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
			CFrame.new(center + Vector3.new(0, 0.12, 0)) * UPRIGHT, Color3.fromHex("#FF4D6D"),
			{ Parent = ctx.model, Shape = CYL, CanCollide = false, Transparency = 0.82 })
		zone.CanQuery = false
	end

	return { safeCenter = safeCenter, safeRadius = B.SafeRadius, patrol = patrol, danger = danger, spots = spots }
end

return Kit
