--!strict
-- Builds one personal plot. Local frame: origin at ground centre, -Z faces the hub,
-- lanes run along X with the house on the left (-X) and zombies entering from the right (+X).
-- Lane 1 is the far row from the hub side, lane 7 the nearest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lanes = require(ReplicatedStorage.Shared.Lanes)
local Format = require(ReplicatedStorage.Shared.Format)
local Parts = require(script.Parent.Parent.Parts)
local House = require(script.Parent.House)

local P = Config.Plot
local T = P.TileSize

local SOIL = Color3.fromRGB(122, 82, 52)
local SOIL_LOCKED = Color3.fromRGB(70, 66, 64)
local GRASS = Color3.fromRGB(92, 200, 80)
local PATH = Color3.fromRGB(176, 150, 110)
local PRIMARY = Color3.fromHex("#3FBF4A")

export type PlotRefs = {
	index: number,
	cframe: CFrame,
	model: Model,
	tiles: { [string]: BasePart },
	laneLocks: { [number]: Model },
	plants: Folder,
	houseBase: CFrame,
	house: Model,
	ownerLabel: TextLabel,
	spawn: CFrame,
	machines: { [string]: Model },
	water: Folder,
}

local PlotBuilder = {}

function PlotBuilder.tileKey(lane: number, col: number): string
	return `{lane}_{col}`
end

function PlotBuilder.laneZ(lane: number): number
	return ((P.Lanes + 1) / 2 - lane) * T
end

function PlotBuilder.colX(col: number): number
	return P.GardenOriginX + (col - 0.5) * T
end

function PlotBuilder.gardenCenter(cf: CFrame): CFrame
	return cf * CFrame.new(P.GardenOriginX + P.Columns * T / 2, 0, 0)
end

local function buildLaneLock(refs: PlotRefs, lane: number)
	local cf = refs.cframe
	local m = Parts.model(`LaneLock_{lane}`, refs.model)
	local z = PlotBuilder.laneZ(lane)
	local gardenW = P.Columns * T
	local midX = P.GardenOriginX + gardenW / 2
	Parts.make({
		Name = "Rope", Parent = m, Color = Color3.fromRGB(255, 176, 32), CanCollide = false,
		Size = Vector3.new(gardenW, 0.3, 0.3), CFrame = cf * CFrame.new(midX, 1.6, z),
	})
	for _, x in { P.GardenOriginX, P.GardenOriginX + gardenW } do
		Parts.make({
			Name = "Post", Parent = m, Color = Color3.fromRGB(110, 74, 44),
			Size = Vector3.new(0.8, 2.4, 0.8), CFrame = cf * CFrame.new(x, 1.2, z),
		})
	end
	local signX = P.GardenOriginX + gardenW + 4
	Parts.make({
		Name = "SignPost", Parent = m, Color = Color3.fromRGB(110, 74, 44),
		Size = Vector3.new(0.6, 4, 0.6), CFrame = cf * CFrame.new(signX, 2, z),
	})
	local board = Parts.make({
		Name = "SignBoard", Parent = m, Color = Color3.fromHex("#1E2A22"),
		Size = Vector3.new(7, 3.4, 0.4), CFrame = cf * CFrame.new(signX, 4.6, z),
	})
	local price = Lanes.price(lane) or 0
	local text = `LANE {lane} LOCKED\n{Format.money(price)}`
	-- Front faces the hub side (where the plot camera sits); back for players inside the garden.
	Parts.surfaceText(board, Enum.NormalId.Front, text, Color3.fromRGB(255, 220, 120))
	Parts.surfaceText(board, Enum.NormalId.Back, text, Color3.fromRGB(255, 220, 120))
	-- Opens the client's confirm dialog; the purchase itself goes through the BuyLane remote.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyLanePrompt"
	prompt.ActionText = `Unlock lane {lane}`
	prompt.ObjectText = Format.money(price)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt:SetAttribute("Lane", lane)
	prompt.Parent = board
	board:SetAttribute("Lane", lane)
	refs.laneLocks[lane] = m
end

function PlotBuilder.build(index: number, cf: CFrame, parent: Instance): PlotRefs
	local model = Parts.model(`Plot_{index}`, parent)
	model:SetAttribute("PlotIndex", index)

	local ground = Parts.make({
		Name = "Ground", Parent = model, Color = GRASS, Material = Enum.Material.Grass,
		Size = Vector3.new(P.Width, 1, P.Depth), CFrame = cf * CFrame.new(0, -0.5, 0),
	})
	model.PrimaryPart = ground

	local gardenW, gardenD = P.Columns * T, P.Lanes * T
	local midX = P.GardenOriginX + gardenW / 2
	Parts.make({
		Name = "GardenBorder", Parent = model, Color = Color3.fromRGB(110, 74, 44),
		Size = Vector3.new(gardenW + 2, 0.4, gardenD + 2), CFrame = cf * CFrame.new(midX, 0.2, 0),
	})
	Parts.make({
		Name = "ZombieRoad", Parent = model, Color = PATH,
		Size = Vector3.new(P.Width / 2 - (P.GardenOriginX + gardenW) - 1, 0.3, gardenD),
		CFrame = cf * CFrame.new((P.GardenOriginX + gardenW + P.Width / 2) / 2, 0.15, 0),
	})
	Parts.make({
		Name = "FrontPath", Parent = model, Color = PATH,
		Size = Vector3.new(P.Width - 4, 0.3, 10), CFrame = cf * CFrame.new(0, 0.15, -P.Depth / 2 + 8),
	})

	local refs: PlotRefs = {
		index = index,
		cframe = cf,
		model = model,
		tiles = {},
		laneLocks = {},
		plants = nil :: any,
		houseBase = cf * CFrame.new(P.HouseX, 0, 0),
		house = nil :: any,
		ownerLabel = nil :: any,
		spawn = cf * CFrame.new(P.HouseX, 4, -40),
		machines = {},
		water = nil :: any,
	}

	local tileFolder = Instance.new("Folder")
	tileFolder.Name = "Tiles"
	tileFolder.Parent = model
	for lane = 1, P.Lanes do
		for col = 1, P.Columns do
			local key = PlotBuilder.tileKey(lane, col)
			local tile = Parts.make({
				Name = "Tile_" .. key, Parent = tileFolder, Color = SOIL,
				Size = Vector3.new(T - 0.6, 0.6, T - 0.6),
				CFrame = cf * CFrame.new(PlotBuilder.colX(col), 0.5, PlotBuilder.laneZ(lane)),
			})
			tile:SetAttribute("PlotIndex", index)
			tile:SetAttribute("Lane", lane)
			tile:SetAttribute("Col", col)
			tile:SetAttribute("TileKey", key)
			refs.tiles[key] = tile
		end
	end

	local plantFolder = Instance.new("Folder")
	plantFolder.Name = "Plants"
	plantFolder.Parent = model
	refs.plants = plantFolder

	refs.house = House.build(1, refs.houseBase, model)

	local signAnchor = Parts.make({
		Name = "OwnerSignAnchor", Parent = model, Color = PRIMARY, CanCollide = false, Transparency = 1,
		Size = Vector3.new(1, 1, 1), CFrame = refs.houseBase * CFrame.new(0, 28, 0),
	})
	local bb = Instance.new("BillboardGui")
	bb.Name = "OwnerSign"
	bb.Size = UDim2.fromOffset(260, 56)
	bb.AlwaysOnTop = true
	bb.Enabled = false
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	bb.Parent = signAnchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromHex("#1E2A22")
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = PRIMARY
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label
	refs.ownerLabel = label

	local portalCf = cf * CFrame.new(P.ZombieSpawnX, 0, 0)
	local portal = Parts.model("Portal", model)
	local ring = Parts.make({
		Name = "Ring", Parent = portal, Color = Color3.fromRGB(120, 40, 220), Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder, CanCollide = false,
		Size = Vector3.new(0.6, 10, 10),
		CFrame = portalCf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	Parts.make({
		Name = "Mouth", Parent = portal, Color = Color3.fromRGB(20, 0, 40), Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder, CanCollide = false,
		Size = Vector3.new(0.4, 7, 7),
		CFrame = ring.CFrame,
	})
	local swirl = Instance.new("ParticleEmitter")
	swirl.Rate = 18
	swirl.Lifetime = NumberRange.new(0.8, 1.4)
	swirl.Speed = NumberRange.new(1, 3)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.LightEmission = 0.8
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.Color = ColorSequence.new(Color3.fromRGB(180, 80, 255), Color3.fromRGB(255, 60, 80))
	swirl.Parent = ring
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalPrompt"
	prompt.ActionText = "Upgrade"
	prompt.ObjectText = "Portal"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = ring

	local water = Instance.new("Folder")
	water.Name = "Water"
	water.Parent = model
	refs.water = water

	return refs
end

-- Show lanes > unlocked as locked (grey soil, rope, price sign); unlocked lanes as plain soil.
function PlotBuilder.setLanes(refs: PlotRefs, unlocked: number)
	for lane = 1, P.Lanes do
		local locked = lane > unlocked
		for col = 1, P.Columns do
			local tile = refs.tiles[PlotBuilder.tileKey(lane, col)]
			tile.Color = if locked then SOIL_LOCKED else SOIL
			tile:SetAttribute("Locked", locked)
		end
		local lock = refs.laneLocks[lane]
		if locked and not lock then
			buildLaneLock(refs, lane)
		elseif not locked and lock then
			lock:Destroy()
			refs.laneLocks[lane] = nil
		end
	end
end

function PlotBuilder.setHouseTier(refs: PlotRefs, tier: number)
	if refs.house and refs.house:GetAttribute("Tier") == tier then
		return
	end
	if refs.house then
		refs.house:Destroy()
	end
	refs.house = House.build(tier, refs.houseBase, refs.model)
end

-- Water upgrades sit behind lane 1 (the +Z edge), outside the tile grid, so lanes, tiles and
-- zombie paths are untouched. Rebuilt from the saved flags.
function PlotBuilder.setWater(refs: PlotRefs, water: { channel: boolean, sprinkler: boolean, pond: boolean })
	local key = `{water.channel}{water.sprinkler}{water.pond}`
	if refs.water:GetAttribute("Key") == key then
		return
	end
	refs.water:SetAttribute("Key", key)
	refs.water:ClearAllChildren()
	local cf = refs.cframe
	local gardenW, gardenD = P.Columns * T, P.Lanes * T
	local midX = P.GardenOriginX + gardenW / 2
	local z = gardenD / 2 + 3
	local blue = Color3.fromRGB(70, 170, 255)
	if water.channel or water.sprinkler or water.pond then
		Parts.make({
			Name = "ChannelStone", Parent = refs.water, Color = Color3.fromRGB(150, 150, 158),
			Size = Vector3.new(gardenW + 2, 0.8, 4), CFrame = cf * CFrame.new(midX, 0.4, z),
		})
		Parts.make({
			Name = "ChannelWater", Parent = refs.water, Color = blue, Material = Enum.Material.Glass,
			Transparency = 0.25, CanCollide = false,
			Size = Vector3.new(gardenW, 0.3, 2.6), CFrame = cf * CFrame.new(midX, 0.85, z),
		})
	end
	if water.sprinkler or water.pond then
		for i = 0, 3 do
			local x = P.GardenOriginX + gardenW * (i + 0.5) / 4
			local head = Parts.make({
				Name = "Sprinkler", Parent = refs.water, Color = Color3.fromRGB(200, 200, 210),
				Size = Vector3.new(0.6, 2.4, 0.6), CFrame = cf * CFrame.new(x, 1.2, z - 2.4),
			})
			local spray = Instance.new("ParticleEmitter")
			spray.Color = ColorSequence.new(Color3.fromRGB(170, 220, 255))
			spray.Rate = 6
			spray.Lifetime = NumberRange.new(0.8, 1.2)
			spray.Speed = NumberRange.new(6, 9)
			spray.SpreadAngle = Vector2.new(40, 40)
			spray.Size = NumberSequence.new(0.25)
			spray.Transparency = NumberSequence.new(0.3)
			spray.Acceleration = Vector3.new(0, -20, 0)
			spray.Parent = head
		end
	end
	if water.pond then
		Parts.make({
			Name = "PondRim", Parent = refs.water, Color = Color3.fromRGB(150, 150, 158),
			Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 19, 19),
			CFrame = cf * CFrame.new(midX, 0.4, z + 13) * CFrame.Angles(0, 0, math.rad(90)),
		})
		Parts.make({
			Name = "PondWater", Parent = refs.water, Color = blue, Material = Enum.Material.Glass,
			Transparency = 0.2, CanCollide = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 17, 17),
			CFrame = cf * CFrame.new(midX, 0.85, z + 13) * CFrame.Angles(0, 0, math.rad(90)),
		})
	end
end

return PlotBuilder
