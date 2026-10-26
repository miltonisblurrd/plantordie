--!strict
-- Template helpers for biome builders. A builder only adds terrain and props; the kit builds
-- the shared skeleton (floor, walls with an entrance, dig spots, patrol points, danger zones)
-- so every biome plays the same way and stays inside the part budget. Biomes are never safe;
-- the only Safe Zone is the shared home area (Shared/SafeZone).
-- Coordinates are biome-local: X across, Z from entrance (-Size/2) to back (+Size/2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeData = require(ReplicatedStorage.Shared.Biomes)
local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local B = Config.Biome
local WALL_H = 26
local ENTRANCE_W = 52
local DESIGN_SIZE = 56 -- builders' scatter counts were tuned for this biome size
local SCATTER_CAP = 2 -- full area scale (4x at 112) blows the boot part budget
local SPOT_GAP = 8
local ENTRANCE_CLEAR = 10 -- radius kept free of props and dig spots just inside the entrance

export type Ctx = {
	biome: BiomeData.Biome,
	cf: CFrame,
	size: number, -- length, kept so older builder calls still read a span
	width: number,
	length: number,
	model: Model,
	props: Model,
	rng: Random,
	pal: BiomeData.Palette,
}

export type DigSpot = { id: string, cf: CFrame, requiredTier: number, model: Model }
export type Skeleton = {
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
	local limX, limZ = ctx.width / 2 - 4, ctx.length / 2 - 4
	x = math.clamp(x, -limX, limX)
	z = math.clamp(z, -limZ, limZ)
	return ctx.cf * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
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
	}
end

-- Keeps props off the entrance lane, the entrance clearing and the walls.
function Kit.isClear(ctx: Ctx, x: number, z: number, margin: number): boolean
	if math.abs(x) > ctx.width / 2 - margin or math.abs(z) > ctx.length / 2 - margin then
		return false
	end
	local clearZ = -ctx.length / 2 + ENTRANCE_CLEAR + 6
	if (Vector2.new(x, z) - Vector2.new(0, clearZ)).Magnitude < ENTRANCE_CLEAR + 10 then
		return false
	end
	local lane = ENTRANCE_W / 2
	if math.abs(x) < lane and z < -ctx.length / 2 + 18 then
		return false
	end
	return not (ctx.biome.Index < BiomeData.Count and math.abs(x) < lane and z > ctx.length / 2 - 18)
end

function Kit.randomPoint(ctx: Ctx, margin: number): (number, number)
	for _ = 1, 40 do
		local x = ctx.rng:NextNumber(-ctx.width / 2, ctx.width / 2)
		local z = ctx.rng:NextNumber(-ctx.length / 2, ctx.length / 2)
		local onEdge = math.abs(x) > ctx.width * 0.28 or math.abs(z) > ctx.length * 0.34
		if (onEdge or ctx.rng:NextNumber() < 0.12) and Kit.isClear(ctx, x, z, margin) then
			return x, z
		end
	end
	return 0, 0
end

function Kit.scatter(ctx: Ctx, count: number, margin: number, fn: (CFrame, Random, number) -> ())
	local scale = math.min((ctx.length / DESIGN_SIZE) * (ctx.width / DESIGN_SIZE), SCATTER_CAP)
	for i = 1, math.round(count * scale) do
		local x, z = Kit.randomPoint(ctx, margin)
		fn(Kit.at(ctx, x, z, ctx.rng:NextNumber(0, math.pi * 2)), ctx.rng, i)
	end
end

-- Floor + side walls + an entrance wall with a gap facing the hub. The back wall has a matching
-- exit gap onto the trail to the next biome, except in the last biome.
local function wallLook(id: string, pal: BiomeData.Palette): (Color3, Enum.Material, Color3)
	if id == "GreenMeadows" then
		return Color3.fromRGB(122, 86, 52), Enum.Material.Ground, pal.Ground
	elseif id == "MushroomForest" then
		return Color3.fromRGB(92, 64, 40), Enum.Material.Ground, Color3.fromRGB(70, 110, 60)
	elseif id == "CactusCanyon" then
		return Color3.fromRGB(196, 120, 64), Enum.Material.Sandstone, Color3.fromRGB(214, 150, 80)
	elseif id == "InfernoJungle" then
		return Color3.fromRGB(40, 32, 34), Enum.Material.Basalt, Color3.fromRGB(255, 90, 30)
	elseif id == "FrostbiteGarden" then
		return Color3.fromRGB(210, 230, 245), Enum.Material.Glacier, Color3.fromRGB(150, 210, 255)
	elseif id == "EnchantedGrove" then
		return Color3.fromRGB(90, 110, 80), Enum.Material.Slate, Color3.fromRGB(80, 200, 140)
	elseif id == "TropicalParadise" then
		return Color3.fromRGB(150, 100, 60), Enum.Material.Ground, Color3.fromRGB(40, 160, 70)
	elseif id == "CoralKingdom" then
		return Color3.fromRGB(180, 140, 130), Enum.Material.Sandstone, Color3.fromRGB(255, 127, 80)
	elseif id == "AutumnWoods" then
		return Color3.fromRGB(110, 70, 40), Enum.Material.Ground, Color3.fromRGB(200, 90, 30)
	elseif id == "SkyIslands" then
		return Color3.fromRGB(190, 180, 160), Enum.Material.Sandstone, Color3.fromRGB(235, 245, 255)
	elseif id == "CrystalCaverns" then
		return Color3.fromRGB(36, 36, 48), Enum.Material.Slate, Color3.fromRGB(92, 225, 230)
	elseif id == "ToxicSwamp" then
		return Color3.fromRGB(70, 90, 50), Enum.Material.Mud, Color3.fromRGB(166, 255, 0)
	elseif id == "AncientWilds" then
		return Color3.fromRGB(176, 150, 110), Enum.Material.Sandstone, Color3.fromRGB(120, 96, 70)
	elseif id == "CosmicGarden" then
		return Color3.fromRGB(40, 20, 70), Enum.Material.Slate, Color3.fromRGB(180, 120, 255)
	end
	return Color3.fromRGB(40, 16, 24), Enum.Material.Slate, Color3.fromRGB(255, 80, 140)
end

local function wall(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, cap: Color3)
	local body = part(ctx, name, size, cf, color, { Parent = ctx.model, Material = material })
	local capH = 2
	part(ctx, name .. "Cap", Vector3.new(size.X, capH, size.Z), cf * CFrame.new(0, size.Y / 2 + capH / 2, 0), cap,
		{ Parent = ctx.model, Material = if cap.R > 0.6 and cap.G < 0.5 then Enum.Material.Neon else Enum.Material.Grass })
	return body
end

function Kit.ground(ctx: Ctx, color: Color3?, material: Enum.Material?)
	local w, len = ctx.width, ctx.length
	local floor = part(ctx, "Floor", Vector3.new(w, 1, len), ctx.cf * CFrame.new(0, -0.4, 0), color or ctx.pal.Ground,
		{ Material = material or Enum.Material.Grass, Parent = ctx.model })
	floor:SetAttribute("BiomeFloor", true)
	local wallColor, wallMat, cap = wallLook(ctx.biome.Id, ctx.pal)
	wall(ctx, "WallLeft", Vector3.new(2, WALL_H, len), ctx.cf * CFrame.new(-w / 2, WALL_H / 2, 0), wallColor, wallMat, cap)
	wall(ctx, "WallRight", Vector3.new(2, WALL_H, len), ctx.cf * CFrame.new(w / 2, WALL_H / 2, 0), wallColor, wallMat, cap)
	local seg = (w - ENTRANCE_W) / 2
	for _, side in { -1, 1 } do
		wall(ctx, "WallFront", Vector3.new(seg, WALL_H, 2),
			ctx.cf * CFrame.new(side * (ENTRANCE_W / 2 + seg / 2), WALL_H / 2, -len / 2), wallColor, wallMat, cap)
	end
	local arch = part(ctx, "EntranceSign", Vector3.new(ENTRANCE_W + 4, 5, 1.2),
		ctx.cf * CFrame.new(0, WALL_H + 4, -len / 2), Color3.fromHex("#1E2A22"), { Parent = ctx.model })
	Parts.surfaceText(arch, Enum.NormalId.Back, ctx.biome.Name, ctx.pal.Accent1)
	Parts.surfaceText(arch, Enum.NormalId.Front, ctx.biome.Name, ctx.pal.Accent1)
	local nextBiome = BiomeData.List[ctx.biome.Index + 1]
	if ctx.biome.Index >= BiomeData.Count or not nextBiome then
		wall(ctx, "WallBack", Vector3.new(w, WALL_H, 2), ctx.cf * CFrame.new(0, WALL_H / 2, len / 2), wallColor, wallMat, cap)
		return
	end
	for _, side in { -1, 1 } do
		wall(ctx, "WallBack", Vector3.new(seg, WALL_H, 2),
			ctx.cf * CFrame.new(side * (ENTRANCE_W / 2 + seg / 2), WALL_H / 2, len / 2), wallColor, wallMat, cap)
	end
	local exit = part(ctx, "ExitSign", Vector3.new(ENTRANCE_W + 4, 5, 1.2),
		ctx.cf * CFrame.new(0, WALL_H + 4, len / 2), Color3.fromHex("#1E2A22"), { Parent = ctx.model })
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

	return { patrol = patrol, danger = danger, spots = spots }
end

return Kit
